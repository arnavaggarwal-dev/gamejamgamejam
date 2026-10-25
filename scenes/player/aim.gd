extends Node2D
## Dotted throw arc shown while the player carries a bomb: its dot sprites (alternating big and
## small) sit along the arc, snapped to the 4-px art grid; the ones not needed hide.

@onready var dots: Array = get_children()

## Global positions along the arc; set every physics frame by the player.
var points := PackedVector2Array():
	set(value):
		points = value
		for i in dots.size():
			dots[i].visible = i < points.size()
			if dots[i].visible:
				dots[i].position = (points[i] / 4.0).floor() * 4.0
