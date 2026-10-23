class_name HUD
extends CanvasLayer
## Hearts, boss bar, big banners, the goal hint and the end panel. Displays only; owns no game state.

signal retry_pressed
signal skip_phase_pressed

const HEART_FULL := preload("res://assets/art/ui/heart_full.png")
const HEART_EMPTY := preload("res://assets/art/ui/heart_empty.png")

var _banner_id := 0

@onready var hearts: Array = $Hearts.get_children()
@onready var boss_bar: ProgressBar = $BossBar/Bar
@onready var banner: Label = $Banner
@onready var hint: Label = $Hint
@onready var flash_rect: ColorRect = $Flash
@onready var end_panel: Control = $EndPanel
@onready var end_label: Label = $EndPanel/VBox/Label
@onready var retry: Button = $EndPanel/VBox/Retry
@onready var skip_button: Button = $SkipPhase


func _ready() -> void:
	retry.pressed.connect(retry_pressed.emit)
	skip_button.visible = OS.is_debug_build()  # testing aid: never shows in a release export
	skip_button.pressed.connect(skip_phase_pressed.emit)


func set_hearts(hp: int) -> void:
	for i in hearts.size():
		hearts[i].texture = HEART_FULL if i < hp else HEART_EMPTY


func set_boss_health(hits_left: int, hits_total: int) -> void:
	boss_bar.max_value = hits_total
	boss_bar.value = hits_left


## Big centred text; a newer banner cancels the older one's hide timer.
func show_banner(text: String, seconds: float) -> void:
	_banner_id += 1
	var id := _banner_id
	banner.text = text
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.2, 0.2)
	banner.show()
	create_tween().tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(seconds).timeout
	if id == _banner_id:
		banner.hide()


## Goal reminder along the bottom; an empty string hides it.
func show_hint(text: String) -> void:
	hint.text = text
	hint.visible = text != ""


func flash() -> void:
	flash_rect.modulate.a = 0.7
	create_tween().tween_property(flash_rect, "modulate:a", 0.0, 0.35)


func show_end(text: String) -> void:
	end_label.text = text
	end_panel.show()
	retry.grab_focus()
