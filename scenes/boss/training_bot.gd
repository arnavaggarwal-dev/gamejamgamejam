class_name TrainingBot
extends Node2D
## Lil' Watt, the tutorial's punching bag. It hovers at the king's lead and core height, so the
## throw that breaks it is the same throw that hurts him. Bombs thrown into its core cost a hit
## and crack it a little more; the "die" animation blows it up, drops the wreck, emits `broken`
## and frees it. In phase 4 it revives the king, then fights beside him (fight()): it follows
## the player up and down too, shoots zap balls, and powers him through a sagging power cable
## plugged into `power_target`.

signal hit(hits_left: int)
signal broken

const HITS := 3
const LEAD := 540.0  # px right of the player, same as the king's core
const SPEED := 260.0
const EXPLOSION := preload("res://scenes/fx/explosion.tscn")
const ZAP_BALL := preload("res://scenes/boss/zap_ball.tscn")
const ZAP_SPEED := 650.0
const ABOVE := 220.0  # px it hovers above the player once it follows him up and down
const SAG := 0.3  # how far the cable droops, per px of span
const PULSE_SPEED := 0.7  # energy pulses per second along the cable
const CABLE_STEPS := 24
const ARC_TIME := 0.07  # s a spark arcing off the cable stays lit

var hp := HITS
var roam_max := 2440.0  # rightmost x it follows the player to (the doom arena is wider)
var power_target: Node2D:  # what the power cable plugs into (the giant king's chest), if anything
	set(value):
		power_target = value
		_reach = 0.0  # the cable shoots out to it
		if value and is_inside_tree():
			create_tween().tween_property(self, "_reach", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
var roaming := true  # follows the player (off while a cutscene flies it around)
var follow_y := false  # phase 4: climbs with the player too
var projectiles: Node  # where its shots go (the arena's Projectiles, cleared when the player dies)
var face := &"hover"  # the Art animation it wears between hurt frames (angry once you broke its dad)
var out_cold := false  # phase 4's last hit knocks it out instead of blowing it up
var _reach := 1.0  # how far the cable has shot out toward its target (0..1)
var _flow := 0.0
var _arc_wait := 0.0
var _arc_left := 0.0

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var juice: AnimationPlayer = $Juice
@onready var core: Node2D = $Hover/Core
@onready var cracks: Node2D = $Hover/Cracks
@onready var link: Node2D = $Link
@onready var cable: Line2D = $Link/Cable
@onready var pulses: Array = $Link/Pulses.get_children()
@onready var arc: Line2D = $Link/Arc
@onready var plug: Node2D = $Link/PlugKing
@onready var art: AnimatedSprite2D = $Hover/Art
@onready var shot_timer: Timer = $ShotTimer


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or hp <= 0 or not roaming:
		return
	position.x = move_toward(position.x, clampf(player.global_position.x + LEAD, 120.0, roam_max), SPEED * delta)
	if follow_y:
		position.y = move_toward(position.y, clampf(player.global_position.y - ABOVE, -1000.0, 420.0), SPEED * delta)


## The power cable: it hangs in a sagging curve from its core to the power target, plugged into
## the target's chest; energy pulses flow along it into the target, and now and then a small
## spark arcs off it.
func _process(delta: float) -> void:
	link.visible = is_instance_valid(power_target) and hp > 0
	if not link.visible:
		return
	var from := core.global_position
	var to := from.lerp(power_target.global_position, _reach)
	var bend := (from + to) / 2.0 + Vector2(0.0, clampf(from.distance_to(to) * SAG, 30.0, 600.0))
	var points := PackedVector2Array()
	for k in CABLE_STEPS + 1:
		points.append(_along(from, bend, to, k / float(CABLE_STEPS)))
	cable.points = points
	plug.global_position = to
	plug.visible = _reach >= 1.0
	_flow = fmod(_flow + PULSE_SPEED * delta, 1.0)
	for i in pulses.size():
		pulses[i].global_position = _along(from, bend, to, fmod(_flow + i / float(pulses.size()), 1.0))
	_arc_left -= delta
	arc.visible = _arc_left > 0.0
	_arc_wait -= delta
	if _arc_wait <= 0.0:
		_arc_wait = randf_range(0.25, 0.6)
		_spark(_along(from, bend, to, randf_range(0.15, 0.85)))


## A point `t` (0..1) along the cable's curve (quadratic, `bend` its control point).
func _along(from: Vector2, bend: Vector2, to: Vector2, t: float) -> Vector2:
	return from.lerp(bend, t).lerp(bend.lerp(to, t), t)


## A short crackle jumping off the cable at `at`, lit for a blink.
func _spark(at: Vector2) -> void:
	var out := Vector2.from_angle(randf() * TAU)
	var jag := PackedVector2Array([at])
	for k in range(1, 5):
		jag.append((at + out * k * 22.0 + out.orthogonal() * randf_range(-14.0, 14.0)).snapped(Vector2(4, 4)))
	arc.points = jag
	arc.get_node("Hot").points = jag
	_arc_left = ARC_TIME


## WeakPoint.body_entered (connected in the scene).
func _on_weak_point_body_entered(body: Node2D) -> void:
	var bomb := body as Bomb
	if bomb == null or not bomb.thrown or bomb.exploded or hp <= 0:
		return
	bomb.explode()
	hp -= 1
	hit.emit(hp)
	for i in cracks.get_child_count():
		cracks.get_child(i).visible = i < HITS - hp
	if hp > 0:
		juice.play(&"hit")
	else:
		break_down()


## Phase 4 cutscene: "YOU BROKE MY DAD!!" It shakes, steams and keeps the angry face.
func get_angry() -> void:
	face = &"angry"
	anim.play(&"angry")
	anim.queue(&"hover")


## Phase 4 cutscene: quivering while it beams its power into the wreck.
func channel() -> void:
	anim.play(&"channel")


## Phase 4: fights beside the king, following the player everywhere and shooting.
func fight() -> void:
	roaming = true
	follow_y = true
	anim.play(&"hover")
	shot_timer.start()


## ShotTimer.timeout (connected in the scene): the "charge" tell, which calls shoot().
func _on_shot_timer_timeout() -> void:
	if hp > 0:
		juice.play(&"charge")


## Called from "charge": a zap ball straight at the player.
func shoot() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or hp <= 0:
		return
	var ball: Node2D = ZAP_BALL.instantiate()
	(projectiles if projectiles else get_parent()).add_child(ball)
	ball.global_position = core.global_position
	ball.velocity = (player.global_position - core.global_position).normalized() * ZAP_SPEED


## Called from "hit": back to its own face after the hurt frame.
func _relax() -> void:
	art.play(face)


func rumble(amount: float) -> void:
	get_tree().call_group("camera", "shake", amount)


## Phase 4 knockout: the last hit knocks it out of the sky instead of blowing it up. One pop, the
## power link snaps, and it drops onto the floor at `spot` and lies there tipped over, steaming.
func knock_out(spot: Vector2) -> void:
	out_cold = true
	hp = 0
	roaming = false
	shot_timer.stop()
	boom(Vector2.ZERO)
	anim.play(&"konk")
	create_tween().tween_property(self, "global_position", spot, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## The ending: it comes round...
func sit_up() -> void:
	anim.play(&"sit_up")


## ...and bows to the new king.
func bow() -> void:
	anim.play(&"bow")


## Blows the bot apart (the tutorial also calls this when the lesson is skipped).
func break_down() -> void:
	if out_cold:
		return
	hp = 0
	if anim.current_animation != &"die":
		anim.play(&"die")


## Called from the "die" animation: one explosion near the core plus a camera kick.
func boom(offset: Vector2) -> void:
	var fx: Node2D = EXPLOSION.instantiate()
	get_parent().add_child(fx)
	fx.global_position = core.global_position + offset
	get_tree().call_group("camera", "shake", 8.0)
