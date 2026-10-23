extends RefCounted
## The jame-gam palette, the only colors any sprite may use.

const CREAM := Color("#fcfbfc")
const GREY := Color("#d9d4d8")
const SALMON := Color("#db9692")
const PEACH := Color("#dcaf91")
const BUTTER := Color("#dbd991")
const MINT := Color("#96db91")
const SKY := Color("#92b5db")
const PERI := Color("#9196db")
const LILAC := Color("#b991dc")
const PINK := Color("#db91d3")
const CHARCOAL := Color("#514d4a")
const INK := Color("#2d2730")
const PLUM := Color("#905677")
const ROSE := Color("#9e696b")
const SAGE := Color("#6da16d")
const TEAL := Color("#009c89")
const SLATE := Color("#5d719a")
const NAVY := Color("#415e9b")
const BLUE := Color("#4f62a7")
const VIOLET := Color("#735fb1")
const CLEAR := Color(0, 0, 0, 0)

# Ramps run shadow -> highlight, hue-shifted cool in the shadows and warm in the lights.
const HERO := [NAVY, TEAL, MINT, CREAM]
const METAL := [INK, NAVY, BLUE, PERI]
const GOLD := [ROSE, PEACH, BUTTER, CREAM]
const GLOW := [SALMON, PEACH, BUTTER, CREAM]
const BOMB := [INK, CHARCOAL, SLATE, GREY]
