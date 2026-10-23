extends SceneTree
## Headless logic checks. Run from the project folder:
##   "$GODOT" --headless --path . --import
##   "$GODOT" --headless --path . -s tests/test_logic.gd
## Exit code 0 = all passed; 1 = a FAIL or any engine/script error; 2 = hung (watchdog).

## Counts every engine or script error and warning raised while the tests run,
## so a crash inside a test fails the suite instead of passing silently.
class ErrorCounter extends Logger:
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		count += 1


var failures := 0
var _errors := ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	# A runtime error inside a test stops _run before quit(); the watchdog ends the process instead of hanging.
	create_timer(60.0, true, false, true).timeout.connect(_on_timeout)
	_run.call_deferred()


func _run() -> void:
	Tutorial.done = true  # fight-logic tests skip the lesson; _test_tutorial runs it on its own
	_test_bomb()
	await _test_player()
	await _test_arena()
	await _test_boss()
	await _test_game_wiring()
	await _test_phase_extras()
	await _test_skip_phase()
	await _test_pause()
	await _test_stage()
	await _test_tutorial()
	await _test_tutorial_rush()
	await _test_title()
	if _errors.count:
		printerr("%d engine/script error(s) during tests" % _errors.count)
	print("%d failure(s)" % failures)
	quit(1 if failures or _errors.count else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS  ", what)
	else:
		failures += 1
		printerr("FAIL  ", what)


func _test_bomb() -> void:
	var bomb: Bomb = load("res://scenes/boss/bomb.tscn").instantiate()
	root.add_child(bomb)
	bomb.pick_up()
	check(bomb.freeze and bomb.collision_layer == 0, "picked-up bomb is frozen and ghosted")
	bomb.throw(Vector2(100, -100))
	check(bomb.thrown and not bomb.freeze and bomb.collision_layer == Bomb.LAYER_BOMB, "thrown bomb is live")
	bomb.explode()
	bomb.explode()
	check(bomb.exploded, "explode is safe to call twice")


func _test_player() -> void:
	var player: Player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	var died := [false]
	player.died.connect(func() -> void: died[0] = true)
	player.take_hit()
	check(player.hp == 2, "a hit costs one heart")
	player.take_hit()
	check(player.hp == 2, "invulnerable right after a hit")
	player.invuln.stop()
	player.take_hit()
	player.invuln.stop()
	player.take_hit()
	check(player.hp == 0 and died[0], "losing the last heart emits died")
	player.reset(Vector2(100, 100))
	check(player.hp == Player.MAX_HP and player.visible, "reset refills hearts and shows the player")
	player.queue_free()
	await process_frame


func _test_arena() -> void:
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	var player: Player = game.get_node("Player")
	for i in 60:
		await physics_frame
	check(player.is_on_floor(), "player stands on the arena floor")
	check(pow(player.jump_velocity, 2.0) / (2.0 * player.gravity) > 640.0 - 468.0, "a jump clears the side platforms")
	player.hurtbox.monitoring = false
	Input.action_press("dash")
	await physics_frame
	await physics_frame
	Input.action_release("dash")
	var hp_before := player.hp
	player.take_hit()
	check(player.dashing and absf(player.velocity.x) == player.dash_speed, "C dashes fast along the facing")
	check(player.hp == hp_before, "a dash dodges hits")
	await create_timer(0.3).timeout
	check(not player.dashing and absf(player.velocity.x) < player.dash_speed, "the dash ends on its own")
	game.queue_free()
	await process_frame


func _on_timeout() -> void:
	printerr("TIMEOUT: a test crashed or hung")
	quit(2)


func _test_boss() -> void:
	var boss: Boss = load("res://scenes/boss/boss.tscn").instantiate()
	root.add_child(boss)
	await process_frame
	check(not boss.take_hit(), "boss ignores hits during the intro")
	boss.start_fight()
	check(is_equal_approx(boss.rig.position.y, 520.0), "intro starts with the boss sunk, no first-frame pop")
	check([boss.next_attack(), boss.next_attack(), boss.next_attack()] == [&"slam", &"bombs", &"slam"], "phase 1 cycles slam, bombs")
	var phases := []
	var won := [false]
	boss.phase_changed.connect(func(p: int) -> void: phases.append(p))
	boss.defeated.connect(func() -> void: won[0] = true)
	for i in boss.hits_total():
		boss.state = Boss.State.IDLE
		boss.take_hit()
	check(phases == [1, 2], "phase advances every 3 hits")
	check(won[0] and boss.state == Boss.State.DEAD, "9 hits defeat the boss")
	boss.queue_free()

	var boss2: Boss = load("res://scenes/boss/boss.tscn").instantiate()
	root.add_child(boss2)
	boss2.rig.position = Vector2.ZERO
	boss2.state = Boss.State.IDLE
	var bomb: Bomb = load("res://scenes/boss/bomb.tscn").instantiate()
	root.add_child(bomb)
	bomb.global_position = Vector2(200, 560)  # held here first, like a real throw
	bomb.pick_up()
	await physics_frame
	var core_at: Vector2 = boss2.get_node("Rig/Core").global_position
	bomb.throw(Vector2.ZERO)
	bomb.global_position = core_at
	for i in 5:
		await physics_frame
	check(boss2.hp == Boss.HITS_PER_PHASE - 1 and bomb.exploded, "a thrown bomb on the core hurts the boss")
	check(bomb.global_position.distance_to(core_at) < 40.0, "the blast stays on the core, not back where the bomb was thrown from")
	boss2.queue_free()
	await process_frame


func _test_game_wiring() -> void:
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var player: Player = game.get_node("Player")
	var boss: Boss = game.get_node("Boss")
	var hud: HUD = game.get_node("HUD")
	player.take_hit()
	check(hud.hearts[2].texture == HUD.HEART_EMPTY and hud.hearts[1].texture == HUD.HEART_FULL, "losing a heart updates the HUD")
	boss.state = Boss.State.IDLE
	boss.take_hit()
	check(hud.boss_bar.value == boss.hits_total() - 1, "a boss hit updates the boss bar")
	boss.defeated.emit()
	await process_frame
	check(not player.hurtbox.monitoring, "player can't be hurt after the knockout")
	game.queue_free()
	await process_frame
	Engine.time_scale = 1.0


func _test_phase_extras() -> void:
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var boss: Boss = game.get_node("Boss")
	boss.phase = 1
	check([boss.next_attack(), boss.next_attack(), boss.next_attack(), boss.next_attack()] == [&"slam", &"bombs", &"laser", &"bombs"], "phase 2 adds the laser")
	check(boss.anim.has_animation(&"laser"), "laser animation exists")
	boss.phase_changed.emit(2)
	var stage: Stage = game.get_node("Arena")
	check(stage.panels[7].collapsed and stage.panels[14].collapsed, "phase 3 opens the pits")
	check(not stage.debris_timer.is_stopped(), "phase 3 starts the falling rubble")
	game.queue_free()
	await process_frame


func _test_skip_phase() -> void:
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var boss: Boss = game.get_node("Boss")
	var hud: HUD = game.get_node("HUD")
	check(hud.skip_button.visible, "skip-phase button shows in debug runs")
	hud.skip_button.pressed.emit()
	check(boss.phase == 1 and boss.hp == Boss.HITS_PER_PHASE, "skip phase jumps to phase 2 with full hits")
	boss.skip_phase()
	boss.skip_phase()
	check(boss.state == Boss.State.DEAD, "skipping from the last phase knocks the king out")
	game.queue_free()
	await process_frame
	Engine.time_scale = 1.0


func _test_pause() -> void:
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var menu: PauseMenu = game.get_node("PauseMenu")
	var press := InputEventAction.new()
	press.action = "pause"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	check(paused and menu.visible, "pause key freezes the fight and shows the menu")
	check(menu.fullscreen.text.begins_with("FULLSCREEN: "), "fullscreen button shows its state")
	menu.resume.pressed.emit()
	check(not paused and not menu.visible, "resume unfreezes and hides the menu")
	game.queue_free()
	await process_frame
	paused = false


func _test_stage() -> void:
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var stage: Stage = game.get_node("Arena")
	var player: Player = game.get_node("Player")
	check(stage.panels.size() == 16, "the floor is 16 panels across a 2560 px arena")
	var piston: Node2D = stage.get_node("Piston")
	check(stage.panels[4].belt_speed == 0.0 and not piston.get_node("AnimationPlayer").is_playing() and stage.zap_timer.is_stopped(), "phase 1 is plain, still stone")
	stage.set_phase(1)
	check(stage.panels[4].belt_speed > 0.0 and stage.panels[11].belt_speed < 0.0, "phase 2 starts conveyors pushing both ways")
	check(piston.get_node("AnimationPlayer").is_playing() and not stage.zap_timer.is_stopped(), "phase 2 starts the lifts and zaps")
	await _ride_lift(player, piston.get_node("Body"))
	var belt_before: float = stage.panels[4].belt_speed
	stage.set_phase(2)
	check(stage.panels[4].belt_speed == -belt_before, "conveyors reverse in phase 3")
	player.global_position = Vector2(240, 598)
	stage.zap_near_player()
	var panel: FloorPanel = stage.panel_at(240)
	check(panel.zapping and panel.warn.visible, "a zap starts with warning stripes under the player")
	await create_timer(FloorPanel.WARN_TIME + 0.15).timeout
	check(panel.zap.visible and not panel.zap_shape.disabled, "then the panel goes live")
	stage.panels[7].collapse()
	var hp_before := player.hp
	player.invuln.stop()
	player.global_position = Vector2(1200, 900)
	await physics_frame
	await physics_frame
	check(player.hp == hp_before - 1 and player.global_position.y < 700 and not stage.panel_at(player.global_position.x).collapsed, "a pit costs a heart and respawns the player on solid floor")
	game.queue_free()
	await process_frame
	Engine.time_scale = 1.0


## Stand on a moving lift for most of a cycle: the player must ride it, not float or get flung.
func _ride_lift(player: Player, body: Node2D) -> void:
	player.hurtbox.monitoring = false
	player.global_position = body.global_position + Vector2(0, -60)
	player.velocity = Vector2.ZERO
	var off := 0
	var worst_gap := 0.0
	var max_up := 0.0
	for i in 200:
		await physics_frame
		if i > 20:
			off += 0 if player.is_on_floor() else 1
			worst_gap = maxf(worst_gap, absf((body.global_position.y - 12.0) - (player.global_position.y + 42.0)))
			max_up = minf(max_up, player.velocity.y)
	check(off < 4 and worst_gap < 6.0, "the player rides a moving lift (off %d frames, gap %.1f px)" % [off, worst_gap])
	check(max_up > -400.0, "a lift never launches the player (peak vy %.0f)" % max_up)
	player.hurtbox.monitoring = true


func _test_tutorial() -> void:
	Tutorial.done = false
	Tutorial.seen = {}
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	var boss: Boss = game.get_node("Boss")
	var hud: HUD = game.get_node("HUD")
	var tutorial: Tutorial = game.get_node("Tutorial")
	await create_timer(2.3).timeout
	check(not boss.visible and is_instance_valid(tutorial.bot) and hud.coach_label.visible, "the tutorial starts against Lil' Watt with the king hidden and a big instruction")
	check(hud.boss_name.text == "LIL' WATT" and hud.boss_bar.value == TrainingBot.HITS, "the boss bar shows the training bot")
	var player: Player = game.get_node("Player")
	check(tutorial.spotlight.visible and player.z_index > tutorial.spotlight.z_index, "the lesson greys out everything but the hero")
	Input.action_press("move_right")
	await create_timer(0.8).timeout
	Input.action_release("move_right")
	await create_timer(0.8).timeout
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	await create_timer(1.0).timeout
	Input.action_press("dash")
	await physics_frame
	await physics_frame
	Input.action_release("dash")
	await create_timer(1.2).timeout
	check(is_instance_valid(tutorial._practice), "walking, jumping then dashing brings out a practice bomb")
	check(tutorial._practice.z_index > tutorial.spotlight.z_index, "the practice bomb stays in colour")
	var skip := InputEventAction.new()
	skip.action = "skip_tutorial"
	skip.pressed = true
	Input.parse_input_event(skip)
	await create_timer(0.4).timeout
	check(Tutorial.done and not tutorial.spotlight.visible and player.z_index < tutorial.spotlight.z_index, "Enter skips the rest and lifts the grey-out")
	await create_timer(1.8).timeout
	check(not is_instance_valid(tutorial.bot) and boss.visible and boss.state == Boss.State.INTRO, "skipping blows up Lil' Watt and the king rises")
	game.queue_free()
	await process_frame
	Engine.time_scale = 1.0


## A player who grabs the practice bomb and hits the core before the lesson asks must not get stuck.
func _test_tutorial_rush() -> void:
	Tutorial.done = false
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	var player: Player = game.get_node("Player")
	var boss: Boss = game.get_node("Boss")
	var tutorial: Tutorial = game.get_node("Tutorial")
	await create_timer(2.3).timeout
	Input.action_press("move_right")
	await create_timer(0.8).timeout
	Input.action_release("move_right")
	await create_timer(0.8).timeout
	for action in ["jump", "dash"]:
		Input.action_press(action)
		await physics_frame
		await physics_frame
		Input.action_release(action)
		await create_timer(1.0).timeout
	while not is_instance_valid(tutorial._practice):
		await physics_frame
	player.global_position = tutorial._practice.global_position + Vector2(-30, -12)
	await physics_frame
	await physics_frame
	player._grab()
	var bomb := player.held_bomb
	player._throw()
	bomb.global_position = tutorial.bot.core.global_position
	await create_timer(2.0).timeout
	var hud: HUD = game.get_node("HUD")
	check(tutorial.bot.hp == TrainingBot.HITS - 1 and hud.coach_label.text.begins_with("AGAIN"), "hitting the core early moves the lesson on")
	check(player.hp == Player.MAX_HP, "a hit on Lil' Watt never hurts the thrower")
	for i in TrainingBot.HITS - 1:
		while not is_instance_valid(tutorial._practice) or tutorial._practice.exploded:
			await physics_frame
		tutorial._practice.throw(Vector2.ZERO)
		tutorial._practice.global_position = tutorial.bot.core.global_position
		await create_timer(0.3).timeout
	check(hud.boss_bar.value == 0, "every hit on Lil' Watt shows on the boss bar")
	await create_timer(4.5).timeout
	check(Tutorial.done and boss.visible and boss.hits_left() == boss.hits_total() and hud.boss_name.text == "KING KILOWATT", "breaking Lil' Watt brings in the king at full health")
	game.queue_free()
	await process_frame
	Engine.time_scale = 1.0


func _test_title() -> void:
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	check(title.get_node("Card/VBox/Start").has_focus(), "title focuses the Start button")
	check(title.get_node("FilmFilter/Rect").material != null, "film filter has its shader material")
	title.queue_free()
	await process_frame
