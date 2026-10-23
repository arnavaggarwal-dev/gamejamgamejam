class_name Tutorial
extends Node
## Hand-holding first fight: one simple instruction at a time, each waiting until the player
## actually does it, against a king who holds still. Afterwards it shows a one-time tip the
## first time each danger appears. Enter (or Tab / gamepad Back) skips the lesson.

const BOMB := preload("res://scenes/boss/bomb.tscn")
const STEP_PAUSE := 0.7
const ARROW_ABOVE_CORE := Vector2(0, -110)
const LIFT := 60  # z added to whatever the current step is about, above the Spotlight (z 50)

static var done := false  # once per session, so restarts go straight to the fight
static var seen := {}  # tip keys already shown this session

var player: Player
var boss: Boss
var hud: HUD
var stage: Stage
var projectiles: Node2D

var _skip := false
var _practice: Bomb
var _start_x := 0.0
var _hits_before := 0
var _lifted: Array[CanvasItem] = []

@onready var core_arrow: AnimatedSprite2D = $CoreArrow
@onready var spotlight: ColorRect = $Spotlight


func setup(p: Player, b: Boss, h: HUD, s: Stage, proj: Node2D) -> void:
	player = p
	boss = b
	hud = h
	stage = s
	projectiles = proj
	boss.attack_started.connect(_on_attack_started)
	stage.zap_started.connect(_tip.bind("zap", "YELLOW STRIPES = ZAP!  GET OFF THEM!"))
	stage.collapsed.connect(_tip.bind("collapse", "THE FLOOR IS BREAKING!  DON'T FALL IN THE HOLES!", 5.0))
	player.hp_changed.connect(_on_hp_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not done and event.is_action_pressed("skip_tutorial"):
		_skip = true


## Returns once the player has finished (or skipped) the lesson.
func run() -> void:
	hud.show_hint("ENTER: SKIP TUTORIAL")
	_start_x = player.global_position.x
	_focus([player])
	await _step("WALK WITH THE  ARROW KEYS", _walked)
	await _step("JUMP WITH  Z", _jumped)
	await _step("DASH WITH  C", _dashed)
	if not _skip:
		_spawn_practice_bomb()
	await _step("A BOMB!  WALK OVER TO IT", _next_to_bomb)
	await _step("PRESS  X  TO PICK IT UP", _holding_bomb)
	_hits_before = boss.hits_left()
	core_arrow.show()
	_focus([player, _practice, boss.get_node("Rig/Core"), core_arrow])
	await _step("THROW IT AT THE GLOWING CORE!\nFACE THE KING AND PRESS  X", _hit_core)
	core_arrow.hide()
	_focus([])
	if not _skip:
		hud.coach("YES!!  THAT'S HOW YOU HURT HIM.\nNOW DODGE HIS ATTACKS.  GO!")
		await get_tree().create_timer(2.6, false).timeout
	_finish()


func _step(text: String, is_done: Callable) -> void:
	if _skip:
		return
	hud.coach(text)
	while not _skip and not is_done.call():
		await get_tree().physics_frame
	if _skip:
		return
	hud.coach("NICE!")
	await get_tree().create_timer(STEP_PAUSE, false).timeout


func _walked() -> bool:
	return absf(player.global_position.x - _start_x) > 160.0


func _jumped() -> bool:
	return not player.is_on_floor()


func _dashed() -> bool:
	return player.dashing


func _next_to_bomb() -> bool:
	return player.held_bomb != null or player._nearest_bomb() == _practice


func _holding_bomb() -> bool:
	return player.held_bomb != null


func _hit_core() -> bool:
	if not is_instance_valid(_practice) and player.held_bomb == null:
		_spawn_practice_bomb()  # it rolled away into nothing; hand them another
	return boss.hits_left() < _hits_before


## A practice bomb that never goes off, dropped a few steps ahead of the player.
func _spawn_practice_bomb() -> void:
	_practice = BOMB.instantiate()
	projectiles.add_child(_practice)
	_practice.global_position = Vector2(clampf(player.global_position.x + 220.0 * player.facing, 120.0, 2440.0), 610.0)
	_practice.get_node("FuseTimer").stop()
	_practice.get_node("AnimationPlayer").stop()
	if not _lifted.is_empty():
		_focus(_lifted + [_practice])  # the lesson is now about the bomb too


## Greys out the world except `nodes`, lifted above the Spotlight; an empty list clears it.
func _focus(nodes: Array) -> void:
	for n in _lifted:
		if is_instance_valid(n):
			n.z_index -= LIFT
	_lifted.clear()
	for n in nodes:
		if is_instance_valid(n):
			n.z_index += LIFT
			_lifted.append(n)
	spotlight.show()
	var fade := create_tween()
	fade.tween_property(spotlight, "material:shader_parameter/amount", 1.0 if _lifted else 0.0, 0.25)
	if _lifted.is_empty():
		fade.tween_callback(spotlight.hide)


func _finish() -> void:
	done = true
	_focus([])
	hud.coach("")
	hud.show_hint("")
	core_arrow.hide()
	if is_instance_valid(_practice) and not _practice.exploded:
		if player.held_bomb == _practice:
			_practice.get_node("FuseTimer").start()  # skipped mid-carry: it becomes a real bomb
			_practice.get_node("AnimationPlayer").play(&"fuse")
		else:
			_practice.queue_free()


func _process(_delta: float) -> void:
	if core_arrow.visible:
		core_arrow.global_position = boss.get_node("Rig/Core").global_position + ARROW_ABOVE_CORE
	if not done or player == null:
		return
	if player.is_on_floor() and stage.panel_at(player.global_position.x).belt_speed != 0.0:
		_tip("belt", "CONVEYOR BELTS PUSH YOU AROUND!")
	var held := player.held_bomb
	if is_instance_valid(held):
		var fuse: Timer = held.get_node("FuseTimer")
		if not fuse.is_stopped() and fuse.time_left < 1.3:
			_tip("hot_bomb", "THROW IT NOW!  IT'S ABOUT TO BLOW!")


func _on_attack_started(attack: StringName) -> void:
	match attack:
		&"slam":
			_tip("slam", "SEE THE RED RING?  A FIST IS COMING.  MOVE!")
		&"bombs":
			_tip("bombs", "BOMBS!  GRAB ONE [X], THROW IT AT THE CORE!")
		&"laser":
			_tip("laser", "LASER!  LOW LINE = JUMP.  HIGH LINE = STAY DOWN.")


func _on_hp_changed(hp: int) -> void:
	if hp == 1:
		_tip("last_heart", "ONE HEART LEFT!  CAREFUL!")


func _tip(key: String, text: String, seconds := 3.5) -> void:
	if not done or seen.has(key):
		return
	seen[key] = true
	hud.show_tip(text, seconds)
