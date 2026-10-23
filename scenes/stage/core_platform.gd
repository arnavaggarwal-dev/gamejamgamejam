class_name CorePlatform
extends StaticBody2D
## Metal plates held around a core. While assembled the plates hum about their home spots
## ("idle"). Plain with a dark core at first; once armed (phase 2 on) the core glows, and
## standing on it plays "break": a shake, the plates burst apart with the collision off and
## the core dark, then the core relights and pulls them back.

signal broke

var armed := false:
	set(value):
		armed = value
		hub.play(&"pulse" if armed else &"dim")
		halo.visible = armed

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var sensor: Area2D = $Sensor
@onready var hub: AnimatedSprite2D = $Parts/Hub
@onready var halo: Sprite2D = $Parts/Halo


## Polled rather than on body_entered, so it breaks on landing, not while jumping up through.
func _physics_process(_delta: float) -> void:
	if not armed or anim.current_animation == &"break":
		return
	for body in sensor.get_overlapping_bodies():
		if (body as CharacterBody2D).is_on_floor():
			anim.play(&"break")
			anim.queue(&"idle")
			broke.emit()
			return
