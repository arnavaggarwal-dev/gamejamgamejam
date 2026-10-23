class_name Player
extends CharacterBody2D
## The little guy: runs, jumps, carries and throws the boss's bombs.

signal hp_changed(hp: int)
signal died

const MAX_HP := 3
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12

@export var speed := 330.0
@export var accel := 2600.0
@export var gravity := 1800.0
@export var jump_velocity := -640.0
@export var throw_velocity := Vector2(620, -760)  # tune in the Task 6 playtest
@export var lob_velocity := Vector2(300, -900)  # used while aim_up is held

var hp := MAX_HP
var facing := 1
var held_bomb: Bomb = null
var _coyote := 0.0
var _jump_buffer := 0.0
var _was_on_floor := true
var _dead := false

@onready var art: Node2D = $Art
@onready var flip: Node2D = $Art/Flip
@onready var body: AnimatedSprite2D = $Art/Flip/Body
@onready var hold_point: Marker2D = $HoldPoint
@onready var pickup_area: Area2D = $PickupArea
@onready var hurtbox: Area2D = $Hurtbox
@onready var invuln: Timer = $InvulnTimer
@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	add_to_group("player")
	hurtbox.area_entered.connect(func(_area: Area2D) -> void: take_hit())
	invuln.timeout.connect(_on_invuln_timeout)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, dir * speed, accel * delta)
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
		flip.scale.x = facing

	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote -= delta
		velocity.y += gravity * delta

	_jump_buffer = JUMP_BUFFER if Input.is_action_just_pressed("jump") else _jump_buffer - delta
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		_squash(Vector2(0.75, 1.25))
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5

	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_squash(Vector2(1.3, 0.75))
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
	_update_pose(dir)


func take_hit() -> void:
	if _dead or not invuln.is_stopped():
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
	hide()
	died.emit()


func _grab() -> void:
	var best: Bomb = null
	for overlap in pickup_area.get_overlapping_bodies():
		var bomb := overlap as Bomb
		if bomb == null or bomb.exploded:
			continue
		if best == null or global_position.distance_to(bomb.global_position) < global_position.distance_to(best.global_position):
			best = bomb
	if best:
		best.pick_up()
		held_bomb = best


func _throw() -> void:
	var v := lob_velocity if Input.is_action_pressed("aim_up") else throw_velocity
	held_bomb.throw(Vector2(v.x * facing, v.y))
	held_bomb = null


func _on_invuln_timeout() -> void:
	if hurtbox.has_overlapping_areas():
		take_hit()


func _squash(s: Vector2) -> void:
	art.scale = s
	create_tween().tween_property(art, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_pose(dir: float) -> void:
	var pose := &"idle"
	if held_bomb:
		pose = &"carry"
	elif not is_on_floor():
		pose = &"jump"
	elif dir != 0.0:
		pose = &"run"
	if body.animation != pose:
		body.play(pose)
