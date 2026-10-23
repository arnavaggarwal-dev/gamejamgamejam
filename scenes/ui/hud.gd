class_name HUD
extends CanvasLayer
## Hearts, boss bar, big banners and the end panel. Displays only; owns no game state.

signal retry_pressed

@onready var hearts: Array = $Hearts.get_children()
@onready var boss_bar: ProgressBar = $BossBar/Bar
@onready var banner: Label = $Banner
@onready var end_panel: Control = $EndPanel
@onready var end_label: Label = $EndPanel/VBox/Label
@onready var retry: Button = $EndPanel/VBox/Retry


func _ready() -> void:
	retry.pressed.connect(retry_pressed.emit)


func set_hearts(hp: int) -> void:
	for i in hearts.size():
		hearts[i].visible = i < hp


func set_boss_health(hits_left: int, hits_total: int) -> void:
	boss_bar.max_value = hits_total
	boss_bar.value = hits_left


func show_banner(text: String, seconds: float) -> void:
	banner.text = text
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.2, 0.2)
	banner.show()
	create_tween().tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(seconds).timeout
	banner.hide()


func show_end(text: String) -> void:
	end_label.text = text
	end_panel.show()
	retry.grab_focus()
