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
| Art | Cuphead-inspired "rubber-hose lite": user hand-draws a few poses + boss parts; Godot adds film filter, line-boil shader, squash/stretch. Jame-gam palette: boss = dark row, arena = pastels, hero = teal, telegraphs = salmon | Cuphead look at a glance without frame-by-frame | drawing runs over budget (fall back to flat shapes) |
| Boss art | Separate transparent PNG per puppet part, joints at known pivots | Cut-out animation in AnimationPlayer | - |
| Language | GDScript | Fast iteration; simplest web export | - |
| Node authoring | All nodes authored in `.tscn`, never `Node.new()` in code | Project rule | - |
| IP | Original characters only, no Nintendo names or look-alikes | Jam rules, takedown risk | - |

## Open / deferred
- Death - **assumed**: restart at the start of the current phase; revisit after first playtest.
- Input - **assumed**: keyboard + gamepad through InputMap actions.
- Base resolution - **assumed**: 1280x720, `canvas_items` stretch with aspect `keep` (single-screen arena must frame the same on every display).
- Ship target - **assumed**: web export on itch.io.
- Audio - deferred: generated SFX (jsfxr), music source TBD on Day 2.
