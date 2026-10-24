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
	# One calm stone colour with soft plum seams (no checker), so the floor reads without buzzing.
	c.rect(0, 1, 40, 19, P.ROSE)
	for x in range(0, 40, 10):
		c.vline(x, 4, 19, P.PLUM)
		c.px(x + 1, 4, P.PEACH)
	c.hline(0, 39, 11, P.PLUM)
	c.hline(0, 39, 19, P.INK)
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


## Core platform plate: king-blue metal with a gold walking edge (outer end pieces are rounded).
static func core_plate(end: bool):
	var c = Canvas.new(12, 8)
	c.rect(1, 1, 10, 6, P.BLUE)
	c.hline(1, 10, 1, P.BUTTER)
	c.hline(1, 10, 2, P.PERI)
	c.hline(1, 10, 6, P.NAVY)
	for rx in [3, 8]:
		c.px(rx, 4, P.PERI)
		c.px(rx + 1, 5, P.INK)
	if end:
		c.px(1, 1, P.CLEAR)
		c.px(1, 6, P.CLEAR)
		c.px(1, 2, P.BUTTER)
	c.outline()
	return c


## The core platform's hub: a dark housing holding the core the plates cling to.
## Frames: lit pulse a, lit pulse b (armed), dim (unarmed or broken).
static func core_hub_frames() -> Array:
	var frames := []
	for r in [2.2, 2.8, 0.0]:
		var c = Canvas.new(12, 8)
		c.rect(1, 1, 10, 6, P.CHARCOAL)
		c.hline(1, 10, 1, P.BUTTER)
		c.ring(5.5, 4.0, 3.4, 1.0, P.BUTTER)
		if r > 0.0:
			c.glow_disc(5.5, 4.0, r, P.GLOW)
		else:
			c.ellipse(5.5, 4.0, 2.4, 2.4, P.SLATE)
			c.px(4, 3, P.PERI)
		c.outline()
		frames.append(c)
	return frames


## Acid flooding the arena of doom's floor: a glowing green crust that bubbles (3 frames).
static func acid_frames() -> Array:
	var frames := []
	for f in 3:
		var c = Canvas.new(40, 20)
		c.rect(0, 0, 40, 20, P.TEAL)
		c.rect(0, 0, 40, 6, P.SAGE)
		c.rect(0, 0, 40, 2, P.MINT)
		for x in range(0, 40):
			if (x + f * 3) % 9 < 4:
				c.px(x, 0, P.CREAM)
		for bub in [[6, 9], [19, 13], [31, 8]]:
			var r: int = (f + bub[0]) % 3
			c.ellipse(bub[0], bub[1] - f, 1.5 + r * 0.5, 1.5 + r * 0.5, P.MINT)
			c.px(bub[0], bub[1] - f - 1, P.CREAM)
		frames.append(c)
	return frames


## A thin stone ledge for the arena of doom (tiles along its length): a lit top edge, stone
## blocks, a dark underside with rivets.
static func ledge():
	var c = Canvas.new(40, 10)
	c.rect(0, 0, 40, 10, P.ROSE)
	c.hline(0, 39, 0, P.PEACH)
	c.hline(0, 39, 1, P.SALMON)
	c.rect(0, 7, 40, 3, P.PLUM)
	for x in [0, 20]:
		c.vline(x, 2, 6, P.PLUM)
	for x in [6, 26]:
		c.px(x, 8, P.SALMON)
	c.hline(0, 39, 9, P.INK)
	return c


## The arena of doom's huge red moon.
static func moon():
	var c = Canvas.new(80, 80)
	c.glow_disc(39.5, 39.5, 38.0, [P.PLUM, P.ROSE, P.SALMON, P.PEACH])
	for cr in [[26, 30, 6.0], [50, 46, 8.0], [36, 58, 4.0], [56, 24, 3.5]]:
		c.ellipse(cr[0], cr[1], cr[2], cr[2] * 0.8, P.ROSE)
		c.ellipse(cr[0] + 1, cr[1] + 1, cr[2] - 1.5, cr[2] * 0.8 - 1.5, P.PLUM)
	return c


## Phase 4 sky lightning, 3 frames for a flicker: a jagged main channel from cloud to ground with
## a few forks, a cream core in a butter glow, ink outline. 540 tall (2160 in game).
static func bolt_frames() -> Array:
	var frames := []
	for f in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = 41 + f * 977
		var c = Canvas.new(48, 540)
		var trunk := _bolt_path(rng, 24.0, 539)
		for k in 5:
			var from: Vector2 = trunk[rng.randi_range(6, trunk.size() - 20)]
			_bolt_stroke(c, _bolt_fork(rng, from, 1.0 if rng.randf() < 0.5 else -1.0, rng.randi_range(8, 18)), false)
		_bolt_stroke(c, trunk, true)
		c.outline()
		frames.append(c)
	return frames


## The main channel: steps of 5-11 px down, each kicked up to 4 px sideways.
static func _bolt_path(rng: RandomNumberGenerator, x: float, bottom: int) -> Array:
	var points := []
	var y := 0
	while y < bottom:
		points.append(Vector2(roundi(x), y))
		y = mini(y + rng.randi_range(5, 11), bottom)
		x = clampf(x + rng.randf_range(-4.0, 4.0), 8.0, 39.0)
	points.append(Vector2(roundi(x), bottom))
	return points


## A fork: drifts down and out to one side from a point on the main channel.
static func _bolt_fork(rng: RandomNumberGenerator, from: Vector2, side: float, steps: int) -> Array:
	var points := [from]
	var p := from
	for s in steps:
		p += Vector2(side * rng.randf_range(1.0, 3.0), rng.randf_range(3.0, 7.0))
		p.x = clampf(p.x, 2.0, 45.0)
		points.append(p.round())
	return points


## Glow first, then the core, along a path (the main channel is thicker than a fork).
static func _bolt_stroke(c, points: Array, thick: bool) -> void:
	for layer in [[P.BUTTER, 2 if thick else 1], [P.CREAM, 1 if thick else 0]]:
		for i in points.size() - 1:
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			for o in range(-layer[1], layer[1] + 1):
				c.line(int(a.x) + o, int(a.y), int(b.x) + o, int(b.y), layer[0])


## The storm cloud a strike falls from: dark puffs with moonlit tops; the second frame glows
## from inside, about to strike.
static func storm_cloud_frames() -> Array:
	var frames := []
	for lit in [false, true]:
		var c = Canvas.new(60, 26)
		for e in [[14, 15, 12, 8], [30, 11, 15, 10], [46, 15, 12, 8], [23, 18, 13, 7], [38, 18, 13, 7]]:
			c.ellipse(e[0], e[1], e[2], e[3], P.INK)
		for e in [[27, 6, 9, 3], [12, 10, 6, 2], [45, 10, 6, 2]]:
			c.ellipse(e[0], e[1], e[2], e[3], P.CHARCOAL)
		if lit:
			c.glow_disc(30, 17, 9, [P.PLUM, P.PEACH, P.BUTTER, P.CREAM])
		frames.append(c)
	return frames


## The scorch a strike leaves on the floor, a few embers still glowing.
static func scorch():
	var c = Canvas.new(36, 8)
	c.ellipse(17.5, 4, 17, 3.5, P.CHARCOAL)
	c.ellipse(17.5, 4, 10, 2, P.INK)
	for x in [6, 13, 22, 29]:
		c.px(x, 3, P.SALMON)
	return c


## Where a sky strike will land: a hot spot glowing on the floor, red rim, bright heart.
static func strike_mark():
	var c = Canvas.new(40, 10)
	c.ellipse(19.5, 5, 19, 4.5, P.PLUM)
	c.ellipse(19.5, 5, 15, 3.4, P.SALMON)
	c.ellipse(19.5, 5, 9, 2, P.PEACH)
	c.ellipse(19.5, 5, 4, 1, P.CREAM)
	return c


## A floating conveyor's belt (4 frames, the treads roll right): treads on top, a navy frame
## with a roller at each end.
static func belt_thin_frames() -> Array:
	var frames := []
	for f in 4:
		var c = Canvas.new(40, 10)
		c.rect(0, 0, 40, 10, P.NAVY)
		c.hline(0, 39, 3, P.BLUE)
		for x in 40:
			c.px(x, 1, P.BUTTER if (x - f * 2) % 8 < 4 else P.CHARCOAL)
			c.px(x, 2, P.PEACH if (x - f * 2) % 8 < 4 else P.INK)
		for rx in [5, 34]:
			c.ellipse(rx, 6.5, 2.5, 2.5, P.CHARCOAL)
			c.px(rx, 6, P.BUTTER)
		c.hline(0, 39, 0, P.INK)
		c.hline(0, 39, 9, P.INK)
		frames.append(c)
	return frames
