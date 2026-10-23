class_name Bomb
extends RigidBody2D
## Lobbed by the boss. The player picks it up and throws it back at the boss's core.

const LAYER_BOMB := 4  # physics layer 3 "bomb"
const EXPLOSION := preload("res://scenes/fx/explosion.tscn")
const ARROW_OFFSET := Vector2(0, -48)
const GROUND_DRAG := 350.0  # px/s² while touching a surface; rolling has no friction of its own

var thrown := false
var exploded := false

@onready var art: Node2D = $Art
@onready var arrow: Node2D = $Arrow
@onready var blast_shape: CollisionShape2D = $BlastArea/CollisionShape2D
@onready var particles: CPUParticles2D = $CPUParticles2D


func _ready() -> void:
	$FuseTimer.timeout.connect(explode)
	$AnimationPlayer.play(&"fuse")


## Rolling bombs coast to a stop on the floor; flight (and the player's aim arc) is untouched.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.get_contact_count() > 0:
		state.linear_velocity.x = move_toward(state.linear_velocity.x, 0.0, GROUND_DRAG * state.step)


## The body rolls (so bombs tumble off platforms) but pixel art must not rotate.
func _process(_delta: float) -> void:
	art.global_rotation = 0.0
	arrow.global_rotation = 0.0
	arrow.global_position = global_position + ARROW_OFFSET


func pick_up() -> void:
	freeze = true
	collision_layer = 0
	arrow.hide()


func throw(v: Vector2) -> void:
	freeze = false
	collision_layer = LAYER_BOMB
	linear_velocity = v
	thrown = true


func explode() -> void:
	if exploded:
		return
	exploded = true
	set_deferred("freeze", true)
	art.hide()
	arrow.hide()
	blast_shape.set_deferred("disabled", false)
	particles.emitting = true
	var boom: Node2D = EXPLOSION.instantiate()
	get_parent().add_child.call_deferred(boom)
	boom.position = position
	get_tree().call_group("camera", "shake", 10.0)
	await get_tree().create_timer(0.15).timeout
	blast_shape.set_deferred("disabled", true)
	await get_tree().create_timer(0.6).timeout
	queue_free()
