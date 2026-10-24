class_name Stage
extends Node2D
## The arena's own moves. Phase 1 is plain stone so the king's attacks read cleanly; phase 2
## switches on the conveyors, the lifts, zaps near the player and the core platforms that fall
## apart underfoot; phase 3 flips the belts, zaps more often and collapses two panels into pits;
## phase 4 raises the arena of doom: under a red moon and a sky full of embers the floor runs on
## to x 7680, broken by lava, with platforms and a tall lift climbing high; once the fight
## resumes (start_strikes), lightning strikes near the player instead of the zaps.

signal zap_started
signal collapsed

const PANEL_W := 160.0
const BELTS := {4: 140.0, 5: 140.0, 11: -140.0, 12: -140.0}
const PITS := [7, 14]
const ZAP_EVERY := [0.0, 5.0, 4.0]  # seconds between zaps, per phase (none in phase 1 or 4)
const ZAP_WIDTH := [2, 2, 3]  # panels per zap, per phase
const DOOM_W := 7680.0  # the arena of doom's width (phase 4)
const ARENA_W := 2560.0
const FLOOR_Y := 640.0
const DOOM_GROUND := [Vector2(3360, 5040), Vector2(5520, 7680)]  # doom floor runs (from x, to x); lava before each
const SKY_STRIKE := preload("res://scenes/stage/sky_strike.tscn")

var phase := 0

@onready var panels: Array = $Floor.get_children()
@onready var zap_timer: Timer = $ZapTimer
@onready var strike_timer: Timer = $StrikeTimer
@onready var doom: Node2D = $DoomArena
@onready var lifts: Array = [$Piston, $Slider]
@onready var core_platforms: Array = $CorePlatforms.get_children()


func _ready() -> void:
	zap_timer.timeout.connect(zap_near_player)
	strike_timer.timeout.connect(strike_near_player)


func stop() -> void:
	zap_timer.stop()
	strike_timer.stop()


func set_phase(p: int) -> void:
	phase = p
	if phase == 1:
		for i in BELTS:
			panels[i].set_belt(BELTS[i])
		for lift in lifts:
			lift.get_node("AnimationPlayer").play(&"glide")
		for plat in core_platforms:
			plat.armed = true
	elif phase == 2:
		for i in BELTS:
			panels[i].set_belt(-panels[i].belt_speed)
		for i in PITS:
			panels[i].collapse()
		collapsed.emit()
	elif phase == 3:
		zap_timer.stop()
		doom.set_deferred(&"process_mode", Node.PROCESS_MODE_INHERIT)  # deferred: phase changes fire inside physics callbacks
		doom.get_node("AnimationPlayer").play(&"reveal")
		return
	zap_timer.start(ZAP_EVERY[phase])


## Phase 4, once the cutscene is over: lightning every StrikeTimer tick.
func start_strikes() -> void:
	strike_timer.start()


## A bolt out of the red sky somewhere near the player.
func strike_near_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var strike: Node2D = SKY_STRIKE.instantiate()
	add_child(strike)
	strike.global_position = Vector2(clampf(player.global_position.x + randf_range(-300.0, 300.0), 80.0, DOOM_W - 80.0), FLOOR_Y)


## Electrifies a short run of panels around the player's feet.
func zap_near_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var width: int = ZAP_WIDTH[phase]
	var center := floori(player.global_position.x / PANEL_W)
	var first := clampi(center - randi_range(0, width - 1), 0, panels.size() - width)
	for i in range(first, first + width):
		panels[i].electrify()
	zap_started.emit()


## Nearest standing spot that is not over a pit or lava (for respawning after a fall).
func safe_spot(x: float) -> Vector2:
	var best := -1
	for i in panels.size():
		if panels[i].collapsed:
			continue
		if best < 0 or absf(_panel_x(i) - x) < absf(_panel_x(best) - x):
			best = i
	var spot := Vector2(_panel_x(best), 598.0)
	if phase == 3:
		for run: Vector2 in DOOM_GROUND:
			var near := Vector2(clampf(x, run.x + 80.0, run.y - 80.0), 598.0)
			if absf(near.x - x) < absf(spot.x - x):
				spot = near
	return spot


## The floor panel under a world x (clamped to the arena).
func panel_at(x: float) -> FloorPanel:
	return panels[clampi(floori(x / PANEL_W), 0, panels.size() - 1)]


func _panel_x(i: int) -> float:
	return (i + 0.5) * PANEL_W
