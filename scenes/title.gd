extends Control
## Title screen: the king idles in his throne room, one button into the fight.


func _ready() -> void:
	var boss: Boss = $Boss
	boss.rig.position = Vector2.ZERO
	boss.get_node("Rig/FistL").hide()
	boss.get_node("Rig/Core/Target").hide()
	boss.anim.play(&"idle")
	var start: Button = $VBox/Start
	start.grab_focus()
	start.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/game.tscn"))
