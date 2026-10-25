class_name Player
extends CharacterBody2D
## The little guy: runs, jumps, and makes his own bombs: [Z] pulls one out of his ammo (5) and
## throws it; holding [A] squeezes out more (eyes screwed shut); a tap of [A] sets one off.

signal hp_changed(hp: int)
signal died
signal fell_in_pit
signal ammo_changed(ammo: int)

const MAX_HP := 5
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const FLOOR_Y := 640.0
const PIT_Y := 820.0  # below the floor: fell through a collapsed panel
const AIM_DOTS := 14
const AIM_STEP := 0.06
const DUST := preload("res://scenes/fx/dust.tscn")
const POOF := preload("res://scenes/fx/poof.tscn")
const SLIME := preload("res://scenes/fx/slime.tscn")
const GHOST := preload("res://scenes/fx/afterimage.tscn")
const HARD_LANDING := 1500.0  # px/s fall speed for the biggest landing squash
const BOMB := preload("res://scenes/boss/bomb.tscn")
const MAX_AMMO := 5
const CHARGE_DELAY := 0.2  # s of holding [A] before he starts squeezing (a tap only detonates)
const CHARGE_TIME := 0.6  # s of squeezing per bomb
const KNOCKBACK := 480.0  # px/s a hit shoves him off whatever hit him
const KNOCK_HOP := -380.0  # ...with a little hop
const BOMB_BOUNCE := Vector2(650.0, -1150.0)  # off a blast: sideways away from it (at most), always this fast up
const AIM_AHEAD := Vector2(100.0, 2400.0)  # a throw aims at a core this far ahead of him (min, max px)
const MAX_FLIGHT := 1.5  # s: a far core gets a faster throw instead of a sky-high one

@export var speed := 330.0
@export var accel := 2600.0
@export var gravity := 2000.0
@export var jump_velocity := -900.0
@export var throw_velocity := Vector2(620, -760)
@export var lob_velocity := Vector2(300, -900)  # used while aim_up is held
@export var dash_speed := 1235.0  # for DashTimer.wait_time (~200 px); i-frames the whole way

var hp := MAX_HP
var facing := 1
var held_bomb: Bomb = null
var dashing: bool:
	get:
		return not dash_timer.is_stopped()
var _coyote := 0.0
var _jump_buffer := 0.0
var _was_on_floor := true
var _dead := false
var _air_dash_ready := true  # one dash per jump
var _air_jump_ready := true  # one jump in mid-air (after a dash, off a ledge, or a double jump)
var _dash_dir := Vector2.RIGHT
var _dash_grounded := false  # started on the floor (and not upward): you can still jump out of it
var frozen := false  # cutscenes: no control and no harm, he just stands and watches
var _thrown: Bomb = null  # the last bomb he threw, for [A] to set off
var ammo := MAX_AMMO
var charging := false  # squeezing out a bomb
var projectiles: Node  # where his bombs go (the arena's Projectiles); his parent if unset
var _charge_held := 0.0
var _charge_left := 0.0

@onready var art: Node2D = $Art
@onready var flip: Node2D = $Art/Flip
@onready var body: AnimatedSprite2D = $Art/Flip/Body
@onready var hold_point: Marker2D = $HoldPoint
@onready var pickup_area: Area2D = $PickupArea
@onready var hurtbox: Area2D = $Hurtbox
@onready var invuln: Timer = $InvulnTimer
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var aim: Node2D = $Aim
@onready var prompt: Sprite2D = $Prompt
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown: Timer = $DashCooldown
@onready var trail: CPUParticles2D = $Trail
@onready var juice: AnimationPlayer = $Juice
@onready var ghost_timer: Timer = $GhostTimer
@onready var crown: Sprite2D = $Art/Crown


func _ready() -> void:
	add_to_group("player")
	hurtbox.area_entered.connect(take_hit)
	invuln.timeout.connect(_on_invuln_timeout)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if global_position.y > PIT_Y:
		fell_in_pit.emit()
		return
	if frozen:
		_stand_still(delta)
		return
	_charge(delta)
	var dir := 0.0 if charging else Input.get_axis("move_left", "move_right")
	if dir != 0.0 and not dashing:
		var turned := (1 if dir > 0.0 else -1) != facing
		facing = 1 if dir > 0.0 else -1
		flip.scale.x = facing
		if turned and is_on_floor() and absf(velocity.x) > speed * 0.5:
			_squash(Vector2(0.85, 1.1))  # skid into the turn
			_puff(DUST, _feet())

	if is_on_floor() or (dashing and _dash_grounded):
		_coyote = COYOTE_TIME  # a ground dash off a ledge can still jump at the end
		_air_dash_ready = _air_dash_ready or is_on_floor()
		_air_jump_ready = _air_jump_ready or is_on_floor()
	else:
		_coyote -= delta
	if Input.is_action_just_pressed("dash") and dash_cooldown.is_stopped() and _air_dash_ready:
		_start_dash()
	if dashing:
		velocity = _dash_dir * dash_speed
	else:
		velocity.x = move_toward(velocity.x, dir * speed, accel * delta)
		if not is_on_floor():
			velocity.y += gravity * delta

	_jump_buffer = JUMP_BUFFER if Input.is_action_just_pressed("jump") else _jump_buffer - delta
	if _jump_buffer > 0.0 and (_coyote > 0.0 or _air_jump_ready):
		var midair := _coyote <= 0.0
		if midair:
			_air_jump_ready = false
		if dashing:
			_cancel_dash()
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		juice.play(&"jump")  # squash, then a big stretch off the ground
		_puff(SLIME if midair else DUST, _feet())  # a slimy splat when he kicks off thin air
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5

	var fall := velocity.y
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_land(clampf(fall / HARD_LANDING, 0.0, 1.0))
	_was_on_floor = is_on_floor()

	if not is_instance_valid(held_bomb) or held_bomb.exploded:
		held_bomb = null
	if Input.is_action_just_pressed("grab"):
		if held_bomb:
			_throw()
		else:
			_grab()
	if Input.is_action_just_pressed("detonate"):
		_detonate()
	if held_bomb:
		held_bomb.global_position = hold_point.global_position
	_update_aim()
	_update_prompt()
	_update_pose(dir)


## Frozen for a cutscene: he slows to a stop and drops onto the floor, nothing else.
func _stand_still(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, accel * delta)
	velocity.y += gravity * delta
	move_and_slide()
	if not is_instance_valid(held_bomb):
		held_bomb = null  # the cutscene clears the bombs
	aim.points = PackedVector2Array()
	prompt.hide()
	_update_pose(0.0)


## The ending: the king's crown lands on his head (much too big). Clonk.
func wear_crown() -> void:
	crown.show()
	_squash(Vector2(1.4, 0.6))
	_puff(DUST, _feet())


## `from` is the hazard that hit him (null for a fall): he is knocked back off it.
func take_hit(from: Area2D = null) -> void:
	if _dead or frozen or dashing or not invuln.is_stopped():
		return
	hp -= 1
	hp_changed.emit(hp)
	get_tree().call_group("camera", "shake", 8.0)
	get_tree().call_group("hud", "flash", 0.85)
	get_tree().call_group("camera", "hitstop", 0.1)
	if hp <= 0:
		_die()
		return
	invuln.start()
	anim.play(&"hurt")
	_squash(Vector2(1.3, 0.7))
	velocity = _knockback(from)


## A small shove away from what hit him, with a little hop. A beam (a hazard more than 4x
## longer than wide: the eye laser, a lightning column, a zapped floor strip) shoves him off its
## line instead, toward whichever side of it he is on.
func _knockback(from: Area2D) -> Vector2:
	var away := Vector2(-facing, 0.0)
	if from:
		away = global_position - from.global_position
		var box := from.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var rect: RectangleShape2D = box.shape as RectangleShape2D if box else null
		if rect and maxf(rect.size.x, rect.size.y) > 4.0 * minf(rect.size.x, rect.size.y):
			var along := (box.global_transform.x if rect.size.x > rect.size.y else box.global_transform.y).normalized()
			var off := global_position - box.global_position
			away = off - along * off.dot(along)
	if away.length() < 1.0:
		away = Vector2(-facing, 0.0)
	var shove := away.normalized() * KNOCKBACK
	return Vector2(shove.x, minf(shove.y, 0.0) + KNOCK_HOP)


## Short burst with i-frames, a stretch and a streak trail, in any of 8 directions: the held
## arrows aim it (same distance diagonally), no arrows means straight ahead. On the ground a
## downward aim can't dig in, so only its sideways part counts.
func _start_dash() -> void:
	var aim := Input.get_vector("move_left", "move_right", "aim_up", "move_down")
	if is_on_floor():
		aim.y = minf(aim.y, 0.0)
	_dash_dir = Vector2(facing, 0.0) if aim.is_zero_approx() else aim.normalized()
	_dash_grounded = is_on_floor() and _dash_dir.y >= 0.0
	if not is_on_floor() or _dash_dir.y < 0.0:
		_air_dash_ready = false  # an upward dash off the ground is the air dash
	dash_timer.start()
	dash_cooldown.start()
	trail.rotation = _dash_dir.angle()  # spreads the streaks along the path...
	trail.angle_min = rad_to_deg(trail.rotation)  # ...and points each one along it
	trail.angle_max = trail.angle_min
	trail.emitting = true
	ghost_timer.start()
	_spawn_ghost()
	juice.play(&"dash_v" if absf(_dash_dir.y) > absf(_dash_dir.x) else &"dash")
	_puff(DUST if is_on_floor() else SLIME, _feet())


## Jump pressed mid-dash: the dash ends early and the jump keeps most of its sideways speed.
func _cancel_dash() -> void:
	dash_timer.stop()
	ghost_timer.stop()
	trail.emitting = false
	velocity.x = _dash_dir.x * dash_speed * 0.7


## DashTimer.timeout (connected in the scene). If the dash ended inside a hazard, it still hurts.
func _end_dash() -> void:
	ghost_timer.stop()
	trail.emitting = false
	velocity = _dash_dir * speed  # a little carry, not the full burst
	if hurtbox.monitoring and hurtbox.has_overlapping_areas():
		take_hit(hurtbox.get_overlapping_areas()[0])


func reset(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	hp = MAX_HP
	ammo = MAX_AMMO
	ammo_changed.emit(ammo)
	held_bomb = null
	_dead = false
	invuln.stop()
	show()
	hp_changed.emit(hp)


func _die() -> void:
	_dead = true
	if is_instance_valid(held_bomb):
		held_bomb.queue_free()
	held_bomb = null
	aim.points = PackedVector2Array()
	prompt.hide()
	hide()
	_puff(POOF, global_position)
	died.emit()


func _nearest_bomb() -> Bomb:
	var best: Bomb = null
	for overlap in pickup_area.get_overlapping_bodies():
		var bomb := overlap as Bomb
		if bomb == null or bomb.exploded:
			continue
		if best == null or global_position.distance_to(bomb.global_position) < global_position.distance_to(best.global_position):
			best = bomb
	return best


## [Z] with empty hands: picks up a bomb lying in reach, else pulls a new one out of his ammo.
func _grab() -> void:
	var best := _nearest_bomb()
	if best == null and ammo > 0:
		best = _make_bomb()
	if best:
		best.pick_up()
		held_bomb = best
		juice.play(&"grab")


## A plain throw at an armed core ahead of him is aimed: the usual sideways speed (faster for a far
## core), with the lift solved so the arc passes through the core (the aim dots show it). Lobs
## (aim_up) stay manual.
func _make_bomb() -> Bomb:
	var bomb: Bomb = BOMB.instantiate()
	(projectiles if projectiles else get_parent()).add_child(bomb)
	bomb.global_position = hold_point.global_position
	ammo -= 1
	ammo_changed.emit(ammo)
	return bomb


## Holding [A] with empty hands, on the ground, short of bombs: after CHARGE_DELAY he stops and
## squeezes (squashed flat, eyes screwed shut), a new bomb every CHARGE_TIME.
func _charge(delta: float) -> void:
	var squeezing := Input.is_action_pressed("detonate") and not is_instance_valid(held_bomb) and is_on_floor() and not dashing and ammo < MAX_AMMO
	_charge_held = _charge_held + delta if squeezing else 0.0
	var was := charging
	charging = _charge_held >= CHARGE_DELAY
	if not charging:
		if was:
			_squash(Vector2(0.85, 1.2))  # pops back up
		return
	if not was:
		_charge_left = CHARGE_TIME
	_charge_left -= delta
	if _charge_left <= 0.0:
		_charge_left = CHARGE_TIME
		ammo += 1
		ammo_changed.emit(ammo)
		_puff(POOF, hold_point.global_position)


func _throw_velocity() -> Vector2:
	if Input.is_action_pressed("aim_up"):
		return Vector2(lob_velocity.x * facing, lob_velocity.y)
	var target := _bomb_target()
	if target == null:
		return Vector2(throw_velocity.x * facing, throw_velocity.y)
	var start := held_bomb.global_position
	var g: float = ProjectSettings.get_setting("physics/2d/default_gravity") * held_bomb.gravity_scale
	var reach := absf(target.global_position.x - start.x)
	var t := minf(reach / throw_velocity.x, MAX_FLIGHT)
	var lift := (target.global_position.y - start.y - 0.5 * g * t * t) / t
	return Vector2(reach / t * facing, clampf(lift, -1500.0, 200.0))


## The nearest armed bomb target (a core's WeakPoint, group "bomb_target") ahead of him.
func _bomb_target() -> Area2D:
	var best: Area2D = null
	for spot: Area2D in get_tree().get_nodes_in_group(&"bomb_target"):
		var ahead := (spot.global_position.x - global_position.x) * facing
		if not spot.monitoring or not spot.is_visible_in_tree() or ahead < AIM_AHEAD.x or ahead > AIM_AHEAD.y:
			continue
		if best == null or spot.global_position.distance_to(global_position) < best.global_position.distance_to(global_position):
			best = spot
	return best


func _throw() -> void:
	held_bomb.target = _bomb_target()
	held_bomb.throw(_throw_velocity())
	_thrown = held_bomb
	held_bomb = null
	juice.play(&"throw")


## [A]: sets a bomb off right now: the one in his hands (overhead, so it rockets him straight
## up), else the last one he threw.
func _detonate() -> void:
	var bomb: Bomb = held_bomb if held_bomb else _thrown
	if is_instance_valid(bomb) and not bomb.exploded:
		bomb.explode()


## Bomb blasts never hurt the little guy. One within reach bounces him away from it, always
## upward, and gives him back his air jump and dash: a bomb under him is a rocket jump.
func blast_from(at: Vector2, reach: float) -> void:
	var away := global_position - at
	if _dead or frozen or away.length() > reach:
		return
	if dashing:
		_cancel_dash()
	velocity = Vector2(clampf(away.x / reach, -1.0, 1.0) * BOMB_BOUNCE.x, BOMB_BOUNCE.y)
	_coyote = 0.0
	_air_jump_ready = true
	_air_dash_ready = true
	juice.play(&"jump")
	_puff(SLIME, _feet())


## Predicts the bomb's flight with the same gravity the RigidBody2D will feel.
func _update_aim() -> void:
	var dots := PackedVector2Array()
	if held_bomb:
		var g := Vector2(0.0, ProjectSettings.get_setting("physics/2d/default_gravity") * held_bomb.gravity_scale)
		var v := _throw_velocity()
		var start := held_bomb.global_position
		for i in range(1, AIM_DOTS + 1):
			var t := i * AIM_STEP
			var p := start + v * t + 0.5 * g * t * t
			if p.y > FLOOR_Y:
				break
			dots.append(p)
	aim.points = dots


## Shows the J key over the bomb the player would grab right now.
func _update_prompt() -> void:
	var target: Bomb = null if held_bomb else _nearest_bomb()
	prompt.visible = target != null
	if target:
		prompt.global_position = target.global_position + Vector2(0, -96)


## Landing squash that grows with the fall: a hop barely squashes, a big drop flattens him,
## kicks up extra dust and bumps the camera.
func _land(impact: float) -> void:
	_squash(Vector2(1.1 + 0.3 * impact, 0.9 - 0.25 * impact))
	_puff(DUST, _feet())
	if impact > 0.7:
		_puff(DUST, _feet() + Vector2(-36, 0))
		_puff(DUST, _feet() + Vector2(36, 0))
		get_tree().call_group("camera", "shake", 5.0)


## GhostTimer.timeout (connected in the scene): leave a fading mint copy of this frame behind.
func _spawn_ghost() -> void:
	var ghost: Sprite2D = GHOST.instantiate()
	ghost.texture = body.sprite_frames.get_frame_texture(body.animation, body.frame)
	get_parent().add_child(ghost)
	ghost.global_transform = body.global_transform


## Body.frame_changed (connected in the scene): a dust kick once per running stride.
func _on_body_frame_changed() -> void:
	if body.animation in [&"run", &"carry_run"] and body.frame == 1 and is_on_floor():
		_puff(DUST, _feet() - Vector2(facing * 20, 0))


func _feet() -> Vector2:
	return global_position + Vector2(0, 26)


func _puff(scene: PackedScene, at: Vector2) -> void:
	var fx: Node2D = scene.instantiate()
	get_parent().add_child(fx)
	fx.global_position = at


func _on_invuln_timeout() -> void:
	if hurtbox.monitoring and hurtbox.has_overlapping_areas():
		take_hit(hurtbox.get_overlapping_areas()[0])


func _squash(s: Vector2) -> void:
	art.scale = s
	create_tween().tween_property(art, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_pose(dir: float) -> void:
	var moving := is_on_floor() and dir != 0.0
	var pose := &"idle"
	if invuln.time_left > invuln.wait_time - 0.25:
		pose = &"hurt"
	elif charging:
		pose = &"strain"
		art.scale = Vector2(1.16 + sin(Time.get_ticks_msec() * 0.04) * 0.05, 0.8)  # squeezing
	elif dashing and not held_bomb and absf(_dash_dir.x) >= absf(_dash_dir.y):
		pose = &"dash"  # steep dashes fall through to the jump / fall poses
	elif held_bomb:
		pose = &"carry_run" if moving else &"carry"
	elif not is_on_floor():
		pose = &"jump" if velocity.y < 0.0 else &"fall"
	elif moving:
		pose = &"run"
	if body.animation != pose:
		body.play(pose)
