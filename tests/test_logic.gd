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
	create_timer(120.0, true, false, true).timeout.connect(_on_timeout)
	_run.call_deferred()


func _run() -> void:
	Tutorial.done = true  # fight-logic tests skip the lesson; _test_tutorial runs it on its own
	_test_bomb()
	await _test_player()
	await _test_arena()
	await _test_hero_juice()
	await _test_boss()
	await _test_giant_stages()
	await _test_boss_moves()
	await _test_target_spin()
	await _test_eye()
	await _test_roam()
	await _test_game_wiring()
	await _test_phase_extras()
	await _test_skip_phase()
	await _test_pause()
	await _test_stage()
	await _test_core_platform()
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
	bomb.global_position = Vector2(-4000, -4000)  # its blast must not reach the next test's player at the origin
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
	check(Player.MAX_HP == 5 and player.hp == 5, "the hero starts with 5 hearts")
	player.take_hit()
	check(player.hp == Player.MAX_HP - 1, "a hit costs one heart")
	player.take_hit()
	check(player.hp == Player.MAX_HP - 1, "invulnerable right after a hit")
	for i in Player.MAX_HP - 1:
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
	await _land(player)
	var up: Vector2 = await _aimed_dash(player, ["aim_up"])
	check(up.is_equal_approx(Vector2(0, -player.dash_speed)), "Up + C dashes straight up")
	await _land(player)
	var diag: Vector2 = await _aimed_dash(player, ["move_right", "aim_up"])
	check(diag.is_equal_approx(Vector2(1, -1).normalized() * player.dash_speed), "a diagonal dash goes just as far (normalized)")
	await _land(player)
	var ground_down: Vector2 = await _aimed_dash(player, ["move_down"])
	check(ground_down.y == 0.0 and absf(ground_down.x) == player.dash_speed, "Down + C on the ground dashes along the floor instead")
	await _land(player)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await create_timer(0.25).timeout
	var air_down: Vector2 = await _aimed_dash(player, ["move_down"])
	check(air_down.is_equal_approx(Vector2(0, player.dash_speed)), "Down + C in the air dashes straight down")
	await _land(player)
	Input.action_press("dash")
	await physics_frame
	await physics_frame
	Input.action_release("dash")
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	check(not player.dashing and player.velocity.y < 0.0 and absf(player.velocity.x) > player.speed, "jumping mid-dash cuts the dash into a jump that keeps its speed")
	await _land(player)
	await _aimed_dash(player, ["aim_up"])
	await create_timer(0.25).timeout  # the up-dash is over; he is in mid-air, no coyote left
	var splats_before := _count_scenes(game, "slime.tscn")
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	check(player.velocity.y < player.jump_velocity * 0.9, "after an up-dash he can still jump once in mid-air")
	check(_count_scenes(game, "slime.tscn") > splats_before, "a mid-air jump bursts a slimy splat")
	await create_timer(0.1).timeout
	var vy := player.velocity.y
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	check(player.velocity.y > vy, "only one mid-air jump until he lands")
	game.queue_free()
	await process_frame


## Holds the given arrows, taps dash and returns the dash velocity.
func _aimed_dash(player: Player, arrows: Array) -> Vector2:
	for a: String in arrows:
		Input.action_press(a)
	Input.action_press("dash")
	await physics_frame
	await physics_frame
	var v := player.velocity
	Input.action_release("dash")
	for a: String in arrows:
		Input.action_release(a)
	return v


func _count_scenes(parent: Node, file: String) -> int:
	return parent.get_children().filter(func(n: Node) -> bool: return n.scene_file_path.ends_with(file)).size()


func _land(player: Player) -> void:
	while not player.is_on_floor() or not player.dash_cooldown.is_stopped():
		await physics_frame


func _test_hero_juice() -> void:
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	var player: Player = game.get_node("Player")
	player.hurtbox.monitoring = false
	await _land(player)
	Input.action_press("dash")
	await physics_frame
	await physics_frame
	Input.action_release("dash")
	await create_timer(0.1).timeout
	check(_count_scenes(game, "afterimage.tscn") >= 2, "a dash leaves fading afterimages behind")
	await _land(player)
	var dust_before := _count_scenes(game, "dust.tscn")
	Input.action_press("move_right")
	await create_timer(0.7).timeout
	Input.action_release("move_right")
	check(_count_scenes(game, "dust.tscn") > dust_before, "running kicks up dust each stride")
	player.global_position = Vector2(200, 120)  # clear of the platforms, ~480 px above the floor
	player.velocity = Vector2.ZERO
	while player.is_on_floor():  # still flagged from before the teleport
		await physics_frame
	while not player.is_on_floor():
		await physics_frame
	check(player.art.scale.y < 0.9, "landing from a drop squashes him (%.2f)" % player.art.scale.y)
	player._land(0.0)
	var soft := player.art.scale.y
	player._land(1.0)
	check(is_equal_approx(soft, 0.9) and is_equal_approx(player.art.scale.y, 0.65), "the landing squash grows with the fall (hop 0.9, big drop 0.65)")
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
	check(is_equal_approx(boss.rig.position.y, -760.0), "intro drops the king in from above, no first-frame pop")
	check([boss.next_attack(), boss.next_attack(), boss.next_attack()] == [&"stomp", &"rain", &"stomp"], "stage 1 (legs) cycles stomp, bomb rain")
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
	var core_at: Vector2 = boss2.weak_point().global_position
	bomb.throw(Vector2.ZERO)
	bomb.global_position = core_at
	for i in 5:
		await physics_frame
	check(boss2.hp == Boss.HITS_PER_PHASE - 1 and bomb.exploded, "a thrown bomb on the core hurts the boss")
	check(bomb.global_position.distance_to(core_at) < 40.0, "the blast stays on the core, not back where the bomb was thrown from")
	boss2.queue_free()
	await process_frame


## Legs, then the torso falls into view, then the head; each stage has its own core.
func _test_giant_stages() -> void:
	var boss: Boss = load("res://scenes/boss/boss.tscn").instantiate()
	root.add_child(boss)
	await process_frame
	var armed := func(i: int) -> bool: return boss.cores[i].get_node("WeakPoint").monitoring
	check(boss.weak_point() == boss.cores[0] and armed.call(0) and not armed.call(1) and not armed.call(2), "stage 1: only the knee core can be hit")
	check(boss.legs.visible and boss.upper.position.y < -600.0, "stage 1: his legs fill the screen, the torso is out of frame above")
	var cracked := func(i: int) -> int: return boss.cracks[i].get_children().filter(func(n: Node) -> bool: return n.visible).size()
	check(cracked.call(0) == 0, "an unhurt leg has no cracks")
	boss.state = Boss.State.IDLE
	boss.take_hit()
	check(cracked.call(0) == 1, "the first hit cracks his leg")
	boss.state = Boss.State.IDLE
	boss.take_hit()
	check(cracked.call(0) == 3, "the second hit cracks it all over")
	boss.state = Boss.State.IDLE
	boss.take_hit()
	await create_timer(2.6).timeout
	check(not boss.legs.visible and is_zero_approx(boss.upper.position.y) and armed.call(1) and not armed.call(0), "breaking the legs drops the torso into view and arms the chest core")
	check(boss.head.position == Vector2(1090, 170) and boss.head.global_position.y > 0.0 and cracked.call(1) == 0, "stage 2: his head sits on the torso's shoulders (no stretched neck), torso uncracked")
	for i in Boss.HITS_PER_PHASE:
		boss.state = Boss.State.IDLE
		boss.take_hit()
	await create_timer(2.1).timeout  # the drop is over, his first attack is not yet
	check(not boss.body.visible and boss.head.global_position.y > 300.0 and boss.head.global_position.y < 450.0 and boss.head.get_node("Jets").visible and armed.call(2) and not armed.call(1), "breaking the torso brings the head in, hovering on jets, and arms the eye")
	check(boss.state == Boss.State.IDLE and boss.anim.current_animation == &"idle_3", "the head fights on")
	check([boss.next_attack(), boss.next_attack(), boss.next_attack()] == [&"swoop", &"spit", &"laser"], "stage 3 swoops, spits bombs and fires the laser")
	boss.queue_free()
	await process_frame


## The attacks that chase the player: the stomp walks its raised leg over, the torso lunges,
## the head swoops through (no player here, so they all go for x = 400).
func _test_boss_moves() -> void:
	var boss: Boss = load("res://scenes/boss/boss.tscn").instantiate()
	root.add_child(boss)
	await process_frame
	boss._play(&"stomp", Boss.State.ATTACK)
	await create_timer(0.6).timeout
	var knee_y: float = boss.weak_point().global_position.y
	check(boss.leg_f.position.y < -200.0 and knee_y > 0.0 and knee_y < 400.0, "the stomp lifts the leg with the knee still in view")
	await create_timer(0.4).timeout
	check(absf(boss.stomp_anchor.global_position.x - 400.0) < 2.0 and is_equal_approx(boss.stomp_ring.global_position.x, 400.0), "the raised leg walks over to the player's spot, under the red ring")
	await create_timer(1.8).timeout
	check(is_equal_approx(boss.stomp_anchor.position.x, 1020.0), "then walks back under him")
	boss.phase = 1
	boss._play(&"charge", Boss.State.ATTACK)
	await create_timer(0.55).timeout
	check(not boss.body.get_node("ChargeHitbox/CollisionShape2D").disabled, "the torso charge is dangerous while it lunges")
	await create_timer(0.25).timeout
	check(boss.body.position.x < -400.0, "the torso lunges ~420 px toward the player")
	check(is_equal_approx(boss.head.position.x - boss.body.position.x, 1090.0), "his head stays on the torso through the lunge")
	boss.phase = 2
	var hover := Vector2(1030, 380)  # the stage-3 hover spot the tell quivers around
	boss._play(&"swoop", Boss.State.ATTACK)
	await create_timer(0.65).timeout  # ~0.85 s of the tell at stage-3 speed
	check(boss.head.position.distance_to(hover) < 12.0 and boss.anim.current_animation == &"swoop", "the swoop tells for most of a second (eye flashing, head quivering) before it moves")
	check(boss.dash_beam.visible and absf(angle_difference(boss.dash_beam.global_rotation, (Vector2(400, 540) - boss.head.global_position).angle())) < 0.05, "a light beam shows the line he is about to dash along")
	var beam_art: Texture2D = boss.dash_beam.get_node("Beam").sprite_frames.get_frame_texture(&"shimmer", 0)
	check(beam_art.get_height() * 4.0 >= 200.0, "the light beam is as wide as his head (%d px)" % (beam_art.get_height() * 4))
	var aim := Vector2(400, 540)  # no player here: he aims at x 400, kept above the floor
	var closest := [INF]
	var flashed := [0.0]
	var last: Vector2 = boss.head.global_position
	for i in 90:
		await physics_frame
		var now: Vector2 = boss.head.global_position
		closest[0] = minf(closest[0], aim.distance_to(Geometry2D.get_closest_point_to_segment(aim, last, now)))
		flashed[0] = maxf(flashed[0], boss.head.material.get_shader_parameter(&"flash"))
		last = now
	check(closest[0] < 20.0, "the head dashes straight through the aimed spot (closest %.0f px)" % closest[0])
	check(flashed[0] > 0.9, "the head flashes white as it dashes")
	boss.queue_free()
	await process_frame


func _test_target_spin() -> void:
	var target: Node2D = load("res://scenes/fx/target.tscn").instantiate()
	root.add_child(target)
	var turned := [0.0]
	for i in 200:
		await physics_frame
		turned[0] = maxf(turned[0], target.rotation)
	check(turned[0] > 1.4, "the target brackets snap a quarter turn every few seconds")
	target.queue_free()
	await process_frame


## His eye follows the player, and the laser leaves from the eye, aimed at the player.
func _test_eye() -> void:
	var boss: Boss = load("res://scenes/boss/boss.tscn").instantiate()
	root.add_child(boss)
	var player: Player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(300, 600)
	await process_frame
	await process_frame
	var look := (player.global_position - boss.eye.global_position).angle()
	check(absf(angle_difference(boss.eye.global_rotation + PI, look)) < 0.05, "his eye always looks at the player")
	boss.phase = 2
	boss._play(&"laser", Boss.State.ATTACK)
	await create_timer(0.85 / boss.anim.speed_scale).timeout
	var beam: Node2D = boss.eye_beam
	var at_player := (player.global_position - beam.global_position).angle()
	check(beam.global_position.distance_to(boss.eye.global_position) < 1.0 and beam.get_node("Beam").visible and not beam.get_node("Hitbox/CollisionShape2D").disabled, "the laser fires out of his eye")
	check(absf(angle_difference(beam.global_rotation, at_player)) < 0.05, "the eye laser is aimed at the player")
	player.queue_free()
	boss.queue_free()
	await process_frame


## Between attacks he roams back and forth near the player, legs stepping as he walks.
func _test_roam() -> void:
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	var boss: Boss = game.get_node("Boss")
	var player: Player = game.get_node("Player")
	player.hurtbox.monitoring = false
	while boss.state != Boss.State.IDLE:
		await physics_frame
	boss.rest_timer.stop()  # no attacks: just watch him walk
	var span := [INF, -INF]
	var lift := [0.0]
	for i in 240:
		await physics_frame
		span[0] = minf(span[0], boss.position.x)
		span[1] = maxf(span[1], boss.position.x)
		lift[0] = maxf(lift[0], -minf(boss.leg_f.position.y, boss.leg_b.position.y))
	check(span[1] - span[0] > 150.0, "he roams the stage while the player stands still (%.0f px)" % (span[1] - span[0]))
	check(lift[0] > 10.0, "his legs step as he walks")
	game.queue_free()
	await process_frame


func _test_game_wiring() -> void:
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var player: Player = game.get_node("Player")
	var boss: Boss = game.get_node("Boss")
	var hud: HUD = game.get_node("HUD")
	player.take_hit()
	check(hud.hearts.size() == Player.MAX_HP and hud.hearts[Player.MAX_HP - 1].texture == HUD.HEART_EMPTY and hud.hearts[Player.MAX_HP - 2].texture == HUD.HEART_FULL, "losing a heart updates the HUD")
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
	check([boss.next_attack(), boss.next_attack(), boss.next_attack(), boss.next_attack()] == [&"swipe", &"bombs", &"charge", &"bombs"], "stage 2 (torso) swipes, throws bombs and charges")
	check(boss.anim.has_animation(&"laser"), "laser animation exists")
	boss.phase_changed.emit(2)
	var stage: Stage = game.get_node("Arena")
	check(stage.panels[7].collapsed and stage.panels[14].collapsed, "phase 3 opens the pits")
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
	check(game.get_node("HUD").flash_rect.modulate.a > 0.9 and player.anim.current_animation == &"hurt", "a fall whites out the screen as he warps back, then he blinks")
	game.queue_free()
	await process_frame
	Engine.time_scale = 1.0


func _test_core_platform() -> void:
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var stage: Stage = game.get_node("Arena")
	var player: Player = game.get_node("Player")
	var plat: CorePlatform = stage.core_platforms[0]
	player.hurtbox.monitoring = false
	player.global_position = plat.global_position + Vector2(0, -60)
	var home := [Vector2(-80, 0)]  # L1's home spot in core_platform.tscn
	var drift := [0.0]
	for i in 60:
		await physics_frame
		drift[0] = maxf(drift[0], plat.get_node("Parts/L1").position.distance_to(home[0]))
	check(player.is_on_floor() and plat.anim.current_animation == &"idle" and not plat.shape.disabled, "phase 1: a core platform holds like a plain platform")
	check(drift[0] > 0.0 and drift[0] <= 3.0, "its plates hum about fixed spots (max drift %.1f px)" % drift[0])
	check(plat.hub.animation == &"dim" and not plat.halo.visible, "unarmed in phase 1, its core is dark")
	stage.set_phase(1)
	check(plat.hub.animation == &"pulse" and plat.halo.visible and plat.aura.emitting, "armed in phase 2, its core glows and an electric aura crackles")
	await create_timer(0.9).timeout
	check(plat.anim.current_animation == &"break" and plat.shape.disabled and player.global_position.y > plat.global_position.y - 40.0, "phase 2: standing on it shakes it apart and drops the player")
	check(plat.hub.animation == &"dim" and not plat.halo.visible and not plat.aura.emitting, "the core goes dark while it is broken")
	check(plat.tethers.visible and plat.tethers.get_child(0).points.size() == CorePlatform.SEGMENTS + 1 and plat.tethers.get_child(0).points[CorePlatform.SEGMENTS].distance_to(plat.plates[0].position) < 2.0, "electric tethers run from the core to each loose plate")
	await create_timer(2.6).timeout
	check(not plat.shape.disabled and plat.get_node("Parts/L1").position.distance_to(home[0]) <= 3.0, "then the core pulls the plates back into place")
	check(plat.hub.animation == &"pulse" and plat.halo.visible and plat.aura.emitting and not plat.tethers.visible, "and glows again once whole")
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
	check(tutorial.bot.cracks.get_child(0).visible and not tutorial.bot.cracks.get_child(1).visible, "each hit cracks Lil' Watt a little more")
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
