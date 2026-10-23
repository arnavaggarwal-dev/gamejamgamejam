extends Area2D
## Ceiling rubble: its shadow marks the landing spot first, then it drops and bursts into dust.

const DUST := preload("res://scenes/fx/dust.tscn")
const FLOOR_Y := 640.0

@export var fall_speed := 900.0
@export var hang_time := 0.45

var _t := 0.0

@onready var shadow: Sprite2D = $Shadow


func _ready() -> void:
	shadow.global_position = Vector2(global_position.x, FLOOR_Y)


func _physics_process(delta: float) -> void:
	_t += delta
	var drop := clampf((global_position.y + 100.0) / (FLOOR_Y + 100.0), 0.3, 1.0)
	shadow.scale = Vector2(2.0, 2.0) * drop
	if _t < hang_time:
		return
	position.y += fall_speed * delta
	if global_position.y >= FLOOR_Y - 24.0:
		var dust: Node2D = DUST.instantiate()
		get_parent().add_child(dust)
		dust.global_position = Vector2(global_position.x, FLOOR_Y - 16.0)
		get_tree().call_group("camera", "shake", 6.0)
		queue_free()
