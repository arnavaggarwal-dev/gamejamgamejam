extends Node2D
## Arena root: wires player, boss, stage, backdrop, tutorial and HUD together and handles restarts.

const GOAL_HINT := "PULL OUT A BOMB [Z], THROW IT AT THE CORE!  HOLD [A] TO MAKE MORE."
const HELPER := preload("res://scenes/boss/training_bot.tscn")
const WATT_SPOT := Vector2(2450.0, -560.0)  # phase 4: Lil' Watt beams into the rising king from here
const WATT_SIZE := Vector2(2.0, 2.0)  # phase 4's Lil' Watt is powered up (and readable zoomed out)
const WATT_DOWN := Vector2(0.0, -102.0)  # Lil' Watt (2x) lying on a ledge, from where the hero would stand

@onready var player: Player = $Player
@onready var boss: Boss = $Boss
@onready var hud: HUD = $HUD
@onready var stage: Stage = $Arena
@onready var backdrop: Node2D = $Backdrop
@onready var tutorial: Tutorial = $Tutorial
@onready var projectiles: Node2D = $Projectiles
@onready var respawn: Marker2D = $RespawnPoint
@onready var camera: Camera2D = $Camera2D
@onready var camera_moves: AnimationPlayer = $Camera2D/Moves  # doom (3x zoom-out), drop / lift (the letterbox view)
@onready var kings_crown: Sprite2D = $KingsCrown

var helper: TrainingBot  # Lil' Watt powering the giant in phase 4


func _ready() -> void:
	player.hp_changed.connect(hud.set_hearts)
	player.ammo_changed.connect(hud.set_ammo)
	player.projectiles = projectiles
	player.died.connect(_on_player_died)
	player.fell_in_pit.connect(_on_player_fell)
	boss.health_changed.connect(hud.set_boss_health)
	boss.health_changed.connect(_on_first_hit, CONNECT_ONE_SHOT)
	boss.health_changed.connect(func(_left: int, _total: int) -> void: backdrop.cheer())
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.defeated.connect(_on_boss_defeated)
	boss.crown_popped.connect(_on_crown_popped)
	hud.retry_pressed.connect(get_tree().reload_current_scene)
	hud.skip_phase_pressed.connect(boss.skip_phase)
	tutorial.setup(player, boss, hud, stage, projectiles)
	hud.set_hearts(player.hp)
	hud.set_ammo(player.ammo)
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
	if boss.state == Boss.State.DEAD:
		return  # he already won: no retry, no fresh Lil' Watt
	for child in projectiles.get_children():
		child.queue_free()
	player.reset(stage.safe_spot(respawn.global_position.x) if boss.phase == Boss.FINAL else respawn.global_position)
	boss.restart_phase()
	if boss.phase == Boss.FINAL and boss.state != Boss.State.PHASE_SHIFT:
		_spawn_helper(Vector2(player.global_position.x + TrainingBot.LEAD, 200.0))  # a fresh Lil' Watt for the retry
		helper.power_target = boss.weak_point()
		helper.fight()
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
	stage.set_phase(phase)
	backdrop.set_phase(phase)
	if phase == Boss.FINAL:
		_final_phase()
		return
	hud.show_banner("PHASE %d" % (phase + 1), 1.2)
	if phase == 2:
		get_tree().call_group("camera", "shake", 14.0)


## Phase 4 cutscene. His head shatters and the camera pulls back threefold over the arena of
## doom; Lil' Watt flies in to the fallen crown ("...DAD?"), turns on you, then beams his power
## into the wreck and the king rises again, as tall as the screen. The camera follows Lil' Watt
## until the fight resumes, with Lil' Watt fighting beside the king: break it to finish him.
func _final_phase() -> void:
	player.frozen = true
	hud.cinema(true)
	for child in projectiles.get_children():
		child.queue_free()
	camera_moves.play(&"doom")  # 3x zoom-out over 0..3840 x -1440..720, the view dropped for the letterbox
	await _wait(2.6)
	if boss.state == Boss.State.DEAD:
		return  # (debug skip) knocked out mid-cutscene
	var crown := boss.fallen_crown.global_position
	_spawn_helper(crown + Vector2(1800.0, -1500.0))
	camera.target = helper
	await _fly(crown + Vector2(0.0, -300.0), 1.8)
	hud.coach("...DAD?")
	await _wait(1.8)
	helper.get_angry()
	hud.coach("YOU BROKE MY DAD!!")
	await _wait(2.2)
	if boss.state == Boss.State.DEAD:
		return
	hud.coach("")
	await _fly(WATT_SPOT, 1.4)
	hud.coach("RISE, FATHER!!")
	helper.channel()
	helper.power_target = boss.weak_point()
	boss.revive()
	await boss.revived
	hud.coach("")
	hud.boss_bar_aside()
	hud.cinema(false)
	camera_moves.play(&"lift")
	camera.target = player
	player.frozen = false
	helper.fight()
	hud.show_banner("FINAL PHASE", 1.4)
	hud.show_tip("LIL' WATT POWERS THE KING!  HIT ITS CORE RIGHT AFTER IT SHOOTS.", 5.0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


## Cutscene move: flies Lil' Watt somewhere (the camera follows it).
func _fly(to: Vector2, seconds: float) -> void:
	var trip := create_tween()
	trip.tween_property(helper, "global_position", to, seconds).set_trans(Tween.TRANS_SINE)
	await trip.finished


## A fresh Lil' Watt for phase 4, parked at `at` (the caller sets it fighting or flying).
func _spawn_helper(at: Vector2) -> void:
	if is_instance_valid(helper):
		helper.queue_free()
	helper = HELPER.instantiate()
	add_child(helper)
	helper.global_position = at
	helper.scale = WATT_SIZE
	helper.z_index = 2  # over its cable (top_level, so its z 1 is absolute), which runs over the king
	helper.roaming = false
	helper.roam_max = Stage.DOOM_W - 120.0
	helper.projectiles = projectiles
	helper.hit.connect(func(_left: int) -> void: boss.power_hit())
	hud.set_boss_name("LIL' WATT")
	hud.set_boss_health(helper.hp, TrainingBot.HITS)


func _on_boss_defeated() -> void:
	player.hurtbox.set_deferred("monitoring", false)  # deferred: defeated fires inside the WeakPoint physics callback
	stage.stop()
	for child in projectiles.get_children():
		child.queue_free()
	await _ending()
	hud.show_hint("")
	await hud.show_banner("LONG LIVE THE LITTLE GUY!", 3.0)
	hud.show_end("YOU WIN!")


## The knockout, letterboxed. Lil' Watt is knocked out of the sky and the power link snaps; the
## king goes limp and comes apart in his moat (his "death" clip), his crown popping off into the
## sky. Once he is gone the crown drops out of the sky onto the little guy (much too big); Lil'
## Watt comes round, takes it in, and bows to the new king. The hero stays frozen afterwards.
func _ending() -> void:
	player.frozen = true
	camera.target = player
	camera_moves.play(&"drop")
	hud.cinema(true)
	hud.coach("")
	hud.flash(1.0, 0.1)
	if is_instance_valid(helper):
		helper.knock_out(stage.safe_spot(helper.global_position.x) + WATT_DOWN)
	await _wait(5.4)  # the king comes apart and sinks; the white-out fades
	kings_crown.global_position = Vector2(player.global_position.x, -1700.0)
	kings_crown.rotation = 0.8
	kings_crown.scale = Vector2(6.3, 6.3)
	kings_crown.show()
	var drop := create_tween().set_parallel()
	drop.tween_property(kings_crown, "global_position", player.crown.global_position, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(kings_crown, "rotation", 0.0, 0.9)
	drop.tween_property(kings_crown, "scale", player.crown.global_scale, 0.9)
	await drop.finished
	kings_crown.hide()
	player.wear_crown()
	get_tree().call_group("camera", "shake", 12.0)
	await _wait(1.0)
	if is_instance_valid(helper):
		helper.sit_up()
		hud.coach("...DAD?")
		await _wait(1.8)
		helper.bow()
		hud.coach("...FINE.  YOU'RE THE KING NOW.")
		await _wait(2.6)
	hud.coach("")
	hud.cinema(false)
	hud.boss_box.hide()  # nobody left to fight
	camera_moves.play(&"lift")
	# he stays frozen (and unhurtable) from here on: the fight is won


## The king's crown pops off as he comes apart: it spins up out of sight (it comes back down
## on the hero at the end of the knockout).
func _on_crown_popped(at: Vector2) -> void:
	kings_crown.global_position = at
	kings_crown.show()
	var fly := create_tween().set_parallel()
	fly.tween_property(kings_crown, "global_position:y", -1900.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fly.tween_property(kings_crown, "rotation", TAU * 2.0, 0.9)
