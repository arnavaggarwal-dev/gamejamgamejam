extends RefCounted
## HUD pieces and "Kilowatt", the 5x7 pixel font (baked 1-px ink outline, white fill so Labels can tint it).

const P = preload("res://tools/art/pal.gd")
const Canvas = preload("res://tools/art/canvas.gd")

const GLYPHS := {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
	"!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
	".": [".....", ".....", ".....", ".....", ".....", ".....", "..#.."],
	",": [".....", ".....", ".....", ".....", ".....", "..#..", ".#..."],
	":": [".....", "..#..", ".....", ".....", ".....", "..#..", "....."],
	"-": [".....", ".....", ".....", ".###.", ".....", ".....", "....."],
	"+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
	"/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
	"'": ["..#..", "..#..", ".....", ".....", ".....", ".....", "....."],
	"(": ["...#.", "..#..", ".#...", ".#...", ".#...", "..#..", "...#."],
	")": [".#...", "..#..", "...#.", "...#.", "...#.", "..#..", ".#..."],
	"[": [".###.", ".#...", ".#...", ".#...", ".#...", ".#...", ".###."],
	"]": [".###.", "...#.", "...#.", "...#.", "...#.", "...#.", ".###."],
	"&": [".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#"],
	"%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
	"=": [".....", ".....", "#####", ".....", "#####", ".....", "....."],
	">": [".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#..."],
	"<": ["...#.", "..#..", ".#...", "#....", ".#...", "..#..", "...#."],
}
const CELL := Vector2i(8, 10)  # 7x9 glyph (5x7 + outline) plus 1 px padding
const COLS := 16
const ADVANCE := 6


## Returns [atlas Image, .fnt text]. Lowercase letters reuse the uppercase glyphs.
static func font(png_name: String) -> Array:
	var keys := GLYPHS.keys()
	var rows := ceili(keys.size() / float(COLS))
	var atlas := Image.create_empty(COLS * CELL.x, rows * CELL.y, false, Image.FORMAT_RGBA8)
	var chars := []
	for i in keys.size():
		var ch: String = keys[i]
		var g = Canvas.new(7, 9)
		g.grid(1, 1, GLYPHS[ch], {"#": Color.WHITE})
		g.outline(P.INK)
		var cell := Vector2i(i % COLS, floori(i / float(COLS))) * CELL
		atlas.blit_rect(g.img, Rect2i(0, 0, 7, 9), cell)
		chars.append([ch.unicode_at(0), cell])
		if ch >= "A" and ch <= "Z":
			chars.append([ch.to_lower().unicode_at(0), cell])
	var lines := PackedStringArray([
		'info face="Kilowatt" size=9 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0',
		"common lineHeight=11 base=9 scaleW=%d scaleH=%d pages=1 packed=0" % [atlas.get_width(), atlas.get_height()],
		'page id=0 file="%s"' % png_name,
		"chars count=%d" % (chars.size() + 1),
		"char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=4 page=0 chnl=15",
	])
	for c in chars:
		lines.append("char id=%d x=%d y=%d width=7 height=9 xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15" % [c[0], c[1].x, c[1].y, ADVANCE])
	return [atlas, "\n".join(lines) + "\n"]


static func heart(full: bool):
	var c = Canvas.new(11, 10)
	var rows := [
		".##...##.",
		"####.####",
		"#########",
		"#########",
		".#######.",
		"..#####..",
		"...###...",
		"....#....",
	]
	c.grid(1, 1, rows, {"#": P.SALMON if full else P.CHARCOAL})
	if full:
		c.px(2, 2, P.CREAM)
		c.px(3, 2, P.CREAM)
		c.px(2, 3, P.CREAM)
		for p in [[7, 6], [6, 7], [8, 5], [9, 4], [9, 3]]:
			c.px(p[0], p[1], P.ROSE)
	c.outline()
	return c


## One bomb of ammo on the HUD (empty: a dim outline of one).
static func bomb_icon(full: bool):
	var c = Canvas.new(11, 12)
	if full:
		c.shade_ellipse(5, 7, 4, 4, P.BOMB, [-0.3, 0.3, 0.8])
		c.px(3, 5, P.GREY)
		c.rect(5, 1, 2, 2, P.CHARCOAL)
		c.px(7, 0, P.BUTTER)
		c.px(8, 1, P.PEACH)
	else:
		c.ellipse(5, 7, 4, 4, P.CHARCOAL)
		c.ellipse(5, 7, 2.5, 2.5, P.INK)
		c.rect(5, 1, 2, 2, P.CHARCOAL)
	c.outline()
	return c


## Key cap prompt ("J" by default) shown over a bomb in reach.
## A keycap: a cream top over a grey lip, ink outline, its label (letters or an arrow) in ink.
## Wider for words (ENTER, ESC).
static func key_cap(label: String):
	var glyphs: Array = [ARROWS[label]] if ARROWS.has(label) else Array(label.split("")).map(func(ch: String) -> Array: return GLYPHS[ch])
	var c = Canvas.new(glyphs.size() * 6 + 5, 12)
	c.rect(1, 1, glyphs.size() * 6 + 3, 10, P.GREY)
	c.rect(1, 1, glyphs.size() * 6 + 3, 8, P.CREAM)
	for k in glyphs.size():
		c.grid(3 + k * 6, 2, glyphs[k], {"#": P.INK})
	c.outline()
	return c


## The arrow keys as they sit on a keyboard: up over left, down, right.
static func arrow_keys():
	var c = Canvas.new(35, 25)
	c.blit(key_cap("UP"), 12, 0)
	for k in 3:
		c.blit(key_cap(["LEFT", "DOWN", "RIGHT"][k]), k * 12, 13)
	return c


const ARROWS := {
	"LEFT": [".....", "..#..", ".#...", "#####", ".#...", "..#..", "....."],
	"RIGHT": [".....", "..#..", "...#.", "#####", "...#.", "..#..", "....."],
	"UP": ["..#..", ".###.", "#.#.#", "..#..", "..#..", "..#..", "....."],
	"DOWN": ["..#..", "..#..", "..#..", "#.#.#", ".###.", "..#..", "....."],
}
