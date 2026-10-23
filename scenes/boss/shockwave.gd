class_name Shockwave
extends Area2D
## Ground wave from a fist slam. Jump over it.

@export var speed := 480.0
var direction := 1


func _ready() -> void:
	$Art.scale.x = direction


func _physics_process(delta: float) -> void:
	position.x += speed * direction * delta
	if position.x < -150.0 or position.x > 1430.0:
		queue_free()
