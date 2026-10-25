class_name HUD
extends CanvasLayer
## Hearts, boss bar, big banners, the goal hint and the end panel. Displays only; owns no game state.

signal retry_pressed
signal title_pressed
signal skip_phase_pressed

const HEART_FULL := preload("res://assets/art/ui/heart_full.png")
const HEART_EMPTY := preload("res://assets/art/ui/heart_empty.png")
const BOMB_FULL := preload("res://assets/art/ui/bomb_full.png")
const BOMB_EMPTY := preload("res://assets/art/ui/bomb_empty.png")

var _banner_id := 0
var _hint_id := 0
var _flash: Tween
var _cinema := false  # letterbox in: hints wait
var _hp := Player.MAX_HP
var _ammo := -1  # what the ammo row last showed (-1: nothing yet)

@onready var hearts_row: Control = $Hearts
@onready var hearts: Array = $Hearts.get_children()
@onready var ammo_row: Control = $Ammo
@onready var ammo_icons: Array[Node] = $Ammo.get_children()
@onready var boss_box: Control = $BossBar
@onready var boss_bar: ProgressBar = $BossBar/Bar
@onready var boss_ghost: ProgressBar = $BossBar/Bar/Ghost  # the chip a hit knocks off, draining after it
@onready var danger: TextureRect = $Danger
@onready var danger_fx: AnimationPlayer = $DangerFx
@onready var boss_name: Label = $BossBar/Name
@onready var banner: Label = $Banner
@onready var hint: RichTextLabel = $Hint
@onready var coach_label: RichTextLabel = $Coach
@onready var flash_rect: ColorRect = $Flash
@onready var end_panel: Control = $EndPanel
@onready var end_label: Label = $EndPanel/VBox/Label
@onready var retry: Button = $EndPanel/VBox/Buttons/Retry
@onready var title_button: Button = $EndPanel/VBox/Buttons/Title
@onready var win_rows: Array[Node] = $EndPanel/VBox/Stats.get_children()
@onready var rank_label: Label = $Rank
@onready var win_fx: AnimationPlayer = $WinFx
@onready var confetti: CPUParticles2D = $Confetti
@onready var skip_button: Button = $SkipPhase
@onready var bars: Array = [$Cinema/Top, $Cinema/Bottom]
@onready var banner_fx: AnimationPlayer = $BannerFx
@onready var coach_fx: AnimationPlayer = $CoachFx
@onready var cinema_fx: AnimationPlayer = $CinemaFx
@onready var goo_fx: AnimationPlayer = $GooFx
@onready var goo: Control = $Goo


func _ready() -> void:
	add_to_group("hud")  # get_tree().call_group("hud", "flash", strength, hold)
	retry.pressed.connect(retry_pressed.emit)
	title_button.pressed.connect(title_pressed.emit)
	skip_button.visible = OS.is_debug_build()  # testing aid: never shows in a release export
	skip_button.pressed.connect(skip_phase_pressed.emit)


## Hearts in the row; a lost one pops and wiggles (its "lose" clip). Down to the last heart, the
## screen's edges pulse red with a heartbeat.
func set_hearts(hp: int) -> void:
	for i in hearts.size():
		hearts[i].texture = HEART_FULL if i < hp else HEART_EMPTY
		if i >= hp and i < _hp:
			hearts[i].get_node("Lose").play(&"lose")
	_hp = hp
	danger.visible = hp == 1
	if hp == 1:
		danger_fx.play(&"pulse")
	else:
		danger_fx.stop()


func _heartbeat() -> void:
	Sfx.play(&"heartbeat", 1.0, -4.0)


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


## The bar drops at once; a pale chip of what was lost lingers behind it, then drains away.
func set_boss_health(hits_left: int, hits_total: int) -> void:
	boss_bar.max_value = hits_total
	boss_ghost.max_value = hits_total
	boss_bar.value = hits_left
	if hits_left >= boss_ghost.value:
		boss_ghost.value = hits_left  # a refill (a new boss on the bar) catches up at once
		return
	var drain := create_tween()
	drain.tween_interval(0.35)
	drain.tween_property(boss_ghost, "value", float(hits_left), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Big centred text; a newer banner cancels the older one's hide timer.
func show_banner(text: String, seconds: float) -> void:
	Sfx.play(&"whoosh", 1.3, -6.0)
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
	hint.text = Keys.bbcode(text, 36)  # [Z] and friends show as keycaps
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
	coach_label.text = Keys.bbcode(text, 54)
	coach_label.visible = text != ""
	if coach_label.visible:
		coach_fx.stop()
		coach_fx.play(&"pop")


## The hero splattered against the screen, Smash style: gobs of goo slap onto the glass, then
## slide down it and fade (the GooFx "splat" clip).
func splat() -> void:
	Sfx.play(&"squish")
	goo_fx.play(&"splat")
	goo_fx.advance(0.0)


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


## Confetti rains down the screen (the ending, then the win screen).
func celebrate() -> void:
	confetti.emitting = true


## The win screen: the panel pops in under a crown, the run's stats tick in one by one and its
## rank slams down like a stamp (the WinFx "win" clip calls _tick, _stamp and _focus_retry).
func show_win(stats: PackedStringArray, rank: String) -> void:
	end_label.text = "YOU WIN!"
	for i in win_rows.size():
		win_rows[i].text = stats[i]
	rank_label.text = rank
	celebrate()
	win_fx.play(&"win")
	win_fx.advance(0.0)


func _tick() -> void:
	Sfx.play(&"tick")
	get_tree().call_group("camera", "shake", 3.0)


func _stamp() -> void:
	Sfx.play(&"stamp")
	flash(0.6)
	get_tree().call_group("camera", "shake", 14.0)


func _focus_retry() -> void:
	retry.grab_focus()
