class_name Game
extends Node2D
## Arena root: wires player, boss, stage, backdrop, tutorial and HUD together and handles restarts.

const GOAL_HINT := "PULL OUT A BOMB  [Z]  THROW IT AT THE CORE!  HOLD  [A]  TO MAKE MORE."
const HELPER := preload("res://scenes/boss/training_bot.tscn")
const FIREWORK := preload("res://scenes/fx/firework.tscn")
const FIREWORK_COLORS := [Color("#db9692"), Color("#dbd991"), Color("#96db91"), Color("#92b5db"), Color("#db91d3"), Color("#b991dc")]
const WATT_TINT := Color(0.588, 0.859, 0.569)  # speaker names in the phase 4 cutscene
const KING_TINT := Color(0.859, 0.851, 0.569)
const WATT_SPOT := Vector2(2450.0, -560.0)  # phase 4: Lil' Watt beams into the rising king from here
const WATT_SIZE := Vector2(2.0, 2.0)  # phase 4's Lil' Watt is powered up (and readable zoomed out)
const WATT_DOWN := Vector2(0.0, -102.0)  # Lil' Watt (2x) lying on a ledge, from where the hero would stand
const CLOSE_UP_ZOOM := 1.25  # the crowning, close up on the hero

@onready var player: Player = $Player
@onready var boss: Boss = $Boss
@onready var hud: HUD = $HUD
@onready var stage: Stage = $Arena
@onready var backdrop: Node2D = $Backdrop
@onready var tutorial: Tutorial = $Tutorial
@onready var projectiles: Node2D = $Projectiles
@onready var camera: Camera2D = $Camera2D
@onready var camera_moves: AnimationPlayer = $Camera2D/Moves  # doom (3x zoom-out), drop / lift (the letterbox view)
@onready var kings_crown: Sprite2D = $KingsCrown
@onready var firework_timer: Timer = $FireworkTimer  # the ending's fireworks, one per tick
@onready var attempt_label: Label = $Attempt  # big "ATTEMPT N" in the world by the start, Geometry Dash style

static var attempt := 1  # this run's try: a game over adds one, the title screen resets it

var helper: TrainingBot  # Lil' Watt powering the giant in phase 4
var _fighting := false
var _clock := 0.0  # seconds of fight this attempt (not the tutorial, not pauses): a win screen stat


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
	hud.retry_pressed.connect(_play_again)
	hud.title_pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/title.tscn"))
	firework_timer.timeout.connect(_launch_firework)
	hud.skip_phase_pressed.connect(boss.skip_phase)
	tutorial.setup(player, boss, hud, stage, projectiles)
	hud.set_hearts(player.hp)
	hud.set_ammo(player.ammo)
	hud.set_boss_health(boss.hits_left(), boss.hits_total())
	Sfx.music(&"title" if attempt == 1 else &"fight")
	if attempt > 1:
		attempt_label.text = "ATTEMPT %d" % attempt
		attempt_label.show()
		await _wait(1.0)
	else:
		await hud.show_banner("LITTLE GUY  vs  BIG GUY", 2.0)
	if Tutorial.done:
		hud.show_hint(GOAL_HINT)
	else:
		await tutorial.run()  # Lil' Watt first; the king stays hidden until it breaks
		hud.show_banner("HERE COMES THE KING!", 1.6)
	boss.start_fight()
	Sfx.music(&"fight")
	_fighting = true


func _process(delta: float) -> void:
	if _fighting:
		_clock += delta


## F2 skips to the next phase in debug runs (same as the HUD button).
func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("debug_skip_phase"):
		boss.skip_phase()


func _on_first_hit(_hits_left: int, _hits_total: int) -> void:
	if Tutorial.done:
		hud.show_hint("")


## Losing all five hearts is game over: he splatters (goo over the screen too, Smash style), the
## king celebrates, and the whole fight starts again from stage 1 (a finished tutorial is not
## replayed).
func _on_player_died() -> void:
	if boss.state != Boss.State.DEAD:
		hud.splat()
		boss.celebrate()
		Sfx.music(&"lose")
	await get_tree().create_timer(1.0, false).timeout
	if boss.state == Boss.State.DEAD:
		return  # he already won: no game over
	await hud.show_banner("GAME OVER", 1.6)
	attempt += 1
	get_tree().reload_current_scene()


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
## doom; Lil' Watt flies in to the fallen crown to the "rise" music, and father and son talk (the
## king from the wreck, his crown sparking) before it turns on you, beams its power into the wreck
## and the king rises again, as tall as the screen. The camera follows Lil' Watt until the fight
## resumes, with Lil' Watt fighting beside the king: break it to finish him.
func _final_phase() -> void:
	Sfx.music(&"")  # a hush while the camera pulls back
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
	Sfx.music(&"rise")
	await _fly(crown + Vector2(0.0, -300.0), 1.8)
	_watt_says("...DAD?")
	await _wait(1.5)
	_king_says("S-SON...?  I'M IN PIECES...")
	await _wait(2.0)
	helper.get_angry()
	_watt_says("YOU BROKE MY DAD!!")
	await _wait(1.8)
	_king_says("RUN...  YOU'RE JUST A LITTLE GUY.")
	await _wait(2.4)
	_watt_says("SO IS HE!!")
	await _wait(1.6)
	if boss.state == Boss.State.DEAD:
		return
	hud.coach("")
	await _fly(WATT_SPOT, 1.4)
	_watt_says("RISE, FATHER!!")
	helper.channel()
	helper.power_target = boss.weak_point()
	boss.revive()
	await boss.revived
	Sfx.play(&"roar")
	Sfx.music(&"final")
	hud.say("KING KILOWATT", "THAT'S MY BOY!!", KING_TINT)
	await _wait(1.4)
	hud.coach("")
	hud.boss_bar_aside()
	hud.cinema(false)
	camera_moves.play(&"lift")
	camera.target = player
	player.frozen = false
	helper.fight()
	hud.show_banner("FINAL PHASE", 1.4)
	hud.show_tip("LIL' WATT POWERS THE KING!  HIT ITS CORE RIGHT AFTER IT SHOOTS.", 5.0)


## Lil' Watt's lines in the phase 4 cutscene, each with a chirp.
func _watt_says(text: String) -> void:
	hud.say("LIL' WATT", text, WATT_TINT)
	Sfx.play(&"chirp")


## The king, in pieces, speaking from the wreck.
func _king_says(text: String) -> void:
	hud.say("KING KILOWATT", text, KING_TINT)
	boss.crackle()


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
	_fighting = false
	player.hurtbox.set_deferred("monitoring", false)  # deferred: defeated fires inside the WeakPoint physics callback
	stage.stop()
	for child in projectiles.get_children():
		child.queue_free()
	Sfx.music(&"")  # the K.O. lands in silence
	_knockout_slowmo()
	await _ending()
	hud.show_hint("")
	await hud.show_banner("LONG LIVE THE LITTLE GUY!", 3.0)
	hud.show_win(PackedStringArray([
		"TIME  %d:%02d" % [floori(_clock / 60.0), int(_clock) % 60],
		"ATTEMPTS  %d" % attempt,
		"HEARTS LEFT  %d / %d" % [player.hp, Player.MAX_HP],
		"BOMBS THROWN  %d" % player.bombs_thrown,
	]), rank(attempt, player.hp))
	Sfx.music(&"title")


## The run's rank on the win screen: S for a first-try win with 4+ hearts left, A for any
## first-try win, B within three attempts, C after that.
static func rank(attempts: int, hearts: int) -> String:
	if attempts == 1:
		return "S" if hearts >= 4 else "A"
	return "B" if attempts <= 3 else "C"


## The knockout blow lands in slow motion under a big K.O. (once the hit's own freeze is over).
func _knockout_slowmo() -> void:
	await get_tree().create_timer(0.15, true, false, true).timeout
	Engine.time_scale = 0.3
	hud.show_banner("K.O.!", 0.4)
	await get_tree().create_timer(1.2, true, false, true).timeout
	Engine.time_scale = 1.0


## The crowning, close up: the camera closes in on the hero (as the crown falls), then pulls back
## out over the arena of doom.
func _close_up(on: bool) -> Signal:
	camera.follow_y = on  # he may still be falling as the crown drops
	var move := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	move.tween_property(camera, "zoom", Vector2.ONE * (CLOSE_UP_ZOOM if on else 1.0 / 3.0), 0.9)
	if not on:
		move.tween_property(camera, "position:y", 360.0, 0.9)
	return move.finished


## A firework bursts somewhere in the top of the view, in a palette colour, sized for the zoom.
func _launch_firework() -> void:
	var firework: Node2D = FIREWORK.instantiate()
	add_child(firework)
	var view := get_viewport_rect().size / camera.zoom
	firework.global_position = camera.get_screen_center_position() + Vector2(randf_range(-0.42, 0.42) * view.x, randf_range(-0.38, -0.08) * view.y)
	firework.modulate = FIREWORK_COLORS.pick_random()
	firework.scale = Vector2.ONE / camera.zoom
	var pitch := randf_range(0.8, 1.3)
	get_tree().create_timer(0.5).timeout.connect(func() -> void: Sfx.play(&"firework", pitch, -4.0))  # as it bursts


## PLAY AGAIN after a win starts a fresh run (attempts back to 1).
func _play_again() -> void:
	attempt = 1
	get_tree().reload_current_scene()


## The knockout, letterboxed. Lil' Watt is knocked out of the sky and the power link snaps; the
## king goes limp and comes apart in his moat (his "death" clip), his crown popping off into the
## sky. Once he is gone the crown drops out of the sky onto the little guy (much too big), the
## camera closing in on him; he hops for joy while fireworks go up and confetti rains, then the
## camera pulls back out and Lil' Watt comes round, takes it in, and bows to the new king. The
## hero stays frozen afterwards.
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
	_close_up(true)
	await drop.finished
	kings_crown.hide()
	player.wear_crown()
	Sfx.music(&"win")
	get_tree().call_group("camera", "shake", 12.0)
	await _wait(0.4)
	player.celebrate()
	hud.celebrate()
	firework_timer.start()
	await _wait(2.0)  # the crowned hero hopping under the fireworks, close up
	await _close_up(false)
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
