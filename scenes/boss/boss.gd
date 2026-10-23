class_name Boss
extends Node2D
## King Kilowatt. Cycles a fixed attack pattern per phase; only thrown bombs hurt him.
## Attacks live in the AnimationPlayer: value tracks move the rig and toggle hitboxes,
## method tracks call aim_slam / slam_impact / spawn_bomb / shake at the right frames.

signal health_changed(hits_left: int, hits_total: int)
signal phase_changed(phase: int)  # 0-based: the second phase emits 1
signal defeated

enum State { INTRO, IDLE, ATTACK, STAGGER, PHASE_SHIFT, DEAD }

const HITS_PER_PHASE := 3
const FLOOR_Y := 640.0
const BOMB_SCENE := preload("res://scenes/boss/bomb.tscn")
const SHOCKWAVE_SCENE := preload("res://scenes/boss/shockwave.tscn")
const PHASES := [
	{attacks = [&"slam", &"bombs"], speed = 1.0, rest = 1.2},
	{attacks = [&"slam", &"bombs", &"bombs"], speed = 1.2, rest = 0.9},
	{attacks = [&"slam", &"bombs", &"bombs"], speed = 1.45, rest = 0.6},
]

@export var projectiles: Node2D

var state := State.INTRO
var phase := 0
var hp := HITS_PER_PHASE
var _attack_index := 0
var _rest_pose := {}

@onready var rig: Node2D = $Rig
@onready var head: Node2D = $Rig/Head
@onready var eye: Node2D = $Rig/Head/Eye
@onready var fist_l: Node2D = $Rig/FistL
@onready var slam_anchor: Node2D = $Rig/SlamAnchor
@onready var fist_r: Node2D = $Rig/SlamAnchor/FistR
@onready var shadow: Node2D = $Rig/SlamAnchor/Shadow
@onready var bomb_spawn: Marker2D = $Rig/FistL/BombSpawn
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var rest_timer: Timer = $RestTimer


func _ready() -> void:
	for n: Node2D in [head, fist_l, fist_r]:
		_rest_pose[n] = n.position
	$Rig/Core/WeakPoint.body_entered.connect(_on_weak_point_body_entered)
	anim.animation_finished.connect(_on_animation_finished)
	rest_timer.timeout.connect(_on_rest_timer_timeout)


func start_fight() -> void:
	_play(&"intro", State.INTRO)


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
	get_tree().call_group("camera", "hitstop", 0.08)
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


# --- called from animation method tracks ---

func aim_slam() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var x := player.global_position.x if player else 400.0
	slam_anchor.position.x = clampf(x, 80.0, 880.0)


func slam_impact() -> void:
	shake(18.0)
	for dir in [-1, 1]:
		var wave: Shockwave = SHOCKWAVE_SCENE.instantiate()
		wave.direction = dir
		_spawn_parent().add_child(wave)
		wave.global_position = Vector2(slam_anchor.global_position.x, FLOOR_Y)


func spawn_bomb() -> void:
	var bomb: Bomb = BOMB_SCENE.instantiate()
	_spawn_parent().add_child(bomb)
	bomb.global_position = bomb_spawn.global_position
	bomb.linear_velocity = Vector2(randf_range(-650.0, -250.0), -350.0)


func shake(amount: float) -> void:
	get_tree().call_group("camera", "shake", amount)


# --- internals ---

func _advance_phase() -> void:
	rest_timer.stop()
	if phase == PHASES.size() - 1:
		_play(&"death", State.DEAD)
		defeated.emit()
		return
	phase += 1
	hp = HITS_PER_PHASE
	_attack_index = 0
	phase_changed.emit(phase)
	_play(StringName("phase_%d" % (phase + 1)), State.PHASE_SHIFT)


func _rest() -> void:
	_play(&"idle", State.IDLE)
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
	$Rig/SlamAnchor/FistR/Hitbox/CollisionShape2D.set_deferred("disabled", true)


func _spawn_parent() -> Node:
	return projectiles if projectiles else get_parent()


func _on_animation_finished(_anim_name: StringName) -> void:
	if state in [State.INTRO, State.ATTACK, State.STAGGER, State.PHASE_SHIFT]:
		_rest()


func _on_rest_timer_timeout() -> void:
	if state == State.IDLE:
		_play(next_attack(), State.ATTACK)


func _on_weak_point_body_entered(body: Node2D) -> void:
	var bomb := body as Bomb
	if bomb and bomb.thrown and not bomb.exploded:
		bomb.explode()
		take_hit()
