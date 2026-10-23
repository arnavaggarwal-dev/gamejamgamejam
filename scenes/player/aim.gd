extends Node2D
## Dotted throw arc shown while the player carries a bomb. Dots snap to the 4-px art grid.

const DOT := Color("#fcfbfc")
const EDGE := Color("#2d2730")

## Global positions along the arc; set every physics frame by the player.
var points := PackedVector2Array():
	set(value):
		points = value
		queue_redraw()


func _draw() -> void:
	for i in points.size():
		var p := (points[i] / 4.0).floor() * 4.0
		var half := 8.0 if i % 2 == 0 else 4.0
		draw_rect(Rect2(p - Vector2(half, half), Vector2(half, half) * 2.0), EDGE)
		draw_rect(Rect2(p - Vector2(half - 4.0, half - 4.0), Vector2(half - 4.0, half - 4.0) * 2.0), DOT)
