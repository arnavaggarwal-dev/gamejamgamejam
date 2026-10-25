extends Camera2D
## Arena camera: follows the target sideways (limits keep it inside the arena). Anything can call:
##   get_tree().call_group("camera", "shake", amount)
##   get_tree().call_group("camera", "hitstop", seconds)

@export var target: Node2D
@export var follow_y := false  # cutscenes: track the target's height too (the crowning close-up)

var _trauma := 0.0


func _ready() -> void:
	add_to_group("camera")


func shake(amount: float) -> void:
	_trauma = maxf(_trauma, amount)


func hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if target:
		position.x = target.global_position.x
		if follow_y:
			position.y = target.global_position.y - 60.0
	_trauma = move_toward(_trauma, 0.0, 60.0 * delta)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _trauma
