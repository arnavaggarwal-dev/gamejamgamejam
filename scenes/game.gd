extends Node2D
## Arena root: wires player, boss, stage, backdrop, tutorial and HUD together and handles restarts.

const GOAL_HINT := "GRAB BOMBS [Z] AND THROW THEM AT THE CORE!"
const HELPER := preload("res://scenes/boss/training_bot.tscn")
const DOOM_ZOOM := Vector2.ONE / 3.0  # phase 4 pulls the camera back threefold

@onready var player: Player = $Player
@onready var boss: Boss = $Boss
@onready var hud: HUD = $HUD
@onready var stage: Stage = $Arena
@onready var backdrop: Node2D = $Backdrop
@onready var tutorial: Tutorial = $Tutorial
@onready var projectiles: Node2D = $Projectiles
@onready var respawn: Marker2D = $RespawnPoint
@onready var camera: Camera2D = $Camera2D

var helper: TrainingBot  # Lil' Watt powering the giant in phase 4


func _ready() -> void:
	player.hp_changed.connect(hud.set_hearts)
	player.died.connect(_on_player_died)
	player.fell_in_pit.connect(_on_player_fell)
	boss.health_changed.connect(hud.set_boss_health)
	boss.health_changed.connect(_on_first_hit, CONNECT_ONE_SHOT)
	boss.health_changed.connect(func(_left: int, _total: int) -> void: backdrop.cheer())
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.defeated.connect(_on_boss_defeated)
	hud.retry_pressed.connect(get_tree().reload_current_scene)
	hud.skip_phase_pressed.connect(boss.skip_phase)
	tutorial.setup(player, boss, hud, stage, projectiles)
	hud.set_hearts(player.hp)
	hud.set_boss_health(boss.hits_left(), boss.hits_total())
	await hud.show_banner("LITTLE GUY  vs  BIG GUY", 2.0)
	if Tutorial.done:
		hud.show_hint(GOAL_HINT)
	else:
		await tutorial.run()  # Lil' Watt first; the king stays hidden until it breaks
		hud.show_banner("HERE COMES THE KING!", 1.6)
	boss.start_fight()


## F2 skips to the next phase in debug runs (same as the HUD button).
func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("debug_skip_phase"):
		boss.skip_phase()


func _on_first_hit(_hits_left: int, _hits_total: int) -> void:
	if Tutorial.done:
		hud.show_hint("")


func _on_player_died() -> void:
	await get_tree().create_timer(1.0, false).timeout
	for child in projectiles.get_children():
		child.queue_free()
	player.reset(respawn.global_position)
	boss.restart_phase()
	if boss.phase == Boss.FINAL:
		_spawn_helper()  # a fresh Lil' Watt for the retry
	hud.show_banner("AGAIN!", 1.0)


## A pit costs a heart (even mid-blink): the screen goes fully white, the player is put back on
## solid floor while it is white, and the hurt blink makes him look like he warped there.
func _on_player_fell() -> void:
	player.invuln.stop()
	player.take_hit()
	hud.flash(1.0, 0.18)
	if player.hp > 0:
		player.global_position = stage.safe_spot(player.global_position.x)
		player.velocity = Vector2.ZERO


func _on_boss_phase_changed(phase: int) -> void:
	hud.flash()
	hud.show_banner("PHASE %d" % (phase + 1), 1.2)
	stage.set_phase(phase)
	backdrop.set_phase(phase)
	if phase == 2:
		get_tree().call_group("camera", "shake", 14.0)
	if phase == Boss.FINAL:
		_final_phase()


## Phase 4: the camera pulls back threefold over the arena of doom while the king rebuilds
## himself, and Lil' Watt flies in to power him. Breaking Lil' Watt finishes him.
func _final_phase() -> void:
	camera.limit_top = -1440  # 720 x 3 tall, floor still at the bottom of the view
	camera.limit_right = int(Stage.DOOM_W)
	create_tween().tween_property(camera, "zoom", DOOM_ZOOM, 2.5).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1.2, false).timeout
	_spawn_helper()
	hud.show_tip("LIL' WATT IS POWERING THE KING!  BREAK LIL' WATT!", 5.0)


func _spawn_helper() -> void:
	if is_instance_valid(helper):
		helper.queue_free()
	helper = HELPER.instantiate()
	add_child(helper)
	helper.global_position = Vector2(boss.weak_point().global_position.x, 420.0)
	helper.power_target = boss.weak_point()
	helper.roam_max = Stage.DOOM_W - 120.0
	helper.hit.connect(func(_left: int) -> void: boss.power_hit())
	hud.set_boss_name("LIL' WATT")
	hud.set_boss_health(helper.hp, TrainingBot.HITS)


func _on_boss_defeated() -> void:
	player.hurtbox.set_deferred("monitoring", false)  # deferred: defeated fires inside the WeakPoint physics callback
	stage.stop()
	if is_instance_valid(helper) and helper.hp > 0:
		helper.break_down()  # (debug skip) the power source goes with him
	backdrop.cheer(6.0)
	hud.flash()
	hud.show_hint("")
	await hud.show_banner("KNOCKOUT!", 2.5)
	hud.show_end("YOU WIN!")
