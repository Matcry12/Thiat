# Day / night algorithm

**Status:** Current

How time of day works. Decision: [0067](../decision/0067-day-night-cycle.md). Code: `scripts/world/day_clock.gd` (the clock), `scripts/world/day_tint.gd` (the screen colour), `scripts/world/light_source.gd` (one light).
Built from how Minecraft, Terraria and Don't Starve do it, not guessed.

## Sources
| Rule | Minecraft | Terraria | Don't Starve |
|---|---|---|---|
| Full day | 20 min (24 000 ticks) | 24 min | 8 min (16 parts of 30 s) |
| Split | day 10, dusk 1.5, night 7, dawn 1.5 | day 15, night 9 | autumn: day 8/16, dusk 6/16, night 2/16; changes per season |
| Dusk / dawn | Smooth sky fade | Smooth fade, sky colour shift | Dusk is its own phase: orange, a bit darker |
| How dark | Sky light 15 -> 4; you still see shapes | Dark blue, you see ground near you | Pitch black, nothing visible without light |
| Light sources | Torch (light 14), lava, glowstone; light falls off per block | Torch (held + placed), campfire; wood + gel = torch | Campfire, torch (held, burns out), Miner hat |
| Night changes | Hostile mobs spawn in low light | Zombies, demon eyes spawn | "Charlie" hurts you in darkness |
| Start | Morning | Morning (4:30 am) | Day 1 morning |
| Sleep / skip | Bed skips night | No skip (sundial later) | Tent skips night |

## Our rules (length = Terraria-ish, darkness = between Minecraft and Don't Starve)
1. **One clock.** `DayClock` holds `time` 0..1 (0 = midnight, 0.25 = dawn, 0.5 = noon). It moves by `delta / day_length_s`. Nothing else keeps time.
2. **Four phases**, set by data: `dawn_start`, `day_start`, `dusk_start`, `night_start` (fractions of the day). Default split of a **12 min day**: day 6 min, dusk 1 min, night 4 min, dawn 1 min.
3. **Screen colour.** One `CanvasModulate` over the world. Its colour is read from a `Gradient` (data, `data/day_night/default.tres`) at `time`. Day = white, dusk = warm orange, night = dark blue (about 25 % brightness: you see shapes and the ground near you, not far), dawn = pink-grey. HUD and F3 are not darkened.
4. **Lights.** Every light is one `LightSource` node (a `PointLight2D` + a soft circle texture) with `radius`, `energy`, `color`, `flicker`. Lights fade in during dusk and out at dawn (`light_fade`), so they cost nothing at noon.
   - Home campfire: big warm light, always on at night.
   - Player: a very small "night eyes" glow (`player_glow_radius`, small), so you never stand in black.
   - Held torch: big warm light while it is in the selected hotbar slot.
   - Placed torch: same light, stays on the ground (slice c).
5. **Torch item.** Recipe at the workbench: 1 wood + 1 gel = 4 torches (slime gel gets a use). Never burns out in v1 (Don't Starve's burn-out = later, if hunger/survival needs pressure).
6. **Start time.** A new game starts at morning (`start_time` 0.30). Load restores the saved time.
7. **API for later features.** `DayClock.phase_changed(phase)`, `DayClock.is_night()`, `DayClock.time`, `DayClock.day_count`. Night monsters, hunger, sleep later listen to these. Nothing changes gameplay at night in this slice; it only looks and feels different.
8. **Never:** in headless test runs the clock starts frozen unless the test turns it on (no surprise darkness in tests).

## Example
You leave home at noon. After 6 min the screen turns orange (dusk, 1 min). Then it is dark blue for 4 min: the campfire glows warm at home, your torch lights a circle of about 5 tiles, the rest is shapes. At dawn it turns pink, then white. A full day = 12 min.

## Tuning (all `@export`, F3)
| Number | Start value |
|---|---|
| `day_length_s` | 720 |
| `dawn_start / day_start / dusk_start / night_start` | 0.20 / 0.283 / 0.783 / 0.867 |
| night brightness (gradient) | ~0.25, blue tint |
| `start_time` | 0.30 |
| campfire light radius | 220 px |
| torch light radius | 160 px |
| player glow radius | 48 px |
| `light_fade` | over dusk / dawn |
| `time_scale` (F3 only) | 1 |

F3: `[Day/Night]` status (clock hh:mm, phase, day N, lights on / total), buttons `Skip to dawn / day / dusk / night`, `Freeze time`, slider `time_scale`. F1: light radius circles (orange).
