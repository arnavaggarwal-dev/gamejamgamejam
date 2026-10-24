extends Area2D
## Lil' Watt's shot in phase 4: a crackling ball flying straight at where the player was. A
## hazard (layer 8) like the king's hitboxes; its Life timer frees it (wired in the scene).

var velocity := Vector2.ZERO


func _physics_process(delta: float) -> void:
	position += velocity * delta
