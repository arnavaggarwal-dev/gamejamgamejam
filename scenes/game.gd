extends Node2D
## Arena root: wires player, boss, stage, backdrop, tutorial and HUD together and handles restarts.

const GOAL_HINT := "GRAB BOMBS [Z] AND THROW THEM AT THE CORE!"

@onready var player: Player = $Player
@onready var boss: Boss = $Boss
@onready var hud: HUD = $HUD
@onready var stage: Stage = $Arena
@onready var backdrop: Node2D = $Backdrop
@onready var tutorial: Tutorial = $Tutorial
@onready var projectiles: Node2D = $Projectiles
@onready var respawn: Marker2D = $RespawnPoint


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
	for child in stage.hazards.get_children():
		child.queue_free()
	player.reset(respawn.global_position)
	boss.restart_phase()
	hud.show_banner("AGAIN!", 1.0)


## A pit costs a heart (even mid-blink) and puts the player back on solid floor.
func _on_player_fell() -> void:
	player.invuln.stop()
	player.take_hit()
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


func _on_boss_defeated() -> void:
	player.hurtbox.set_deferred("monitoring", false)  # deferred: defeated fires inside the WeakPoint physics callback
	stage.stop()
	backdrop.cheer(6.0)
	hud.flash()
	hud.show_hint("")
	await hud.show_banner("KNOCKOUT!", 2.5)
	hud.show_end("YOU WIN!")
