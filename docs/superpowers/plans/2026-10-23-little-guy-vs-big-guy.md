# Little Guy vs. Big Guy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A 2-day jam game for the theme "I'm just a little guy": a tiny hero fights one giant robot king (King Kilowatt) across 3 phases by throwing the boss's own bombs back at his core.

**Architecture:** One 2D arena scene (`game.tscn`) instances a Player, a Boss, a HUD and a film filter. The Boss is a cut-out puppet: a small enum state machine in `boss.gd` picks attacks from a fixed per-phase cycle, and every attack is an AnimationPlayer animation whose value tracks move the rig and toggle hitboxes and whose method tracks call `aim_slam` / `slam_impact` / `spawn_bomb` / `laser_fire` / `shake`. Children signal up, parents call down, `game.gd` wires everything; no EventBus, no autoloads.

**Tech Stack:** Godot 4.7.1 (GL Compatibility), GDScript, headless SceneTree test script, Web export for itch.io.

**Decision record:** `docs/decisions/2026-10-23-little-guy-vs-big-guy.md`

## Global Constraints

- Godot 4.7.1, renderer `gl_compatibility`, GDScript only.
- All nodes authored in `.tscn` files. Never `Node.new()` in code. Instancing authored scenes with `PackedScene.instantiate()` is fine.
- Base resolution 1280x720, stretch mode `canvas_items`, aspect `keep`. Floor top is at y = 640.
- Colors come only from the jame-gam palette (table below). Boss = dark row, arena = pastels, hero = teal, warnings = salmon.
- Original characters only. No Nintendo names, sprites or look-alikes.
- No em dashes in any in-game text.
- Commit messages are the user's alone: never add `Co-Authored-By` or any AI attribution line.
- All work stays inside the project folder `C:\Users\ARNAVAGGARWAL\Documents\jamegamgamejam`. Never write outputs to AppData or a scratchpad.
- Never launch a windowed Godot run yourself (it steals the iGPU from the user's playtest). Tests run `--headless` only. Every "playtest" step is done by the user pressing F5 in the editor.
- Physics layers (bit values in brackets): 1 world [1], 2 player [2], 3 bomb [4], 4 hurts_player [8], 5 boss_weakpoint [16].

**Godot executable** (the folder really is named `...win64.exe`):

```bash
GODOT="/c/Users/ARNAVAGGARWAL/Downloads/Utility apps/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
```

**Test commands** (run from the project folder; `--import` refreshes the `class_name` cache and must run after adding any new script):

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s tests/test_logic.gd
```

Exit code 0 and a final line `0 failure(s)` means pass. Exit code 1 = a `FAIL` line or any engine/script error (the runner counts them through a `Logger` and prints `N engine/script error(s) during tests`; scroll up for the `ERROR` / `SCRIPT ERROR`). Exit code 2 with `TIMEOUT` = the run hung. Lines like `ObjectDB instances leaked at exit` after the final line are harmless.

**Palette** (use these exact `Color()` values in `.tscn` files):

| Name | Hex | Color() |
|---|---|---|
| cream | #fcfbfc | 0.988, 0.984, 0.988 |
| grey | #d9d4d8 | 0.851, 0.831, 0.847 |
| salmon | #db9692 | 0.859, 0.588, 0.573 |
| peach | #dcaf91 | 0.863, 0.686, 0.569 |
| butter | #dbd991 | 0.859, 0.851, 0.569 |
| mint | #96db91 | 0.588, 0.859, 0.569 |
| sky | #92b5db | 0.573, 0.71, 0.859 |
| periwinkle | #9196db | 0.569, 0.588, 0.859 |
| lilac | #b991dc | 0.725, 0.569, 0.863 |
| pink | #db91d3 | 0.859, 0.569, 0.827 |
| charcoal | #514d4a | 0.318, 0.302, 0.29 |
| ink | #2d2730 | 0.176, 0.153, 0.188 |
| plum | #905677 | 0.565, 0.337, 0.467 |
| rose | #9e696b | 0.62, 0.412, 0.42 |
| sage | #6da16d | 0.427, 0.631, 0.427 |
| teal | #009c89 | 0, 0.612, 0.537 |
| slate | #5d719a | 0.365, 0.443, 0.604 |
| navy | #415e9b | 0.255, 0.369, 0.608 |
| blue | #4f62a7 | 0.31, 0.384, 0.655 |
| violet | #735fb1 | 0.451, 0.373, 0.694 |

**Placeholder art:** until the user's drawings arrive, every `Sprite2D` uses a `GradientTexture2D` sub-resource. Rectangles use a 2-stop solid gradient. Ellipses use `fill = 1` (radial) with stops `0, 0.94, 1` fading to transparent. Task 9 swaps them for PNGs without touching code.

---

## Schedule

| When | Claude (code) | User (art and sound) |
|---|---|---|
| Day 1 morning | Tasks 1-3: setup, bomb, player | Draw hero poses |
| Day 1 afternoon | Tasks 4-6: arena, boss phase 1, HUD. **Milestone: full fight playable with placeholders** | Draw boss parts; playtest at milestone |
| Day 2 morning | Tasks 7-8: laser + platform break, film filter + title | Draw bomb, shockwave, background, floor, platform, heart |
| Day 2 afternoon | Tasks 9-11: art swap, audio, web export | Make SFX in jsfxr, pick music, upload to itch |

**Cut order if late:** Task 10 music, then the phase-3 platform break (Task 7 Steps 5-6 plus the last check in `_test_phase_extras`), then the title screen (Task 8 Steps 5-7, keeping the main scene on `game.tscn`).

## File structure

```
project.godot                      settings, input map, layer names
export_presets.cfg                 Web preset (Task 11)
assets/shaders/boil.gdshader       line-boil wobble for drawn sprites
assets/shaders/boil_material.tres  shared ShaderMaterial using boil
assets/shaders/film_filter.gdshader  full-screen old-cartoon filter
assets/art/...                     user PNGs (Task 9)
assets/sfx/..., assets/music/...   user audio (Task 10)
scenes/game.tscn + game.gd         arena root, wiring, restarts
scenes/camera.gd                   fixed camera: shake + hitstop
scenes/title.tscn + title.gd       title screen
scenes/fx/film_filter.tscn         CanvasLayer + ColorRect with filter
scenes/player/player.tscn + .gd    the little guy
scenes/boss/boss.tscn + boss.gd    King Kilowatt puppet + attack logic
scenes/boss/bomb.tscn + bomb.gd    throwable bomb
scenes/boss/shockwave.tscn + .gd   slam ground wave
scenes/ui/hud.tscn + hud.gd        hearts, boss bar, banner, end panel
tests/test_logic.gd                headless checks
```

---

### Task 1: Project setup, shaders and test runner

Skills: `godot-prompter:godot-project-setup`, `godot-prompter:input-handling`, `godot-prompter:shader-basics`, `godot-prompter:godot-testing`

**Files:**
- Modify: `project.godot` (full rewrite)
- Modify: `.gitignore`
- Create: `assets/shaders/boil.gdshader`
- Create: `assets/shaders/boil_material.tres`
- Create: `tests/test_logic.gd`

**Interfaces:**
- Produces: input actions `move_left`, `move_right`, `jump`, `grab`, `aim_up`; material `res://assets/shaders/boil_material.tres`; test helpers `check(ok: bool, what: String)` and `_run()` in `tests/test_logic.gd`.

- [ ] **Step 1: Initialise a git repo for the project**

The project currently sits untracked inside the home-folder repo. Give it its own:

```bash
cd "/c/Users/ARNAVAGGARWAL/Documents/jamegamgamejam"
git init
git branch -M main
```

- [ ] **Step 2: Rewrite `project.godot`**

```ini
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=5

[application]

config/name="Little Guy vs Big Guy"
config/features=PackedStringArray("4.7", "GL Compatibility")
config/icon="res://icon.svg"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[input]

move_left={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":0,"axis_value":-1.0,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":13,"pressure":0.0,"pressed":true,"script":null)
]
}
move_right={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":0,"axis_value":1.0,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":14,"pressure":0.0,"pressed":true,"script":null)
]
}
jump={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":90,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":0,"pressure":0.0,"pressed":true,"script":null)
]
}
grab={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":74,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":88,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":2,"pressure":0.0,"pressed":true,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":1,"pressure":0.0,"pressed":true,"script":null)
]
}
aim_up={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194320,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":1,"axis_value":-1.0,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":11,"pressure":0.0,"pressed":true,"script":null)
]
}

[layer_names]

2d_physics/layer_1="world"
2d_physics/layer_2="player"
2d_physics/layer_3="bomb"
2d_physics/layer_4="hurts_player"
2d_physics/layer_5="boss_weakpoint"

[physics]

3d/physics_engine="Jolt Physics"

[rendering]

rendering_device/driver.windows="d3d12"
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

Controls: A/D or arrows move, Space or Z jump, J or X grab/throw, hold W or Up while throwing to lob. Gamepad: stick or d-pad move, A jump, X or B grab/throw, stick-up or d-pad-up to lob.

- [ ] **Step 3: Ignore build output**

Append these lines to `.gitignore` and create an empty `build/.gdignore`, so git ignores the export output but keeps the marker that stops Godot importing (and re-packing) anything in `build/`:

```
/build/*
!/build/.gdignore
```

- [ ] **Step 4: Create `assets/shaders/boil.gdshader`**

```glsl
shader_type canvas_item;

// Rubber-hose "line boil": UVs wobble in steps of `fps`, so still drawings look hand-animated.
uniform float fps = 12.0;
uniform float strength = 1.5; // wobble size in texture pixels
uniform float noise_scale = 0.05;

varying vec4 vertex_color;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	vertex_color = COLOR;
}

void fragment() {
	float t = floor(TIME * fps);
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	vec2 wobble = vec2(noise(px * noise_scale + t * 7.13), noise(px * noise_scale + t * 3.71 + 17.0)) - 0.5;
	COLOR = texture(TEXTURE, UV + wobble * 2.0 * strength * TEXTURE_PIXEL_SIZE) * vertex_color;
}
```

- [ ] **Step 5: Create `assets/shaders/boil_material.tres`**

```
[gd_resource type="ShaderMaterial" format=3]

[ext_resource type="Shader" path="res://assets/shaders/boil.gdshader" id="1_boil"]

[resource]
shader = ExtResource("1_boil")
shader_parameter/fps = 12.0
shader_parameter/strength = 1.5
shader_parameter/noise_scale = 0.05
```

- [ ] **Step 6: Create `tests/test_logic.gd`**

```gdscript
extends SceneTree
## Headless logic checks. Run from the project folder:
##   "$GODOT" --headless --path . --import
##   "$GODOT" --headless --path . -s tests/test_logic.gd
## Exit code 0 = all passed.

var failures := 0


func _initialize() -> void:
	# A runtime error inside a test stops _run before quit(); the watchdog ends the process instead of hanging.
	create_timer(20.0, true, false, true).timeout.connect(_on_timeout)
	_run.call_deferred()


func _run() -> void:
	print("%d failure(s)" % failures)
	quit(1 if failures else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS  ", what)
	else:
		failures += 1
		printerr("FAIL  ", what)


func _on_timeout() -> void:
	printerr("TIMEOUT: a test crashed or hung")
	quit(2)
```

- [ ] **Step 7: Run the empty test suite**

Run the two test commands from the header.
Expected: last line `0 failure(s)`, exit code 0, no `ERROR:` lines from `project.godot` parsing.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "chore: project setup, input map, boil shader, test runner"
```

---

### Task 2: Bomb

Skills: `godot-prompter:physics-system`, `godot-prompter:particles-vfx`, `godot-prompter:animation-system`

**Files:**
- Create: `scenes/boss/bomb.gd`
- Create: `scenes/boss/bomb.tscn`
- Modify: `tests/test_logic.gd`

**Interfaces:**
- Consumes: `res://assets/shaders/boil_material.tres` (Task 1).
- Produces: `class_name Bomb extends RigidBody2D` with `const LAYER_BOMB := 4`, `var thrown: bool`, `var exploded: bool`, `func pick_up() -> void`, `func throw(v: Vector2) -> void`, `func explode() -> void`. Calls `get_tree().call_group("camera", "shake", amount)` (camera arrives in Task 4; with no camera it is a no-op).

- [ ] **Step 1: Write the failing test**

In `tests/test_logic.gd`, change `_run()` to:

```gdscript
func _run() -> void:
	_test_bomb()
	print("%d failure(s)" % failures)
	quit(1 if failures else 0)
```

and add below `check()`:

```gdscript
func _test_bomb() -> void:
	var bomb: Bomb = load("res://scenes/boss/bomb.tscn").instantiate()
	root.add_child(bomb)
	bomb.pick_up()
	check(bomb.freeze and bomb.collision_layer == 0, "picked-up bomb is frozen and ghosted")
	bomb.throw(Vector2(100, -100))
	check(bomb.thrown and not bomb.freeze and bomb.collision_layer == Bomb.LAYER_BOMB, "thrown bomb is live")
	bomb.explode()
	bomb.explode()
	check(bomb.exploded, "explode is safe to call twice")
```

- [ ] **Step 2: Run test to verify it fails**

Run the test commands. Expected: parse error mentioning `Bomb` (type not found), non-zero exit code.

- [ ] **Step 3: Create `scenes/boss/bomb.gd`**

```gdscript
class_name Bomb
extends RigidBody2D
## Lobbed by the boss. The player picks it up and throws it back at the boss's core.

const LAYER_BOMB := 4  # physics layer 3 "bomb"

var thrown := false
var exploded := false

@onready var art: Node2D = $Art
@onready var blast_shape: CollisionShape2D = $BlastArea/CollisionShape2D
@onready var particles: CPUParticles2D = $CPUParticles2D


func _ready() -> void:
	$FuseTimer.timeout.connect(explode)
	$AnimationPlayer.play(&"fuse")


func pick_up() -> void:
	freeze = true
	collision_layer = 0


func throw(v: Vector2) -> void:
	freeze = false
	collision_layer = LAYER_BOMB
	linear_velocity = v
	thrown = true


func explode() -> void:
	if exploded:
		return
	exploded = true
	set_deferred("freeze", true)
	art.hide()
	blast_shape.set_deferred("disabled", false)
	particles.emitting = true
	get_tree().call_group("camera", "shake", 10.0)
	await get_tree().create_timer(0.15).timeout
	blast_shape.set_deferred("disabled", true)
	await get_tree().create_timer(0.6).timeout
	queue_free()
```

- [ ] **Step 4: Create `scenes/boss/bomb.tscn`**

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/boss/bomb.gd" id="1_bomb"]
[ext_resource type="Material" path="res://assets/shaders/boil_material.tres" id="2_boil"]

[sub_resource type="PhysicsMaterial" id="PhysicsMaterial_bounce"]
friction = 0.8
bounce = 0.3

[sub_resource type="CircleShape2D" id="CircleShape2D_body"]
radius = 20.0

[sub_resource type="CircleShape2D" id="CircleShape2D_blast"]
radius = 90.0

[sub_resource type="Gradient" id="Gradient_bomb"]
offsets = PackedFloat32Array(0, 0.94, 1)
colors = PackedColorArray(0.176, 0.153, 0.188, 1, 0.176, 0.153, 0.188, 1, 0.176, 0.153, 0.188, 0)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_bomb"]
gradient = SubResource("Gradient_bomb")
width = 44
height = 44
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(1, 0.5)

[sub_resource type="Gradient" id="Gradient_spark"]
offsets = PackedFloat32Array(0, 0.94, 1)
colors = PackedColorArray(0.859, 0.851, 0.569, 1, 0.859, 0.851, 0.569, 1, 0.859, 0.851, 0.569, 0)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_spark"]
gradient = SubResource("Gradient_spark")
width = 12
height = 12
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(1, 0.5)

[sub_resource type="Animation" id="Animation_fuse"]
resource_name = "fuse"
length = 3.0
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Art:modulate")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0, 1, 1.1, 1.8, 1.9, 2.3, 2.4, 2.6, 2.7, 2.8, 2.9, 2.95),
"transitions": PackedFloat32Array(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1),
"update": 1,
"values": [Color(1, 1, 1, 1), Color(5, 5, 5, 1), Color(1, 1, 1, 1), Color(5, 5, 5, 1), Color(1, 1, 1, 1), Color(5, 5, 5, 1), Color(1, 1, 1, 1), Color(5, 5, 5, 1), Color(1, 1, 1, 1), Color(5, 5, 5, 1), Color(1, 1, 1, 1), Color(5, 5, 5, 1)]
}

[sub_resource type="AnimationLibrary" id="AnimationLibrary_bomb"]
_data = {
&"fuse": SubResource("Animation_fuse")
}

[node name="Bomb" type="RigidBody2D"]
collision_layer = 4
physics_material_override = SubResource("PhysicsMaterial_bounce")
gravity_scale = 1.5
freeze_mode = 1
script = ExtResource("1_bomb")

[node name="Art" type="Node2D" parent="."]

[node name="Body" type="Sprite2D" parent="Art"]
material = ExtResource("2_boil")
texture = SubResource("GradientTexture2D_bomb")

[node name="Spark" type="Sprite2D" parent="Art"]
position = Vector2(8, -24)
texture = SubResource("GradientTexture2D_spark")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_body")

[node name="FuseTimer" type="Timer" parent="."]
wait_time = 3.0
one_shot = true
autostart = true

[node name="BlastArea" type="Area2D" parent="."]
collision_layer = 8
collision_mask = 0
monitoring = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="BlastArea"]
shape = SubResource("CircleShape2D_blast")
disabled = true

[node name="CPUParticles2D" type="CPUParticles2D" parent="."]
emitting = false
amount = 24
lifetime = 0.5
one_shot = true
explosiveness = 1.0
spread = 180.0
gravity = Vector2(0, 0)
initial_velocity_min = 120.0
initial_velocity_max = 320.0
scale_amount_min = 6.0
scale_amount_max = 12.0
color = Color(0.859, 0.588, 0.573, 1)

[node name="AnimationPlayer" type="AnimationPlayer" parent="."]
libraries = {
&"": SubResource("AnimationLibrary_bomb")
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run the test commands. Expected: 3 `PASS` lines, `0 failure(s)`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add scenes/boss/bomb.gd scenes/boss/bomb.tscn tests/test_logic.gd
git commit -m "feat: throwable bomb with fuse, blast and particles"
```

---

### Task 3: Player

Skills: `godot-prompter:player-controller`, `godot-prompter:input-handling`, `godot-prompter:tween-animation`, `godot-prompter:2d-essentials`

**Files:**
- Create: `scenes/player/player.gd`
- Create: `scenes/player/player.tscn`
- Modify: `tests/test_logic.gd`

**Interfaces:**
- Consumes: `Bomb.pick_up()`, `Bomb.throw(v)`, `Bomb.exploded` (Task 2); input actions (Task 1).
- Produces: `class_name Player extends CharacterBody2D` in group `"player"` with `signal hp_changed(hp: int)`, `signal died`, `const MAX_HP := 3`, `var hp: int`, `var held_bomb: Bomb`, `var invuln: Timer` (onready), `func take_hit() -> void`, `func reset(at: Vector2) -> void`. Origin is the body centre; standing on the floor means `y = 598`. Exports `throw_velocity` and `lob_velocity` are the main tuning knobs.

- [ ] **Step 1: Write the failing test**

In `tests/test_logic.gd`, change `_run()` to:

```gdscript
func _run() -> void:
	_test_bomb()
	await _test_player()
	print("%d failure(s)" % failures)
	quit(1 if failures else 0)
```

and add:

```gdscript
func _test_player() -> void:
	var player: Player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	var died := [false]
	player.died.connect(func() -> void: died[0] = true)
	player.take_hit()
	check(player.hp == 2, "a hit costs one heart")
	player.take_hit()
	check(player.hp == 2, "invulnerable right after a hit")
	player.invuln.stop()
	player.take_hit()
	player.invuln.stop()
	player.take_hit()
	check(player.hp == 0 and died[0], "losing the last heart emits died")
	player.reset(Vector2(100, 100))
	check(player.hp == Player.MAX_HP and player.visible, "reset refills hearts and shows the player")
	player.queue_free()
	await process_frame
```

- [ ] **Step 2: Run test to verify it fails**

Run the test commands. Expected: parse error mentioning `Player`, non-zero exit.

- [ ] **Step 3: Create `scenes/player/player.gd`**

```gdscript
class_name Player
extends CharacterBody2D
## The little guy: runs, jumps, carries and throws the boss's bombs.

signal hp_changed(hp: int)
signal died

const MAX_HP := 3
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12

@export var speed := 330.0
@export var accel := 2600.0
@export var gravity := 1800.0
@export var jump_velocity := -640.0
@export var throw_velocity := Vector2(620, -760)  # tune in the Task 6 playtest
@export var lob_velocity := Vector2(300, -900)  # used while aim_up is held

var hp := MAX_HP
var facing := 1
var held_bomb: Bomb = null
var _coyote := 0.0
var _jump_buffer := 0.0
var _was_on_floor := true
var _dead := false

@onready var art: Node2D = $Art
@onready var flip: Node2D = $Art/Flip
@onready var body: AnimatedSprite2D = $Art/Flip/Body
@onready var hold_point: Marker2D = $HoldPoint
@onready var pickup_area: Area2D = $PickupArea
@onready var hurtbox: Area2D = $Hurtbox
@onready var invuln: Timer = $InvulnTimer
@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	add_to_group("player")
	hurtbox.area_entered.connect(func(_area: Area2D) -> void: take_hit())
	invuln.timeout.connect(_on_invuln_timeout)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, dir * speed, accel * delta)
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
		flip.scale.x = facing

	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote -= delta
		velocity.y += gravity * delta

	_jump_buffer = JUMP_BUFFER if Input.is_action_just_pressed("jump") else _jump_buffer - delta
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		_squash(Vector2(0.75, 1.25))
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5

	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_squash(Vector2(1.3, 0.75))
	_was_on_floor = is_on_floor()

	if not is_instance_valid(held_bomb) or held_bomb.exploded:
		held_bomb = null
	if Input.is_action_just_pressed("grab"):
		if held_bomb:
			_throw()
		else:
			_grab()
	if held_bomb:
		held_bomb.global_position = hold_point.global_position
	_update_pose(dir)


func take_hit() -> void:
	if _dead or not invuln.is_stopped():
		return
	hp -= 1
	hp_changed.emit(hp)
	get_tree().call_group("camera", "shake", 8.0)
	if hp <= 0:
		_die()
		return
	invuln.start()
	anim.play(&"hurt")
	velocity = Vector2(-facing * 260.0, -380.0)


func reset(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	hp = MAX_HP
	held_bomb = null
	_dead = false
	invuln.stop()
	show()
	hp_changed.emit(hp)


func _die() -> void:
	_dead = true
	if is_instance_valid(held_bomb):
		held_bomb.queue_free()
	held_bomb = null
	hide()
	died.emit()


func _grab() -> void:
	var best: Bomb = null
	for overlap in pickup_area.get_overlapping_bodies():
		var bomb := overlap as Bomb
		if bomb == null or bomb.exploded:
			continue
		if best == null or global_position.distance_to(bomb.global_position) < global_position.distance_to(best.global_position):
			best = bomb
	if best:
		best.pick_up()
		held_bomb = best


func _throw() -> void:
	var v := lob_velocity if Input.is_action_pressed("aim_up") else throw_velocity
	held_bomb.throw(Vector2(v.x * facing, v.y))
	held_bomb = null


func _on_invuln_timeout() -> void:
	if hurtbox.has_overlapping_areas():
		take_hit()


func _squash(s: Vector2) -> void:
	art.scale = s
	create_tween().tween_property(art, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_pose(dir: float) -> void:
	var pose := &"idle"
	if held_bomb:
		pose = &"carry"
	elif not is_on_floor():
		pose = &"jump"
	elif dir != 0.0:
		pose = &"run"
	if body.animation != pose:
		body.play(pose)
```

- [ ] **Step 4: Create `scenes/player/player.tscn`**

`Art` sits at the feet so squash and stretch pivots on the ground. `Flip` only mirrors. Every pose uses the same teal placeholder until Task 9.

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/player/player.gd" id="1_player"]
[ext_resource type="Material" path="res://assets/shaders/boil_material.tres" id="2_boil"]

[sub_resource type="Gradient" id="Gradient_body"]
offsets = PackedFloat32Array(0, 0.94, 1)
colors = PackedColorArray(0, 0.612, 0.537, 1, 0, 0.612, 0.537, 1, 0, 0.612, 0.537, 0)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_body"]
gradient = SubResource("Gradient_body")
width = 60
height = 84
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(1, 0.5)

[sub_resource type="SpriteFrames" id="SpriteFrames_body"]
animations = [{
"frames": [{
"duration": 1.0,
"texture": SubResource("GradientTexture2D_body")
}],
"loop": true,
"name": &"carry",
"speed": 8.0
}, {
"frames": [{
"duration": 1.0,
"texture": SubResource("GradientTexture2D_body")
}],
"loop": true,
"name": &"idle",
"speed": 8.0
}, {
"frames": [{
"duration": 1.0,
"texture": SubResource("GradientTexture2D_body")
}],
"loop": true,
"name": &"jump",
"speed": 8.0
}, {
"frames": [{
"duration": 1.0,
"texture": SubResource("GradientTexture2D_body")
}],
"loop": true,
"name": &"run",
"speed": 8.0
}]

[sub_resource type="CapsuleShape2D" id="CapsuleShape2D_body"]
radius = 22.0
height = 84.0

[sub_resource type="CircleShape2D" id="CircleShape2D_pickup"]
radius = 56.0

[sub_resource type="CapsuleShape2D" id="CapsuleShape2D_hurt"]
radius = 16.0
height = 70.0

[sub_resource type="Animation" id="Animation_hurt"]
resource_name = "hurt"
length = 1.0
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Art:modulate")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1),
"transitions": PackedFloat32Array(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1),
"update": 1,
"values": [Color(1, 1, 1, 0.25), Color(1, 1, 1, 1), Color(1, 1, 1, 0.25), Color(1, 1, 1, 1), Color(1, 1, 1, 0.25), Color(1, 1, 1, 1), Color(1, 1, 1, 0.25), Color(1, 1, 1, 1), Color(1, 1, 1, 0.25), Color(1, 1, 1, 1), Color(1, 1, 1, 1)]
}

[sub_resource type="AnimationLibrary" id="AnimationLibrary_player"]
_data = {
&"hurt": SubResource("Animation_hurt")
}

[node name="Player" type="CharacterBody2D"]
collision_layer = 2
script = ExtResource("1_player")

[node name="Art" type="Node2D" parent="."]
position = Vector2(0, 42)

[node name="Flip" type="Node2D" parent="Art"]

[node name="Body" type="AnimatedSprite2D" parent="Art/Flip"]
material = ExtResource("2_boil")
position = Vector2(0, -42)
sprite_frames = SubResource("SpriteFrames_body")
animation = &"idle"

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CapsuleShape2D_body")

[node name="HoldPoint" type="Marker2D" parent="."]
position = Vector2(0, -78)

[node name="PickupArea" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 4
monitorable = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="PickupArea"]
shape = SubResource("CircleShape2D_pickup")

[node name="Hurtbox" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 8
monitorable = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="Hurtbox"]
shape = SubResource("CapsuleShape2D_hurt")

[node name="InvulnTimer" type="Timer" parent="."]
one_shot = true

[node name="AnimationPlayer" type="AnimationPlayer" parent="."]
libraries = {
&"": SubResource("AnimationLibrary_player")
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run the test commands. Expected: 7 `PASS` lines, `0 failure(s)`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add scenes/player tests/test_logic.gd
git commit -m "feat: player movement, hearts, grab and throw"
```

---

### Task 4: Arena, camera and game scene

Skills: `godot-prompter:scene-organization`, `godot-prompter:camera-system`, `godot-prompter:2d-essentials`

**Files:**
- Create: `scenes/camera.gd`
- Create: `scenes/game.gd`
- Create: `scenes/game.tscn`
- Modify: `project.godot` (main scene)
- Modify: `tests/test_logic.gd`

**Interfaces:**
- Consumes: `Player` (Task 3).
- Produces: Camera2D in group `"camera"` with `func shake(amount: float) -> void` and `func hitstop(seconds: float) -> void`; `game.tscn` nodes `Background`, `Arena/Floor`, `Arena/WallL`, `Arena/WallR`, `Arena/PlatformL` (220, 480), `Arena/PlatformM` (540, 400), `Arena/PlatformR` (820, 480), `Projectiles`, `Player`, `RespawnPoint` (200, 598), `Camera2D`.

- [ ] **Step 1: Write the failing test**

In `tests/test_logic.gd`, add `await _test_arena()` after `await _test_player()` in `_run()`, and add:

```gdscript
func _test_arena() -> void:
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	var player: Player = game.get_node("Player")
	for i in 60:
		await physics_frame
	check(player.is_on_floor(), "player stands on the arena floor")
	game.queue_free()
	await process_frame
```

- [ ] **Step 2: Run test to verify it fails**

Run the test commands. Expected: error loading `res://scenes/game.tscn`, then `TIMEOUT` after 20 s, exit code 2.

- [ ] **Step 3: Create `scenes/camera.gd`**

```gdscript
extends Camera2D
## Fixed arena camera. Anything can call:
##   get_tree().call_group("camera", "shake", amount)
##   get_tree().call_group("camera", "hitstop", seconds)

var _trauma := 0.0


func _ready() -> void:
	add_to_group("camera")


func shake(amount: float) -> void:
	_trauma = maxf(_trauma, amount)


func hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	_trauma = move_toward(_trauma, 0.0, 60.0 * delta)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _trauma
```

- [ ] **Step 4: Create `scenes/game.gd`**

```gdscript
extends Node2D
## Arena root: wires player, boss and HUD together and handles restarts.

@onready var player: Player = $Player
@onready var projectiles: Node2D = $Projectiles
@onready var respawn: Marker2D = $RespawnPoint


func _ready() -> void:
	player.died.connect(_on_player_died)


func _on_player_died() -> void:
	await get_tree().create_timer(1.0).timeout
	for child in projectiles.get_children():
		child.queue_free()
	player.reset(respawn.global_position)
```

- [ ] **Step 5: Create `scenes/game.tscn`**

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/game.gd" id="1_game"]
[ext_resource type="Script" path="res://scenes/camera.gd" id="2_cam"]
[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="3_player"]
[ext_resource type="Material" path="res://assets/shaders/boil_material.tres" id="4_boil"]

[sub_resource type="Gradient" id="Gradient_sky"]
offsets = PackedFloat32Array(0, 1)
colors = PackedColorArray(0.573, 0.71, 0.859, 1, 0.725, 0.569, 0.863, 1)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_sky"]
gradient = SubResource("Gradient_sky")
width = 1280
height = 720
fill_from = Vector2(0, 0)
fill_to = Vector2(0, 1)

[sub_resource type="Gradient" id="Gradient_floor"]
offsets = PackedFloat32Array(0, 1)
colors = PackedColorArray(0.427, 0.631, 0.427, 1, 0.427, 0.631, 0.427, 1)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_floor"]
gradient = SubResource("Gradient_floor")
width = 1400
height = 80

[sub_resource type="Gradient" id="Gradient_platform"]
offsets = PackedFloat32Array(0, 1)
colors = PackedColorArray(0.62, 0.412, 0.42, 1, 0.62, 0.412, 0.42, 1)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_platform"]
gradient = SubResource("Gradient_platform")
width = 200
height = 24

[sub_resource type="RectangleShape2D" id="RectangleShape2D_floor"]
size = Vector2(1400, 80)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_wall"]
size = Vector2(40, 1400)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_platform"]
size = Vector2(200, 24)

[node name="Game" type="Node2D"]
script = ExtResource("1_game")

[node name="Background" type="Sprite2D" parent="."]
position = Vector2(640, 360)
texture = SubResource("GradientTexture2D_sky")

[node name="Arena" type="Node2D" parent="."]

[node name="Floor" type="StaticBody2D" parent="Arena"]
position = Vector2(640, 680)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Arena/Floor"]
shape = SubResource("RectangleShape2D_floor")

[node name="Art" type="Sprite2D" parent="Arena/Floor"]
material = ExtResource("4_boil")
texture = SubResource("GradientTexture2D_floor")

[node name="WallL" type="StaticBody2D" parent="Arena"]
position = Vector2(-20, 360)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Arena/WallL"]
shape = SubResource("RectangleShape2D_wall")

[node name="WallR" type="StaticBody2D" parent="Arena"]
position = Vector2(1300, 360)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Arena/WallR"]
shape = SubResource("RectangleShape2D_wall")

[node name="PlatformL" type="StaticBody2D" parent="Arena"]
position = Vector2(220, 480)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Arena/PlatformL"]
shape = SubResource("RectangleShape2D_platform")
one_way_collision = true

[node name="Art" type="Sprite2D" parent="Arena/PlatformL"]
material = ExtResource("4_boil")
texture = SubResource("GradientTexture2D_platform")

[node name="PlatformM" type="StaticBody2D" parent="Arena"]
position = Vector2(540, 400)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Arena/PlatformM"]
shape = SubResource("RectangleShape2D_platform")
one_way_collision = true

[node name="Art" type="Sprite2D" parent="Arena/PlatformM"]
material = ExtResource("4_boil")
texture = SubResource("GradientTexture2D_platform")

[node name="PlatformR" type="StaticBody2D" parent="Arena"]
position = Vector2(820, 480)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Arena/PlatformR"]
shape = SubResource("RectangleShape2D_platform")
one_way_collision = true

[node name="Art" type="Sprite2D" parent="Arena/PlatformR"]
material = ExtResource("4_boil")
texture = SubResource("GradientTexture2D_platform")

[node name="Projectiles" type="Node2D" parent="."]

[node name="Player" parent="." instance=ExtResource("3_player")]
position = Vector2(200, 598)

[node name="RespawnPoint" type="Marker2D" parent="."]
position = Vector2(200, 598)

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(640, 360)
script = ExtResource("2_cam")
```

- [ ] **Step 6: Set the main scene**

In `project.godot`, under `[application]`, add after `config/name=...`:

```ini
run/main_scene="res://scenes/game.tscn"
```

- [ ] **Step 7: Run tests to verify they pass**

Run the test commands. Expected: 8 `PASS` lines, `0 failure(s)`, exit 0.

- [ ] **Step 8: User playtest (do not launch it yourself)**

Ask the user to open the project and press F5. Check: the teal blob runs with A/D, jumps with Space, lands with a squash, jumps up through platforms and stands on them, and can't leave the screen.

- [ ] **Step 9: Commit**

```bash
git add scenes/camera.gd scenes/game.gd scenes/game.tscn project.godot tests/test_logic.gd
git commit -m "feat: arena with platforms, shake camera, game scene"
```

---

### Task 5: Boss (phase-1 attacks, phases, death)

Skills: `godot-prompter:state-machine`, `godot-prompter:animation-system`, `godot-prompter:physics-system`

**Files:**
- Create: `scenes/boss/shockwave.gd`
- Create: `scenes/boss/shockwave.tscn`
- Create: `scenes/boss/boss.gd`
- Create: `scenes/boss/boss.tscn`
- Modify: `scenes/game.gd`
- Modify: `scenes/game.tscn`
- Modify: `tests/test_logic.gd`

**Interfaces:**
- Consumes: `Bomb` (Task 2), group `"player"` (Task 3), group `"camera"` (Task 4).
- Produces: `class_name Boss extends Node2D` with `signal health_changed(hits_left: int, hits_total: int)`, `signal phase_changed(phase: int)` (0-based, so the second phase emits 1), `signal defeated`, `enum State { INTRO, IDLE, ATTACK, STAGGER, PHASE_SHIFT, DEAD }`, `const HITS_PER_PHASE := 3`, `const PHASES`, `var state`, `var phase`, `var hp`, `var rig` (onready), `func start_fight()`, `func hits_total() -> int`, `func hits_left() -> int`, `func next_attack() -> StringName`, `func take_hit() -> bool`, `func restart_phase()`, method-track targets `aim_slam()`, `slam_impact()`, `spawn_bomb()`, `shake(amount: float)`. `class_name Shockwave extends Area2D` with `var direction: int`.

- [ ] **Step 1: Write the failing test**

In `tests/test_logic.gd`, add `await _test_boss()` after `await _test_arena()` in `_run()`, and add:

```gdscript
func _test_boss() -> void:
	var boss: Boss = load("res://scenes/boss/boss.tscn").instantiate()
	root.add_child(boss)
	await process_frame
	check(not boss.take_hit(), "boss ignores hits during the intro")
	check([boss.next_attack(), boss.next_attack(), boss.next_attack()] == [&"slam", &"bombs", &"slam"], "phase 1 cycles slam, bombs")
	var phases := []
	var won := [false]
	boss.phase_changed.connect(func(p: int) -> void: phases.append(p))
	boss.defeated.connect(func() -> void: won[0] = true)
	for i in boss.hits_total():
		boss.state = Boss.State.IDLE
		boss.take_hit()
	check(phases == [1, 2], "phase advances every 3 hits")
	check(won[0] and boss.state == Boss.State.DEAD, "9 hits defeat the boss")
	boss.queue_free()

	var boss2: Boss = load("res://scenes/boss/boss.tscn").instantiate()
	root.add_child(boss2)
	boss2.rig.position = Vector2.ZERO
	boss2.state = Boss.State.IDLE
	var bomb: Bomb = load("res://scenes/boss/bomb.tscn").instantiate()
	root.add_child(bomb)
	bomb.global_position = boss2.get_node("Rig/Core").global_position
	bomb.throw(Vector2.ZERO)
	for i in 5:
		await physics_frame
	check(boss2.hp == Boss.HITS_PER_PHASE - 1 and bomb.exploded, "a thrown bomb on the core hurts the boss")
	boss2.queue_free()
	await process_frame
```

- [ ] **Step 2: Run test to verify it fails**

Run the test commands. Expected: parse error mentioning `Boss`, non-zero exit.

- [ ] **Step 3: Create `scenes/boss/shockwave.gd`**

```gdscript
class_name Shockwave
extends Area2D
## Ground wave from a fist slam. Jump over it.

@export var speed := 480.0
var direction := 1


func _ready() -> void:
	$Art.scale.x = direction


func _physics_process(delta: float) -> void:
	position.x += speed * direction * delta
	if position.x < -150.0 or position.x > 1430.0:
		queue_free()
```

- [ ] **Step 4: Create `scenes/boss/shockwave.tscn`**

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/boss/shockwave.gd" id="1_wave"]
[ext_resource type="Material" path="res://assets/shaders/boil_material.tres" id="2_boil"]

[sub_resource type="Gradient" id="Gradient_wave"]
offsets = PackedFloat32Array(0, 0.94, 1)
colors = PackedColorArray(0.863, 0.686, 0.569, 1, 0.863, 0.686, 0.569, 1, 0.863, 0.686, 0.569, 0)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_wave"]
gradient = SubResource("Gradient_wave")
width = 70
height = 50
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(1, 0.5)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_wave"]
size = Vector2(50, 36)

[node name="Shockwave" type="Area2D"]
collision_layer = 8
collision_mask = 0
monitoring = false
script = ExtResource("1_wave")

[node name="Art" type="Sprite2D" parent="."]
material = ExtResource("2_boil")
position = Vector2(0, -25)
texture = SubResource("GradientTexture2D_wave")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, -18)
shape = SubResource("RectangleShape2D_wave")
```

- [ ] **Step 5: Create `scenes/boss/boss.gd`**

```gdscript
class_name Boss
extends Node2D
## King Kilowatt. Cycles a fixed attack pattern per phase; only thrown bombs hurt him.
## Attacks live in the AnimationPlayer: value tracks move the rig and toggle hitboxes,
## method tracks call aim_slam / slam_impact / spawn_bomb / shake at the right frames.

signal health_changed(hits_left: int, hits_total: int)
signal phase_changed(phase: int)  # 0-based: the second phase emits 1
signal defeated

enum State { INTRO, IDLE, ATTACK, STAGGER, PHASE_SHIFT, DEAD }

const HITS_PER_PHASE := 3
const FLOOR_Y := 640.0
const BOMB_SCENE := preload("res://scenes/boss/bomb.tscn")
const SHOCKWAVE_SCENE := preload("res://scenes/boss/shockwave.tscn")
const PHASES := [
	{attacks = [&"slam", &"bombs"], speed = 1.0, rest = 1.2},
	{attacks = [&"slam", &"bombs", &"bombs"], speed = 1.2, rest = 0.9},
	{attacks = [&"slam", &"bombs", &"bombs"], speed = 1.45, rest = 0.6},
]

@export var projectiles: Node2D

var state := State.INTRO
var phase := 0
var hp := HITS_PER_PHASE
var _attack_index := 0
var _rest_pose := {}

@onready var rig: Node2D = $Rig
@onready var head: Node2D = $Rig/Head
@onready var eye: Node2D = $Rig/Head/Eye
@onready var fist_l: Node2D = $Rig/FistL
@onready var slam_anchor: Node2D = $Rig/SlamAnchor
@onready var fist_r: Node2D = $Rig/SlamAnchor/FistR
@onready var shadow: Node2D = $Rig/SlamAnchor/Shadow
@onready var bomb_spawn: Marker2D = $Rig/FistL/BombSpawn
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var rest_timer: Timer = $RestTimer


func _ready() -> void:
	for n: Node2D in [head, fist_l, fist_r]:
		_rest_pose[n] = n.position
	$Rig/Core/WeakPoint.body_entered.connect(_on_weak_point_body_entered)
	anim.animation_finished.connect(_on_animation_finished)
	rest_timer.timeout.connect(_on_rest_timer_timeout)


func start_fight() -> void:
	_play(&"intro", State.INTRO)


func hits_total() -> int:
	return HITS_PER_PHASE * PHASES.size()


func hits_left() -> int:
	return (PHASES.size() - 1 - phase) * HITS_PER_PHASE + hp


func next_attack() -> StringName:
	var attacks: Array = PHASES[phase].attacks
	var attack: StringName = attacks[_attack_index % attacks.size()]
	_attack_index += 1
	return attack


## Returns true if the hit counted. The boss is only vulnerable while idle or attacking.
func take_hit() -> bool:
	if state != State.IDLE and state != State.ATTACK:
		return false
	hp -= 1
	health_changed.emit(hits_left(), hits_total())
	get_tree().call_group("camera", "hitstop", 0.08)
	if hp <= 0:
		_advance_phase()
	else:
		_play(&"stagger", State.STAGGER)
	return true


func restart_phase() -> void:
	if state == State.DEAD:
		return
	hp = HITS_PER_PHASE
	_attack_index = 0
	health_changed.emit(hits_left(), hits_total())
	_rest()


# --- called from animation method tracks ---

func aim_slam() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var x := player.global_position.x if player else 400.0
	slam_anchor.position.x = clampf(x, 80.0, 880.0)


func slam_impact() -> void:
	shake(18.0)
	for dir in [-1, 1]:
		var wave: Shockwave = SHOCKWAVE_SCENE.instantiate()
		wave.direction = dir
		_spawn_parent().add_child(wave)
		wave.global_position = Vector2(slam_anchor.global_position.x, FLOOR_Y)


func spawn_bomb() -> void:
	var bomb: Bomb = BOMB_SCENE.instantiate()
	_spawn_parent().add_child(bomb)
	bomb.global_position = bomb_spawn.global_position
	bomb.linear_velocity = Vector2(randf_range(-650.0, -250.0), -350.0)


func shake(amount: float) -> void:
	get_tree().call_group("camera", "shake", amount)


# --- internals ---

func _advance_phase() -> void:
	rest_timer.stop()
	if phase == PHASES.size() - 1:
		_play(&"death", State.DEAD)
		defeated.emit()
		return
	phase += 1
	hp = HITS_PER_PHASE
	_attack_index = 0
	phase_changed.emit(phase)
	_play(StringName("phase_%d" % (phase + 1)), State.PHASE_SHIFT)


func _rest() -> void:
	_play(&"idle", State.IDLE)
	rest_timer.start(PHASES[phase].rest)


func _play(anim_name: StringName, new_state: State) -> void:
	_reset_rig()
	state = new_state
	anim.speed_scale = PHASES[phase].speed
	anim.play(anim_name)


func _reset_rig() -> void:
	for n: Node2D in _rest_pose:
		n.position = _rest_pose[n]
	rig.position = Vector2.ZERO
	rig.modulate = Color.WHITE
	eye.modulate = Color.WHITE
	shadow.hide()
	$Rig/SlamAnchor/FistR/Hitbox/CollisionShape2D.set_deferred("disabled", true)


func _spawn_parent() -> Node:
	return projectiles if projectiles else get_parent()


func _on_animation_finished(_anim_name: StringName) -> void:
	if state in [State.INTRO, State.ATTACK, State.STAGGER, State.PHASE_SHIFT]:
		_rest()


func _on_rest_timer_timeout() -> void:
	if state == State.IDLE:
		_play(next_attack(), State.ATTACK)


func _on_weak_point_body_entered(body: Node2D) -> void:
	var bomb := body as Bomb
	if bomb and bomb.thrown and not bomb.exploded:
		bomb.explode()
		take_hit()
```

- [ ] **Step 6: Create `scenes/boss/boss.tscn`**

The rig starts at `(0, 520)` (sunk behind the floor, crown peeking out) and rises in the `intro` animation. Child positions are the rest pose when the rig is at `(0, 0)`. `FistR` rests off-screen above `SlamAnchor`; `aim_slam` moves the anchor to the player's x.

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/boss/boss.gd" id="1_boss"]
[ext_resource type="Material" path="res://assets/shaders/boil_material.tres" id="2_boil"]

[sub_resource type="Gradient" id="Gradient_torso"]
offsets = PackedFloat32Array(0, 1)
colors = PackedColorArray(0.565, 0.337, 0.467, 1, 0.565, 0.337, 0.467, 1)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_torso"]
gradient = SubResource("Gradient_torso")
width = 360
height = 420

[sub_resource type="Gradient" id="Gradient_armor"]
offsets = PackedFloat32Array(0, 1)
colors = PackedColorArray(0.255, 0.369, 0.608, 1, 0.255, 0.369, 0.608, 1)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_armor"]
gradient = SubResource("Gradient_armor")
width = 130
height = 100

[sub_resource type="Gradient" id="Gradient_core"]
offsets = PackedFloat32Array(0, 0.94, 1)
colors = PackedColorArray(0.859, 0.588, 0.573, 1, 0.859, 0.588, 0.573, 1, 0.859, 0.588, 0.573, 0)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_core"]
gradient = SubResource("Gradient_core")
width = 130
height = 130
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(1, 0.5)

[sub_resource type="Gradient" id="Gradient_head"]
offsets = PackedFloat32Array(0, 1)
colors = PackedColorArray(0.365, 0.443, 0.604, 1, 0.365, 0.443, 0.604, 1)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_head"]
gradient = SubResource("Gradient_head")
width = 280
height = 200

[sub_resource type="Gradient" id="Gradient_crown"]
offsets = PackedFloat32Array(0, 1)
colors = PackedColorArray(0.859, 0.851, 0.569, 1, 0.859, 0.851, 0.569, 1)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_crown"]
gradient = SubResource("Gradient_crown")
width = 160
height = 60

[sub_resource type="Gradient" id="Gradient_eye"]
offsets = PackedFloat32Array(0, 0.94, 1)
colors = PackedColorArray(0.988, 0.984, 0.988, 1, 0.988, 0.984, 0.988, 1, 0.988, 0.984, 0.988, 0)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_eye"]
gradient = SubResource("Gradient_eye")
width = 80
height = 80
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(1, 0.5)

[sub_resource type="Gradient" id="Gradient_fist"]
offsets = PackedFloat32Array(0, 0.94, 1)
colors = PackedColorArray(0.451, 0.373, 0.694, 1, 0.451, 0.373, 0.694, 1, 0.451, 0.373, 0.694, 0)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_fist"]
gradient = SubResource("Gradient_fist")
width = 170
height = 150
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(1, 0.5)

[sub_resource type="Gradient" id="Gradient_shadow"]
offsets = PackedFloat32Array(0, 0.94, 1)
colors = PackedColorArray(0.176, 0.153, 0.188, 0.5, 0.176, 0.153, 0.188, 0.5, 0.176, 0.153, 0.188, 0)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_shadow"]
gradient = SubResource("Gradient_shadow")
width = 220
height = 40
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(1, 0.5)

[sub_resource type="CircleShape2D" id="CircleShape2D_core"]
radius = 70.0

[sub_resource type="RectangleShape2D" id="RectangleShape2D_fist"]
size = Vector2(150, 130)

[sub_resource type="Animation" id="Animation_idle"]
resource_name = "idle"
length = 1.6
loop_mode = 1
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Rig/Head:position")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0, 0.8, 1.6),
"transitions": PackedFloat32Array(1, 1, 1),
"update": 0,
"values": [Vector2(1090, 170), Vector2(1090, 182), Vector2(1090, 170)]
}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("Rig/FistL:position")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0, 0.8, 1.6),
"transitions": PackedFloat32Array(1, 1, 1),
"update": 0,
"values": [Vector2(880, 540), Vector2(880, 556), Vector2(880, 540)]
}

[sub_resource type="Animation" id="Animation_intro"]
resource_name = "intro"
length = 1.5
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Rig:position")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0, 1.2),
"transitions": PackedFloat32Array(0.4, 1),
"update": 0,
"values": [Vector2(0, 520), Vector2(0, 0)]
}
tracks/1/type = "method"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath(".")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(1.2),
"transitions": PackedFloat32Array(1),
"values": [{
"args": [14.0],
"method": &"shake"
}]
}

[sub_resource type="Animation" id="Animation_slam"]
resource_name = "slam"
length = 1.4
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Rig/SlamAnchor/FistR:position")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0, 0.7, 0.85, 1.1, 1.4),
"transitions": PackedFloat32Array(0.5, 2, 1, 1, 1),
"update": 0,
"values": [Vector2(0, -260), Vector2(0, 40), Vector2(0, 565), Vector2(0, 565), Vector2(0, -260)]
}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("Rig/SlamAnchor/Shadow:visible")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0, 1.1),
"transitions": PackedFloat32Array(1, 1),
"update": 1,
"values": [true, false]
}
tracks/2/type = "value"
tracks/2/imported = false
tracks/2/enabled = true
tracks/2/path = NodePath("Rig/SlamAnchor/Shadow:scale")
tracks/2/interp = 1
tracks/2/loop_wrap = true
tracks/2/keys = {
"times": PackedFloat32Array(0, 0.85),
"transitions": PackedFloat32Array(1, 1),
"update": 0,
"values": [Vector2(0.3, 0.3), Vector2(1, 1)]
}
tracks/3/type = "value"
tracks/3/imported = false
tracks/3/enabled = true
tracks/3/path = NodePath("Rig/SlamAnchor/FistR/Hitbox/CollisionShape2D:disabled")
tracks/3/interp = 1
tracks/3/loop_wrap = true
tracks/3/keys = {
"times": PackedFloat32Array(0, 0.75, 1.1),
"transitions": PackedFloat32Array(1, 1, 1),
"update": 1,
"values": [true, false, true]
}
tracks/4/type = "method"
tracks/4/imported = false
tracks/4/enabled = true
tracks/4/path = NodePath(".")
tracks/4/interp = 1
tracks/4/loop_wrap = true
tracks/4/keys = {
"times": PackedFloat32Array(0, 0.85),
"transitions": PackedFloat32Array(1, 1),
"values": [{
"args": [],
"method": &"aim_slam"
}, {
"args": [],
"method": &"slam_impact"
}]
}

[sub_resource type="Animation" id="Animation_bombs"]
resource_name = "bombs"
length = 1.5
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Rig/FistL:position")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0, 0.3, 0.45, 0.75, 0.9, 1.5),
"transitions": PackedFloat32Array(1, 1, 1, 1, 1, 1),
"update": 0,
"values": [Vector2(880, 540), Vector2(960, 330), Vector2(840, 380), Vector2(960, 330), Vector2(840, 380), Vector2(880, 540)]
}
tracks/1/type = "method"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath(".")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0.45, 0.9),
"transitions": PackedFloat32Array(1, 1),
"values": [{
"args": [],
"method": &"spawn_bomb"
}, {
"args": [],
"method": &"spawn_bomb"
}]
}

[sub_resource type="Animation" id="Animation_stagger"]
resource_name = "stagger"
length = 0.8
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Rig:position")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0, 0.1, 0.2, 0.3, 0.5),
"transitions": PackedFloat32Array(1, 1, 1, 1, 1),
"update": 0,
"values": [Vector2(0, 0), Vector2(14, 0), Vector2(-14, 0), Vector2(8, 0), Vector2(0, 0)]
}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("Rig:modulate")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0, 0.5),
"transitions": PackedFloat32Array(1, 1),
"update": 0,
"values": [Color(1, 0.45, 0.45, 1), Color(1, 1, 1, 1)]
}

[sub_resource type="Animation" id="Animation_phase_2"]
resource_name = "phase_2"
length = 1.4
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Rig/ArmorL:position")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0, 1.2),
"transitions": PackedFloat32Array(2, 1),
"update": 0,
"values": [Vector2(960, 320), Vector2(880, 900)]
}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("Rig/ArmorL:rotation")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0, 1.2),
"transitions": PackedFloat32Array(1, 1),
"update": 0,
"values": [0.0, 2.5]
}
tracks/2/type = "value"
tracks/2/imported = false
tracks/2/enabled = true
tracks/2/path = NodePath("Rig:modulate")
tracks/2/interp = 1
tracks/2/loop_wrap = true
tracks/2/keys = {
"times": PackedFloat32Array(0, 0.6),
"transitions": PackedFloat32Array(1, 1),
"update": 0,
"values": [Color(1, 0.45, 0.45, 1), Color(1, 1, 1, 1)]
}
tracks/3/type = "method"
tracks/3/imported = false
tracks/3/enabled = true
tracks/3/path = NodePath(".")
tracks/3/interp = 1
tracks/3/loop_wrap = true
tracks/3/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"values": [{
"args": [20.0],
"method": &"shake"
}]
}

[sub_resource type="Animation" id="Animation_phase_3"]
resource_name = "phase_3"
length = 1.4
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Rig/ArmorR:position")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0, 1.2),
"transitions": PackedFloat32Array(2, 1),
"update": 0,
"values": [Vector2(1200, 320), Vector2(1280, 900)]
}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("Rig/ArmorR:rotation")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0, 1.2),
"transitions": PackedFloat32Array(1, 1),
"update": 0,
"values": [0.0, -2.5]
}
tracks/2/type = "value"
tracks/2/imported = false
tracks/2/enabled = true
tracks/2/path = NodePath("Rig:modulate")
tracks/2/interp = 1
tracks/2/loop_wrap = true
tracks/2/keys = {
"times": PackedFloat32Array(0, 0.6),
"transitions": PackedFloat32Array(1, 1),
"update": 0,
"values": [Color(1, 0.45, 0.45, 1), Color(1, 1, 1, 1)]
}
tracks/3/type = "method"
tracks/3/imported = false
tracks/3/enabled = true
tracks/3/path = NodePath(".")
tracks/3/interp = 1
tracks/3/loop_wrap = true
tracks/3/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"values": [{
"args": [20.0],
"method": &"shake"
}]
}

[sub_resource type="Animation" id="Animation_death"]
resource_name = "death"
length = 2.5
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Rig:position")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0, 0.15, 0.3, 0.45, 0.6, 2.5),
"transitions": PackedFloat32Array(1, 1, 1, 1, 2, 1),
"update": 0,
"values": [Vector2(0, 0), Vector2(16, 0), Vector2(-16, 0), Vector2(12, 0), Vector2(-12, 0), Vector2(0, 700)]
}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("Rig:modulate")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0, 2.5),
"transitions": PackedFloat32Array(1, 1),
"update": 0,
"values": [Color(1, 1, 1, 1), Color(0.5, 0.5, 0.5, 1)]
}
tracks/2/type = "method"
tracks/2/imported = false
tracks/2/enabled = true
tracks/2/path = NodePath(".")
tracks/2/interp = 1
tracks/2/loop_wrap = true
tracks/2/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"values": [{
"args": [25.0],
"method": &"shake"
}]
}

[sub_resource type="AnimationLibrary" id="AnimationLibrary_boss"]
_data = {
&"bombs": SubResource("Animation_bombs"),
&"death": SubResource("Animation_death"),
&"idle": SubResource("Animation_idle"),
&"intro": SubResource("Animation_intro"),
&"phase_2": SubResource("Animation_phase_2"),
&"phase_3": SubResource("Animation_phase_3"),
&"slam": SubResource("Animation_slam"),
&"stagger": SubResource("Animation_stagger")
}

[node name="Boss" type="Node2D"]
script = ExtResource("1_boss")

[node name="Rig" type="Node2D" parent="."]
position = Vector2(0, 520)

[node name="Torso" type="Sprite2D" parent="Rig"]
material = ExtResource("2_boil")
position = Vector2(1080, 470)
texture = SubResource("GradientTexture2D_torso")

[node name="ArmorL" type="Sprite2D" parent="Rig"]
material = ExtResource("2_boil")
position = Vector2(960, 320)
texture = SubResource("GradientTexture2D_armor")

[node name="ArmorR" type="Sprite2D" parent="Rig"]
material = ExtResource("2_boil")
position = Vector2(1200, 320)
texture = SubResource("GradientTexture2D_armor")

[node name="Core" type="Sprite2D" parent="Rig"]
material = ExtResource("2_boil")
position = Vector2(1060, 420)
texture = SubResource("GradientTexture2D_core")

[node name="WeakPoint" type="Area2D" parent="Rig/Core"]
collision_layer = 16
collision_mask = 4
monitorable = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="Rig/Core/WeakPoint"]
shape = SubResource("CircleShape2D_core")

[node name="Head" type="Sprite2D" parent="Rig"]
material = ExtResource("2_boil")
position = Vector2(1090, 170)
texture = SubResource("GradientTexture2D_head")

[node name="Crown" type="Sprite2D" parent="Rig/Head"]
material = ExtResource("2_boil")
position = Vector2(0, -125)
texture = SubResource("GradientTexture2D_crown")

[node name="Eye" type="Sprite2D" parent="Rig/Head"]
material = ExtResource("2_boil")
position = Vector2(-50, 0)
texture = SubResource("GradientTexture2D_eye")

[node name="FistL" type="Sprite2D" parent="Rig"]
material = ExtResource("2_boil")
position = Vector2(880, 540)
texture = SubResource("GradientTexture2D_fist")

[node name="BombSpawn" type="Marker2D" parent="Rig/FistL"]
position = Vector2(-20, -60)

[node name="SlamAnchor" type="Node2D" parent="Rig"]
position = Vector2(500, 0)

[node name="Shadow" type="Sprite2D" parent="Rig/SlamAnchor"]
visible = false
position = Vector2(0, 640)
texture = SubResource("GradientTexture2D_shadow")

[node name="FistR" type="Sprite2D" parent="Rig/SlamAnchor"]
material = ExtResource("2_boil")
position = Vector2(0, -260)
texture = SubResource("GradientTexture2D_fist")

[node name="Hitbox" type="Area2D" parent="Rig/SlamAnchor/FistR"]
collision_layer = 8
collision_mask = 0
monitoring = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="Rig/SlamAnchor/FistR/Hitbox"]
shape = SubResource("RectangleShape2D_fist")
disabled = true

[node name="AnimationPlayer" type="AnimationPlayer" parent="."]
libraries = {
&"": SubResource("AnimationLibrary_boss")
}

[node name="RestTimer" type="Timer" parent="."]
one_shot = true
```

- [ ] **Step 7: Put the boss in the arena**

In `scenes/game.tscn`, add this line after the other `ext_resource` lines:

```
[ext_resource type="PackedScene" path="res://scenes/boss/boss.tscn" id="5_boss"]
```

and insert this node directly after the `Background` node block (so the boss draws behind the arena):

```
[node name="Boss" parent="." node_paths=PackedStringArray("projectiles") instance=ExtResource("5_boss")]
projectiles = NodePath("../Projectiles")
```

- [ ] **Step 8: Start the fight from `scenes/game.gd`**

Replace the whole file with:

```gdscript
extends Node2D
## Arena root: wires player, boss and HUD together and handles restarts.

@onready var player: Player = $Player
@onready var boss: Boss = $Boss
@onready var projectiles: Node2D = $Projectiles
@onready var respawn: Marker2D = $RespawnPoint


func _ready() -> void:
	player.died.connect(_on_player_died)
	boss.start_fight()


func _on_player_died() -> void:
	await get_tree().create_timer(1.0).timeout
	for child in projectiles.get_children():
		child.queue_free()
	player.reset(respawn.global_position)
	boss.restart_phase()
```

- [ ] **Step 9: Run tests to verify they pass**

Run the test commands. Expected: 14 `PASS` lines, `0 failure(s)`, exit 0.

- [ ] **Step 10: User playtest (do not launch it yourself)**

Ask the user to press F5. Check: the boss rises with a shake; a shadow appears under the player and a fist slams there, sending two ground waves out; the left fist lobs two bombs that blink faster before exploding; J picks a bomb up and J again throws it; a throw that hits the salmon core flashes the boss red and freezes the frame briefly; three hits drop the left armor plate and speed him up.

- [ ] **Step 11: Commit**

```bash
git add scenes/boss scenes/game.gd scenes/game.tscn tests/test_logic.gd
git commit -m "feat: King Kilowatt boss with slam, bombs, phases and death"
```

---

### Task 6: HUD and game wiring (Day 1 milestone)

Skills: `godot-prompter:hud-system`, `godot-prompter:godot-ui`, `godot-prompter:tween-animation`

**Files:**
- Create: `scenes/ui/hud.gd`
- Create: `scenes/ui/hud.tscn`
- Modify: `scenes/game.gd` (full rewrite)
- Modify: `scenes/game.tscn`
- Modify: `tests/test_logic.gd`

**Interfaces:**
- Consumes: `Player.hp_changed`, `Player.died`, `Player.reset` (Task 3); `Boss.health_changed`, `Boss.phase_changed`, `Boss.defeated`, `Boss.start_fight`, `Boss.restart_phase`, `Boss.hits_left`, `Boss.hits_total` (Task 5).
- Produces: `class_name HUD extends CanvasLayer` with `signal retry_pressed`, `var hearts: Array` (untyped on purpose so `.visible` type-checks), `var boss_bar: ProgressBar`, `func set_hearts(hp: int)`, `func set_boss_health(hits_left: int, hits_total: int)`, `func show_banner(text: String, seconds: float)` (awaitable), `func show_end(text: String)`.

- [ ] **Step 1: Write the failing test**

In `tests/test_logic.gd`, add `await _test_game_wiring()` after `await _test_boss()` in `_run()`, and add:

```gdscript
func _test_game_wiring() -> void:
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var player: Player = game.get_node("Player")
	var boss: Boss = game.get_node("Boss")
	var hud: HUD = game.get_node("HUD")
	player.take_hit()
	check(not hud.hearts[2].visible and hud.hearts[1].visible, "losing a heart updates the HUD")
	boss.state = Boss.State.IDLE
	boss.take_hit()
	check(hud.boss_bar.value == boss.hits_total() - 1, "a boss hit updates the boss bar")
	game.queue_free()
	await process_frame
	Engine.time_scale = 1.0
```

- [ ] **Step 2: Run test to verify it fails**

Run the test commands. Expected: parse error mentioning `HUD`, non-zero exit.

- [ ] **Step 3: Create `scenes/ui/hud.gd`**

```gdscript
class_name HUD
extends CanvasLayer
## Hearts, boss bar, big banners and the end panel. Displays only; owns no game state.

signal retry_pressed

@onready var hearts: Array = $Hearts.get_children()
@onready var boss_bar: ProgressBar = $BossBar/Bar
@onready var banner: Label = $Banner
@onready var end_panel: Control = $EndPanel
@onready var end_label: Label = $EndPanel/VBox/Label
@onready var retry: Button = $EndPanel/VBox/Retry


func _ready() -> void:
	retry.pressed.connect(retry_pressed.emit)


func set_hearts(hp: int) -> void:
	for i in hearts.size():
		hearts[i].visible = i < hp


func set_boss_health(hits_left: int, hits_total: int) -> void:
	boss_bar.max_value = hits_total
	boss_bar.value = hits_left


func show_banner(text: String, seconds: float) -> void:
	banner.text = text
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.2, 0.2)
	banner.show()
	create_tween().tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(seconds).timeout
	banner.hide()


func show_end(text: String) -> void:
	end_label.text = text
	end_panel.show()
	retry.grab_focus()
```

- [ ] **Step 4: Create `scenes/ui/hud.tscn`**

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/ui/hud.gd" id="1_hud"]

[sub_resource type="Gradient" id="Gradient_heart"]
offsets = PackedFloat32Array(0, 0.94, 1)
colors = PackedColorArray(0.859, 0.588, 0.573, 1, 0.859, 0.588, 0.573, 1, 0.859, 0.588, 0.573, 0)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_heart"]
gradient = SubResource("Gradient_heart")
width = 40
height = 40
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(1, 0.5)

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_bar_bg"]
bg_color = Color(0.176, 0.153, 0.188, 1)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_right = 8
corner_radius_bottom_left = 8

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_bar_fill"]
bg_color = Color(0.859, 0.588, 0.573, 1)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_right = 8
corner_radius_bottom_left = 8

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_panel"]
content_margin_left = 48.0
content_margin_top = 32.0
content_margin_right = 48.0
content_margin_bottom = 32.0
bg_color = Color(0.176, 0.153, 0.188, 0.85)
corner_radius_top_left = 16
corner_radius_top_right = 16
corner_radius_bottom_right = 16
corner_radius_bottom_left = 16

[node name="HUD" type="CanvasLayer"]
layer = 10
script = ExtResource("1_hud")

[node name="Hearts" type="HBoxContainer" parent="."]
offset_left = 24.0
offset_top = 24.0
offset_right = 160.0
offset_bottom = 64.0
theme_override_constants/separation = 8

[node name="Heart1" type="TextureRect" parent="Hearts"]
layout_mode = 2
texture = SubResource("GradientTexture2D_heart")

[node name="Heart2" type="TextureRect" parent="Hearts"]
layout_mode = 2
texture = SubResource("GradientTexture2D_heart")

[node name="Heart3" type="TextureRect" parent="Hearts"]
layout_mode = 2
texture = SubResource("GradientTexture2D_heart")

[node name="BossBar" type="VBoxContainer" parent="."]
anchor_left = 1.0
anchor_right = 1.0
offset_left = -464.0
offset_top = 20.0
offset_right = -24.0
offset_bottom = 80.0
grow_horizontal = 0

[node name="Name" type="Label" parent="BossBar"]
layout_mode = 2
theme_override_colors/font_color = Color(0.988, 0.984, 0.988, 1)
theme_override_colors/font_outline_color = Color(0.176, 0.153, 0.188, 1)
theme_override_constants/outline_size = 8
theme_override_font_sizes/font_size = 22
text = "KING KILOWATT"
horizontal_alignment = 2

[node name="Bar" type="ProgressBar" parent="BossBar"]
custom_minimum_size = Vector2(440, 22)
layout_mode = 2
theme_override_styles/background = SubResource("StyleBoxFlat_bar_bg")
theme_override_styles/fill = SubResource("StyleBoxFlat_bar_fill")
max_value = 9.0
value = 9.0
show_percentage = false

[node name="Banner" type="Label" parent="."]
visible = false
anchor_top = 0.5
anchor_right = 1.0
anchor_bottom = 0.5
offset_top = -60.0
offset_bottom = 60.0
grow_horizontal = 2
grow_vertical = 2
theme_override_colors/font_color = Color(0.859, 0.851, 0.569, 1)
theme_override_colors/font_outline_color = Color(0.176, 0.153, 0.188, 1)
theme_override_constants/outline_size = 18
theme_override_font_sizes/font_size = 72
horizontal_alignment = 1
vertical_alignment = 1

[node name="EndPanel" type="PanelContainer" parent="."]
visible = false
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -110.0
offset_right = 200.0
offset_bottom = 110.0
grow_horizontal = 2
grow_vertical = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_panel")

[node name="VBox" type="VBoxContainer" parent="EndPanel"]
layout_mode = 2
theme_override_constants/separation = 24
alignment = 1

[node name="Label" type="Label" parent="EndPanel/VBox"]
layout_mode = 2
theme_override_colors/font_color = Color(0.988, 0.984, 0.988, 1)
theme_override_font_sizes/font_size = 48
text = "YOU WIN!"
horizontal_alignment = 1

[node name="Retry" type="Button" parent="EndPanel/VBox"]
layout_mode = 2
theme_override_font_sizes/font_size = 28
text = "Play again"
```

- [ ] **Step 5: Add the HUD to `scenes/game.tscn`**

Add after the other `ext_resource` lines:

```
[ext_resource type="PackedScene" path="res://scenes/ui/hud.tscn" id="6_hud"]
```

and add at the end of the file:

```
[node name="HUD" parent="." instance=ExtResource("6_hud")]
```

- [ ] **Step 6: Rewrite `scenes/game.gd`**

```gdscript
extends Node2D
## Arena root: wires player, boss and HUD together and handles restarts.

@onready var player: Player = $Player
@onready var boss: Boss = $Boss
@onready var hud: HUD = $HUD
@onready var projectiles: Node2D = $Projectiles
@onready var respawn: Marker2D = $RespawnPoint


func _ready() -> void:
	player.hp_changed.connect(hud.set_hearts)
	player.died.connect(_on_player_died)
	boss.health_changed.connect(hud.set_boss_health)
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.defeated.connect(_on_boss_defeated)
	hud.retry_pressed.connect(get_tree().reload_current_scene)
	hud.set_hearts(player.hp)
	hud.set_boss_health(boss.hits_left(), boss.hits_total())
	await hud.show_banner("LITTLE GUY  vs  BIG GUY", 2.0)
	boss.start_fight()


func _on_player_died() -> void:
	await get_tree().create_timer(1.0).timeout
	for child in projectiles.get_children():
		child.queue_free()
	player.reset(respawn.global_position)
	boss.restart_phase()
	hud.show_banner("AGAIN!", 1.0)


func _on_boss_phase_changed(phase: int) -> void:
	hud.show_banner("PHASE %d" % (phase + 1), 1.2)


func _on_boss_defeated() -> void:
	await hud.show_banner("KNOCKOUT!", 2.5)
	hud.show_end("YOU WIN!")
```

- [ ] **Step 7: Run tests to verify they pass**

Run the test commands. Expected: 16 `PASS` lines, `0 failure(s)`, exit 0.

- [ ] **Step 8: Milestone playtest and tuning (user presses F5)**

The whole fight should now be playable start to finish with placeholders. Ask the user to play it twice and report. Tuning knobs, in the order to try:
- Throws miss the core: `Player.throw_velocity` / `lob_velocity` (Inspector on the Player instance in `game.tscn`), or the core's `CircleShape2D_core` radius in `boss.tscn`.
- Too hard: `PHASES[*].rest` longer, or `speed` lower in `boss.gd`.
- Bombs land somewhere awkward: the `randf_range(-650.0, -250.0)` x-velocity in `Boss.spawn_bomb`.
- Floaty jump: raise `Player.gravity` and `jump_velocity` together.

Apply any agreed changes, rerun the tests.

- [ ] **Step 9: Commit**

```bash
git add scenes/ui scenes/game.gd scenes/game.tscn tests/test_logic.gd
git commit -m "feat: HUD with hearts, boss bar, banners and retry"
```

---

### Task 7: Laser attack and phase-3 platform break

Skills: `godot-prompter:animation-system`, `godot-prompter:physics-system`

**Files:**
- Modify: `scenes/boss/boss.gd`
- Modify: `scenes/boss/boss.tscn`
- Modify: `scenes/game.gd`
- Modify: `scenes/game.tscn`
- Modify: `tests/test_logic.gd`

**Interfaces:**
- Consumes: `Boss` internals (Task 5), `game.gd` (Task 6).
- Produces: `Boss.laser_fire()` (method-track target; Task 10 adds its sound), boss nodes `LaserLow` and `LaserHigh`, `game.tscn` node `Arena/ArenaAnim` with animation `break_platforms`.

- [ ] **Step 1: Write the failing test**

In `tests/test_logic.gd`, add `await _test_phase_extras()` after `await _test_game_wiring()` in `_run()`, and add:

```gdscript
func _test_phase_extras() -> void:
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var boss: Boss = game.get_node("Boss")
	boss.phase = 1
	check([boss.next_attack(), boss.next_attack(), boss.next_attack(), boss.next_attack()] == [&"slam", &"bombs", &"laser", &"bombs"], "phase 2 adds the laser")
	check(boss.anim.has_animation(&"laser"), "laser animation exists")
	boss.phase_changed.emit(2)
	var arena_anim: AnimationPlayer = game.get_node("Arena/ArenaAnim")
	check(arena_anim.current_animation == "break_platforms", "phase 3 breaks the platforms")
	game.queue_free()
	await process_frame
```

- [ ] **Step 2: Run test to verify it fails**

Run the test commands. Expected: `FAIL  phase 2 adds the laser`, `FAIL  laser animation exists`, an error about `Arena/ArenaAnim` not found, an `engine/script error(s) during tests` line, exit code 1.

- [ ] **Step 3: Update `scenes/boss/boss.gd`**

Replace the `PHASES` constant with:

```gdscript
const PHASES := [
	{attacks = [&"slam", &"bombs"], speed = 1.0, rest = 1.2},
	{attacks = [&"slam", &"bombs", &"laser", &"bombs"], speed = 1.2, rest = 0.9},
	{attacks = [&"slam", &"bombs", &"laser", &"bombs"], speed = 1.45, rest = 0.6},
]
```

Add these two lines after `@onready var rest_timer: Timer = $RestTimer`:

```gdscript
@onready var laser_low: Node2D = $LaserLow
@onready var laser_high: Node2D = $LaserHigh
```

Add this method after `spawn_bomb()`:

```gdscript
func laser_fire() -> void:
	shake(6.0)
```

Append these lines to the end of `_reset_rig()`:

```gdscript
	for laser: Node2D in [laser_low, laser_high]:
		laser.get_node("Warn").hide()
		laser.get_node("Beam").hide()
		laser.get_node("Hitbox/CollisionShape2D").set_deferred("disabled", true)
```

Update the header comment's method list to read `aim_slam / slam_impact / spawn_bomb / laser_fire / shake`.

- [ ] **Step 4: Add the laser to `scenes/boss/boss.tscn`**

Insert these sub-resources directly before the `[sub_resource type="AnimationLibrary" id="AnimationLibrary_boss"]` line:

```
[sub_resource type="Gradient" id="Gradient_warn"]
offsets = PackedFloat32Array(0, 1)
colors = PackedColorArray(0.859, 0.588, 0.573, 1, 0.859, 0.588, 0.573, 1)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_warn"]
gradient = SubResource("Gradient_warn")
width = 1280
height = 6

[sub_resource type="Gradient" id="Gradient_beam"]
offsets = PackedFloat32Array(0, 1)
colors = PackedColorArray(0.859, 0.569, 0.827, 1, 0.859, 0.569, 0.827, 1)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_beam"]
gradient = SubResource("Gradient_beam")
width = 1280
height = 34

[sub_resource type="RectangleShape2D" id="RectangleShape2D_beam"]
size = Vector2(1280, 30)

[sub_resource type="Animation" id="Animation_laser"]
resource_name = "laser"
length = 2.6
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("LaserLow/Warn:visible")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0, 0.7),
"transitions": PackedFloat32Array(1, 1),
"update": 1,
"values": [true, false]
}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("LaserLow/Beam:visible")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0.7, 1.1),
"transitions": PackedFloat32Array(1, 1),
"update": 1,
"values": [true, false]
}
tracks/2/type = "value"
tracks/2/imported = false
tracks/2/enabled = true
tracks/2/path = NodePath("LaserLow/Hitbox/CollisionShape2D:disabled")
tracks/2/interp = 1
tracks/2/loop_wrap = true
tracks/2/keys = {
"times": PackedFloat32Array(0.7, 1.1),
"transitions": PackedFloat32Array(1, 1),
"update": 1,
"values": [false, true]
}
tracks/3/type = "value"
tracks/3/imported = false
tracks/3/enabled = true
tracks/3/path = NodePath("LaserHigh/Warn:visible")
tracks/3/interp = 1
tracks/3/loop_wrap = true
tracks/3/keys = {
"times": PackedFloat32Array(1.3, 2),
"transitions": PackedFloat32Array(1, 1),
"update": 1,
"values": [true, false]
}
tracks/4/type = "value"
tracks/4/imported = false
tracks/4/enabled = true
tracks/4/path = NodePath("LaserHigh/Beam:visible")
tracks/4/interp = 1
tracks/4/loop_wrap = true
tracks/4/keys = {
"times": PackedFloat32Array(2, 2.4),
"transitions": PackedFloat32Array(1, 1),
"update": 1,
"values": [true, false]
}
tracks/5/type = "value"
tracks/5/imported = false
tracks/5/enabled = true
tracks/5/path = NodePath("LaserHigh/Hitbox/CollisionShape2D:disabled")
tracks/5/interp = 1
tracks/5/loop_wrap = true
tracks/5/keys = {
"times": PackedFloat32Array(2, 2.4),
"transitions": PackedFloat32Array(1, 1),
"update": 1,
"values": [false, true]
}
tracks/6/type = "value"
tracks/6/imported = false
tracks/6/enabled = true
tracks/6/path = NodePath("Rig/Head/Eye:modulate")
tracks/6/interp = 1
tracks/6/loop_wrap = true
tracks/6/keys = {
"times": PackedFloat32Array(0, 1.1, 1.3, 2.4),
"transitions": PackedFloat32Array(1, 1, 1, 1),
"update": 1,
"values": [Color(1, 0.45, 0.45, 1), Color(1, 1, 1, 1), Color(1, 0.45, 0.45, 1), Color(1, 1, 1, 1)]
}
tracks/7/type = "method"
tracks/7/imported = false
tracks/7/enabled = true
tracks/7/path = NodePath(".")
tracks/7/interp = 1
tracks/7/loop_wrap = true
tracks/7/keys = {
"times": PackedFloat32Array(0.7, 2),
"transitions": PackedFloat32Array(1, 1),
"values": [{
"args": [],
"method": &"laser_fire"
}, {
"args": [],
"method": &"laser_fire"
}]
}
```

In the `AnimationLibrary_boss` `_data` block, add this line after the `&"intro"` line:

```
&"laser": SubResource("Animation_laser"),
```

Insert these nodes directly before the `[node name="AnimationPlayer" type="AnimationPlayer" parent="."]` line. The low beam sits where a grounded player stands (jump it); the high beam sits at side-platform height (stay on the floor):

```
[node name="LaserLow" type="Node2D" parent="."]
position = Vector2(640, 612)

[node name="Warn" type="Sprite2D" parent="LaserLow"]
visible = false
texture = SubResource("GradientTexture2D_warn")

[node name="Beam" type="Sprite2D" parent="LaserLow"]
visible = false
material = ExtResource("2_boil")
texture = SubResource("GradientTexture2D_beam")

[node name="Hitbox" type="Area2D" parent="LaserLow"]
collision_layer = 8
collision_mask = 0
monitoring = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="LaserLow/Hitbox"]
shape = SubResource("RectangleShape2D_beam")
disabled = true

[node name="LaserHigh" type="Node2D" parent="."]
position = Vector2(640, 440)

[node name="Warn" type="Sprite2D" parent="LaserHigh"]
visible = false
texture = SubResource("GradientTexture2D_warn")

[node name="Beam" type="Sprite2D" parent="LaserHigh"]
visible = false
material = ExtResource("2_boil")
texture = SubResource("GradientTexture2D_beam")

[node name="Hitbox" type="Area2D" parent="LaserHigh"]
collision_layer = 8
collision_mask = 0
monitoring = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="LaserHigh/Hitbox"]
shape = SubResource("RectangleShape2D_beam")
disabled = true
```

- [ ] **Step 5: Add the platform break to `scenes/game.tscn`**

Insert these sub-resources directly before the `[node name="Game" type="Node2D"]` line. `ArenaAnim`'s root is its parent `Arena`, so paths are relative to `Arena`:

```
[sub_resource type="Animation" id="Animation_break"]
resource_name = "break_platforms"
length = 1.0
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("PlatformL/CollisionShape2D:disabled")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 1,
"values": [true]
}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("PlatformR/CollisionShape2D:disabled")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 1,
"values": [true]
}
tracks/2/type = "value"
tracks/2/imported = false
tracks/2/enabled = true
tracks/2/path = NodePath("PlatformL:position")
tracks/2/interp = 1
tracks/2/loop_wrap = true
tracks/2/keys = {
"times": PackedFloat32Array(0, 0.15, 1),
"transitions": PackedFloat32Array(1, 2, 1),
"update": 0,
"values": [Vector2(220, 480), Vector2(220, 492), Vector2(200, 900)]
}
tracks/3/type = "value"
tracks/3/imported = false
tracks/3/enabled = true
tracks/3/path = NodePath("PlatformR:position")
tracks/3/interp = 1
tracks/3/loop_wrap = true
tracks/3/keys = {
"times": PackedFloat32Array(0, 0.15, 1),
"transitions": PackedFloat32Array(1, 2, 1),
"update": 0,
"values": [Vector2(820, 480), Vector2(820, 492), Vector2(840, 900)]
}
tracks/4/type = "value"
tracks/4/imported = false
tracks/4/enabled = true
tracks/4/path = NodePath("PlatformL:rotation")
tracks/4/interp = 1
tracks/4/loop_wrap = true
tracks/4/keys = {
"times": PackedFloat32Array(0.15, 1),
"transitions": PackedFloat32Array(1, 1),
"update": 0,
"values": [0.0, 1.0]
}
tracks/5/type = "value"
tracks/5/imported = false
tracks/5/enabled = true
tracks/5/path = NodePath("PlatformR:rotation")
tracks/5/interp = 1
tracks/5/loop_wrap = true
tracks/5/keys = {
"times": PackedFloat32Array(0.15, 1),
"transitions": PackedFloat32Array(1, 1),
"update": 0,
"values": [0.0, -1.0]
}

[sub_resource type="AnimationLibrary" id="AnimationLibrary_arena"]
_data = {
&"break_platforms": SubResource("Animation_break")
}
```

Insert this node directly after the `PlatformR` `Art` node block (before `Projectiles`):

```
[node name="ArenaAnim" type="AnimationPlayer" parent="Arena"]
libraries = {
&"": SubResource("AnimationLibrary_arena")
}
```

- [ ] **Step 6: Trigger it from `scenes/game.gd`**

Add after `@onready var respawn: Marker2D = $RespawnPoint`:

```gdscript
@onready var arena_anim: AnimationPlayer = $Arena/ArenaAnim
```

Replace `_on_boss_phase_changed` with:

```gdscript
func _on_boss_phase_changed(phase: int) -> void:
	hud.show_banner("PHASE %d" % (phase + 1), 1.2)
	if phase == 2:
		arena_anim.play(&"break_platforms")
		get_tree().call_group("camera", "shake", 14.0)
```

- [ ] **Step 7: Run tests to verify they pass**

Run the test commands. Expected: 19 `PASS` lines, `0 failure(s)`, exit 0.

- [ ] **Step 8: User playtest (F5)**

Check: in phase 2 a thin salmon line appears along the floor, then a pink beam (jump over it), then a line at side-platform height, then a beam (stay low); the eye flashes during each warning; reaching phase 3 drops the left and right platforms.

- [ ] **Step 9: Commit**

```bash
git add scenes/boss/boss.gd scenes/boss/boss.tscn scenes/game.gd scenes/game.tscn tests/test_logic.gd
git commit -m "feat: low/high laser in phases 2-3, phase 3 breaks side platforms"
```

---

### Task 8: Film filter and title screen

Skills: `godot-prompter:shader-basics`, `godot-prompter:godot-ui`

**Files:**
- Create: `assets/shaders/film_filter.gdshader`
- Create: `scenes/fx/film_filter.tscn`
- Create: `scenes/title.gd`
- Create: `scenes/title.tscn`
- Modify: `scenes/game.tscn`
- Modify: `project.godot`
- Modify: `tests/test_logic.gd`

**Interfaces:**
- Consumes: `scenes/game.tscn` (Task 6).
- Produces: reusable `res://scenes/fx/film_filter.tscn` (CanvasLayer, layer 20, above the HUD); main scene becomes `res://scenes/title.tscn`.

- [ ] **Step 1: Write the failing test**

In `tests/test_logic.gd`, add `await _test_title()` after `await _test_phase_extras()` in `_run()`, and add:

```gdscript
func _test_title() -> void:
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	check(title.get_node("VBox/Start").has_focus(), "title focuses the Start button")
	check(title.get_node("FilmFilter/Rect").material != null, "film filter has its shader material")
	title.queue_free()
	await process_frame
```

- [ ] **Step 2: Run test to verify it fails**

Run the test commands. Expected: error loading `res://scenes/title.tscn`, an `engine/script error(s) during tests` line, exit code 1.

- [ ] **Step 3: Create `assets/shaders/film_filter.gdshader`**

```glsl
shader_type canvas_item;

// Old-cartoon film look over the whole screen: fade, warm tint, grain, flicker, vignette.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float fade = 0.15;
uniform vec3 tint = vec3(1.0, 0.94, 0.82);
uniform float grain = 0.07;
uniform float flicker = 0.04;
uniform float vignette = 0.9;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float t = floor(TIME * 24.0);
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(luma) * tint, fade);
	c += (hash(SCREEN_UV * 731.0 + t) - 0.5) * grain;
	c *= 1.0 - flicker * hash(vec2(t, 0.37));
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - dot(d, d) * vignette;
	COLOR = vec4(c, 1.0);
}
```

- [ ] **Step 4: Create `scenes/fx/film_filter.tscn`**

```
[gd_scene format=3]

[ext_resource type="Shader" path="res://assets/shaders/film_filter.gdshader" id="1_film"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_film"]
shader = ExtResource("1_film")
shader_parameter/fade = 0.15
shader_parameter/tint = Vector3(1, 0.94, 0.82)
shader_parameter/grain = 0.07
shader_parameter/flicker = 0.04
shader_parameter/vignette = 0.9

[node name="FilmFilter" type="CanvasLayer"]
layer = 20

[node name="Rect" type="ColorRect" parent="."]
material = SubResource("ShaderMaterial_film")
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
```

- [ ] **Step 5: Create `scenes/title.gd`**

```gdscript
extends Control
## Title screen: one button into the fight.


func _ready() -> void:
	var start: Button = $VBox/Start
	start.grab_focus()
	start.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/game.tscn"))
```

- [ ] **Step 6: Create `scenes/title.tscn`**

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/title.gd" id="1_title"]
[ext_resource type="PackedScene" path="res://scenes/fx/film_filter.tscn" id="2_film"]

[sub_resource type="Gradient" id="Gradient_bg"]
offsets = PackedFloat32Array(0, 1)
colors = PackedColorArray(0.573, 0.71, 0.859, 1, 0.725, 0.569, 0.863, 1)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_bg"]
gradient = SubResource("Gradient_bg")
width = 1280
height = 720
fill_from = Vector2(0, 0)
fill_to = Vector2(0, 1)

[node name="Title" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_title")

[node name="Bg" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
texture = SubResource("GradientTexture2D_bg")
expand_mode = 1

[node name="VBox" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -560.0
offset_top = -200.0
offset_right = 560.0
offset_bottom = 200.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 20
alignment = 1

[node name="Name" type="Label" parent="VBox"]
layout_mode = 2
theme_override_colors/font_color = Color(0.859, 0.851, 0.569, 1)
theme_override_colors/font_outline_color = Color(0.176, 0.153, 0.188, 1)
theme_override_constants/outline_size = 20
theme_override_font_sizes/font_size = 64
text = "LITTLE GUY vs BIG GUY"
horizontal_alignment = 1

[node name="Tag" type="Label" parent="VBox"]
layout_mode = 2
theme_override_colors/font_color = Color(0.988, 0.984, 0.988, 1)
theme_override_colors/font_outline_color = Color(0.176, 0.153, 0.188, 1)
theme_override_constants/outline_size = 8
theme_override_font_sizes/font_size = 28
text = "I'm just a little guy."
horizontal_alignment = 1

[node name="Start" type="Button" parent="VBox"]
custom_minimum_size = Vector2(220, 60)
layout_mode = 2
size_flags_horizontal = 4
theme_override_font_sizes/font_size = 32
text = "Start"

[node name="Controls" type="Label" parent="VBox"]
layout_mode = 2
theme_override_colors/font_color = Color(0.988, 0.984, 0.988, 1)
theme_override_colors/font_outline_color = Color(0.176, 0.153, 0.188, 1)
theme_override_constants/outline_size = 6
theme_override_font_sizes/font_size = 20
text = "A/D move    Space jump    J grab and throw    hold W + J to lob"
horizontal_alignment = 1

[node name="FilmFilter" parent="." instance=ExtResource("2_film")]
```

- [ ] **Step 7: Add the filter to the game and switch the main scene**

In `scenes/game.tscn`, add after the other `ext_resource` lines:

```
[ext_resource type="PackedScene" path="res://scenes/fx/film_filter.tscn" id="7_film"]
```

and add at the end of the file:

```
[node name="FilmFilter" parent="." instance=ExtResource("7_film")]
```

In `project.godot`, change `run/main_scene="res://scenes/game.tscn"` to:

```ini
run/main_scene="res://scenes/title.tscn"
```

- [ ] **Step 8: Run tests to verify they pass**

Run the test commands. Expected: 21 `PASS` lines, `0 failure(s)`, exit 0.

- [ ] **Step 9: User check in the editor (F5)**

The headless runner cannot compile shaders, so ask the user to: open the project, check the Output panel shows no shader errors, press F5. Check: the title shows with grain, flicker and vignette; Start (mouse, Enter or gamepad A) enters the fight; sprite edges wobble 12 times a second. If the filter is too strong, lower `grain` / `fade` on `scenes/fx/film_filter.tscn` > Rect > Material.

- [ ] **Step 10: Commit**

```bash
git add assets/shaders/film_filter.gdshader scenes/fx scenes/title.gd scenes/title.tscn scenes/game.tscn project.godot tests/test_logic.gd
git commit -m "feat: old-film filter and title screen"
```

---

### Task 9: Swap in the user's rubber-hose art

Skills: `godot-prompter:assets-pipeline`, `godot-prompter:animation-system`

**Files:**
- Create: `assets/art/**.png` (from the user)
- Modify: `scenes/player/player.tscn`, `scenes/boss/boss.tscn`, `scenes/boss/bomb.tscn`, `scenes/boss/shockwave.tscn`, `scenes/game.tscn`, `scenes/ui/hud.tscn`

**Interfaces:**
- Consumes: every placeholder `GradientTexture2D` from Tasks 2-8.
- Produces: no code changes. Node names and positions stay the same, so all tests keep passing.

**Art spec for the user** (transparent PNG, thick black outlines in ink #2d2730, palette colors only, rubber-hose style: pie-cut eyes, white gloves, noodle limbs). Draw at these exact pixel sizes so the swap is drop-in:

| File | Size (px) | Replaces |
|---|---|---|
| `assets/art/hero/idle.png` | 120 x 168 (2x) | player `idle` |
| `assets/art/hero/run1.png`, `run2.png` | 120 x 168 | player `run` |
| `assets/art/hero/jump.png` | 120 x 168 | player `jump` |
| `assets/art/hero/carry.png` | 120 x 168 | player `carry` (arms up) |
| `assets/art/boss/torso.png` | 360 x 420 | `Rig/Torso` |
| `assets/art/boss/head.png` | 280 x 200 | `Rig/Head` |
| `assets/art/boss/crown.png` | 160 x 60 | `Rig/Head/Crown` |
| `assets/art/boss/eye.png` | 80 x 80 | `Rig/Head/Eye` |
| `assets/art/boss/core.png` | 130 x 130 | `Rig/Core` |
| `assets/art/boss/fist.png` | 170 x 150 | `Rig/FistL`, `Rig/SlamAnchor/FistR` |
| `assets/art/boss/armor.png` | 130 x 100 | `Rig/ArmorL`, `Rig/ArmorR` |
| `assets/art/bomb.png` | 44 x 44 | bomb `Art/Body` |
| `assets/art/shockwave.png` | 70 x 50 | shockwave `Art` |
| `assets/art/background.png` | 1280 x 720 | game `Background` |
| `assets/art/floor.png` | 1400 x 80 | `Arena/Floor/Art` |
| `assets/art/platform.png` | 200 x 24 | the three platform `Art` nodes |
| `assets/art/heart.png` | 40 x 40 | the three HUD hearts |

Only swap the files that exist; missing ones keep their placeholder.

- [ ] **Step 1: Import**

Run `"$GODOT" --headless --path . --import` so each PNG gets its `.import` file.

- [ ] **Step 2: Swap the player frames**

In `scenes/player/player.tscn`, add after the existing `ext_resource` lines:

```
[ext_resource type="Texture2D" path="res://assets/art/hero/idle.png" id="3_idle"]
[ext_resource type="Texture2D" path="res://assets/art/hero/run1.png" id="4_run1"]
[ext_resource type="Texture2D" path="res://assets/art/hero/run2.png" id="5_run2"]
[ext_resource type="Texture2D" path="res://assets/art/hero/jump.png" id="6_jump"]
[ext_resource type="Texture2D" path="res://assets/art/hero/carry.png" id="7_carry"]
```

Replace the whole `[sub_resource type="SpriteFrames" id="SpriteFrames_body"]` block with:

```
[sub_resource type="SpriteFrames" id="SpriteFrames_body"]
animations = [{
"frames": [{
"duration": 1.0,
"texture": ExtResource("7_carry")
}],
"loop": true,
"name": &"carry",
"speed": 8.0
}, {
"frames": [{
"duration": 1.0,
"texture": ExtResource("3_idle")
}],
"loop": true,
"name": &"idle",
"speed": 8.0
}, {
"frames": [{
"duration": 1.0,
"texture": ExtResource("6_jump")
}],
"loop": true,
"name": &"jump",
"speed": 8.0
}, {
"frames": [{
"duration": 1.0,
"texture": ExtResource("4_run1")
}, {
"duration": 1.0,
"texture": ExtResource("5_run2")
}],
"loop": true,
"name": &"run",
"speed": 8.0
}]
```

On the `Body` node, add `scale = Vector2(0.5, 0.5)` (the hero is drawn at 2x). Delete the now-unused `Gradient_body` and `GradientTexture2D_body` sub-resources.

- [ ] **Step 3: Swap every other texture**

For each row in the table above: add an `ext_resource` line for the PNG at the top of the owning `.tscn` with an id of the form `art_<name>` (so it can't clash with the numbered ids Task 10 adds), change that node's `texture = SubResource("GradientTexture2D_x")` to `texture = ExtResource("art_<name>")`, and delete the `Gradient_x` / `GradientTexture2D_x` pair once nothing references it. Example for the bomb in `scenes/boss/bomb.tscn`:

```
[ext_resource type="Texture2D" path="res://assets/art/bomb.png" id="art_bomb"]
```

```
[node name="Body" type="Sprite2D" parent="Art"]
material = ExtResource("2_boil")
texture = ExtResource("art_bomb")
```

- [ ] **Step 4: Run tests**

Run the test commands. Expected: 21 `PASS` lines, `0 failure(s)`, no `ERROR:` lines about missing resources.

- [ ] **Step 5: User check (F5)**

Check that the art lines up: the core sits inside the torso, the fist bottom touches the floor on a slam, and the hero's feet touch the ground. Nudge node `position`s in the editor if a drawing's pivot is off. Never resize the collision shapes to fit art; shapes are gameplay.

- [ ] **Step 6: Commit**

```bash
git add assets/art scenes
git commit -m "art: rubber-hose hero, King Kilowatt, props and HUD"
```

---

### Task 10: Sound effects and music

Skills: `godot-prompter:audio-system`

**Files:**
- Create: `assets/sfx/jump.wav`, `throw.wav`, `hurt.wav`, `boom.wav`, `slam.wav`, `hit.wav`, `laser.wav` (from the user, made at https://sfxr.me); `assets/music/fight.ogg` (from the user)
- Modify: `scenes/player/player.tscn`, `scenes/player/player.gd`, `scenes/boss/bomb.tscn`, `scenes/boss/bomb.gd`, `scenes/boss/boss.tscn`, `scenes/boss/boss.gd`, `scenes/game.tscn`

**Interfaces:**
- Consumes: `Player._physics_process` jump branch, `Player._throw`, `Player.take_hit`, `Bomb.explode`, `Boss.slam_impact`, `Boss.take_hit`, `Boss.laser_fire`.
- Produces: no new interfaces.

- [ ] **Step 1: Import**

Run `"$GODOT" --headless --path . --import`. Then ask the user to select `assets/music/fight.ogg` in the editor's FileSystem dock, open the Import tab, tick **Loop**, and press **Reimport**.

- [ ] **Step 2: Player sounds**

In `scenes/player/player.tscn`, add:

```
[ext_resource type="AudioStream" path="res://assets/sfx/jump.wav" id="8_jump"]
[ext_resource type="AudioStream" path="res://assets/sfx/throw.wav" id="9_throw"]
[ext_resource type="AudioStream" path="res://assets/sfx/hurt.wav" id="10_hurt"]
```

and at the end of the file:

```
[node name="SfxJump" type="AudioStreamPlayer" parent="."]
stream = ExtResource("8_jump")

[node name="SfxThrow" type="AudioStreamPlayer" parent="."]
stream = ExtResource("9_throw")

[node name="SfxHurt" type="AudioStreamPlayer" parent="."]
stream = ExtResource("10_hurt")
```

In `scenes/player/player.gd`: inside the jump branch, after `_squash(Vector2(0.75, 1.25))`, add `$SfxJump.play()`. In `_throw()`, after `held_bomb.throw(...)`, add `$SfxThrow.play()`. In `take_hit()`, after `hp_changed.emit(hp)`, add `$SfxHurt.play()`.

- [ ] **Step 3: Bomb sound**

In `scenes/boss/bomb.tscn`, add:

```
[ext_resource type="AudioStream" path="res://assets/sfx/boom.wav" id="4_boom"]
```

and at the end:

```
[node name="SfxBoom" type="AudioStreamPlayer" parent="."]
stream = ExtResource("4_boom")
```

In `scenes/boss/bomb.gd` `explode()`, after `particles.emitting = true`, add `$SfxBoom.play()`. Keep `boom.wav` under 0.7 s, because the bomb frees itself 0.75 s after exploding.

- [ ] **Step 4: Boss sounds**

In `scenes/boss/boss.tscn`, add:

```
[ext_resource type="AudioStream" path="res://assets/sfx/slam.wav" id="3_slam"]
[ext_resource type="AudioStream" path="res://assets/sfx/hit.wav" id="4_hit"]
[ext_resource type="AudioStream" path="res://assets/sfx/laser.wav" id="5_laser"]
```

and at the end:

```
[node name="SfxSlam" type="AudioStreamPlayer" parent="."]
stream = ExtResource("3_slam")

[node name="SfxHit" type="AudioStreamPlayer" parent="."]
stream = ExtResource("4_hit")

[node name="SfxLaser" type="AudioStreamPlayer" parent="."]
stream = ExtResource("5_laser")
```

In `scenes/boss/boss.gd`: in `slam_impact()`, after `shake(18.0)`, add `$SfxSlam.play()`. In `take_hit()`, after `hp -= 1`, add `$SfxHit.play()`. In `laser_fire()`, after `shake(6.0)`, add `$SfxLaser.play()`.

- [ ] **Step 5: Music**

In `scenes/game.tscn`, add:

```
[ext_resource type="AudioStream" path="res://assets/music/fight.ogg" id="8_music"]
```

and at the end:

```
[node name="Music" type="AudioStreamPlayer" parent="."]
stream = ExtResource("8_music")
volume_db = -8.0
autoplay = true
```

- [ ] **Step 6: Run tests**

Run the test commands. Expected: 21 `PASS` lines, `0 failure(s)`.

- [ ] **Step 7: User check (F5)**

Every action makes its sound, and the music loops without a gap.

- [ ] **Step 8: Commit**

```bash
git add assets/sfx assets/music scenes
git commit -m "audio: sfx for jump, throw, hurt, bombs, slam, hits, laser; fight music"
```

---

### Task 11: Web export for itch.io

Skills: `godot-prompter:export-pipeline`

**Files:**
- Create: `export_presets.cfg`

**Interfaces:**
- Consumes: the whole project. Export templates for 4.7.1 are already installed at `%APPDATA%\Godot\export_templates\4.7.1.stable`.
- Produces: `build/web/index.html` + `.pck` + `.wasm` + `.js` (gitignored).

- [ ] **Step 1: Create `export_presets.cfg`**

Threads are off so the build runs on itch.io without SharedArrayBuffer headers.

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="docs/*, tests/*, build/*"
export_path="build/web/index.html"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
```

- [ ] **Step 2: Export**

```bash
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
```

Expected: `build/web/index.html`, `index.pck`, `index.wasm`, `index.js` exist; no `ERROR:` lines.

- [ ] **Step 3: Local browser check (user)**

```bash
python -m http.server 8000 --directory build/web
```

Ask the user to open http://localhost:8000, play through once, then stop the server (Ctrl+C). Do not leave it running.

- [ ] **Step 4: Zip for itch**

Git Bash on Windows has no `zip`, so use PowerShell from the project folder:

```powershell
Compress-Archive -Path build/web/* -DestinationPath build/little-guy-vs-big-guy-web.zip -Force
```

- [ ] **Step 5: Upload (user only)**

The user uploads `build/little-guy-vs-big-guy-web.zip` on itch.io: Kind of project = HTML, tick "This file will be played in the browser", viewport 1280 x 720, tick "Mobile friendly" off, "SharedArrayBuffer support" off. Publishing is the user's action; never upload on their behalf.

- [ ] **Step 6: Commit**

```bash
git add export_presets.cfg
git commit -m "build: web export preset for itch.io"
```
