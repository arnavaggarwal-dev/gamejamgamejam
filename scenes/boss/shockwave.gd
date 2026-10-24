class_name Shockwave
extends Area2D
## Ground wave from a stomp. Jump over it.

@export var speed := 480.0
var direction := 1


func _ready() -> void:
	$Art.flip_h = direction < 0


func _physics_process(delta: float) -> void:
	position.x += speed * direction * delta
	if position.x < -150.0 or position.x > Stage.DOOM_W + 150.0:
		queue_free()
