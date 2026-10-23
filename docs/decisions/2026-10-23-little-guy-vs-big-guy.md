# Little Guy vs. Big Guy - decisions

Jam theme: "I'm just a little guy". Target: Godot 4.7, GL Compatibility.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | Complete jam game, 2 days, solo | Jam deadline | a teammate joins |
| Concept | One boss fight: tiny hero vs. giant boss, 3 phases | Theme fit; final-Bowser-fight vibe | - |
| Dimension | 2D side-view platformer, single arena | Only sane 2-day option; Mario boss feel | - |
| Authority | Single-player | - | - |
| Damage model | Hero cannot hit boss directly; picks up the boss's bombs and throws them back | One extra verb (grab/throw); readable dodge-grab-throw-stagger loop | playtests say it's too easy or too hard |
| Boss | Giant robot king; armor falls off each phase | Rigid parts animate with simple tweens; visible progress | - |
| Length | One boss, 3 phases (no boss rush); phase 3 reuses phase-2 attacks, faster, plus platform breaks | Polish over quantity; drawing eats ~1 day | Day 1 finishes early |
| Art | Pixel art at 4x (320x180 art canvas), drawn by code in `tools/art/` (regenerate with `build_art.gd` then `build_frames.gd`). Jame-gam palette only, ink outlines on foreground, outline-free background, top-left light with hue-shifted ramps. Replaced the rubber-hose plan (2026-10-23, user found the placeholder look unreadable) | Consistent, repeatable, no artist bottleneck | the user wants to hand-draw over it |
| Boss art | One sprite per puppet part, as 4x-scaled children so hitboxes and animation paths are unchanged | Cut-out animation in AnimationPlayer | - |
| Stage size | 2560 px wide arena, camera follows the player; the king rides a rail and stays ~560 px to the player's right between attacks; backdrop in two Parallax2D layers | User found one screen too small when upscaled | the fight feels too spread out |
| Stage events | Phase 1 is plain stone. Phase 2 switches on electric floor panels (warn 1.1 s, zap 0.9 s, near the player), conveyor belts and the piston and sliding lifts; phase 3 reverses the belts, zaps more often, opens pits and drops rubble | User wants a stage that "does something", but phase 1 must stay calm so the king's attacks read | a playtest finds it unfair |
| Controls | Arrows move, Up aims a lob, X jumps, Z grabs and throws, C dashes (~200 px over 0.16 s, squash to 75% height, i-frames, one air dash), Esc/P pauses | User's request | - |
| Visual calm | Backdrop dimmed a step, slower crowd, torches, gear, banners and clouds, fewer motes, plain floor tiles; gameplay VFX unchanged | User found the screen tiring to look at | readability suffers |
| Tutorial | Step-by-step lesson that waits for each action (walk, jump, dash, reach bomb, pick up, throw) against Lil' Watt, a small hovering training bot with the king's core (3 hits, same lead and core height as the king). The king stays hidden and rises at full health once it breaks. A greyscale Spotlight leaves only the step's subject in colour; a hit on the bot completes every earlier bomb step so rushing ahead never stalls; Enter skips (the bot blows up); once per session; then one-time tips per hazard | User wants it impossible to be confused, and practice hits must not cost the king health | - |
| Authoring | Prefer nodes and scenes over code: AnimationPlayer sequences (panel zap/collapse), Path2D + PathFollow2D lifts with no script, Timer nodes, scene signal connections | User preference | - |
| Readability | Z prompt over grabbable bombs, bobbing arrow on loose bombs, dotted throw arc, lock-on brackets on the core, slam reticle, laser warning line, goal/laser hints, hit sparks, dust, explosions, phase flash | The user asked to "understand the game" at a glance | playtest shows clutter |
| Language | GDScript | Fast iteration; simplest web export | - |
| Node authoring | All nodes authored in `.tscn`, never `Node.new()` in code | Project rule | - |
| IP | Original characters only, no Nintendo names or look-alikes | Jam rules, takedown risk | - |

## Open / deferred
- Death - **assumed**: restart at the start of the current phase; revisit after first playtest.
- Input - **assumed**: keyboard + gamepad through InputMap actions.
- Base resolution - **assumed**: 1280x720, `canvas_items` stretch with aspect `keep` (single-screen arena must frame the same on every display).
- Ship target - **assumed**: web export on itch.io.
- Audio - deferred: generated SFX (jsfxr), music source TBD on Day 2.
