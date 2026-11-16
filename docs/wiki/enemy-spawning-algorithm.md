# Enemy spawning algorithm

**Status:** Current

How enemies appear in the world. Decision: [0053](../decision/0053-natural-enemy-spawning.md). Code: `scripts/enemies/enemy_spawner.gd`.
Built from how Minecraft and Terraria do it, not guessed. Reuse it for every new enemy (W10 guards, new biomes).

## Sources
| Rule | Minecraft | Terraria |
|---|---|---|
| When | Many small tries each tick, so arrivals are uneven | Chance per tick `1/spawnRate`, lower when near `maxSpawns` |
| Where | 24-128 blocks away, never close | Just off-screen |
| Packs | One centre, members a few steps around it | Mostly single |
| Habitat | Biome spawn lists + weights; slimes only in seeded "slime chunks" + swamps | Biome changes list and rate |
| How many | Cap per category, scales with loaded area; per-player cap | `maxSpawns` per player; towns lower it |
| Leaving | Far = instant; mid range = small random chance after idle | Far off-screen = gone |
| World feel | Animals made with the chunk and stay; monsters topped up | Topped up |

## Our algorithm (where = Minecraft, when = Terraria)
1. **Every `tick_interval` (1 s):** pick one spot in the ring (off-screen, inside loaded chunks, on land, outside home / station safe radius, outside the boss land, clear of obstacles by their collision radius).
2. **For each enemy type:** `chance = base_chance x rate_for(biome at spot) x (spot_rate_mult if slime spot) x (1 - near / cap)`. First success spawns a pack (`pack_min..pack_max`) around the spot.
3. **Slime spots:** seeded grid (`spot_cell_size`, `spot_chance` ~10 %); same seed = same spots, so the player learns where slimes live.
4. **Residents:** when a chunk loads, each spot in it may get one pack (`resident_chance`), once per load. The world looks lived-in.
5. **Leaving:** far + idle -> random `despawn_chance` per second; very far -> at once. Never mid-fight, never hand-placed enemies.
6. **Never:** while the player is dead, while the boss is engaged, in a test run (unless the test turns it on).

## Types are data
One `data/enemies/<id>.tres` per type (`rate_<biome>` floats, stats, drops, pack size, `visual` with `tint`). A biome not listed = never spawns there. Tough biomes = rarer, tougher, better drops.

| Type | Biomes (rate) |
|---|---|
| slime | forest 1, plains 1, taiga 0.6, autumn 0.6 |
| swamp_slime | swamp 1.5 |
| sand_slime | beach_sand 0.4 |
| ice_slime | snowy 0.25 |
| rock_slime | rocky 0.25 |

## Tuning
All numbers are `@export`: F3 `EnemySpawner` + `Enemy <id> data`. F1 shows the ring, cap, safe / boss circles and slime spots.
