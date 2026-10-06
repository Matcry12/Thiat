# 0026 - Island generator (W1)

## Context
v1 needs one big island (200 x 120 cells, 6400 x 3840 px) where the player walks from home to the
boss ([0025](0025-v1-open-world.md)). The old map was a small flat field with rocks.

## Decision
- **Shape:** radial falloff + noise gives a blob. We keep only the land connected to home. If the
  boss area is cut off, we carve a bridge. A small erode + dilate step (`_open_land`) removes 1-cell
  land strips, because the walker could not pass them.
- **Areas:** by distance from home to boss, with a noise wobble: forest (near home), rocky (middle),
  boss (far right).
- **Water:** collision only on coast cells (about 311 shapes), on the wall layer.
- **Rocks:** no flood fill per rock. Reachability is by geometry: spacing and `rock_clearance`
  (agent radius x 2 + one flow step = 44 px) are at least the walker width, so the 16 px grid sees the gaps.
- **Switch:** `Params.island_on = false` gives the old map back.
- **Tiles:** rocky = cobble, boss = dark grass, water = `Water_tiles.png`. Campfire = Bonfire frame 0.

## Why
The shape and areas come from a few numbers, so they are tunable in F3. Geometry rules are cheap:
a full rebuild takes about 460-505 ms (budget 2000 ms).

## Consequences
| Limit | What you see |
|---|---|
| Area borders are hard tile edges | No soft blend between forest, rocky and boss ground (no transition tiles yet) |
| Water is on the wall layer | Arrows stop at the water edge |
| Every F3 map change rebuilds the whole map | A short hitch; build ms is in the log and `[Map]` status |
