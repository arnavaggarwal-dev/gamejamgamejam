extends RefCounted
## Hard-edged pixel canvas over an RGBA Image. Nothing here anti-aliases: every pixel is fully on or off.

const P = preload("res://tools/art/pal.gd")
const LIGHT := Vector3(-0.55, -0.7, 0.45)  # top-left key light, shared by every shaded shape

var img: Image
var w: int
var h: int


func _init(width: int, height: int) -> void:
	w = width
	h = height
	img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


func px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		img.set_pixel(x, y, c)


func at(x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= w or y >= h:
		return P.CLEAR
	return img.get_pixel(x, y)


func solid(x: int, y: int) -> bool:
	return at(x, y).a > 0.5


func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
	for yy in range(y, y + rh):
		for xx in range(x, x + rw):
			px(xx, yy, c)


func hline(x0: int, x1: int, y: int, c: Color) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		px(x, y, c)


func vline(x: int, y0: int, y1: int, c: Color) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		px(x, y, c)


func line(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		px(x0, y0, c)
		if x0 == x1 and y0 == y1:
			return
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


func inside_ellipse(x: int, y: int, cx: float, cy: float, rx: float, ry: float) -> bool:
	var dx := (x + 0.5 - cx) / rx
	var dy := (y + 0.5 - cy) / ry
	return dx * dx + dy * dy <= 1.0


func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 1):
		for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 1):
			if inside_ellipse(x, y, cx, cy, rx, ry):
				px(x, y, c)


## Ellipse lit from the top-left: ramp[0] is the shadow, ramp[-1] the specular spot.
func shade_ellipse(cx: float, cy: float, rx: float, ry: float, ramp: Array, bands := [0.05, 0.45, 0.88]) -> void:
	var l := LIGHT.normalized()
	for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 1):
		for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 1):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			var d := nx * nx + ny * ny
			if d > 1.0:
				continue
			var lit := Vector3(nx, ny, sqrt(1.0 - d)).dot(l)
			var i := 0
			for b in bands:
				if lit > b:
					i += 1
			px(x, y, ramp[mini(i, ramp.size() - 1)])


## Radial glow: brightest at the centre (ramp[-1]) out to ramp[0] at the rim.
func glow_disc(cx: float, cy: float, r: float, ramp: Array) -> void:
	for y in range(floori(cy - r) - 1, ceili(cy + r) + 1):
		for x in range(floori(cx - r) - 1, ceili(cx + r) + 1):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length() / r
			if d > 1.0:
				continue
			var i := clampi(int((1.0 - d) * ramp.size() * 1.15), 0, ramp.size() - 1)
			px(x, y, ramp[i])


func ring(cx: float, cy: float, r: float, thickness: float, c: Color) -> void:
	for y in range(floori(cy - r) - 1, ceili(cy + r) + 1):
		for x in range(floori(cx - r) - 1, ceili(cx + r) + 1):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d <= r and d > r - thickness:
				px(x, y, c)


## Stamp an ASCII grid: '.' is transparent, every other char must be in key.
func grid(x0: int, y0: int, rows: Array, key: Dictionary) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch != ".":
				px(x0 + x, y0 + y, key[ch])


## 1-px outline around every opaque island (4-neighbour), drawn into transparent pixels only.
func outline(c := P.INK) -> void:
	var src := img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + o
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and src.get_pixel(n.x, n.y).a > 0.5:
					img.set_pixel(x, y, c)
					break


func recolor(from: Color, to: Color) -> void:
	for y in h:
		for x in w:
			if img.get_pixel(x, y).is_equal_approx(from):
				img.set_pixel(x, y, to)


func blit(other, x0: int, y0: int) -> void:
	for y in other.h:
		for x in other.w:
			var c: Color = other.img.get_pixel(x, y)
			if c.a > 0.0:
				px(x0 + x, y0 + y, c)


func flipped():
	var out = get_script().new(w, h)
	out.img = img.duplicate()
	out.img.flip_x()
	return out


static func strip(frames: Array) -> Image:
	var fw: int = frames[0].w
	var fh: int = frames[0].h
	var sheet := Image.create_empty(fw * frames.size(), fh, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		sheet.blit_rect(frames[i].img, Rect2i(0, 0, fw, fh), Vector2i(i * fw, 0))
	return sheet
