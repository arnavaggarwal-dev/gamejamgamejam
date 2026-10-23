extends RefCounted
## The throne room. The background stays soft and outline-free so the outlined
## foreground (hero, boss, hazards) always reads on top of it.
## The arena is 2560 world px wide (640 art px); the wall scrolls at half speed, so it is 480 art px.

const P = preload("res://tools/art/pal.gd")
const Canvas = preload("res://tools/art/canvas.gd")

const WALL_W := 480
const WINDOWS := [36, 132, 312, 408]
const BANNERS := [94, 370]
const TORCHES := [20, 120, 180, 302, 359, 460]
const GEAR_AT := Vector2i(240, 76)
const GEAR_R := 44.0
const GEAR_TEETH := 12


## Back wall with window holes (the sky layer shows through them).
static func wall():
	var c = Canvas.new(WALL_W, 180)
	c.rect(0, 0, WALL_W, 180, P.CREAM)
	for row in range(0, 15):
		var y := row * 8
		c.hline(0, WALL_W - 1, y, P.GREY)
		var shift := 8 if row % 2 else 0
		for bx in range(-shift, WALL_W, 16):
			c.vline(bx, y, y + 7, P.GREY)
	# Lilac wainscot where the crowd's balcony stands.
	c.rect(0, 118, WALL_W, 32, P.LILAC)
	c.hline(0, WALL_W - 1, 118, P.PERI)
	c.hline(0, WALL_W - 1, 119, P.CREAM)
	for wx in WINDOWS:
		_window(c, wx, 22, 36, 84)
	c.rect(0, 150, WALL_W, 10, P.PERI)
	c.hline(0, WALL_W - 1, 150, P.CREAM)
	return c


static func _in_window(xx: int, yy: int, x: int, y: int, ww: int, wh: int, grow: int, c) -> bool:
	var r := ww / 2.0 + grow
	if xx < x - grow or xx >= x + ww + grow or yy >= y + wh + grow:
		return false
	return yy >= y + ww / 2.0 or c.inside_ellipse(xx, yy, x + ww / 2.0, y + ww / 2.0, r, r)


static func _window(c, x: int, y: int, ww: int, wh: int) -> void:
	for yy in range(y - 3, y + wh + 3):
		for xx in range(x - 3, x + ww + 3):
			if _in_window(xx, yy, x, y, ww, wh, 0, c):
				c.px(xx, yy, P.CLEAR)
			elif _in_window(xx, yy, x, y, ww, wh, 2, c):
				c.px(xx, yy, P.LILAC)
	c.vline(x + floori(ww / 2.0), y, y + wh - 1, P.LILAC)
	c.hline(x, x + ww - 1, y + 46, P.LILAC)
	c.rect(x - 4, y + wh, ww + 8, 3, P.PERI)
	c.hline(x - 4, x + ww + 3, y + wh, P.LILAC)


## Sky seen through the windows: periwinkle high up, sky blue below. Tiles horizontally.
static func sky():
	var c = Canvas.new(160, 180)
	c.rect(0, 0, 160, 180, P.SKY)
	c.rect(0, 0, 160, 36, P.PERI)
	for y in range(36, 42):
		for x in 160:
			if (x + y) % 2 == 0:
				c.px(x, y, P.PERI)
	return c


## A strip of clouds that tiles horizontally; it drifts behind the windows.
static func clouds():
	var c = Canvas.new(160, 60)
	var puffs := [[20, 14, 9, 4], [30, 12, 7, 5], [40, 15, 8, 3], [86, 38, 10, 4], [97, 36, 7, 5], [106, 39, 6, 3], [140, 22, 8, 3], [150, 20, 6, 4]]
	for p in puffs:
		for dx in [-160, 0, 160]:
			c.ellipse(p[0] + dx, p[1] + 1, p[2], p[3], P.GREY)
			c.ellipse(p[0] + dx, p[1], p[2], p[3], P.CREAM)
	return c


## The big gear behind the throne, turning one tooth per cycle (6 frames).
static func gear_frames() -> Array:
	var frames := []
	var size := int((GEAR_R + 8) * 2)
	for f in 6:
		var c = Canvas.new(size, size)
		var cx := size / 2.0
		var turn := f * (TAU / GEAR_TEETH) / 6.0
		for y in size:
			for x in size:
				var v := Vector2(x + 0.5 - cx, y + 0.5 - cx)
				var d := v.length()
				var a := fposmod((v.angle() - turn) / TAU * GEAR_TEETH, 1.0)
				var tooth := d > GEAR_R and d <= GEAR_R + 7 and a < 0.45
				if (d <= GEAR_R or tooth) and d > GEAR_R * 0.3:
					c.px(x, y, P.PERI if d > GEAR_R * 0.85 or tooth else P.LILAC)
		c.ring(cx, cx, GEAR_R * 0.3, 2, P.PERI)
		for k in 4:
			var sa := turn + k * TAU / 4.0
			c.line(int(cx + cos(sa) * GEAR_R * 0.35), int(cx + sin(sa) * GEAR_R * 0.35), int(cx + cos(sa) * GEAR_R * 0.8), int(cx + sin(sa) * GEAR_R * 0.8), P.PERI)
		frames.append(c)
	return frames


## A royal banner swaying left, centre, right, centre (4 frames).
static func banner_frames() -> Array:
	var frames := []
	for sway in [-1, 0, 1, 0]:
		var c = Canvas.new(20, 68)
		c.rect(0, 0, 20, 2, P.PLUM)
		for yy in range(2, 66):
			var dx := int(round(sway * maxf(0.0, yy - 18) / 48.0 * 2.0))
			for xx in range(2, 18):
				var cut := yy > 58 and absi(xx - 10) < (yy - 58)
				if not cut:
					c.px(xx + dx, yy, P.ROSE if xx >= 14 else (P.PEACH if xx == 2 else P.SALMON))
		var ey := 18
		c.grid(6 + int(round(sway * 0.5)), ey, [
			"....BB..",
			"...BB...",
			"..BBBBB.",
			"....BB..",
			"...BB...",
			"..BB....",
			"..B.....",
		], {"B": P.BUTTER})
		frames.append(c)
	return frames


## Wall torch: a plum sconce with a flickering flame (4 frames).
static func torch_frames() -> Array:
	var frames := []
	var shapes := [[11.0, 0], [13.0, 1], [12.0, -1], [14.0, 0]]
	for s in shapes:
		var c = Canvas.new(12, 26)
		var h: float = s[0]
		var lean: int = s[1]
		for y in range(0, 18):
			var t := (17.0 - y) / h
			if t > 1.0:
				continue
			var half := sin(clampf(t, 0.0, 1.0) * PI) * 3.6 * (0.6 + 0.4 * t)
			var cx := 6.0 + lean * (1.0 - t)
			for x in 12:
				var d := absf(x + 0.5 - cx)
				if d <= half:
					var inner := d < half * 0.45 and t < 0.75
					var col: Color = P.CREAM if inner and t < 0.45 else (P.BUTTER if inner else (P.PEACH if t < 0.7 else P.SALMON))
					c.px(x, y, col)
		c.rect(3, 18, 6, 2, P.ROSE)
		c.rect(4, 20, 4, 4, P.PLUM)
		c.px(3, 18, P.PEACH)
		c.outline()
		frames.append(c)
	return frames


## Soft warm light behind each torch (semi-transparent bands, no anti-aliasing).
static func glow():
	var c = Canvas.new(48, 48)
	for y in 48:
		for x in 48:
			var d := Vector2(x + 0.5 - 24, y + 0.5 - 24).length()
			if d < 12:
				c.px(x, y, Color(P.BUTTER, 0.28))
			elif d < 20:
				c.px(x, y, Color(P.BUTTER, 0.16))
			elif d < 24:
				c.px(x, y, Color(P.PEACH, 0.08))
	return c


## The king's robot subjects on the balcony: idle bob (frames 0-1) and cheering (frames 2-3).
static func crowd_frames() -> Array:
	var frames := []
	var bodies := [P.SLATE, P.PLUM, P.SAGE, P.ROSE, P.VIOLET, P.BLUE, P.CHARCOAL]
	var count := 30
	for f in 4:
		var c = Canvas.new(WALL_W, 26)
		var cheering := f >= 2
		for i in count:
			var hop := 0
			if cheering:
				hop = -3 if (i + f) % 2 == 0 else 0
			elif (i + f) % 3 == 0:
				hop = 1
			c.blit(_robot(bodies[(i * 3) % bodies.size()], i % 3, cheering), 3 + i * 16, 4 + hop)
		frames.append(c)
	return frames


## One spectator on a 14x22 canvas, feet on the bottom row, soft plum outline
## (a step quieter than the ink-outlined foreground).
static func _robot(body: Color, head_kind: int, arms_up: bool):
	var c = Canvas.new(14, 22)
	c.rect(3, 12, 8, 9, body)
	c.hline(4, 9, 14, P.BUTTER if head_kind == 1 else P.GREY)
	if head_kind == 0:
		c.ellipse(7, 9, 3.5, 3.5, body)
	elif head_kind == 1:
		c.rect(4, 6, 6, 6, body)
	else:
		c.ellipse(7, 9, 4.5, 3.0, body)
	c.px(5, 9, P.CREAM)
	c.px(8, 9, P.CREAM)
	c.vline(7, 2, 4, P.CHARCOAL)
	c.px(7, 1, P.SALMON if head_kind == 2 else P.BUTTER)
	if arms_up:
		c.vline(2, 6, 12, body)
		c.vline(11, 6, 12, body)
	else:
		c.vline(2, 13, 17, body)
		c.vline(11, 13, 17, body)
	c.outline(P.PLUM)
	return c


## Balcony railing in front of the crowd.
static func railing():
	var c = Canvas.new(WALL_W, 10)
	c.hline(0, WALL_W - 1, 0, P.CREAM)
	c.hline(0, WALL_W - 1, 1, P.PERI)
	for x in range(2, WALL_W, 8):
		c.rect(x, 2, 2, 7, P.LILAC)
		c.vline(x + 1, 2, 8, P.PERI)
	c.hline(0, WALL_W - 1, 8, P.PERI)
	c.hline(0, WALL_W - 1, 9, P.VIOLET)
	return c


## One floor panel tile (40x20 art = 160x80 world). Collision top is row 0; tiles 10 px wide line up across panels.
static func floor_tile():
	var c = Canvas.new(40, 20)
	for y in range(1, 20):
		for x in 40:
			var tile := (floori(x / 10.0) + floori((y - 3) / 8.0)) % 2 == 0
			c.px(x, y, P.ROSE if tile else P.PLUM)
	for x in range(0, 40, 10):
		c.vline(x, 4, 19, P.INK)
		c.px(x + 1, 4, P.PEACH)
	for y in [11, 19]:
		c.hline(0, 39, y, P.INK)
	c.hline(0, 39, 0, P.INK)
	c.hline(0, 39, 1, P.PEACH)
	c.hline(0, 39, 2, P.PEACH)
	c.hline(0, 39, 3, P.ROSE)
	return c


## Conveyor belt panel: butter chevrons march right (4 frames; flipped for leftward belts).
static func belt_frames() -> Array:
	var frames := []
	for f in 4:
		var c = floor_tile()
		c.rect(0, 1, 40, 6, P.SLATE)
		c.hline(0, 39, 1, P.GREY)
		c.hline(0, 39, 6, P.INK)
		for k in range(-1, 6):
			var x0 := k * 8 + f * 2
			for i in 3:
				c.px(x0 + i, 2 + i, P.BUTTER)
				c.px(x0 + i, 6 - i - 1 + 0, P.BUTTER)
		for rx in range(4, 40, 10):
			c.ellipse(rx + (f % 2), 9, 2, 2, P.CHARCOAL)
			c.px(rx + (f % 2), 9, P.GREY)
		frames.append(c)
	return frames


## Warning stripes painted over a panel about to be electrified (2 frames).
static func warn_frames() -> Array:
	var frames := []
	for f in 2:
		var c = Canvas.new(40, 6)
		for y in 6:
			for x in 40:
				if (x + y + f * 4) % 8 < 4:
					c.px(x, y, P.BUTTER)
				else:
					c.px(x, y, Color(P.INK, 0.8))
		frames.append(c)
	return frames


## Electricity crackling along a zapped panel (3 frames): thick forked bolts over a hot base strip,
## ink-outlined so they read against the pale wall.
static func zap_frames() -> Array:
	var frames := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for f in 3:
		var c = Canvas.new(40, 16)
		c.rect(0, 13, 40, 3, P.SKY)
		c.hline(0, 39, 14, P.CREAM)
		for bolt in 4:
			var x := rng.randi_range(3, 36)
			var y := 14
			while y > 1:
				var nx := clampi(x + rng.randi_range(-3, 3), 1, 38)
				var ny := maxi(1, y - rng.randi_range(2, 4))
				c.line(x, y, nx, ny, P.BUTTER)
				c.line(x + 1, y, nx + 1, ny, P.CREAM)
				x = nx
				y = ny
		c.outline(P.INK)
		frames.append(c)
	return frames


## Moving lift: caution-striped girder with thruster flames underneath (2 frames).
static func lift_frames() -> Array:
	var frames := []
	for f in 2:
		var c = Canvas.new(50, 12)
		c.rect(1, 1, 48, 4, P.BUTTER)
		for x in range(1, 49):
			if (x + 0) % 6 < 3:
				c.vline(x, 2, 4, P.INK)
		c.hline(1, 48, 1, P.CREAM)
		for tx in [8, 41]:
			c.rect(tx - 2, 5, 4, 2, P.SLATE)
			for i in 3 + f:
				var half := 1 if i < 2 else 0
				c.hline(tx - half, tx + half, 7 + i, P.BUTTER if i < 2 else P.PEACH)
			c.px(tx, 7, P.CREAM)
		c.outline()
		frames.append(c)
	return frames


## Ceiling rubble that falls in the last phase (2 tumble frames).
static func debris_frames() -> Array:
	var frames := []
	for f in 2:
		var c = Canvas.new(14, 12)
		var rows := [
			"...#####....",
			"..#######...",
			".#########..",
			"###########.",
			"############",
			".##########.",
			"..#######...",
			"....###.....",
		]
		c.grid(1, 2, rows, {"#": P.ROSE})
		c.shade_ellipse(6.5, 6.0, 5.5, 4.0, [P.PLUM, P.ROSE, P.PEACH, P.CREAM], [-0.2, 0.4, 0.88])
		c.px(4, 4, P.CHARCOAL)
		c.px(9, 7, P.CHARCOAL)
		if f == 1:
			c.img.flip_x()
			c.img.flip_y()
		c.outline()
		frames.append(c)
	return frames


## One-way girder platform.
static func platform():
	var c = Canvas.new(50, 6)
	c.rect(1, 1, 48, 4, P.ROSE)
	c.hline(1, 48, 1, P.PEACH)
	c.hline(1, 48, 4, P.PLUM)
	for x in range(5, 46, 8):
		c.px(x, 3, P.INK)
	c.px(2, 2, P.BUTTER)
	c.px(47, 2, P.BUTTER)
	c.outline()
	return c
