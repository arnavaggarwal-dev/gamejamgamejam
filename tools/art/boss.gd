extends RefCounted
## King Kilowatt's puppet parts. Sizes are art px (1/4 of the in-game size); the boss faces left.

const P = preload("res://tools/art/pal.gd")
const Canvas = preload("res://tools/art/canvas.gd")


## Left-lit metal fill for a span [l, r] on row y.
static func _metal_span(c, l: int, r: int, y: int, top: int) -> void:
	var span := maxf(1.0, r - l)
	for x in range(l, r + 1):
		var u := (x - l) / span
		var col: Color = P.BLUE
		if u < 0.1 or y - top < 2:
			col = P.PERI
		elif u > 0.62:
			col = P.NAVY
		c.px(x, y, col)


static func _rivet(c, x: int, y: int) -> void:
	c.px(x, y, P.PERI)
	c.px(x + 1, y + 1, P.INK)


static func _gold_band(c, x: int, y: int, bw: int, bh: int) -> void:
	c.rect(x, y, bw, bh, P.BUTTER)
	c.hline(x, x + bw - 1, y, P.CREAM)
	c.hline(x, x + bw - 1, y + bh - 1, P.PEACH)
	for xx in range(x + int(bw * 0.7), x + bw):
		c.vline(xx, y + 1, y + bh - 1, P.PEACH)


static func torso():
	var c = Canvas.new(90, 105)
	for y in 105:
		var t := clampf((y - 12) / 92.0, 0.0, 1.0)
		var half := 44.0 - 10.0 * t
		var inset := 0.0
		if y < 12:
			inset = 12.0 - sqrt(144.0 - pow(12.0 - y, 2.0))
		_metal_span(c, int(45 - half + inset), int(44 + half - inset), y, 0)
	# Plate seams and rivets.
	for sy in [30, 62]:
		for x in range(4, 86):
			if c.solid(x, sy):
				c.px(x, sy, P.INK)
	for x in range(10, 82, 9):
		_rivet(c, x, 6)
		_rivet(c, x, 33)
	# Reactor socket around the core (the core sprite sits at local 40,40).
	c.ellipse(40, 40, 19, 19, P.INK)
	c.ring(40, 40, 18, 3, P.CHARCOAL)
	for y in range(20, 42):
		for x in range(20, 42):
			if c.at(x, y) == P.CHARCOAL:
				c.px(x, y, P.GREY)
	for b in [[27, 27], [52, 27], [27, 52], [52, 52]]:
		c.px(b[0], b[1], P.BUTTER)
	# Royal belt with a lightning buckle.
	_gold_band(c, 0, 70, 90, 7)
	for x in 90:
		for y in range(70, 77):
			if not _in_torso(x, y):
				c.px(x, y, P.CLEAR)
	c.rect(36, 68, 12, 11, P.PLUM)
	c.grid(38, 69, [
		"....BB..",
		"...BB...",
		"..BBBBB.",
		"....BB..",
		"...BB...",
		"..BB....",
		"..B.....",
	], {"B": P.BUTTER})
	c.outline()
	return c


static func _in_torso(x: int, y: int) -> bool:
	var t := clampf((y - 12) / 92.0, 0.0, 1.0)
	var half := 44.0 - 10.0 * t
	return x >= int(45 - half) and x <= int(44 + half)


static func head():
	var c = Canvas.new(70, 50)
	for y in 50:
		var inset := 0
		if y < 6:
			inset = 6 - int(sqrt(36.0 - pow(6.0 - y, 2.0)))
		elif y > 43:
			inset = 6 - int(sqrt(36.0 - pow(y - 43.0, 2.0)))
		_metal_span(c, 4 + inset, 65 - inset, y, 0)
	# Ear bolts.
	for ex in [0, 66]:
		c.rect(ex, 18, 4, 14, P.BUTTER)
		c.vline(ex + 3, 18, 31, P.PEACH)
		c.hline(ex, ex + 3, 18, P.CREAM)
	# Face screen with faint scanlines.
	c.rect(8, 12, 46, 30, P.INK)
	for sy in range(14, 41, 3):
		c.hline(9, 52, sy, P.CHARCOAL)
	# Angry brow plate over the eye, and the mouth grille.
	for i in 30:
		var bx := 10 + i
		var by := 8 + floori(i / 5.0)
		c.vline(bx, by, by + 3, P.BLUE)
		c.px(bx, by, P.PERI)
	for gy in [30, 33, 36]:
		c.hline(38, 50, gy, P.SLATE)
	c.outline()
	return c


static func crown():
	var c = Canvas.new(40, 16)
	for sx in [5, 20, 35]:
		for i in 9:
			var half := floori(i / 2.0)
			c.hline(sx - half, sx + half, 1 + i, P.BUTTER)
			c.px(sx + half, 1 + i, P.PEACH)
		c.px(sx, 1, P.CREAM)
	_gold_band(c, 1, 9, 38, 6)
	c.rect(19, 10, 3, 3, P.SALMON)
	c.px(19, 10, P.CREAM)
	for jx in [8, 31]:
		c.rect(jx, 11, 2, 2, P.MINT)
	c.outline()
	return c


## The big eye: a cool lens with a slit pupil glancing left (2 frames).
static func eye_frames() -> Array:
	var frames := []
	for look in [0, 1]:
		var c = Canvas.new(20, 20)
		c.ellipse(10, 10, 9.5, 9.5, P.INK)
		c.glow_disc(10, 10, 8, [P.PERI, P.SKY, P.CREAM])
		c.rect(6 + look, 6, 2, 8, P.INK)
		c.px(13, 5, P.CREAM)
		c.px(14, 6, P.CREAM)
		frames.append(c)
	return frames


## The weak spot: a pulsing reactor orb (4 frames).
static func core_frames() -> Array:
	var frames := []
	var radii := [12.0, 13.0, 14.0, 13.0]
	for i in radii.size():
		var c = Canvas.new(32, 32)
		c.glow_disc(16, 16, radii[i], P.GLOW)
		var arm := 3 + (i % 2)
		c.hline(16 - arm, 16 + arm, 16, P.CREAM)
		c.vline(16, 16 - arm, 16 + arm, P.CREAM)
		frames.append(c)
	return frames


## Lock-on brackets around the core: "hit here" (2 frames).
static func target_frames() -> Array:
	var frames := []
	for inset in [3, 1]:
		var c = Canvas.new(44, 44)
		var lo: int = inset
		var hi: int = 43 - inset
		for corner in [[lo, lo, 1, 1], [hi, lo, -1, 1], [lo, hi, 1, -1], [hi, hi, -1, -1]]:
			for i in 7:
				c.px(corner[0] + i * corner[2], corner[1], P.BUTTER)
				c.px(corner[0], corner[1] + i * corner[3], P.BUTTER)
				c.px(corner[0] + i * corner[2], corner[1] + corner[3], P.PEACH)
				c.px(corner[0] + corner[2], corner[1] + i * corner[3], P.PEACH)
		c.outline()
		frames.append(c)
	return frames


## Right fist, clenched, knuckles down: the slam.
static func fist_closed():
	var c = Canvas.new(42, 38)
	for y in range(8, 30):
		_metal_span(c, 4, 39, y, 8)
	for k in 4:
		var kx := 8.5 + k * 8.5
		c.shade_ellipse(kx, 31, 4.6, 5.5, P.METAL, [-0.3, 0.3, 0.8])
		if k > 0:
			c.vline(int(kx - 4.3), 24, 35, P.INK)
	c.shade_ellipse(4.5, 20, 4.5, 6.5, P.METAL, [-0.3, 0.3, 0.8])
	_gold_band(c, 6, 1, 30, 8)
	c.rect(17, 3, 8, 3, P.INK)
	c.outline()
	return c


## Left hand, open, fingers up: holds and lobs the bombs.
static func fist_open():
	var c = Canvas.new(42, 38)
	for y in range(16, 32):
		_metal_span(c, 7, 38, y, 16)
	for f in 4:
		var fx := 10 + f * 7
		for y in range(3 + (f % 2) * 2, 18):
			_metal_span(c, fx, fx + 5, y, 3 + (f % 2) * 2)
		if f > 0:
			c.vline(fx - 1, 6, 20, P.INK)
	c.shade_ellipse(5, 22, 5, 4, P.METAL, [-0.3, 0.3, 0.8])
	_gold_band(c, 8, 30, 30, 7)
	c.outline()
	return c


## Shoulder pauldron: a half dome with a gold rim (both shoulders use it; the right one is flipped).
static func armor():
	var c = Canvas.new(32, 24)
	c.shade_ellipse(16, 22, 15.5, 21, P.METAL, [-0.2, 0.35, 0.85])
	_gold_band(c, 1, 18, 30, 5)
	c.hline(0, 31, 23, P.CLEAR)
	for rx in [6, 15, 24]:
		_rivet(c, rx, 9 + floori(absi(rx - 15) / 3.0))
	c.outline()
	return c


## Floor marker where the fist will land: dashed salmon ring over a soft shadow.
static func reticle():
	var c = Canvas.new(56, 12)
	for y in 12:
		for x in 56:
			var outer: bool = c.inside_ellipse(x, y, 28, 6, 28, 6)
			var inner: bool = c.inside_ellipse(x, y, 28, 6, 26.5, 4.6)
			if inner:
				c.px(x, y, Color(P.INK, 0.4))
			elif outer and floori(x / 4.0) % 2 == 0:
				c.px(x, y, P.SALMON)
	return c


## Lil' Watt, the tutorial bot: a round little king on a jet with the same core in its chest.
## Frames: hover a, hover b (jet flicker), hurt (eye shut), broken (X eye, no jet, cracked).
static func bot_frames() -> Array:
	var frames := []
	for kind in ["hover_a", "hover_b", "hurt", "broken"]:
		var c = Canvas.new(40, 44)
		if kind != "broken":
			var flame := [P.CREAM, P.BUTTER, P.BUTTER, P.PEACH, P.PEACH, P.SALMON, P.SALMON]
			for i in (7 if kind == "hover_a" else 5):
				var half := maxi(0, 3 - floori(i / 2.0))
				c.hline(20 - half, 19 + half, 35 + i, flame[i])
		for y in range(8, 35):
			var dy := y - 21.0 + 0.5
			var half := int(sqrt(maxf(0.0, 169.0 - dy * dy)))
			_metal_span(c, 20 - half, 19 + half, y, 8)
		c.rect(3, 23, 4, 3, P.SLATE)
		c.rect(33, 23, 4, 3, P.SLATE)
		# Visor with one big eye, like the king's.
		c.rect(11, 12, 18, 6, P.INK)
		match kind:
			"hurt":  # > < wince
				for p in [[15, 13], [16, 14], [15, 15], [24, 13], [23, 14], [24, 15]]:
					c.px(p[0], p[1], P.CREAM)
			"broken":
				c.line(17, 13, 21, 16, P.SALMON)
				c.line(21, 13, 17, 16, P.SALMON)
			_:
				c.rect(18, 13, 4, 4, P.SKY)
				c.px(18, 13, P.CREAM)
				c.vline(20, 14, 15, P.INK)
		# Core socket: the glowing core sprite sits on top of this.
		c.ellipse(20, 26, 6, 6, P.INK)
		c.ring(20, 26, 6.5, 1.2, P.BUTTER)
		var tilt := 1 if kind == "broken" else 0
		for sx in [14, 20, 26]:
			for i in 4:
				var h := floori(i / 2.0)
				c.hline(sx - h, sx + h, 2 + i + tilt, P.BUTTER)
			c.px(sx, 2 + tilt, P.CREAM)
		_gold_band(c, 12, 6 + tilt, 17, 3)
		if kind == "broken":
			c.recolor(P.BLUE, P.SLATE)
			c.recolor(P.PERI, P.BLUE)
			c.line(11, 21, 15, 29, P.INK)
		c.outline()
		frames.append(c)
	return frames


## A giant leg (thigh into shin), from out of frame down to the ankle. Knee socket at (15, 106):
## the front leg's knee core sits there; the back leg's stays dark.
static func leg():
	var c = Canvas.new(32, 146)
	for y in 146:
		var half := 14
		if y > 112:
			half = 11  # narrower shin
		elif y > 98:
			half = 13
		_metal_span(c, 16 - half, 15 + half, y, -10)
	# Plate seams, rivets, a gold thigh band and an ankle cuff.
	for sy in [40, 74, 128]:
		for x in 32:
			if c.solid(x, sy):
				c.px(x, sy, P.INK)
	for ry in [20, 56, 90]:
		_rivet(c, 6, ry)
		_rivet(c, 24, ry)
	_gold_band(c, 2, 12, 28, 5)
	_gold_band(c, 5, 138, 22, 5)
	# Knee socket.
	c.ellipse(15.5, 106, 11, 11, P.INK)
	c.ring(15.5, 106, 10, 2, P.CHARCOAL)
	for b in [[9, 100], [22, 100], [9, 112], [22, 112]]:
		c.px(b[0], b[1], P.BUTTER)
	c.outline()
	return c


## A giant boot, toe to the left (the king faces left), gold toe cap, dark sole.
static func foot():
	var c = Canvas.new(66, 24)
	for y in range(1, 23):
		var left := 1
		if y < 9:
			left = 26 - y * 2  # instep slopes down to the toe
		var right := 64
		if y < 4:
			right = 52
		_metal_span(c, maxi(left, 1), right, y, 1)
	for y in range(9, 19):
		for x in range(1, 13):
			if c.solid(x, y):
				c.px(x, y, P.BUTTER if y > 10 else P.CREAM)
	c.vline(13, 9, 18, P.PEACH)
	c.rect(1, 19, 64, 4, P.CHARCOAL)
	c.hline(1, 64, 19, P.INK)
	for rx in [22, 36, 50]:
		_rivet(c, rx, 12)
	c.outline()
	return c


## The long neck that holds his head out of frame until the torso is destroyed.
static func neck():
	var c = Canvas.new(22, 140)
	for y in 140:
		_metal_span(c, 3, 18, y, -10)
		if y % 14 == 0:
			c.hline(3, 18, y, P.INK)
			c.hline(3, 18, y + 1, P.SLATE)
			c.px(5, y + 4, P.BUTTER)
			c.px(16, y + 4, P.BUTTER)
	c.outline()
	return c
