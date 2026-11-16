# 0053 — Natural enemy spawning: biome tables, slime spots, chance per second

**Status:** Active

Supersedes the spawn part of [0052](0052-enemies-slime.md) (fixed timer, flat biome list). The enemy setup itself stands.

## Context
Playtest of the first spawner: slimes came "too many, too often" and felt like a machine (a pack every 6 s, anywhere in forest / plains).

## Decision
Mix of Minecraft (where) and Terraria (when):
- **Biome table per type:** `EnemyData.rate_<biome>` floats (one per biome, F3-tunable) read via `rate_for(label)`. Slime types are data (one `.tres` each, same scene + brain): green (forest 1.0, plains 1.0, taiga 0.6, autumn 0.6), swamp slime (swamp 1.5), sand slime (beach_sand 0.4), ice slime (snowy 0.25), rock slime (rocky 0.25). Tough-biome types have more HP and drop more gel. Skin = `EnemyVisualData.tint` for now; drawn variants later.
- **Slime spots** (Minecraft slime chunks): a seeded ~1 in 10 of map squares (`spot_cell_size`, `spot_chance`) get `spot_rate_mult` (x4). Same seed = same spots. F1 shows them.
- **When:** every `tick_interval` (1 s) per type: `chance = base_chance x biome rate x spot bonus x (1 - near / cap)`. No fixed timer.
- **Residents:** when a chunk loads, each slime spot in it may get a pack (`resident_chance`), once per chunk load.
- **Soft despawn:** far (> `despawn_dist`) and idle enemies leave by a random chance per second (`despawn_chance`); past `hard_despawn_dist` at once. Only the spawner's own enemies.
- Kept from 0052: off-screen only, safe radius around home + stations, boss zone, no spawn while dead / boss engaged, test-run guard, not saved.

## Why
A learnable world (slime meadows you return to), uneven arrivals, fewer enemies when some are already near.

## Consequences
- Some seeds put a slime spot near home's safe radius edge: tune `safe_radius`.
- Variants share gel as their drop until W7 adds rare drops.
