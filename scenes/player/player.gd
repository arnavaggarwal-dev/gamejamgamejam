class_name Player
extends CharacterBody2D
## The little guy: runs, jumps, carries and throws the boss's bombs.

signal hp_changed(hp: int)
signal died
signal fell_in_pit

const MAX_HP := 3
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const FLOOR_Y := 640.0
const PIT_Y := 820.0  # below the floor: fell through a collapsed panel
const AIM_DOTS := 14
const AIM_STEP := 0.06
const DUST := preload("res://scenes/fx/dust.tscn")
const POOF := preload("res://scenes/fx/poof.tscn")

@export var speed := 330.0
@export var accel := 2600.0
@export var gravity := 2000.0
@export var jump_velocity := -900.0
@export var throw_velocity := Vector2(620, -760)
@export var lob_velocity := Vector2(300, -900)  # used while aim_up is held
@export var dash_speed := 950.0  # for DashTimer.wait_time; i-frames the whole way

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


func _ready() -> void:
	add_to_group("player")
	hurtbox.area_entered.connect(func(_area: Area2D) -> void: take_hit())
	invuln.timeout.connect(_on_invuln_timeout)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if global_position.y > PIT_Y:
		fell_in_pit.emit()
		return
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0 and not dashing:
		facing = 1 if dir > 0.0 else -1
		flip.scale.x = facing

	if is_on_floor():
		_coyote = COYOTE_TIME
		_air_dash_ready = true
	else:
		_coyote -= delta
	if Input.is_action_just_pressed("dash") and dash_cooldown.is_stopped() and _air_dash_ready:
		_start_dash()
	if dashing:
		velocity = Vector2(facing * dash_speed, 0.0)
	else:
		velocity.x = move_toward(velocity.x, dir * speed, accel * delta)
		if not is_on_floor():
			velocity.y += gravity * delta

	_jump_buffer = JUMP_BUFFER if Input.is_action_just_pressed("jump") else _jump_buffer - delta
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		_squash(Vector2(0.85, 1.15))
		_puff(DUST, _feet())
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5

	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_squash(Vector2(1.15, 0.85))
		_puff(DUST, _feet())
	_was_on_floor = is_on_floor()

	if not is_instance_valid(held_bomb) or held_bomb.exploded:
		held_bomb = null
	if Input.is_action_just_pressed("grab"):
		if held_bomb:
			_throw()
		else:
			_grab()
	if held_bomb:
		held_bomb.global_position = hold_point.global_position
	_update_aim()
	_update_prompt()
	_update_pose(dir)


func take_hit() -> void:
	if _dead or dashing or not invuln.is_stopped():
		return
	hp -= 1
	hp_changed.emit(hp)
	get_tree().call_group("camera", "shake", 8.0)
	if hp <= 0:
		_die()
		return
	invuln.start()
	anim.play(&"hurt")
	velocity = Vector2(-facing * 260.0, -380.0)


## Short burst in the facing direction with i-frames, a stretch and a streak trail.
func _start_dash() -> void:
	if not is_on_floor():
		_air_dash_ready = false
	dash_timer.start()
	dash_cooldown.start()
	trail.emitting = true
	juice.play(&"dash")
	_puff(DUST, _feet())


## DashTimer.timeout (connected in the scene). If the dash ended inside a hazard, it still hurts.
func _end_dash() -> void:
	trail.emitting = false
	velocity.x = facing * speed
	if hurtbox.monitoring and hurtbox.has_overlapping_areas():
		take_hit()


func reset(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	hp = MAX_HP
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


func _grab() -> void:
	var best := _nearest_bomb()
	if best:
		best.pick_up()
		held_bomb = best


func _throw_velocity() -> Vector2:
	var v := lob_velocity if Input.is_action_pressed("aim_up") else throw_velocity
	return Vector2(v.x * facing, v.y)


func _throw() -> void:
	held_bomb.throw(_throw_velocity())
	held_bomb = null


## Predicts the bomb's flight with the same gravity the RigidBody2D will feel.
func _update_aim() -> void:
	var dots := PackedVector2Array()
	if held_bomb:
		var g := Vector2(0.0, ProjectSettings.get_setting("physics/2d/default_gravity") * held_bomb.gravity_scale)
		var v := _throw_velocity()
		var start := hold_point.global_position
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


func _feet() -> Vector2:
	return global_position + Vector2(0, 26)


func _puff(scene: PackedScene, at: Vector2) -> void:
	var fx: Node2D = scene.instantiate()
	get_parent().add_child(fx)
	fx.global_position = at


func _on_invuln_timeout() -> void:
	if hurtbox.monitoring and hurtbox.has_overlapping_areas():
		take_hit()


func _squash(s: Vector2) -> void:
	art.scale = s
	create_tween().tween_property(art, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_pose(dir: float) -> void:
	var moving := is_on_floor() and dir != 0.0
	var pose := &"idle"
	if invuln.time_left > invuln.wait_time - 0.25:
		pose = &"hurt"
	elif dashing and not held_bomb:
		pose = &"dash"
	elif held_bomb:
		pose = &"carry_run" if moving else &"carry"
	elif not is_on_floor():
		pose = &"jump" if velocity.y < 0.0 else &"fall"
	elif moving:
		pose = &"run"
	if body.animation != pose:
		body.play(pose)
