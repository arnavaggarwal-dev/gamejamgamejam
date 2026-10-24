class_name Bomb
extends RigidBody2D
## Lobbed by the boss. The player picks it up and throws it back at the boss's core.

const LAYER_BOMB := 4  # physics layer 3 "bomb"
const EXPLOSION := preload("res://scenes/fx/explosion.tscn")
const ARROW_OFFSET := Vector2(0, -48)
const PIT_Y := 900.0
const GROUND_DRAG := 350.0  # px/s² while touching a surface; rolling has no friction of its own
const SPIN := 12.0  # rad/s while airborne

var thrown := false
var exploded := false
var size := 1.0  # set before it enters the tree: phase 4's bombs come bigger, blast and all

@onready var art: Node2D = $Art
@onready var arrow: Node2D = $Arrow
@onready var blast_shape: CollisionShape2D = $BlastArea/CollisionShape2D
@onready var particles: CPUParticles2D = $CPUParticles2D


func _ready() -> void:
	art.scale *= size
	$CollisionShape2D.scale *= size
	blast_shape.scale *= size
	particles.scale_amount_min *= size
	particles.scale_amount_max *= size
	$FuseTimer.timeout.connect(explode)
	$AnimationPlayer.play(&"fuse")


## Rolling bombs coast to the speed of whatever they sit on (0 for stone, the belt speed on a
## conveyor); flight, and so the player's aim arc, is untouched.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if state.get_contact_count() > 0:
		var belt := state.get_contact_collider_velocity_at_position(0).x
		state.linear_velocity.x = move_toward(state.linear_velocity.x, belt, GROUND_DRAG * state.step)


## The body rolls (so bombs tumble off platforms) but the art stays upright while it rests or is
## carried; in the air it spins with its flight, and settles back upright on landing.
func _process(delta: float) -> void:
	if not freeze and get_contact_count() == 0:
		art.global_rotation += SPIN * (1.0 if linear_velocity.x >= 0.0 else -1.0) * delta
	else:
		art.global_rotation = lerp_angle(art.global_rotation, 0.0, minf(1.0, 20.0 * delta))
	arrow.global_rotation = 0.0
	arrow.global_position = global_position + ARROW_OFFSET * size
	if global_position.y > PIT_Y:
		queue_free()  # rolled into a pit


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
	_settle.call_deferred(global_position)
	get_tree().call_group("hud", "flash", 0.35)
	get_tree().call_group("camera", "hitstop", 0.04)
	art.hide()
	arrow.hide()
	blast_shape.set_deferred("disabled", false)
	particles.emitting = true
	var boom: Node2D = EXPLOSION.instantiate()
	get_parent().add_child.call_deferred(boom)
	boom.position = position
	boom.scale = Vector2.ONE * size
	get_tree().call_group("camera", "shake", 10.0)
	await get_tree().create_timer(0.15).timeout
	blast_shape.set_deferred("disabled", true)
	await get_tree().create_timer(0.6).timeout
	queue_free()


## Freezes the spent bomb where it blew up. Re-freezing a body that was frozen before (held)
## snaps it back to where it was last frozen, the thrower's hands, so the spot is set again.
func _settle(at: Vector2) -> void:
	freeze = true
	global_position = at
