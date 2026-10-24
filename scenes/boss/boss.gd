class_name Boss
extends Node2D
## King Kilowatt, too big for the screen. Stage 1 only his legs fit in frame (weak spot: the
## front knee); break them and the torso crashes down, head on its shoulders (chest core);
## break that and the head pops off and flies on jet boosters (the eye). Break the head and it
## shatters; he lies in pieces until Lil' Watt's power reaches the wreck (revive()), then rises
## as a giant as tall as the zoomed-out screen (phase 4). Hits on Lil' Watt reach him through
## power_hit(). Only thrown bombs hurt, and each hit cracks the part being fought.
## Attacks live in the AnimationPlayer: value tracks move the rig and toggle hitboxes, method
## tracks call stomp_* / aim_* / swoop / rain_bomb / spawn_bomb / spit_bomb / boom / land / shake.
## Moves that chase the player (the stomp's walk, the head's dash) are tweens started there.
## Between attacks he roams: he drifts either side of his spot near the player, legs stepping.

signal health_changed(hits_left: int, hits_total: int)
signal phase_changed(phase: int)  # 0-based: the second phase emits 1
signal defeated
signal attack_started(attack: StringName)
signal revived  # phase 4: back on his feet, giant-sized, and about to fight

enum State { INTRO, IDLE, ATTACK, STAGGER, PHASE_SHIFT, DEAD }

const HITS_PER_PHASE := 3
const FLOOR_Y := 640.0
const BOMB_SCENE := preload("res://scenes/boss/bomb.tscn")
const SHOCKWAVE_SCENE := preload("res://scenes/boss/shockwave.tscn")
const SPARK_SCENE := preload("res://scenes/fx/spark.tscn")
const EXPLOSION_SCENE := preload("res://scenes/fx/explosion.tscn")
const DUST_SCENE := preload("res://scenes/fx/dust.tscn")
const PHASES := [
	{attacks = [&"stomp", &"rain"], speed = 1.0, rest = 1.2},  # legs
	{attacks = [&"swipe", &"bombs"], speed = 1.2, rest = 0.9},  # torso (moves by roaming, no charge)
	{attacks = [&"swoop", &"spit", &"laser", &"spit"], speed = 1.3, rest = 0.7},  # head
	{attacks = [&"step", &"rain", &"laser", &"rain"], speed = 1.0, rest = 1.1},  # rebuilt giant
]
const FINAL := 3  # the rebuilt giant's phase: no weak spot of his own, Lil' Watt powers him
const GROWN_SCALE := 1.58  # the giant's crown reaches the top of the 3x zoomed-out view
const GROWN_POS := Vector2(-661, -371)  # Rig offset once he has grown, scaled about his feet (1140, 640)
const FINAL_X := 780.0  # where the giant rises: torso at x 1920, mid screen, in the lava moat
const GIANT_ROAM := 420.0  # px the giant may step either side of his spot (he stays in his moat)
const GIANT_BIG_BOMB := 2.5  # phase 4's rain bombs, scaled up for the zoomed-out view

@export var projectiles: Node2D

# The king rides a rail behind the arena: between attacks he slides to stay RAIL_LEAD px
# right of the player. Boss.position.x offsets the whole rig (torso rests at local x 1080;
# the knee, chest and eye cores all sit near it, so the same throw reaches each stage).
const RAIL_MIN := 0.0
const RAIL_MAX := 1280.0
const RAIL_LEAD := 560.0
const RAIL_SPEED := 300.0
const WANDER := 260.0  # px he roams either side of his spot near the player
const WANDER_RATE := 0.6  # rad/s of the roaming sway
const STRIDE := 36.0  # px a leg lifts per step while he walks
const DASH_OVERSHOOT := 300.0  # px the head dashes past where it aimed
const TORSO_X := 1080.0
const ARENA_W := 2560.0
const DOOM_W := 3840.0  # phase 4's arena of doom (one zoomed-out screen)

var state := State.INTRO
var phase := 0
var hp := HITS_PER_PHASE
var _attack_index := 0
var _rest_pose := {}
var _rail_dust := 0.0
var _move: Tween  # the running chase tween (stomp walk / head dash), killed on any new animation
var _wander := 0.0
var _stride := 0.0
var _dash_target := Vector2.ZERO

@onready var rig: Node2D = $Rig
@onready var legs: Node2D = $Rig/Legs
@onready var stomp_anchor: Node2D = $Rig/Legs/StompAnchor
@onready var stomp_ring: Node2D = $Rig/Legs/StompRing
@onready var leg_f: Node2D = $Rig/Legs/StompAnchor/LegF
@onready var leg_b: Node2D = $Rig/Legs/LegB
@onready var upper: Node2D = $Rig/Upper
@onready var head: Node2D = $Rig/Upper/Head
@onready var eye: Node2D = $Rig/Upper/Head/Eye
@onready var mouth: Marker2D = $Rig/Upper/Head/Mouth
@onready var eye_beam: Node2D = $Rig/Upper/Head/EyeBeam
@onready var dash_beam: Node2D = $Rig/Upper/Head/DashBeam
@onready var fallen_crown: Node2D = $Rig/Upper/FallenCrown
@onready var body: Node2D = $Rig/Upper/Body
@onready var fist_l: Node2D = $Rig/Upper/Body/FistL
@onready var bomb_spawn: Marker2D = $Rig/Upper/Body/FistL/BombSpawn
@onready var cores: Array = [$Rig/Legs/StompAnchor/LegF/KneeCore, $Rig/Upper/Body/Core, $Rig/Upper/Head/EyeCore]
@onready var cracks: Array = [$Rig/Legs/StompAnchor/LegF/Cracks, $Rig/Upper/Body/Cracks, $Rig/Upper/Head/Cracks]
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var rest_timer: Timer = $RestTimer


func _ready() -> void:
	_capture_rest_pose()
	for core: Node2D in cores:
		core.get_node("WeakPoint").body_entered.connect(_on_weak_point_body_entered)
	anim.animation_finished.connect(_on_animation_finished)
	rest_timer.timeout.connect(_on_rest_timer_timeout)


## Drops into the arena right next to the player (hidden until now in the arena scene).
func start_fight() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		position.x = _rail_goal(player)
	show()
	_play(&"intro", State.INTRO)


## His eye always looks at the player (the art's pupil looks left, hence the half turn).
func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		eye.global_rotation = (player.global_position - eye.global_position).angle() - PI


## Rides the rail while resting, roaming either side of his spot near the player so attacks
## still land close; in the legs stage the legs step as he walks.
func _physics_process(delta: float) -> void:
	if state != State.IDLE or phase == FINAL:  # the giant stands his ground
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	_wander += WANDER_RATE * delta
	var goal := clampf(_rail_goal(player) + sin(_wander) * WANDER, RAIL_MIN, RAIL_MAX)
	var before := position.x
	position.x = move_toward(position.x, goal, RAIL_SPEED * delta)
	var moving := absf(position.x - before) > 0.1
	if moving:
		_rail_dust -= delta
		if _rail_dust <= 0.0:
			_rail_dust = 0.2
			_fx(DUST_SCENE, Vector2(weak_point().global_position.x + randf_range(-150.0, 150.0), FLOOR_Y - 16.0))
	if phase == 0:
		_step_legs(delta, moving)


## Walking legs: front and back lift in turn; a foot coming down kicks up dust.
func _step_legs(delta: float, moving: bool) -> void:
	var before := signf(sin(_stride))
	_stride = _stride + 7.0 * delta if moving else 0.0
	var lift := sin(_stride) * STRIDE
	leg_f.position.y = -maxf(lift, 0.0)
	leg_b.position.y = -maxf(-lift, 0.0)
	if moving and signf(sin(_stride)) != before:
		var foot: Node2D = (leg_b if before > 0.0 else leg_f).get_node("Foot")
		_fx(DUST_SCENE, Vector2(foot.global_position.x, FLOOR_Y - 16.0))


func _rail_goal(player: Node2D) -> float:
	return clampf(player.global_position.x + RAIL_LEAD - TORSO_X, RAIL_MIN, RAIL_MAX)


## Cracks spread over the part being fought as it takes hits: one, then all three.
func _show_cracks() -> void:
	if phase >= cracks.size():
		return
	var damage := HITS_PER_PHASE - hp
	var shown := damage * (damage + 1) / 2
	for i in cracks[phase].get_child_count():
		cracks[phase].get_child(i).visible = i < shown


## The core to hit right now: the front knee, then the chest, then the eye; the giant's chest is
## where Lil' Watt's power goes in.
func weak_point() -> Node2D:
	return cores[1] if phase == FINAL else cores[phase]


## Phase 4: each hit on Lil' Watt, his power source, costs the giant a hit.
func power_hit() -> void:
	if phase != FINAL or state == State.DEAD:
		return
	hp -= 1
	health_changed.emit(hp, HITS_PER_PHASE)
	get_tree().call_group("hud", "flash", 0.8)
	get_tree().call_group("camera", "hitstop", 0.12)
	if hp <= 0:
		_advance_phase()


func hits_total() -> int:
	return HITS_PER_PHASE * PHASES.size()


func hits_left() -> int:
	return (PHASES.size() - 1 - phase) * HITS_PER_PHASE + hp


func next_attack() -> StringName:
	var attacks: Array = PHASES[phase].attacks
	var attack: StringName = attacks[_attack_index % attacks.size()]
	_attack_index += 1
	return attack


## Returns true if the hit counted. The boss is only vulnerable while idle or attacking.
func take_hit() -> bool:
	if state != State.IDLE and state != State.ATTACK:
		return false
	hp -= 1
	_show_cracks()
	health_changed.emit(hits_left(), hits_total())
	get_tree().call_group("hud", "flash", 0.8)
	get_tree().call_group("camera", "hitstop", 0.12)
	_fx(SPARK_SCENE, weak_point().global_position)
	if hp <= 0:
		_advance_phase()
	else:
		_play(&"stagger", State.STAGGER)
	return true


func restart_phase() -> void:
	if state == State.DEAD or state == State.PHASE_SHIFT:  # never cut a stage break short
		return
	hp = HITS_PER_PHASE
	_attack_index = 0
	_show_cracks()
	health_changed.emit(hits_left(), hits_total())
	_rest()


## Debug shortcut: jump to the next phase (from the last phase, straight to the knockout).
func skip_phase() -> void:
	if state == State.DEAD:
		return
	hp = 0
	health_changed.emit(hits_left(), hits_total())
	_advance_phase()


# --- called from animation method tracks ---

## Stage 1: the lifted front leg walks over to the player; a red ring marks where it lands.
func stomp_aim() -> void:
	var x := _player_x()
	stomp_ring.global_position.x = x
	_chase().tween_property(stomp_anchor, "global_position:x", x, 0.45 / anim.speed_scale).set_trans(Tween.TRANS_SINE)


func stomp_impact() -> void:
	_quake(stomp_anchor.global_position.x, 20.0)


## ...and walks back to stand under him.
func stomp_return() -> void:
	_chase().tween_property(stomp_anchor, "position:x", _rest_pose[stomp_anchor].x, 0.4 / anim.speed_scale).set_trans(Tween.TRANS_SINE)


## Stage 4: with his front leg raised, the giant steps his whole body toward the player (staying
## within GIANT_ROAM of his spot in the moat), so the foot comes down as near him as it can while
## staying under the torso. The red ring is held on its floor spot while the rig carries it.
func step_aim() -> void:
	var goal := clampf(position.x + _player_x() - stomp_anchor.global_position.x, FINAL_X - GIANT_ROAM, FINAL_X + GIANT_ROAM)
	var spot := stomp_anchor.global_position.x + goal - position.x
	stomp_ring.global_position.x = spot
	var walk := _chase().set_parallel()
	walk.tween_property(self, "position:x", goal, 0.45 / anim.speed_scale).set_trans(Tween.TRANS_SINE)
	walk.tween_property(stomp_ring, "global_position:x", spot, 0.45 / anim.speed_scale)


## ...then steps back to his spot in the moat, under the moon.
func step_home() -> void:
	_chase().tween_property(self, "position:x", FINAL_X, 0.4 / anim.speed_scale).set_trans(Tween.TRANS_SINE)


## Stage 3 tell: aim the dash at the player (called repeatedly, then it locks) and lay the
## light beam along that line.
func aim_dash() -> void:
	_dash_target = _player_pos()
	_dash_target.y = minf(_dash_target.y, 540.0)  # the head must not dash into the floor
	dash_beam.global_rotation = (_dash_target - head.global_position).angle()


## Stage 3: the head dashes straight along the beam, through the aimed spot and past it, then
## flies home (the swoop animation flashes it white and keeps the ram hitbox live). Diving at
## a spot by the floor, it hits the spot and skids on along the floor instead of into it.
func swoop() -> void:
	var dir := (_dash_target - head.global_position).normalized()
	var past := _dash_target + dir * DASH_OVERSHOOT
	var s := anim.speed_scale
	var path := _chase()
	if past.y > 540.0:
		path.tween_property(head, "global_position", _dash_target, 0.28 / s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		past = _dash_target + Vector2(signf(dir.x) * DASH_OVERSHOOT * 0.7, 0.0)
		path.tween_property(head, "global_position:x", clampf(past.x, 80.0, ARENA_W - 80.0), 0.15 / s).set_ease(Tween.EASE_OUT)
	else:
		path.tween_property(head, "global_position", past, 0.35 / s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	path.tween_interval(0.15 / s)
	path.tween_property(head, "position", _rest_pose[head], 0.6 / s).set_trans(Tween.TRANS_SINE)


## Stage 3 laser tell: point the eye beam at the player (called repeatedly, then it locks).
func aim_eye_beam() -> void:
	eye_beam.global_rotation = (_player_pos() - eye_beam.global_position).angle()


func _reset_eye() -> void:
	eye.modulate = Color.WHITE


func spawn_bomb() -> void:
	_drop_bomb(bomb_spawn.global_position, Vector2(randf_range(-650.0, -250.0), -350.0))


## Stages 1 and 4: his hands are out of frame, so bombs fall from the sky near the player
## (from above the zoomed-out view in phase 4).
func rain_bomb() -> void:
	var x := clampf(_player_x() + randf_range(-320.0, 320.0), 80.0, (DOOM_W if phase == FINAL else ARENA_W) - 80.0)
	if phase == FINAL:
		_drop_bomb(Vector2(x, -1500.0), Vector2.ZERO, GIANT_BIG_BOMB)
	else:
		_drop_bomb(Vector2(x, -60.0), Vector2.ZERO)


## Phase 4, once Lil' Watt's power reaches the wreck: the pieces gather mid arena of doom (out
## of sight, he is all in pieces) and rise into the giant. Emits `revived` when he is up.
func revive() -> void:
	if phase != FINAL or state != State.PHASE_SHIFT:
		return
	position.x = FINAL_X
	_play(&"revive", State.PHASE_SHIFT)


## The rebuild in phase 4 mends every crack.
func heal_cracks() -> void:
	for part: Node2D in cracks:
		for crack: Node2D in part.get_children():
			crack.hide()


func spit_bomb() -> void:
	_drop_bomb(mouth.global_position, Vector2(randf_range(-700.0, -350.0), -420.0))


## A huge moment (the head shattering, re-forming, the giant's roar): full white flash and a freeze.
func blast() -> void:
	shake(30.0)
	get_tree().call_group("hud", "flash", 1.0)
	get_tree().call_group("camera", "hitstop", 0.15)


func laser_fire() -> void:
	shake(6.0)


## One blast somewhere on a body part (stage breaks and the knockout chain these).
func boom(part: NodePath) -> void:
	shake(16.0)
	var at: Vector2 = get_node(part).global_position
	_fx(EXPLOSION_SCENE, at + Vector2(randf_range(-150.0, 150.0), randf_range(-150.0, 120.0)))


## A body part hitting the floor: a big shake and dust either side.
func land(part: NodePath) -> void:
	shake(24.0)
	var x: float = get_node(part).global_position.x
	for dir in [-1, 1]:
		_fx(DUST_SCENE, Vector2(x + dir * 120.0, FLOOR_Y - 16.0))


func _fx(scene: PackedScene, at: Vector2) -> void:
	var fx: Node2D = scene.instantiate()
	_spawn_parent().add_child(fx)
	fx.global_position = at


func shake(amount: float) -> void:
	get_tree().call_group("camera", "shake", amount)


func _quake(x: float, amount: float) -> void:
	shake(amount)
	for dir in [-1, 1]:
		var wave: Shockwave = SHOCKWAVE_SCENE.instantiate()
		wave.direction = dir
		_spawn_parent().add_child(wave)
		wave.global_position = Vector2(x, FLOOR_Y)
		_fx(DUST_SCENE, Vector2(x + dir * 72.0, FLOOR_Y - 16.0))


func _chase() -> Tween:
	if _move:
		_move.kill()
	_move = create_tween()
	return _move


func _drop_bomb(at: Vector2, velocity: Vector2, size := 1.0) -> void:
	var bomb: Bomb = BOMB_SCENE.instantiate()
	bomb.size = size
	_spawn_parent().add_child(bomb)
	bomb.global_position = at
	bomb.linear_velocity = velocity


func _player_pos() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player.global_position if player else Vector2(400.0, 560.0)


func _player_x() -> float:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return clampf(player.global_position.x if player else 400.0, 80.0, (DOOM_W if phase == FINAL else ARENA_W) - 80.0)


# --- internals ---

## The state changes now; the animation starts deferred, because a hit arrives inside the
## WeakPoint physics callback and the stage breaks switch weak points on and off.
func _advance_phase() -> void:
	rest_timer.stop()
	if phase == PHASES.size() - 1:
		state = State.DEAD
		_play.call_deferred(&"death", State.DEAD)
		defeated.emit()
		return
	phase += 1
	hp = HITS_PER_PHASE
	_attack_index = 0
	state = State.PHASE_SHIFT
	phase_changed.emit(phase)
	_play.call_deferred(&"shatter" if phase == FINAL else StringName("phase_%d" % (phase + 1)), State.PHASE_SHIFT)


func _rest() -> void:
	_play(StringName("idle_%d" % (phase + 1)), State.IDLE)
	rest_timer.start(PHASES[phase].rest)


func _play(anim_name: StringName, new_state: State) -> void:
	_reset_rig()
	state = new_state
	anim.speed_scale = PHASES[phase].speed
	anim.play(anim_name)
	anim.advance(0.0)  # apply key 0 now so the reset rest pose never renders for a frame


func _reset_rig() -> void:
	if _move:
		_move.kill()
	for n: Node2D in _rest_pose:
		n.position = _rest_pose[n]
	rig.position = GROWN_POS if phase == FINAL else Vector2.ZERO
	rig.modulate = Color.WHITE
	eye.modulate = Color.WHITE
	body.modulate = Color.WHITE
	fist_l.modulate = Color.WHITE
	stomp_ring.hide()
	for box in [leg_f.get_node("Hitbox"), fist_l.get_node("Hitbox"), head.get_node("RamHitbox")]:
		box.get_node("CollisionShape2D").set_deferred("disabled", true)
	eye_beam.get_node("Warn").hide()
	eye_beam.get_node("Beam").hide()
	eye_beam.get_node("Hitbox/CollisionShape2D").set_deferred("disabled", true)
	dash_beam.hide()
	head.material.set_shader_parameter(&"flash", 0.0)


## Where each part sits at rest in this stage (a stage break moves the torso and head).
func _capture_rest_pose() -> void:
	for n: Node2D in [legs, stomp_anchor, leg_f, leg_b, upper, body, head, fist_l]:
		_rest_pose[n] = n.position


func _spawn_parent() -> Node:
	return projectiles if projectiles else get_parent()


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"shatter":
		return  # he lies in pieces until revive()
	if state == State.PHASE_SHIFT:
		_capture_rest_pose()
	if anim_name == &"revive":
		revived.emit()
	if state in [State.INTRO, State.ATTACK, State.STAGGER, State.PHASE_SHIFT]:
		_rest()


func _on_rest_timer_timeout() -> void:
	if state == State.IDLE:
		var attack := next_attack()
		attack_started.emit(attack)
		_play(attack, State.ATTACK)


func _on_weak_point_body_entered(body: Node2D) -> void:
	var bomb := body as Bomb
	if bomb and bomb.thrown and not bomb.exploded:
		bomb.explode()
		take_hit()
