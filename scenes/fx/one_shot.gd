extends AnimatedSprite2D
## One-shot pixel effect: plays its animation once from the first frame, then frees itself.


func _ready() -> void:
	animation_finished.connect(queue_free)
	play()
