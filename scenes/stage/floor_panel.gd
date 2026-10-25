class_name FloorPanel
extends StaticBody2D
## One 160-px slice of the arena floor: plain stone or a conveyor belt (constant_linear_velocity).
## Its AnimationPlayer holds the "zap" (warning stripes, then live current) and "collapse" sequences.

const WARN_TIME := 1.1  # the warning section of the "zap" animation
const BELT_ANIM_SPEED := 140.0  # belt speed that plays the roll animation at 1x

@export var belt_speed := 0.0  # px/s; positive pushes right, 0 is plain stone

var collapsed := false
var zapping: bool:
	get:
		return anim.is_playing() and anim.current_animation == "zap"

@onready var tile: Sprite2D = $Slab/Tile
@onready var belt: AnimatedSprite2D = $Slab/Belt
@onready var warn: AnimatedSprite2D = $Slab/Warn
@onready var zap: AnimatedSprite2D = $Slab/Zap
@onready var zap_shape: CollisionShape2D = $ZapArea/CollisionShape2D
@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	set_belt(belt_speed)


func set_belt(speed: float) -> void:
	belt_speed = speed
	constant_linear_velocity = Vector2(speed, 0.0)
	belt.visible = speed != 0.0
	tile.visible = speed == 0.0
	belt.flip_h = speed < 0.0
	belt.speed_scale = maxf(0.1, absf(speed) / BELT_ANIM_SPEED)


func electrify() -> void:
	if not collapsed and not zapping:
		anim.play(&"zap")
		anim.advance(0.0)


## No advance(0) here: this can run inside the boss-hit physics callback, and the first key
## toggles a collision shape; the AnimationPlayer applies it on the next idle frame instead.
func collapse() -> void:
	if not collapsed:
		collapsed = true
		anim.play(&"collapse")
		Sfx.play(&"crumble", randf_range(0.85, 1.15), -4.0)


## Method-track target in "zap": a small kick when the current goes live.
func zap_shake() -> void:
	get_tree().call_group("camera", "shake", 3.0)
	Sfx.play(&"buzz", 1.0, -4.0)
