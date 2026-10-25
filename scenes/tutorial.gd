class_name Tutorial
extends Node
## Hand-holding first fight: one simple instruction at a time, each waiting until the player
## actually does it, against Lil' Watt, a little training bot (the king stays hidden until it
## breaks). Afterwards it shows a one-time tip the first time each danger appears.
## Enter (or Tab / gamepad Back) skips the lesson.

const STEP_PAUSE := 0.7
const ARROW_ABOVE_CORE := Vector2(0, -140)
const LIFT := 60  # z added to whatever the current step is about, above the Spotlight (z 50)

static var done := false  # once per session, so restarts go straight to the fight
static var seen := {}  # tip keys already shown this session

var player: Player
var boss: Boss
var hud: HUD
var stage: Stage
var projectiles: Node2D

var _skip := false
var _start_x := 0.0
var _recharged := false
var _greyed := false
var _lifted: Array[CanvasItem] = []

@onready var core_arrow: AnimatedSprite2D = $CoreArrow
@onready var spotlight: ColorRect = $Spotlight
@onready var bot: TrainingBot = $TrainingBot
@onready var grey: AnimationPlayer = $Grey


func _ready() -> void:
	if done:
		bot.queue_free()  # restarts go straight to the king


func setup(p: Player, b: Boss, h: HUD, s: Stage, proj: Node2D) -> void:
	player = p
	boss = b
	hud = h
	stage = s
	projectiles = proj
	boss.attack_started.connect(_on_attack_started)
	stage.zap_started.connect(_tip.bind("zap", "YELLOW STRIPES = ZAP!  GET OFF THEM!"))
	stage.collapsed.connect(_tip.bind("collapse", "THE FLOOR IS BREAKING!  DON'T FALL IN THE HOLES!", 5.0))
	for plat in stage.core_platforms:
		plat.broke.connect(_tip.bind("core_platform", "GLOWING PLATFORMS FALL APART!  THEY COME BACK."))
	player.hp_changed.connect(_on_hp_changed)
	boss.phase_changed.connect(func(p: int) -> void:
		if p == 1:
			_tip("guard", "HIS CHEST IS ARMOURED!  THROW WHEN IT OPENS, RIGHT AFTER HIS ATTACKS.", 5.0))
	player.ammo_changed.connect(func(_ammo: int) -> void: _recharged = _recharged or player.charging)


func _unhandled_input(event: InputEvent) -> void:
	if not done and event.is_action_pressed("skip_tutorial"):
		_skip = true


## Returns once Lil' Watt is in pieces, whether the player broke it or skipped the lesson.
func run() -> void:
	hud.show_hint("ENTER: SKIP TUTORIAL")
	hud.set_boss_name("LIL' WATT")
	hud.set_boss_health(bot.hp, TrainingBot.HITS)
	bot.hit.connect(hud.set_boss_health.bind(TrainingBot.HITS))
	_start_x = player.global_position.x
	_focus([player])
	await _step("WALK WITH THE  ARROW KEYS", _walked)
	await _step("JUMP WITH  X\nAND AGAIN IN THE AIR!", _jumped)
	await _step("DASH WITH  C\nHOLD ARROWS TO AIM IT", _dashed)
	await _step("PRESS  Z  TO PULL OUT A BOMB", _holding_bomb)
	core_arrow.show()
	_focus([player, player.held_bomb, bot, core_arrow])  # the whole bot, so its cracks show
	await _step("THROW IT AT THE GLOWING CORE!\nFACE THE ROBOT AND PRESS  Z", _bot_hit)
	await _step("HOLD  A  TO SQUEEZE OUT MORE BOMBS", _made_bomb)
	await _step("AGAIN!  BREAK LIL' WATT!", _bot_broken)
	core_arrow.hide()
	_focus([])
	if not _skip:
		hud.coach("YOU BROKE IT!!\nNOW FOR THE REAL BOSS...")
		await get_tree().create_timer(2.0, false).timeout
	_finish()
	if is_instance_valid(bot):
		await bot.broken
	hud.set_boss_name("KING KILOWATT")
	hud.set_boss_health(boss.hits_left(), boss.hits_total())


func _step(text: String, is_done: Callable) -> void:
	if _skip or is_done.call():
		return  # skipped, or the player already did it
	hud.coach(text)
	while not _skip and not is_done.call():
		await get_tree().physics_frame
	if _skip:
		return
	hud.coach("NICE!")
	Sfx.play(&"coin")
	await get_tree().create_timer(STEP_PAUSE, false).timeout


func _walked() -> bool:
	return absf(player.global_position.x - _start_x) > 160.0


func _jumped() -> bool:
	return not player.is_on_floor()


func _dashed() -> bool:
	return player.dashing


func _holding_bomb() -> bool:
	return _bot_hit() or player.held_bomb != null


## A hit on the bot also ends the earlier bomb steps, so a player who rushes ahead (pulls out a
## bomb and throws before the lesson asks) never waits on a step they already did.
func _bot_hit() -> bool:
	return bot.hp < TrainingBot.HITS


## Squeezed out at least one bomb (or already broke the bot).
func _made_bomb() -> bool:
	return _recharged or bot.hp <= 0


func _bot_broken() -> bool:
	return bot.hp <= 0


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
	if _greyed != not _lifted.is_empty():
		_greyed = not _lifted.is_empty()
		grey.play(&"in" if _greyed else &"out")


func _finish() -> void:
	done = true
	_focus([])
	hud.coach("")
	hud.show_hint("")
	core_arrow.hide()
	if is_instance_valid(bot):
		bot.break_down()


func _process(_delta: float) -> void:
	if core_arrow.visible and is_instance_valid(bot):
		core_arrow.global_position = bot.core.global_position + ARROW_ABOVE_CORE
	if not done and not _lifted.is_empty() and is_instance_valid(player.held_bomb) and not _lifted.has(player.held_bomb):
		_focus(_lifted + [player.held_bomb])  # a bomb he pulls out stays in colour
	if not done or player == null:
		return
	if player.is_on_floor() and stage.panel_at(player.global_position.x).belt_speed != 0.0:
		_tip("belt", "CONVEYOR BELTS PUSH YOU AROUND!")
	var held := player.held_bomb
	if is_instance_valid(held):
		var fuse: Timer = held.get_node("FuseTimer")
		if not fuse.is_stopped() and fuse.time_left < 1.3:
			_tip("hot_bomb", "IT'S ABOUT TO BLOW!  THROW IT, OR [A] TO BOUNCE OFF IT!")
	if player.ammo == 0 and not is_instance_valid(held):
		_tip("no_ammo", "OUT OF BOMBS!  HOLD [A] TO SQUEEZE OUT MORE.")


func _on_attack_started(attack: StringName) -> void:
	match attack:
		&"stomp":
			_tip("stomp", "HIS FOOT WALKS TO THE RED RING.  MOVE!")
		&"step":
			_tip("step", "THE GIANT STEPS TO THE RED RING.  MOVE!")
		&"rocket":
			_tip("rocket", "ROCKET HAND!  JUMP OVER IT  (OR DASH THROUGH).")
		&"swoop":
			_tip("swoop", "HE DASHES ALONG THE LIGHT BEAM!  GET OFF IT!")
		&"hop":
			_tip("hop", "HE JUMPS!  JUMP THE SHOCKWAVES WHEN HE LANDS.")
		&"slam":
			_tip("slam", "FIST SLAM!  JUMP THE SHOCKWAVES.")
		&"spit":
			_tip("spit", "ZAP BALLS!  DODGE THEM (OR DASH THROUGH).")
		&"laser":
			_tip("laser", "EYE LASER!  STEP OUT OF THE RED LINE!")


func _on_hp_changed(hp: int) -> void:
	if hp == 1:
		_tip("last_heart", "ONE HEART LEFT!  LOSE IT AND YOU START OVER!")


func _tip(key: String, text: String, seconds := 3.5) -> void:
	if not done or seen.has(key):
		return
	seen[key] = true
	hud.show_tip(text, seconds)
