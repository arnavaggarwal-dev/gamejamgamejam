extends RefCounted
## The throne room. The background stays soft and outline-free so the outlined
## foreground (hero, boss, hazards) always reads on top of it.

const P = preload("res://tools/art/pal.gd")
const Canvas = preload("res://tools/art/canvas.gd")


static func background():
	var c = Canvas.new(320, 180)
	c.rect(0, 0, 320, 180, P.CREAM)
	# Quiet brick courses: grey mortar on cream, so the outlined foreground owns the contrast.
	for row in range(0, 15):
		var y := row * 8
		c.hline(0, 319, y, P.GREY)
		var shift := 8 if row % 2 else 0
		for bx in range(-shift, 320, 16):
			c.vline(bx, y, y + 7, P.GREY)
	# Lilac wainscot panels along the bottom of the wall.
	c.rect(0, 118, 320, 32, P.LILAC)
	c.hline(0, 319, 118, P.PERI)
	c.hline(0, 319, 119, P.CREAM)
	for px_ in range(20, 320, 40):
		c.vline(px_, 122, 146, P.PERI)
		c.vline(px_ + 1, 122, 146, P.CREAM)
	# A giant gear behind the king's throne spot.
	_gear(c, 262, 84, 50.0, 12)
	# Arched windows with sky and clouds.
	for wx in [30, 118]:
		_window(c, wx, 22, 36, 84)
	# Royal banners.
	for bx in [86, 168]:
		_banner(c, bx, 10, 16, 64)
	# Baseboard where the wall meets the floor.
	c.rect(0, 150, 320, 10, P.PERI)
	c.hline(0, 319, 150, P.CREAM)
	return c


static func _gear(c, cx: int, cy: int, r: float, teeth: int) -> void:
	for y in range(cy - int(r) - 8, cy + int(r) + 8):
		for x in range(cx - int(r) - 8, cx + int(r) + 8):
			var v := Vector2(x - cx, y - cy)
			var d := v.length()
			var a := fposmod(v.angle() / TAU * teeth, 1.0)
			var tooth := d > r and d <= r + 7 and a < 0.45
			if (d <= r or tooth) and d > r * 0.3:
				c.px(x, y, P.PERI if d > r * 0.85 or tooth else P.LILAC)
	c.ring(cx, cy, r * 0.3, 2, P.PERI)


static func _in_window(xx: int, yy: int, x: int, y: int, ww: int, wh: int, grow: int, c) -> bool:
	var r := ww / 2.0 + grow
	if xx < x - grow or xx >= x + ww + grow or yy >= y + wh + grow:
		return false
	return yy >= y + ww / 2.0 or c.inside_ellipse(xx, yy, x + ww / 2.0, y + ww / 2.0, r, r)


static func _window(c, x: int, y: int, ww: int, wh: int) -> void:
	for yy in range(y - 3, y + wh + 3):
		for xx in range(x - 3, x + ww + 3):
			if _in_window(xx, yy, x, y, ww, wh, 0, c):
				c.px(xx, yy, P.SKY)
			elif _in_window(xx, yy, x, y, ww, wh, 2, c):
				c.px(xx, yy, P.LILAC)
	c.ellipse(x + 10, y + 40, 7, 3, P.CREAM)
	c.ellipse(x + 17, y + 38, 6, 4, P.CREAM)
	c.ellipse(x + 26, y + 62, 6, 3, P.CREAM)
	c.vline(x + floori(ww / 2.0), y, y + wh - 1, P.LILAC)
	c.hline(x, x + ww - 1, y + 46, P.LILAC)
	c.rect(x - 4, y + wh, ww + 8, 3, P.PERI)
	c.hline(x - 4, x + ww + 3, y + wh, P.LILAC)


static func _banner(c, x: int, y: int, bw: int, bh: int) -> void:
	c.rect(x - 2, y - 2, bw + 4, 2, P.PLUM)
	for yy in range(y, y + bh):
		for xx in range(x, x + bw):
			var cut := yy > y + bh - 8 and absi(xx - (x + floori(bw / 2.0))) < (yy - (y + bh - 8))
			if not cut:
				c.px(xx, yy, P.ROSE if xx >= x + bw - 4 else P.SALMON)
	c.vline(x, y, y + bh - 9, P.PEACH)
	c.grid(x + 4, y + 16, [
		"....BB..",
		"...BB...",
		"..BBBBB.",
		"....BB..",
		"...BB...",
		"..BB....",
		"..B.....",
	], {"B": P.BUTTER})


## Arena floor: warm stone tiles with a lit lip; collision top is row 0.
static func floor_strip():
	var c = Canvas.new(350, 20)
	for y in range(1, 20):
		for x in 350:
			var tile := (floori(x / 10.0) + floori((y - 3) / 8.0)) % 2 == 0
			c.px(x, y, P.ROSE if tile else P.PLUM)
	for x in range(0, 350, 10):
		c.vline(x, 4, 19, P.INK)
		c.px(x + 1, 4, P.PEACH)
	for y in [11, 19]:
		c.hline(0, 349, y, P.INK)
	c.hline(0, 349, 0, P.INK)
	c.hline(0, 349, 1, P.PEACH)
	c.hline(0, 349, 2, P.PEACH)
	c.hline(0, 349, 3, P.ROSE)
	return c


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
