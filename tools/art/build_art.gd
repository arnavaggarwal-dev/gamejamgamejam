extends SceneTree
## Regenerates every sprite in assets/art from code. Run from the project folder:
##   "$GODOT" --headless --path . -s tools/art/build_art.gd
## Also writes build/art_preview.png (all sheets at 4x) and build/art_mockup.png for eyeballing.

const Canvas = preload("res://tools/art/canvas.gd")
const P = preload("res://tools/art/pal.gd")
const Hero = preload("res://tools/art/hero.gd")
const Boss = preload("res://tools/art/boss.gd")
const World = preload("res://tools/art/world.gd")
const Fx = preload("res://tools/art/fx.gd")
const Ui = preload("res://tools/art/ui.gd")

const OUT := "res://assets/art/"
const SCALE := 4

var _preview: Array[Image] = []


func _initialize() -> void:
	_hero()
	_boss()
	_world()
	_fx()
	_ui()
	_write_preview()
	_write_mockup()
	quit()


func _world() -> void:
	var sky = World.sky()
	var clouds = World.clouds()
	var wall = World.wall()
	_save_sheet("world/sky.png", [sky])
	_save_sheet("world/clouds.png", [clouds])
	_save_sheet("world/wall.png", [wall])
	# Flattened 320-wide backdrop for the title screen (and the mockup).
	var bg = Canvas.new(320, 180)
	for x in [0, 160]:
		bg.blit(sky, x, 0)
		bg.blit(clouds, x, 30)
	bg.blit(wall, 0, 0)
	_save_sheet("world/background.png", [bg])
	var tile = World.floor_tile()
	var floor_strip = Canvas.new(350, 20)
	for x in range(0, 350, 40):
		floor_strip.blit(tile, x, 0)
	_save_sheet("world/floor.png", [floor_strip])
	_save_sheet("world/floor_tile.png", [tile])
	_save_sheet("world/belt.png", World.belt_frames())
	_save_sheet("world/warn.png", World.warn_frames())
	_save_sheet("world/zap.png", World.zap_frames())
	_save_sheet("world/platform.png", [World.platform()])
	_save_sheet("world/lift.png", World.lift_frames())
	_save_sheet("world/core_plate.png", [World.core_plate(false)])
	_save_sheet("world/core_plate_end.png", [World.core_plate(true)])
	_save_sheet("world/core_hub.png", World.core_hub_frames())
	_save_sheet("world/gear.png", World.gear_frames())
	_save_sheet("world/banner.png", World.banner_frames())
	_save_sheet("world/torch.png", World.torch_frames())
	_save_sheet("world/glow.png", [World.glow()])
	_save_sheet("world/crowd.png", World.crowd_frames())
	_save_sheet("world/railing.png", [World.railing()])


func _fx() -> void:
	_save_sheet("fx/bomb.png", Fx.bomb_frames())
	_save_sheet("fx/arrow.png", Fx.arrow_frames())
	_save_sheet("fx/streak.png", [Fx.streak()])
	_save_sheet("fx/zap_bit.png", [Fx.zap_bit()])
	_save_sheet("fx/explosion.png", Fx.explosion_frames())
	_save_sheet("fx/spark.png", Fx.spark_frames())
	_save_sheet("fx/dust.png", Fx.dust_frames())
	_save_sheet("fx/slime.png", Fx.slime_frames())
	_save_sheet("fx/poof.png", Fx.poof_frames())
	_save_sheet("fx/goo_blob.png", [Fx.goo_blob()])
	_save_sheet("fx/goo_puddle.png", [Fx.goo_puddle()])
	_save_sheet("fx/ember.png", [Fx.ember()])
	_save_sheet("hero/sprout.png", [Hero.sprout()])
	_save_sheet("fx/shockwave.png", Fx.shockwave_frames())
	_save_sheet("fx/laser_warn.png", Fx.laser_warn_frames())
	_save_sheet("fx/laser_beam.png", Fx.laser_beam_frames())
	_save_sheet("fx/dash_beam.png", Fx.dash_beam_frames())


func _ui() -> void:
	_save_sheet("ui/heart_full.png", [Ui.heart(true)])
	_save_sheet("ui/heart_empty.png", [Ui.heart(false)])
	_save_sheet("ui/bomb_full.png", [Ui.bomb_icon(true)])
	_save_sheet("ui/bomb_empty.png", [Ui.bomb_icon(false)])
	_save_sheet("ui/key_z.png", [Ui.key_cap("Z")])
	for key in ["X", "C", "A", "UP", "ENTER", "ESC"]:
		_save_sheet("ui/key_%s.png" % key.to_lower(), [Ui.key_cap(key)])
	_save_sheet("ui/key_arrows.png", [Ui.arrow_keys()])
	var font: Array = Ui.font("kilowatt.png")
	_save("ui/kilowatt.png", font[0])
	var f := FileAccess.open(OUT + "ui/kilowatt.fnt", FileAccess.WRITE)
	f.store_string(font[1])
	f.close()


## Composes the arena at its in-game positions (world px / 4) at 4x,
## so the art can be judged together without running a windowed game (build/art_mockup.png).
func _write_mockup() -> void:
	var m := Image.create_empty(320, 180, false, Image.FORMAT_RGBA8)
	m.fill(P.SKY)
	var bg := _load("world/background.png")
	if bg:
		m.blit_rect(bg, Rect2i(Vector2i.ZERO, bg.get_size()), Vector2i.ZERO)
	var parts := [
		["boss/torso.png", Vector2(1080, 470), false],
		["boss/armor.png", Vector2(960, 320), false],
		["boss/armor.png", Vector2(1200, 320), true],
		["boss/core.png:32", Vector2(1060, 420), false],
		["boss/target.png:44", Vector2(1060, 420), false],
		["boss/head.png", Vector2(1090, 170), false],
		["boss/crown.png", Vector2(1090, 45), false],
		["boss/eye.png:20", Vector2(1040, 170), false],
		["boss/fist_open.png", Vector2(880, 540), false],
		["world/floor.png", Vector2(640, 680), false],
		["world/platform.png", Vector2(220, 480), false],
		["world/platform.png", Vector2(540, 400), false],
		["world/platform.png", Vector2(820, 480), false],
		["boss/reticle.png", Vector2(420, 640), false],
		["hero/hero_run.png:20", Vector2(200, 598 - 4), false],
		["hero/hero_carry.png:20", Vector2(540, 388 - 42 - 4), false],
		["fx/bomb.png:16", Vector2(540, 388 - 112), false],
		["fx/bomb.png:16", Vector2(330, 620), false],
		["fx/arrow.png:7", Vector2(330, 580), false],
	]
	for part in parts:
		var spec: PackedStringArray = part[0].split(":")
		var im := _load(spec[0])
		if im == null:
			continue
		if spec.size() > 1:
			im = im.get_region(Rect2i(0, 0, int(spec[1]), im.get_height()))
		if part[2]:
			im.flip_x()
		var at: Vector2 = part[1] / SCALE - Vector2(im.get_size()) / 2.0
		m.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(at.round()))
	m.resize(320 * SCALE, 180 * SCALE, Image.INTERPOLATE_NEAREST)
	m.save_png("res://build/art_mockup.png")


func _load(path: String) -> Image:
	var full := ProjectSettings.globalize_path(OUT + path)
	if not FileAccess.file_exists(full):
		return null
	return Image.load_from_file(full)


func _boss() -> void:
	_save_sheet("boss/torso.png", [Boss.torso()])
	_save_sheet("boss/head.png", [Boss.head()])
	_save_sheet("boss/crown.png", [Boss.crown()])
	_save_sheet("boss/eye.png", Boss.eye_frames())
	_save_sheet("boss/core.png", Boss.core_frames())
	_save_sheet("boss/target.png", Boss.target_frames())
	_save_sheet("boss/fist_closed.png", [Boss.fist_closed()])
	_save_sheet("boss/fist_open.png", [Boss.fist_open()])
	_save_sheet("boss/armor.png", [Boss.armor()])
	_save_sheet("boss/reticle.png", [Boss.reticle()])
	_save_sheet("boss/leg.png", [Boss.leg()])
	_save_sheet("boss/foot.png", [Boss.foot()])
	_save_sheet("boss/jet.png", Boss.jet_frames())
	_save_sheet("boss/shard.png", [Boss.shard()])
	_save_sheet("boss/arm_bone.png", [Boss.arm_bone()])
	_save_sheet("boss/arm_joint.png", [Boss.arm_joint()])
	_save_sheet("boss/cable.png", [Boss.cable()])
	_save_sheet("boss/core_shield.png", [Boss.core_shield()])
	_save_sheet("boss/zap_ball.png", Boss.zap_ball_frames())
	_save_sheet("world/acid.png", World.acid_frames())
	_save_sheet("world/ledge.png", [World.ledge()])
	_save_sheet("world/belt_thin.png", World.belt_thin_frames())
	_save_sheet("world/moon.png", [World.moon()])
	_save_sheet("fx/aim_dot.png", [Fx.aim_dot(true)])
	_save_sheet("fx/aim_dot_small.png", [Fx.aim_dot(false)])
	for i in 3:
		_save_sheet("boss/crack_%d.png" % i, [Boss.crack(31 + i * 17)])
	_save_sheet("boss/bot.png", Boss.bot_frames())


func _hero() -> void:
	var anims: Dictionary = Hero.animations()
	for anim_name in anims:
		var frames := []
		for pose in anims[anim_name]:
			frames.append(Hero.frame(pose))
		_save_sheet("hero/hero_%s.png" % anim_name, frames)


func _save_sheet(path: String, frames: Array) -> void:
	var sheet := Canvas.strip(frames)
	_save(path, sheet)


func _save(path: String, image: Image) -> void:
	var full := OUT + path
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(full.get_base_dir()))
	var err := image.save_png(full)
	if err != OK:
		push_error("could not save %s (%d)" % [full, err])
	_preview.append(image)
	print("wrote ", full, " ", image.get_size())


func _write_preview() -> void:
	var width := 0
	var height := 0
	for im in _preview:
		width = maxi(width, im.get_width() * SCALE)
		height += im.get_height() * SCALE + 8
	var sheet := Image.create_empty(width + 16, height + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(P.GREY)
	var y := 8
	for im in _preview:
		var big := im.duplicate()
		big.resize(im.get_width() * SCALE, im.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(8, y))
		y += big.get_height() + 8
	sheet.save_png("res://build/art_preview.png")
