extends Node2D
## Arena root: wires player, boss and HUD together and handles restarts.

const GOAL_HINT := "GRAB BOMBS [J] AND THROW THEM AT THE CORE!"
const LASER_HINT := "LOW BEAM: JUMP!   HIGH BEAM: STAY DOWN!"

@onready var player: Player = $Player
@onready var boss: Boss = $Boss
@onready var hud: HUD = $HUD
@onready var projectiles: Node2D = $Projectiles
@onready var respawn: Marker2D = $RespawnPoint
@onready var arena_anim: AnimationPlayer = $Arena/ArenaAnim


func _ready() -> void:
	player.hp_changed.connect(hud.set_hearts)
	player.died.connect(_on_player_died)
	boss.health_changed.connect(hud.set_boss_health)
	boss.health_changed.connect(_on_first_hit, CONNECT_ONE_SHOT)
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.defeated.connect(_on_boss_defeated)
	hud.retry_pressed.connect(get_tree().reload_current_scene)
	hud.skip_phase_pressed.connect(boss.skip_phase)
	hud.set_hearts(player.hp)
	hud.set_boss_health(boss.hits_left(), boss.hits_total())
	await hud.show_banner("LITTLE GUY  vs  BIG GUY", 2.0)
	hud.show_hint(GOAL_HINT)
	boss.start_fight()


## F2 skips to the next phase in debug runs (same as the HUD button).
func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("debug_skip_phase"):
		boss.skip_phase()


func _on_first_hit(_hits_left: int, _hits_total: int) -> void:
	hud.show_hint("")


func _on_player_died() -> void:
	await get_tree().create_timer(1.0).timeout
	for child in projectiles.get_children():
		child.queue_free()
	player.reset(respawn.global_position)
	boss.restart_phase()
	hud.show_banner("AGAIN!", 1.0)


func _on_boss_phase_changed(phase: int) -> void:
	hud.flash()
	hud.show_banner("PHASE %d" % (phase + 1), 1.2)
	if phase == 1:
		hud.show_hint(LASER_HINT)
	if phase == 2:
		hud.show_hint("")
		arena_anim.play(&"break_platforms")
		get_tree().call_group("camera", "shake", 14.0)


func _on_boss_defeated() -> void:
	player.hurtbox.set_deferred("monitoring", false)  # deferred: defeated fires inside the WeakPoint physics callback
	hud.flash()
	hud.show_hint("")
	await hud.show_banner("KNOCKOUT!", 2.5)
	hud.show_end("YOU WIN!")
