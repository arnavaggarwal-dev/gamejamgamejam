extends Camera2D
## Fixed arena camera. Anything can call:
##   get_tree().call_group("camera", "shake", amount)
##   get_tree().call_group("camera", "hitstop", seconds)

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
	_trauma = move_toward(_trauma, 0.0, 60.0 * delta)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _trauma
