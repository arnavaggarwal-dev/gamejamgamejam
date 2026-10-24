class_name TrainingBot
extends Node2D
## Lil' Watt, the tutorial's punching bag. It hovers at the king's lead and core height, so the
## throw that breaks it is the same throw that hurts him. Bombs thrown into its core cost a hit
## and crack it a little more; the "die" animation blows it up, drops the wreck, emits `broken`
## and frees it. In phase 4 it powers the rebuilt king through a lightning link to `power_target`.

signal hit(hits_left: int)
signal broken

const HITS := 3
const LEAD := 540.0  # px right of the player, same as the king's core
const SPEED := 260.0
const EXPLOSION := preload("res://scenes/fx/explosion.tscn")

var hp := HITS
var roam_max := 2440.0  # rightmost x it follows the player to (the doom arena is wider)
var power_target: Node2D  # what the lightning link feeds (the giant king's chest), if anything

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var juice: AnimationPlayer = $Juice
@onready var core: Node2D = $Hover/Core
@onready var cracks: Node2D = $Hover/Cracks
@onready var link: Line2D = $Link


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and hp > 0:
		position.x = move_toward(position.x, clampf(player.global_position.x + LEAD, 120.0, roam_max), SPEED * delta)


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
