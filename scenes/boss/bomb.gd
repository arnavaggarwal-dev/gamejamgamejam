class_name Bomb
extends RigidBody2D
## The little guy's bomb: he pulls it out of his ammo and throws it at a core; left alone, its fuse
## sets it off. Its blast never hurts him: it bounces him away (Player.blast_from), a rocket jump.

const LAYER_BOMB := 4  # physics layer 3 "bomb"
const EXPLOSION := preload("res://scenes/fx/explosion.tscn")
const ARROW_OFFSET := Vector2(0, -48)
const PIT_Y := 900.0
const GROUND_DRAG := 350.0  # px/s² while touching a surface; rolling has no friction of its own
const SPIN := 12.0  # rad/s while airborne (no air drag: linear damp is 0, so it flies the arc the aim predicts)
const BLAST_REACH := 150.0  # px from the blast that bounces the player
const HOMING_RANGE := 240.0  # a thrown bomb this close to its target may nudge toward it
const HOMING_TURN := 3.0  # rad/s at most that nudge turns it (aim help, not a magnet)
const HOMING_CONE := 0.5  # only while the target is within ~60 degrees of its heading (cosine)

var thrown := false
var exploded := false
var target: Node2D  # the core it was thrown at, if any (a gentle nudge over the last stretch)

@onready var art: Node2D = $Art
@onready var arrow: Node2D = $Arrow
@onready var particles: CPUParticles2D = $CPUParticles2D


func _ready() -> void:
	$FuseTimer.timeout.connect(explode)
	$AnimationPlayer.play(&"fuse")


## Rolling bombs coast to the speed of whatever they sit on (0 for stone, the belt speed on a
## conveyor); flight, and so the player's aim arc, is untouched.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if thrown and is_instance_valid(target):
		_nudge(state)
	if state.get_contact_count() > 0:
		var belt := state.get_contact_collider_velocity_at_position(0).x
		state.linear_velocity.x = move_toward(state.linear_velocity.x, belt, GROUND_DRAG * state.step)


## Aim help over the last stretch: while the target is still ahead (within HOMING_CONE of where
## the bomb is flying) the bomb's heading turns a little toward it, its speed untouched. Once it
## has gone past or wide, the help is off for good: a bomb never turns back.
func _nudge(state: PhysicsDirectBodyState2D) -> void:
	var to := target.global_position - state.transform.origin
	var v := state.linear_velocity
	if to.length() > HOMING_RANGE or v.length() < 1.0:
		return
	if v.normalized().dot(to.normalized()) < HOMING_CONE:
		target = null
		return
	var most := HOMING_TURN * state.step
	state.linear_velocity = v.rotated(clampf(v.angle_to(to), -most, most))


## The body rolls (so bombs tumble off platforms) but the art stays upright while it rests or is
## carried; in the air it spins with its flight, and settles back upright on landing.
func _process(delta: float) -> void:
	if not freeze and get_contact_count() == 0:
		art.global_rotation += SPIN * (1.0 if linear_velocity.x >= 0.0 else -1.0) * delta
	else:
		art.global_rotation = lerp_angle(art.global_rotation, 0.0, minf(1.0, 20.0 * delta))
	arrow.global_rotation = 0.0
	arrow.global_position = global_position + ARROW_OFFSET
	if global_position.y > PIT_Y:
		queue_free()  # rolled into a pit


func pick_up() -> void:
	freeze = true
	collision_layer = 0
	arrow.hide()


func throw(v: Vector2) -> void:
	freeze = false
	collision_layer = LAYER_BOMB
	linear_velocity = v
	thrown = true


func explode() -> void:
	if exploded:
		return
	exploded = true
	_settle.call_deferred(global_position)
	get_tree().call_group("hud", "flash", 0.35)
	get_tree().call_group("camera", "hitstop", 0.04)
	art.hide()
	arrow.hide()
	particles.emitting = true
	var boom: Node2D = EXPLOSION.instantiate()
	get_parent().add_child.call_deferred(boom)
	boom.position = position
	get_tree().call_group("camera", "shake", 10.0)
	Sfx.play(&"boom")
	get_tree().call_group("player", "blast_from", global_position, BLAST_REACH)
	await get_tree().create_timer(0.75).timeout
	queue_free()


## Freezes the spent bomb where it blew up. Re-freezing a body that was frozen before (held)
## snaps it back to where it was last frozen, the thrower's hands, so the spot is set again.
func _settle(at: Vector2) -> void:
	freeze = true
	global_position = at
