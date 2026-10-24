class_name TrainingBot
extends Node2D
## Lil' Watt, the tutorial's punching bag. It hovers at the king's lead and core height, so the
## throw that breaks it is the same throw that hurts him. Bombs thrown into its core cost a hit
## and crack it a little more; the "die" animation blows it up, drops the wreck, emits `broken`
## and frees it. In phase 4 it revives the king, then fights beside him (fight()): it follows
## the player up and down too, shoots zap balls, and powers him through a lightning link to
## `power_target`.

signal hit(hits_left: int)
signal broken

const HITS := 3
const LEAD := 540.0  # px right of the player, same as the king's core
const SPEED := 260.0
const EXPLOSION := preload("res://scenes/fx/explosion.tscn")
const ZAP_BALL := preload("res://scenes/boss/zap_ball.tscn")
const ZAP_SPEED := 650.0
const ABOVE := 220.0  # px it hovers above the player once it follows him up and down

var hp := HITS
var roam_max := 2440.0  # rightmost x it follows the player to (the doom arena is wider)
var power_target: Node2D  # what the lightning link feeds (the giant king's chest), if anything
var roaming := true  # follows the player (off while a cutscene flies it around)
var follow_y := false  # phase 4: climbs with the player too
var projectiles: Node  # where its shots go (the arena's Projectiles, cleared when the player dies)
var face := &"hover"  # the Art animation it wears between hurt frames (angry once you broke its dad)

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var juice: AnimationPlayer = $Juice
@onready var core: Node2D = $Hover/Core
@onready var cracks: Node2D = $Hover/Cracks
@onready var link: Line2D = $Link
@onready var art: AnimatedSprite2D = $Hover/Art
@onready var shot_timer: Timer = $ShotTimer


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or hp <= 0 or not roaming:
		return
	position.x = move_toward(position.x, clampf(player.global_position.x + LEAD, 120.0, roam_max), SPEED * delta)
	if follow_y:
		position.y = move_toward(position.y, clampf(player.global_position.y - ABOVE, -1000.0, 420.0), SPEED * delta)


## The power link: a zig-zag bolt from the core to the power target, re-jagged every other frame.
func _process(_delta: float) -> void:
	link.visible = is_instance_valid(power_target) and hp > 0
	if not link.visible or Engine.get_process_frames() % 2:
		return
	var from := core.global_position
	var to := power_target.global_position
	var side := (to - from).orthogonal().normalized()
	var bolt := PackedVector2Array([from])  # sized for phase 4's 3x zoom-out
	for k in range(1, 12):
		bolt.append((from.lerp(to, k / 12.0) + side * randf_range(0.4, 1.0) * 70.0 * (1 if k % 2 else -1)).snapped(Vector2(4, 4)))
	bolt.append(to)
	link.points = bolt
	link.get_node("Bolt").points = bolt


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


## Blows the bot apart (the tutorial also calls this when the lesson is skipped).
func break_down() -> void:
	hp = 0
	if anim.current_animation != &"die":
		anim.play(&"die")


## Called from the "die" animation: one explosion near the core plus a camera kick.
func boom(offset: Vector2) -> void:
	var fx: Node2D = EXPLOSION.instantiate()
	get_parent().add_child(fx)
	fx.global_position = core.global_position + offset
	get_tree().call_group("camera", "shake", 8.0)
