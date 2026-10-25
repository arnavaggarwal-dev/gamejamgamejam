extends RefCounted
## Props and effects: the bomb, explosions, hit sparks, dust, the slam shockwave, the laser.

const P = preload("res://tools/art/pal.gd")
const Canvas = preload("res://tools/art/canvas.gd")

const FIRE := [P.SALMON, P.PEACH, P.BUTTER, P.CREAM]
const SMOKE := [P.CHARCOAL, P.GREY, P.GREY, P.CREAM]


## The bomb with a fizzing fuse (3 frames). Body radius 5 matches its collision circle.
static func bomb_frames() -> Array:
	var frames := []
	var sparks := [
		[[13, 1, P.CREAM], [12, 1, P.BUTTER], [14, 1, P.BUTTER], [13, 0, P.BUTTER], [13, 2, P.BUTTER]],
		[[13, 1, P.BUTTER], [12, 0, P.CREAM], [14, 2, P.CREAM], [14, 0, P.SALMON], [12, 2, P.SALMON]],
		[[13, 1, P.SALMON], [13, 0, P.BUTTER], [14, 1, P.CREAM]],
	]
	for s in sparks:
		var c = Canvas.new(16, 16)
		c.shade_ellipse(7.5, 9.5, 5.5, 5.5, P.BOMB, [-0.2, 0.45, 0.9])
		c.rect(8, 3, 3, 2, P.SLATE)
		c.hline(8, 10, 3, P.GREY)
		c.px(11, 2, P.PEACH)
		c.px(12, 2, P.PEACH)
		c.outline()
		for p in s:
			c.px(p[0], p[1], p[2])
		frames.append(c)
	return frames


## "Grab me" arrow that bobs over loose bombs (2 frames).
static func arrow_frames() -> Array:
	var frames := []
	for dy in [0, 1]:
		var c = Canvas.new(7, 8)
		c.grid(0, dy, [
			".BBBBB.",
			"..BBB..",
			"..BBB..",
			"...B...",
		], {"B": P.BUTTER})
		c.hline(1, 5, dy, P.CREAM)
		c.outline()
		frames.append(c)
	return frames


## Speed streak left behind by a dash (symmetric, so it never needs flipping).
static func streak():
	var c = Canvas.new(8, 2)
	c.hline(0, 7, 0, P.MINT)
	c.hline(1, 6, 1, P.CREAM)
	return c


## A tiny zig-zag spark for the core platforms' electric aura (ink-outlined to read on the pale wall).
static func zap_bit():
	var c = Canvas.new(6, 7)
	for p in [[3, 1], [2, 2], [2, 3], [3, 3], [3, 4], [2, 5]]:
		c.px(p[0], p[1], P.BUTTER)
	c.px(3, 1, P.CREAM)
	c.px(2, 2, P.CREAM)
	c.outline()
	return c


## 8-frame explosion: flash, fireball, breakup, smoke.
static func explosion_frames() -> Array:
	var frames := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var c = Canvas.new(48, 48)
	c.glow_disc(24, 24, 6, [P.BUTTER, P.CREAM])
	frames.append(c)
	c = Canvas.new(48, 48)
	c.ellipse(24, 24, 13, 13, P.BUTTER)
	c.ellipse(24, 24, 10, 10, P.CREAM)
	frames.append(c)
	c = Canvas.new(48, 48)
	c.ellipse(24, 24, 18, 18, P.PEACH)
	c.ellipse(24, 24, 15, 15, P.BUTTER)
	c.ellipse(23, 23, 8, 8, P.CREAM)
	frames.append(c)
	var stages := [
		[7, 12.0, 7.0, FIRE, 0, 6.0],
		[7, 15.0, 6.5, [P.PLUM, P.SALMON, P.PEACH, P.BUTTER], 0, 0.0],
		[6, 16.0, 5.5, SMOKE, -2, 0.0],
		[6, 18.0, 3.5, SMOKE, -4, 0.0],
		[5, 20.0, 2.0, [P.GREY, P.GREY, P.CREAM, P.CREAM], -6, 0.0],
	]
	for st in stages:
		c = Canvas.new(48, 48)
		if st[5] > 0.0:
			c.ellipse(24, 24, st[5] + 2, st[5] + 2, P.BUTTER)
		for i in st[0]:
			var a: float = TAU * i / st[0] + rng.randf_range(-0.3, 0.3)
			var d: float = st[1] + rng.randf_range(-2.0, 2.0)
			var r: float = st[2] + rng.randf_range(-1.0, 1.0)
			c.shade_ellipse(24 + cos(a) * d, 24 + sin(a) * d + st[4], r, r, st[3], [-0.2, 0.35, 0.85])
		frames.append(c)
	return frames


## Boss-hit spark: a star burst (4 frames).
static func spark_frames() -> Array:
	var frames := []
	for f in 4:
		var c = Canvas.new(24, 24)
		var reach: int = [4, 8, 11, 11][f]
		var start: int = [0, 2, 6, 10][f]
		for k in 8:
			var a := TAU * k / 8.0
			for r in range(start, reach + 1):
				var x := 12 + int(round(cos(a) * r))
				var y := 12 + int(round(sin(a) * r))
				c.px(x, y, P.CREAM if r > reach - 2 else P.BUTTER)
		if f < 2:
			c.ellipse(12, 12, 2.5 - f, 2.5 - f, P.CREAM)
		frames.append(c)
	return frames


## Little dust puff for jumps and landings (5 frames).
static func dust_frames() -> Array:
	var frames := []
	var spread := [2.0, 3.5, 4.5, 5.5, 6.0]
	var size := [2.0, 2.5, 2.5, 1.8, 1.0]
	for f in 5:
		var c = Canvas.new(16, 8)
		for side in [-1, 1]:
			c.shade_ellipse(8 + side * spread[f], 5 - f * 0.3, size[f], size[f] * 0.8, SMOKE, [-0.3, 0.3, 0.85])
		frames.append(c)
	return frames


## Slimy splat when the little guy jumps or dashes in mid-air: a squashed teal blob bursts into
## droplets that fly out and drip down (6 frames).
static func slime_frames() -> Array:
	var frames := []
	for f in 6:
		var c = Canvas.new(28, 16)
		if f < 2:
			c.shade_ellipse(14, 8, 5.0 - f * 2.0, 2.6 - f, P.HERO)
		var d := 3.0 + f * 2.2
		var r := maxf(0.8, 2.4 - f * 0.3)
		for k in 6:
			var a := TAU * k / 6.0 + 0.3
			c.shade_ellipse(14 + cos(a) * d, 8 + sin(a) * d * 0.55 + f * 0.6, r, r, P.HERO)
		frames.append(c)
	return frames


## A gob of the little guy flying off when he splatters (a goo particle).
static func goo_blob():
	var c = Canvas.new(7, 7)
	c.shade_ellipse(3, 3, 2.8, 2.6, P.HERO, [-0.05, 0.5, 0.9])
	c.outline()
	return c


## What is left of him after a splat: a flat puddle of goo with drips running off its rim, his
## eyes crossed out (x x) and a scrap of salmon scarf in it.
static func goo_puddle():
	var c = Canvas.new(44, 11)
	c.shade_ellipse(21.5, 7, 19, 3.2, P.HERO, [-0.05, 0.62, 0.92])
	for blob in [[6, 6, 4.0, 2.2], [37, 6.5, 4.5, 2.0], [14, 5, 4.0, 2.4], [29, 5, 5.0, 2.6]]:
		c.shade_ellipse(blob[0], blob[1], blob[2], blob[3], P.HERO, [-0.05, 0.62, 0.92])
	for drop in [[2, 8], [41, 9], [11, 9], [33, 9]]:
		c.px(drop[0], drop[1], P.TEAL)
	for ex in [17, 24]:
		for p in [[0, 0], [1, 1], [2, 2], [2, 0], [0, 2]]:
			c.px(ex + p[0], 4 + p[1], P.INK)
	c.hline(29, 34, 8, P.SALMON)
	c.hline(30, 35, 9, P.ROSE)
	c.outline()
	return c


## Bigger puff ring for the player's knock-out (6 frames).
static func poof_frames() -> Array:
	var frames := []
	for f in 6:
		var c = Canvas.new(28, 28)
		var d := 3.0 + f * 1.8
		var r := maxf(0.8, 4.0 - f * 0.6)
		for k in 7:
			var a := TAU * k / 7.0 + f * 0.15
			c.shade_ellipse(14 + cos(a) * d, 14 + sin(a) * d - f * 0.5, r, r, SMOKE, [-0.3, 0.3, 0.85])
		if f < 2:
			c.ellipse(14, 14, 3 - f, 3 - f, P.CREAM)
		frames.append(c)
	return frames


## Slam ground wave travelling right (3 frames, flipped in game for the left one).
static func shockwave_frames() -> Array:
	var frames := []
	for f in 3:
		var c = Canvas.new(20, 14)
		c.shade_ellipse(13 + f * 0.5, 9, 6, 6 - f * 0.5, [P.SALMON, P.PEACH, P.BUTTER, P.CREAM], [-0.2, 0.35, 0.85])
		c.shade_ellipse(7, 11, 4, 3, [P.SALMON, P.PEACH, P.PEACH, P.CREAM], [-0.2, 0.35, 0.85])
		c.shade_ellipse(2.5 + f, 12, 2, 1.6, SMOKE, [-0.3, 0.3, 0.85])
		c.hline(0, 19, 13, P.CLEAR)
		c.outline()
		c.hline(1, 19, 13, P.INK)
		frames.append(c)
	return frames


## Marching-ants warning line where a laser is about to fire (2 frames).
static func laser_warn_frames() -> Array:
	var frames := []
	for f in 2:
		var c = Canvas.new(640, 3)
		for x in 640:
			if (x + f * 5) % 10 < 6:
				c.vline(x, 0, 2, P.SALMON)
				c.px(x, 1, P.CREAM)
		frames.append(c)
	return frames


## The head's dash tell: a beam of light as wide as the head (50 art px = 200 px) along the line
## it is about to dash: cream core, butter band, an edge that dithers out into sparkles, and
## streaks running along it (2 frames). Drawn solid; the node makes it see-through.
static func dash_beam_frames() -> Array:
	var frames := []
	for f in 2:
		var c = Canvas.new(640, 50)
		for y in 50:
			var d := absf(y - 24.5)
			for x in 640:
				if d < 10.0:
					c.px(x, y, P.CREAM)
				elif d < 18.0:
					c.px(x, y, P.CREAM if (x + f * 16) % 32 < 10 and d < 14.0 else P.BUTTER)
				elif d < 22.0 and (x + y + f) % 2 == 0:
					c.px(x, y, P.BUTTER)
				elif d < 25.0 and (x * 7 + y * 13 + f * 5) % 23 == 0:
					c.px(x, y, P.CREAM)
		frames.append(c)
	return frames


## The beam itself: hot cream core, pink edges that crackle (3 frames).
static func laser_beam_frames() -> Array:
	var frames := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for f in 3:
		var c = Canvas.new(640, 12)
		for x in 640:
			var top := 2 - rng.randi_range(0, 1)
			var bottom := 9 + rng.randi_range(0, 1)
			c.vline(x, top, bottom, P.PINK)
			c.vline(x, top + 2, bottom - 2, P.CREAM)
			if rng.randf() < 0.08:
				c.px(x, top - 1, P.PINK)
		c.glow_disc(632, 6, 6.0 + f % 2, [P.PINK, P.CREAM, P.CREAM])
		frames.append(c)
	return frames


## A dot of the throw-aim arc (it alternates big and small): ink edge, cream heart on the big one.
static func aim_dot(big: bool):
	var c = Canvas.new(4 if big else 2, 4 if big else 2)
	if big:
		c.rect(0, 0, 4, 4, P.INK)
		c.rect(1, 1, 2, 2, P.CREAM)
	else:
		c.rect(0, 0, 2, 2, P.INK)
	return c
