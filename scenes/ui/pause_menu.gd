class_name PauseMenu
extends CanvasLayer
## Esc / P / gamepad Start pauses the fight. Runs while the tree is paused (process_mode ALWAYS).

const TITLE_SCENE := "res://scenes/title.tscn"

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var hero_box: Control = $Panel/VBox/HeroBox
@onready var hero: Node2D = $Panel/VBox/HeroBox/Hero
@onready var resume: Button = $Panel/VBox/Resume
@onready var restart: Button = $Panel/VBox/Restart
@onready var fullscreen: Button = $Panel/VBox/Fullscreen
@onready var quit: Button = $Panel/VBox/Quit
@onready var zs_root: Node2D = $Panel/VBox/HeroBox/Zs
@onready var pop_fx: AnimationPlayer = $PopFx
@onready var doze: AnimationPlayer = $Doze

func _ready() -> void:
	hide()
	resume.pressed.connect(close)
	restart.pressed.connect(_restart)
	fullscreen.pressed.connect(_toggle_fullscreen)
	quit.pressed.connect(_quit_to_title)
	hero_box.resized.connect(_place_hero)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)


func _place_hero() -> void:
	hero.position = hero_box.size / 2.0
	zs_root.position = hero.position + Vector2(28, -50)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


## Freezes the fight and pops the panel in over a dimmed arena.
func open() -> void:
	get_tree().paused = true
	show()
	_refresh_fullscreen_label()
	resume.grab_focus()
	pop_fx.play(&"open")
	doze.play(&"doze")  # the little guy dozes while you take a break: Zs drift up and fade


func close() -> void:
	doze.stop()
	hide()
	get_tree().paused = false


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _quit_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_WINDOWED if _is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(mode)
	_refresh_fullscreen_label()


func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _refresh_fullscreen_label() -> void:
	fullscreen.text = "FULLSCREEN: ON" if _is_fullscreen() else "FULLSCREEN: OFF"
