class_name Bomb
extends RigidBody2D
## Lobbed by the boss. The player picks it up and throws it back at the boss's core.

const LAYER_BOMB := 4  # physics layer 3 "bomb"
const EXPLOSION := preload("res://scenes/fx/explosion.tscn")

var thrown := false
var exploded := false

@onready var art: Node2D = $Art
@onready var arrow: Node2D = $Arrow
@onready var blast_shape: CollisionShape2D = $BlastArea/CollisionShape2D
@onready var particles: CPUParticles2D = $CPUParticles2D


func _ready() -> void:
	$FuseTimer.timeout.connect(explode)
	$AnimationPlayer.play(&"fuse")


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
