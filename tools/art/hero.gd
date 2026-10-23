extends RefCounted
## The little guy: a teal bean with a sprout and a salmon scarf.
## Frames are 20x22 art px, feet on the bottom rows, facing right, one shared rig so every frame matches.

const P = preload("res://tools/art/pal.gd")
const Canvas = preload("res://tools/art/canvas.gd")
const W := 20
const H := 22

const TAIL_HANG := [[4, 3], [3, 4], [3, 5]]
const LEAF := [
	["...MM", "..MMS", ".S...", ".S..."],
	["..MM.", ".MMS.", ".S...", ".S..."],
]


static func frame(pose: Dictionary):
	var c = Canvas.new(W, H)
	var cx := 10.0
	var cy: float = 12.0 + pose.get("bob", 0)
	var rx: float = pose.get("rx", 6.5)
	var ry: float = pose.get("ry", 6.5)
	var arms: String = pose.get("arms", "side")
	var arm_y: int = int(cy) + pose.get("arm_dy", 1)

	# Behind the body: feet, the far arm, the scarf tail.
	for f in pose.get("feet", [[6, 19], [11, 19]]):
		c.rect(f[0], f[1], 3, 1, P.SLATE)
		c.rect(f[0], f[1] + 1, 3, 1, P.NAVY)
	if arms == "side":
		c.rect(2, arm_y, 2, 2, P.NAVY)
	for t in pose.get("tail", TAIL_HANG):
		c.px(t[0], int(cy) + t[1], P.SALMON)
		c.px(t[0], int(cy) + t[1] + 1, P.ROSE)

	c.shade_ellipse(cx, cy, rx, ry, P.HERO, [-0.05, 0.74, 0.95])

	# Scarf band where the body is, knotted at the back.
	var band := int(cy) + 3
	for x in W:
		if c.solid(x, band):
			c.px(x, band, P.SALMON)
		if c.solid(x, band + 1):
			c.px(x, band + 1, P.ROSE)
	c.rect(3, band, 2, 2, P.SALMON)
	c.px(4, band + 1, P.ROSE)

	# Face, looking right.
	var ey := int(cy) - 3
	match pose.get("eyes", "open"):
		"open":
			for ex in [9, 12]:
				c.rect(ex, ey, 2, 3, P.INK)
				c.px(ex, ey, P.CREAM)
		"blink":
			for ex in [9, 12]:
				c.rect(ex, ey + 2, 2, 1, P.INK)
		"hurt":
			for p in [[9, 0], [10, 1], [9, 2], [13, 0], [12, 1], [13, 2]]:
				c.px(p[0], ey + p[1], P.INK)
	c.px(8, ey + 3, P.SALMON)
	c.px(14, ey + 3, P.SALMON)
	c.px(11, ey + 4, P.INK)

	# Near arm.
	if arms == "side":
		c.rect(16, arm_y, 2, 2, P.TEAL)
		c.px(16, arm_y, P.MINT)
	elif arms == "up":
		for ax in [4, 15]:
			c.vline(ax, 3, int(cy) - 5, P.MINT)
			c.vline(ax + 1, 3, int(cy) - 5, P.TEAL)
			c.rect(ax - 1, 1, 3, 2, P.TEAL)
			c.hline(ax - 1, ax, 1, P.MINT)

	c.grid(8, int(cy) - 10, LEAF[pose.get("leaf", 0)], {"M": P.MINT, "S": P.SAGE})
	c.outline()
	return c


static func _run_poses(arms: String) -> Array:
	return [
		{"feet": [[3, 19], [13, 19]], "arms": arms, "arm_dy": 2, "tail": [[3, 2], [1, 1], [0, 2]], "leaf": 1},
		{"bob": -1, "feet": [[8, 18], [11, 19]], "arms": arms, "arm_dy": 0, "tail": [[3, 2], [1, 3], [0, 2]]},
		{"feet": [[4, 19], [12, 19]], "arms": arms, "arm_dy": 1, "tail": [[3, 3], [1, 2], [0, 3]], "leaf": 1},
		{"bob": -1, "feet": [[9, 19], [12, 18]], "arms": arms, "arm_dy": 0, "tail": [[3, 2], [1, 1], [0, 1]]},
	]


## name -> Array of pose dictionaries (one per frame)
static func animations() -> Dictionary:
	var breathe := {"bob": 1, "rx": 7.0, "ry": 6.0, "leaf": 1}
	return {
		"idle": [{}, breathe, {}, {"eyes": "blink"}],
		"run": _run_poses("side"),
		"jump": [{"bob": -1, "rx": 5.8, "ry": 7.2, "feet": [[7, 19], [10, 19]], "arm_dy": -1, "tail": [[4, 4], [3, 6], [3, 7]]}],
		"fall": [{"rx": 7.0, "ry": 6.0, "feet": [[5, 20], [12, 20]], "arm_dy": -2, "tail": [[3, 1], [2, 0], [1, -1]], "leaf": 1}],
		"carry": [{"arms": "up"}, {"arms": "up", "bob": 1, "rx": 7.0, "ry": 6.0, "leaf": 1}],
		"carry_run": _run_poses("up"),
		"hurt": [{"eyes": "hurt", "bob": 1, "rx": 7.2, "ry": 5.8, "arm_dy": -1, "tail": [[3, 1], [1, 0], [0, -1]]}],
		"dash": [{"rx": 7.6, "ry": 5.6, "bob": 1, "feet": [[2, 18], [6, 19]], "arm_dy": 0, "tail": [[3, 1], [1, 1], [0, 1]], "leaf": 1}],
	}
