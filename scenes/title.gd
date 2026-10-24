extends Control
## Title screen: the king idles in his throne room, one button into the fight.


func _ready() -> void:
	# Poster pose: the giant fight starts with only his legs in frame, so the title shows him
	# squashed into one screen instead (torso down, head on his shoulders, no legs).
	var boss: Boss = $Boss
	boss.rig.position = Vector2.ZERO
	boss.legs.hide()
	boss.upper.position = Vector2.ZERO
	boss.get_node("Rig/Upper/Body/Core/Target").hide()
	boss.anim.play(&"idle_2")
	var start: Button = $Card/VBox/Start
	start.grab_focus()
	start.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/game.tscn"))
