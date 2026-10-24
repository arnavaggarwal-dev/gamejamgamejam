class_name Stage
extends Node2D
## The arena's own moves. Phase 1 is plain stone so the king's attacks read cleanly; phase 2
## switches on the conveyors, the lifts, zaps near the player and the core platforms that fall
## apart underfoot; phase 3 flips the belts, zaps more often and collapses two panels into pits.

signal zap_started
signal collapsed

const PANEL_W := 160.0
const BELTS := {4: 140.0, 5: 140.0, 11: -140.0, 12: -140.0}
const PITS := [7, 14]
const ZAP_EVERY := [0.0, 5.0, 4.0]  # seconds between zaps, per phase (none in phase 1)
const ZAP_WIDTH := [2, 2, 3]  # panels per zap, per phase
const ARENA_W := 2560.0

var phase := 0

@onready var panels: Array = $Floor.get_children()
@onready var zap_timer: Timer = $ZapTimer
@onready var lifts: Array = [$Piston, $Slider]
@onready var core_platforms: Array = $CorePlatforms.get_children()


func _ready() -> void:
	zap_timer.timeout.connect(zap_near_player)


func stop() -> void:
	zap_timer.stop()


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
	zap_timer.start(ZAP_EVERY[phase])


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


## Nearest standing spot that is not over a pit (for respawning after a fall).
func safe_spot(x: float) -> Vector2:
	var best := -1
	for i in panels.size():
		if panels[i].collapsed:
			continue
		if best < 0 or absf(_panel_x(i) - x) < absf(_panel_x(best) - x):
			best = i
	return Vector2(_panel_x(best), 598.0)


## The floor panel under a world x (clamped to the arena).
func panel_at(x: float) -> FloorPanel:
	return panels[clampi(floori(x / PANEL_W), 0, panels.size() - 1)]


func _panel_x(i: int) -> float:
	return (i + 0.5) * PANEL_W
