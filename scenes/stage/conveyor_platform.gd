class_name ConveyorPlatform
extends StaticBody2D
## A floating conveyor: a one-way platform whose belt carries whoever stands on it at `speed`
## px/s (positive pushes right); its treads roll the same way.

@export var speed := 140.0


func _ready() -> void:
	constant_linear_velocity = Vector2(speed, 0.0)
	for belt: AnimatedSprite2D in $Belts.get_children():
		belt.flip_h = speed < 0.0
		belt.speed_scale = absf(speed) / 140.0
