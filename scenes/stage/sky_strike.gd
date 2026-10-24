extends Node2D
## Phase 4 lightning out of the red sky: a blinking warning column, then a bolt down the whole
## of it (step out, or dash through). Sits on the floor; the "strike" animation times it all,
## calls boom() and frees it.

const EXPLOSION := preload("res://scenes/fx/explosion.tscn")


func _ready() -> void:
	scale.x = [-1.0, 1.0].pick_random()  # mirrors the bolt's zig-zag so strikes vary


func boom() -> void:
	get_tree().call_group("camera", "shake", 10.0)
	get_tree().call_group("hud", "flash", 0.2)
	var fx: Node2D = EXPLOSION.instantiate()
	get_parent().add_child(fx)
	fx.global_position = global_position
