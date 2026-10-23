extends Sprite2D
## Scrolls a repeating texture region sideways forever (the clouds behind the windows).

@export var speed := 6.0  # art px per second


func _process(delta: float) -> void:
	region_rect.position.x = fposmod(region_rect.position.x + speed * delta, texture.get_width())
