extends Control
## Title screen: one button into the fight.


func _ready() -> void:
	var start: Button = $VBox/Start
	start.grab_focus()
	start.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/game.tscn"))
