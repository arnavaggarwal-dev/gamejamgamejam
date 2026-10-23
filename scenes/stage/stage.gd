class_name Stage
extends Node2D
## The arena's own moves: zapping floor panels near the player, conveyor belts that flip
## each phase, and the phase-3 collapse (pits plus falling rubble).

signal zap_started
signal collapsed

const DEBRIS := preload("res://scenes/stage/debris.tscn")
const PANEL_W := 160.0
const BELTS := {4: 140.0, 5: 140.0, 11: -140.0, 12: -140.0}
const PITS := [7, 14]
const ZAP_EVERY := [7.0, 5.0, 4.0]  # seconds between zaps, per phase
const ZAP_WIDTH := [2, 2, 3]  # panels per zap, per phase
const DEBRIS_EVERY := 1.4
const ARENA_W := 2560.0

var phase := 0

@onready var panels: Array = $Floor.get_children()
@onready var hazards: Node2D = $Hazards
@onready var zap_timer: Timer = $ZapTimer
@onready var debris_timer: Timer = $DebrisTimer


func _ready() -> void:
	for i in BELTS:
		panels[i].set_belt(BELTS[i])
	zap_timer.timeout.connect(zap_near_player)
	debris_timer.timeout.connect(_drop_debris)


## Starts the hazards once the fight (or tutorial) is over its intro.
func start() -> void:
	zap_timer.start(ZAP_EVERY[phase])


func stop() -> void:
	zap_timer.stop()
	debris_timer.stop()


func set_phase(p: int) -> void:
	phase = p
	for i in BELTS:
		panels[i].set_belt(-panels[i].belt_speed)
	if not zap_timer.is_stopped():
		zap_timer.start(ZAP_EVERY[phase])
	if phase == 2:
		for i in PITS:
			panels[i].collapse()
		debris_timer.start(DEBRIS_EVERY)
		collapsed.emit()


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


func _drop_debris() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var rock: Node2D = DEBRIS.instantiate()
	hazards.add_child(rock)
	rock.global_position = Vector2(clampf(player.global_position.x + randf_range(-380.0, 380.0), 80.0, ARENA_W - 80.0), -60.0)
