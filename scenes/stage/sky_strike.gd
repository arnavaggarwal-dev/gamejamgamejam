extends Node2D
## Phase 4 lightning out of the red sky. A storm cloud gathers at the top of the screen and
## flickers lit while a red ring tightens on the floor below it (a faint column joins them);
## a faint leader flickers, then the branching bolt strikes the whole column (step out, or dash
## through) and thins out; a blast, sparks and a scorch that cools. Sits on the floor; the
## "strike" animation times it all, calls boom() and frees it.

const EXPLOSION := preload("res://scenes/fx/explosion.tscn")


func _ready() -> void:
	scale.x = [-1.0, 1.0].pick_random()  # mirrors the bolt so strikes vary


func boom() -> void:
	get_tree().call_group("camera", "shake", 10.0)
	get_tree().call_group("hud", "flash", 0.2)
	var fx: Node2D = EXPLOSION.instantiate()
	get_parent().add_child(fx)
	fx.global_position = global_position
