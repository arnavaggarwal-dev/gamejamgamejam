extends SceneTree
## Second art step, run after the PNGs are imported:
##   "$GODOT" --headless --path . --import
##   "$GODOT" --headless --path . -s tools/art/build_frames.gd
## Builds SpriteFrames .tres for every animated sheet and the shared pixel UI theme.

const P = preload("res://tools/art/pal.gd")
const ART := "res://assets/art/"

# sheet path -> [frame size, {animation: [png, frame count, fps, loop, optional first frame]}]
const SHEETS := {
	"hero/hero_frames.tres": [Vector2i(20, 22), {
		"idle": ["hero/hero_idle.png", 4, 5.0, true],
		"run": ["hero/hero_run.png", 4, 11.0, true],
		"jump": ["hero/hero_jump.png", 1, 1.0, true],
		"fall": ["hero/hero_fall.png", 1, 1.0, true],
		"carry": ["hero/hero_carry.png", 2, 4.0, true],
		"carry_run": ["hero/hero_carry_run.png", 4, 11.0, true],
		"hurt": ["hero/hero_hurt.png", 1, 1.0, true],
		"dash": ["hero/hero_dash.png", 1, 1.0, true],
	}],
	"fx/bomb_frames.tres": [Vector2i(16, 16), {"fuse": ["fx/bomb.png", 3, 12.0, true]}],
	"fx/arrow_frames.tres": [Vector2i(7, 8), {"bob": ["fx/arrow.png", 2, 3.0, true]}],
	"fx/explosion_frames.tres": [Vector2i(48, 48), {"play": ["fx/explosion.png", 8, 18.0, false]}],
	"fx/spark_frames.tres": [Vector2i(24, 24), {"play": ["fx/spark.png", 4, 20.0, false]}],
	"fx/dust_frames.tres": [Vector2i(16, 8), {"play": ["fx/dust.png", 5, 16.0, false]}],
	"fx/slime_frames.tres": [Vector2i(28, 16), {"play": ["fx/slime.png", 6, 18.0, false]}],
	"fx/poof_frames.tres": [Vector2i(28, 28), {"play": ["fx/poof.png", 6, 14.0, false]}],
	"fx/shockwave_frames.tres": [Vector2i(20, 14), {"roll": ["fx/shockwave.png", 3, 12.0, true]}],
	"fx/laser_warn_frames.tres": [Vector2i(640, 3), {"march": ["fx/laser_warn.png", 2, 12.0, true]}],
	"fx/laser_beam_frames.tres": [Vector2i(640, 12), {"crackle": ["fx/laser_beam.png", 3, 20.0, true]}],
	"boss/eye_frames.tres": [Vector2i(20, 20), {"look": ["boss/eye.png", 2, 1.5, true]}],
	"boss/jet_frames.tres": [Vector2i(12, 18), {"burn": ["boss/jet.png", 2, 12.0, true]}],
	"boss/bot_frames.tres": [Vector2i(40, 44), {"hover": ["boss/bot.png", 2, 8.0, true, 0], "hurt": ["boss/bot.png", 1, 1.0, false, 2], "broken": ["boss/bot.png", 1, 1.0, false, 3]}],
	"boss/core_frames.tres": [Vector2i(32, 32), {"pulse": ["boss/core.png", 4, 8.0, true]}],
	"boss/target_frames.tres": [Vector2i(44, 44), {"blink": ["boss/target.png", 2, 3.0, true]}],
	"world/gear_frames.tres": [Vector2i(104, 104), {"turn": ["world/gear.png", 6, 3.0, true]}],
	"world/banner_frames.tres": [Vector2i(20, 68), {"sway": ["world/banner.png", 4, 1.5, true]}],
	"world/torch_frames.tres": [Vector2i(12, 26), {"flicker": ["world/torch.png", 4, 6.0, true]}],
	"world/crowd_frames.tres": [Vector2i(480, 26), {"idle": ["world/crowd.png", 2, 1.2, true, 0], "cheer": ["world/crowd.png", 2, 8.0, true, 2]}],
	"world/belt_frames.tres": [Vector2i(40, 20), {"roll": ["world/belt.png", 4, 12.0, true]}],
	"world/warn_frames.tres": [Vector2i(40, 6), {"blink": ["world/warn.png", 2, 8.0, true]}],
	"world/zap_frames.tres": [Vector2i(40, 16), {"crackle": ["world/zap.png", 3, 18.0, true]}],
	"world/lift_frames.tres": [Vector2i(50, 12), {"hover": ["world/lift.png", 2, 10.0, true]}],
	"world/core_hub_frames.tres": [Vector2i(12, 8), {"pulse": ["world/core_hub.png", 2, 4.0, true, 0], "dim": ["world/core_hub.png", 1, 1.0, true, 2]}],
	"world/debris_frames.tres": [Vector2i(14, 12), {"tumble": ["world/debris.png", 2, 8.0, true]}],
}


func _initialize() -> void:
	for out in SHEETS:
		var size: Vector2i = SHEETS[out][0]
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		var anims: Dictionary = SHEETS[out][1]
		for anim in anims:
			var spec: Array = anims[anim]
			var sheet: Texture2D = load(ART + spec[0])
			frames.add_animation(anim)
			frames.set_animation_speed(anim, spec[2])
			frames.set_animation_loop_mode(anim, SpriteFrames.LOOP_LINEAR if spec[3] else SpriteFrames.LOOP_NONE)
			var first: int = spec[4] if spec.size() > 4 else 0
			for i in range(first, first + spec[1]):
				var region := AtlasTexture.new()
				region.atlas = sheet
				region.region = Rect2(i * size.x, 0, size.x, size.y)
				frames.add_frame(anim, region)
		_save(frames, ART + out)
	_save(_theme(), ART + "ui/theme.tres")
	quit()


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	print("wrote ", path) if err == OK else push_error("could not save %s (%d)" % [path, err])


func _box(bg: Color, border: Color, width: int, margin := Vector2(16, 8)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.content_margin_left = margin.x
	s.content_margin_right = margin.x
	s.content_margin_top = margin.y
	s.content_margin_bottom = margin.y
	return s


## Square-cornered, ink-bordered UI so the HUD and menus sit on the same 4x pixel grid as the sprites.
func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = load(ART + "ui/kilowatt.fnt")
	t.default_font_size = 36
	t.set_color("font_color", "Label", P.CREAM)
	t.set_color("font_shadow_color", "Label", P.INK)
	t.set_constant("shadow_offset_x", "Label", 4)
	t.set_constant("shadow_offset_y", "Label", 4)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "Button", P.INK)
	t.set_stylebox("normal", "Button", _box(P.CREAM, P.INK, 4))
	t.set_stylebox("hover", "Button", _box(P.BUTTER, P.INK, 4))
	t.set_stylebox("pressed", "Button", _box(P.PEACH, P.INK, 4))
	var focus := _box(P.CLEAR, P.BUTTER, 4)
	focus.draw_center = false
	focus.set_expand_margin_all(8)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("background", "ProgressBar", _box(P.INK, P.INK, 4, Vector2.ZERO))
	t.set_stylebox("fill", "ProgressBar", _box(P.SALMON, P.INK, 4, Vector2.ZERO))
	t.set_stylebox("panel", "PanelContainer", _box(Color(P.INK, 0.92), P.CREAM, 4, Vector2(48, 32)))
	return t
