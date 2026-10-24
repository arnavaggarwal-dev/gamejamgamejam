class_name Boss
extends Node2D
## King Kilowatt, too big for the screen. Stage 1 only his legs fit in frame (weak spot: the
## front knee); break them and the torso crashes down (chest core); break that and the head
## drops onto the floor (the eye). Only thrown bombs hurt him.
## Attacks live in the AnimationPlayer: value tracks move the rig and toggle hitboxes, method
## tracks call aim_* / *_impact / rain_bomb / spawn_bomb / spit_bomb / boom / land / shake.

signal health_changed(hits_left: int, hits_total: int)
signal phase_changed(phase: int)  # 0-based: the second phase emits 1
signal defeated
signal attack_started(attack: StringName)

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
	{attacks = [&"slam", &"bombs", &"laser", &"bombs"], speed = 1.2, rest = 0.9},  # torso
	{attacks = [&"hop", &"spit", &"laser", &"spit"], speed = 1.4, rest = 0.7},  # head
]

@export var projectiles: Node2D

# The king rides a rail behind the arena: between attacks he slides to stay RAIL_LEAD px
# right of the player. Boss.position.x offsets the whole rig (torso rests at local x 1080;
# the knee, chest and eye cores all sit near it, so the same throw reaches each stage).
const RAIL_MIN := 0.0
const RAIL_MAX := 1280.0
const RAIL_LEAD := 560.0
const RAIL_SPEED := 260.0
const TORSO_X := 1080.0
const ARENA_W := 2560.0

var state := State.INTRO
var phase := 0
var hp := HITS_PER_PHASE
var _attack_index := 0
var _rest_pose := {}
var _rail_dust := 0.0

@onready var rig: Node2D = $Rig
@onready var legs: Node2D = $Rig/Legs
@onready var stomp_anchor: Node2D = $Rig/Legs/StompAnchor
@onready var leg_f: Node2D = $Rig/Legs/StompAnchor/LegF
@onready var upper: Node2D = $Rig/Upper
@onready var head: Node2D = $Rig/Upper/Head
@onready var eye: Node2D = $Rig/Upper/Head/Eye
@onready var mouth: Marker2D = $Rig/Upper/Head/Mouth
@onready var fist_l: Node2D = $Rig/Upper/Body/FistL
@onready var slam_anchor: Node2D = $Rig/Upper/Body/SlamAnchor
@onready var fist_r: Node2D = $Rig/Upper/Body/SlamAnchor/FistR
@onready var shadow: Node2D = $Rig/Upper/Body/SlamAnchor/Shadow
@onready var bomb_spawn: Marker2D = $Rig/Upper/Body/FistL/BombSpawn
@onready var cores: Array = [$Rig/Legs/StompAnchor/LegF/KneeCore, $Rig/Upper/Body/Core, $Rig/Upper/Head/EyeCore]
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var rest_timer: Timer = $RestTimer
@onready var laser_low: Node2D = $LaserLow
@onready var laser_high: Node2D = $LaserHigh


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


## Rides the rail toward the player while resting, so attacks always land near them.
func _physics_process(delta: float) -> void:
	if state != State.IDLE:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var before := position.x
	position.x = move_toward(position.x, _rail_goal(player), RAIL_SPEED * delta)
	if absf(position.x - before) > 0.1:
		_rail_dust -= delta
		if _rail_dust <= 0.0:
			_rail_dust = 0.2
			_fx(DUST_SCENE, Vector2(weak_point().global_position.x + randf_range(-150.0, 150.0), FLOOR_Y - 16.0))


func _rail_goal(player: Node2D) -> float:
	return clampf(player.global_position.x + RAIL_LEAD - TORSO_X, RAIL_MIN, RAIL_MAX)


## The core to hit right now: the front knee, then the chest, then the eye.
func weak_point() -> Node2D:
	return cores[phase]


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
	if state == State.DEAD:
		return
	hp = HITS_PER_PHASE
	_attack_index = 0
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

func aim_slam() -> void:
	slam_anchor.global_position.x = _player_x()


func aim_stomp() -> void:
	stomp_anchor.global_position.x = _player_x()


func slam_impact() -> void:
	_quake(slam_anchor.global_position.x, 18.0)


func stomp_impact() -> void:
	_quake(stomp_anchor.global_position.x, 20.0)


func hop_impact() -> void:
	_quake(head.global_position.x, 16.0)


func spawn_bomb() -> void:
	_drop_bomb(bomb_spawn.global_position, Vector2(randf_range(-650.0, -250.0), -350.0))


## Stage 1: his hands are out of frame, so bombs fall from the sky near the player.
func rain_bomb() -> void:
	_drop_bomb(Vector2(clampf(_player_x() + randf_range(-320.0, 320.0), 80.0, ARENA_W - 80.0), -60.0), Vector2.ZERO)


func spit_bomb() -> void:
	_drop_bomb(mouth.global_position, Vector2(randf_range(-700.0, -350.0), -420.0))


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


func _drop_bomb(at: Vector2, velocity: Vector2) -> void:
	var bomb: Bomb = BOMB_SCENE.instantiate()
	_spawn_parent().add_child(bomb)
	bomb.global_position = at
	bomb.linear_velocity = velocity


func _player_x() -> float:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return clampf(player.global_position.x if player else 400.0, 80.0, ARENA_W - 80.0)


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
	_play.call_deferred(StringName("phase_%d" % (phase + 1)), State.PHASE_SHIFT)


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
	for n: Node2D in _rest_pose:
		n.position = _rest_pose[n]
	rig.position = Vector2.ZERO
	rig.modulate = Color.WHITE
	eye.modulate = Color.WHITE
	shadow.hide()
	stomp_anchor.get_node("Shadow").hide()
	for box in [fist_r.get_node("Hitbox"), leg_f.get_node("Hitbox"), head.get_node("HopHitbox")]:
		box.get_node("CollisionShape2D").set_deferred("disabled", true)
	for laser: Node2D in [laser_low, laser_high]:
		laser.get_node("Warn").hide()
		laser.get_node("Beam").hide()
		laser.get_node("Hitbox/CollisionShape2D").set_deferred("disabled", true)


## Where each part sits at rest in this stage (a stage break moves the torso and head).
func _capture_rest_pose() -> void:
	for n: Node2D in [legs, stomp_anchor, leg_f, upper, head, fist_l, fist_r]:
		_rest_pose[n] = n.position


func _spawn_parent() -> Node:
	return projectiles if projectiles else get_parent()


func _on_animation_finished(_anim_name: StringName) -> void:
	if state == State.PHASE_SHIFT:
		_capture_rest_pose()
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
