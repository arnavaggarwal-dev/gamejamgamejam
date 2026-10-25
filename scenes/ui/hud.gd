class_name HUD
extends CanvasLayer
## Hearts, boss bar, big banners, the goal hint and the end panel. Displays only; owns no game state.

signal retry_pressed
signal skip_phase_pressed

const HEART_FULL := preload("res://assets/art/ui/heart_full.png")
const HEART_EMPTY := preload("res://assets/art/ui/heart_empty.png")
const BOMB_FULL := preload("res://assets/art/ui/bomb_full.png")
const BOMB_EMPTY := preload("res://assets/art/ui/bomb_empty.png")

var _banner_id := 0
var _hint_id := 0
var _flash: Tween
var _cinema := false  # letterbox in: hints wait
var _ammo := -1  # what the ammo row last showed (-1: nothing yet)

@onready var hearts_row: Control = $Hearts
@onready var hearts: Array = $Hearts.get_children()
@onready var ammo_row: Control = $Ammo
@onready var ammo_icons: Array[Node] = $Ammo.get_children()
@onready var boss_box: Control = $BossBar
@onready var boss_bar: ProgressBar = $BossBar/Bar
@onready var boss_name: Label = $BossBar/Name
@onready var banner: Label = $Banner
@onready var hint: Label = $Hint
@onready var coach_label: Label = $Coach
@onready var flash_rect: ColorRect = $Flash
@onready var end_panel: Control = $EndPanel
@onready var end_label: Label = $EndPanel/VBox/Label
@onready var retry: Button = $EndPanel/VBox/Retry
@onready var skip_button: Button = $SkipPhase
@onready var bars: Array = [$Cinema/Top, $Cinema/Bottom]
@onready var banner_fx: AnimationPlayer = $BannerFx
@onready var coach_fx: AnimationPlayer = $CoachFx
@onready var cinema_fx: AnimationPlayer = $CinemaFx


func _ready() -> void:
	add_to_group("hud")  # get_tree().call_group("hud", "flash", strength, hold)
	retry.pressed.connect(retry_pressed.emit)
	skip_button.visible = OS.is_debug_build()  # testing aid: never shows in a release export
	skip_button.pressed.connect(skip_phase_pressed.emit)


func set_hearts(hp: int) -> void:
	for i in hearts.size():
		hearts[i].texture = HEART_FULL if i < hp else HEART_EMPTY


## Bombs in the row; each new one pops into its slot with a poof (its "fill" clip).
func set_ammo(ammo: int) -> void:
	for i in ammo_icons.size():
		ammo_icons[i].texture = BOMB_FULL if i < ammo else BOMB_EMPTY
		if _ammo >= 0 and i >= _ammo and i < ammo:
			var fill: AnimationPlayer = ammo_icons[i].get_node("Fill")
			fill.play(&"fill")
			fill.advance(0.0)  # pop and poof start this frame
	_ammo = ammo


func set_boss_name(text: String) -> void:
	boss_name.text = text


func set_boss_health(hits_left: int, hits_total: int) -> void:
	boss_bar.max_value = hits_total
	boss_bar.value = hits_left


## Big centred text; a newer banner cancels the older one's hide timer.
func show_banner(text: String, seconds: float) -> void:
	_banner_id += 1
	var id := _banner_id
	banner.text = text
	banner.show()
	banner_fx.stop()
	banner_fx.play(&"pop")
	await get_tree().create_timer(seconds).timeout
	if id == _banner_id:
		banner.hide()


## Goal reminder along the bottom; an empty string hides it.
func show_hint(text: String) -> void:
	_hint_id += 1
	hint.text = text
	hint.visible = text != "" and not _cinema


## A hint that clears itself after a few seconds (unless another hint replaced it).
func show_tip(text: String, seconds := 3.5) -> void:
	show_hint(text)
	var id := _hint_id
	await get_tree().create_timer(seconds, false).timeout
	if id == _hint_id:
		show_hint("")


## Big tutorial instruction under the boss bar; an empty string hides it.
func coach(text: String) -> void:
	coach_label.text = text
	coach_label.visible = text != ""
	if coach_label.visible:
		coach_fx.stop()
		coach_fx.play(&"pop")


## White screen flash: `strength` is the starting opacity, `hold` keeps it there before fading.
func flash(strength := 0.7, hold := 0.0) -> void:
	if _flash:
		_flash.kill()
	flash_rect.modulate.a = strength
	_flash = create_tween()
	_flash.tween_interval(hold)
	_flash.tween_property(flash_rect, "modulate:a", 0.0, 0.35)


## Cutscene letterbox: black bars slide in top and bottom while the hearts and boss bar step
## aside (and the hint clears), or slide back out.
func cinema(on: bool) -> void:
	_cinema = on
	hearts_row.visible = not on
	ammo_row.visible = not on
	boss_box.visible = not on
	if on:
		show_hint("")
	cinema_fx.play(&"in" if on else &"out")


## Phase 4: the boss bar moves to the top-right corner (open sky), so the screen-tall king's
## head stays clear.
func boss_bar_aside() -> void:
	boss_box.anchor_left = 1.0
	boss_box.anchor_right = 1.0
	boss_box.offset_left = -472.0
	boss_box.offset_right = -24.0


func show_end(text: String) -> void:
	end_label.text = text
	end_panel.show()
	retry.grab_focus()
