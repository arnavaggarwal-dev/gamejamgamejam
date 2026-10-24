class_name CorePlatform
extends StaticBody2D
## Metal plates held around a core. While assembled the plates hum about their home spots
## ("idle"). Plain with a dark core at first; once armed (phase 2 on) the core glows and an
## electric aura crackles round it. Standing on it plays "break": a shake, the plates burst
## apart (collision off, core dark) on crackling tethers, then the core relights and the
## tethers haul the plates back to the middle.

signal broke

const ZAG := 14.0  # how far a tether bolt zig-zags off the straight line, px
const SEGMENTS := 5

var armed := false:
	set(value):
		armed = value
		hub.play(&"pulse" if armed else &"dim")
		halo.visible = armed
		aura.emitting = armed

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var sensor: Area2D = $Sensor
@onready var hub: AnimatedSprite2D = $Parts/Hub
@onready var halo: Sprite2D = $Parts/Halo
@onready var aura: CPUParticles2D = $Aura
@onready var tethers: Node2D = $Parts/Tethers
@onready var plates: Array = [$Parts/L1, $Parts/L2, $Parts/R1, $Parts/R2]


## Re-jags each tether bolt (ink edge plus butter core) from the core to its plate every
## other frame, zig-zagging side to side so it crackles like lightning.
func _process(_delta: float) -> void:
	if not tethers.visible or Engine.get_process_frames() % 2:
		return
	for i in plates.size():
		var end: Vector2 = plates[i].position
		var side := end.orthogonal().normalized()
		var bolt := PackedVector2Array([Vector2.ZERO])
		for k in range(1, SEGMENTS):
			var sway := randf_range(0.4, 1.0) * ZAG * (1 if k % 2 else -1)
			bolt.append((end * k / float(SEGMENTS) + side * sway).snapped(Vector2(4, 4)))
		bolt.append(end)
		var edge: Line2D = tethers.get_child(i)
		edge.points = bolt
		edge.get_child(0).points = bolt


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
