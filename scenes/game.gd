extends Node2D
## Arena root: wires player, boss and HUD together and handles restarts.

@onready var player: Player = $Player
@onready var boss: Boss = $Boss
@onready var hud: HUD = $HUD
@onready var projectiles: Node2D = $Projectiles
@onready var respawn: Marker2D = $RespawnPoint


func _ready() -> void:
	player.hp_changed.connect(hud.set_hearts)
	player.died.connect(_on_player_died)
	boss.health_changed.connect(hud.set_boss_health)
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.defeated.connect(_on_boss_defeated)
	hud.retry_pressed.connect(get_tree().reload_current_scene)
	hud.set_hearts(player.hp)
	hud.set_boss_health(boss.hits_left(), boss.hits_total())
	await hud.show_banner("LITTLE GUY  vs  BIG GUY", 2.0)
	boss.start_fight()


func _on_player_died() -> void:
	await get_tree().create_timer(1.0).timeout
	for child in projectiles.get_children():
		child.queue_free()
	player.reset(respawn.global_position)
	boss.restart_phase()
	hud.show_banner("AGAIN!", 1.0)


func _on_boss_phase_changed(phase: int) -> void:
	hud.show_banner("PHASE %d" % (phase + 1), 1.2)


func _on_boss_defeated() -> void:
	await hud.show_banner("KNOCKOUT!", 2.5)
	hud.show_end("YOU WIN!")
