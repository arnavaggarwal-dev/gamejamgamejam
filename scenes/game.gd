extends Node2D
## Arena root: wires player, boss and HUD together and handles restarts.

@onready var player: Player = $Player
@onready var boss: Boss = $Boss
@onready var projectiles: Node2D = $Projectiles
@onready var respawn: Marker2D = $RespawnPoint


func _ready() -> void:
	player.died.connect(_on_player_died)
	boss.start_fight()


func _on_player_died() -> void:
	await get_tree().create_timer(1.0).timeout
	for child in projectiles.get_children():
		child.queue_free()
	player.reset(respawn.global_position)
	boss.restart_phase()
