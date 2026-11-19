# 0038 — Climate biomes on a 512x512 island, swimmable water

**Status:** Active

Extends [0037](0037-plains-forest-vegetation.md). Plan + sources: [world-gen-plan.md](../wiki/world-gen-plan.md),
[worldgen-biomes-water-research.md](../reference/worldgen-biomes-water-research.md). Demo: `tools/asset_viewer/world_preview.py`.

## Context
The island (200x120 cells) is split by distance from home into forest / rocky / boss. The user wants Minecraft-like
biomes that blend naturally, a world that feels big, and rivers and lakes. The demo showed climate noise gives 0
cold/warm clashes where random regions give 811.

## Decision
- **Biomes come from climate noise** (continentalness, temperature, humidity, roughness, domain-warped), picked by
  nearest point in a biome table. Biomes: Plains, Forest, Autumn forest, Taiga, Snowy taiga, Rocky hills, Swamp, Beach
  (sand warm / gravel cold), River, Lake, Ocean. Only Pixel Crawler art (0034).
- **Island first, 512x512 cells.** Ocean all around. Later the same climate maps can grow into a larger world.
- **Water is swimmable:** rivers and lakes do not block; in water the player moves slower and shows a water effect
  (ripples / splash, a slot node, swap later). Deep ocean beyond the shore stays the edge. Speed factor is an @export.
- **Chunks:** a 512x512 island is too many nodes to build at once, so the world is generated and loaded in chunks around
  the player (same seed -> same chunk; chopped trees remembered per chunk).
- **Boss site:** far from home, on cold / rocky land.

## Build steps (each playable, judged, previewed first)
1. Climate + biome map at today's size: biome per cell replaces the distance areas; ground fill per biome; F3 biome view.
2. Chunks + 512x512 default.
3. Water: rivers, lakes, beaches, swim slow + effect.
4. Biome content one by one (Taiga, Autumn, Snowy, Rocky, Swamp) with a preview picture each.
5. Set places: home, boss site, landmarks.

## Consequences
- The old forest / rocky / boss areas and their sliders go away; tests that check per-area counts are rewritten.
- Map seeds change again.

## Step 1 built (200x120, island shape unchanged)
- `MapGen._make_biomes`: temperature / humidity / roughness (domain-warped, ranked over the land, pulled mild around home) -> nearest point of `BIOME_TABLE` -> majority smooth, small patches absorbed, warm / cold clashes repaired, beaches (sand warm / gravel cold) near water. Plains | Forest | Autumn | Taiga | Snowy | Rocky | Swamp | Beach.
- Legacy Area derived from the biome (`BIOME_AREA`, marked ponytail: removed in step 4); FightZone stays BOSS.
- New grounds Sand and Snow (Pixel Crawler, edge shape from the dirt / grass window, coloured by the fills); each ground has its own layer (dirt 1, sand 2, cobble 3, snow 4, grass 5).
- Autumn / taiga / swamp = grass with a tint; autumn / taiga / snowy / swamp reuse the forest tree pass until step 4.
- Test: `MapGen.climate_clashes` = 0 over several seeds (tests/test_island_nodes.gd).
- Biomes are data: `BiomeData` (scripts/map/biome_data.gd), one .tres per biome in `data/biomes/`, listed in `MapStyle.biomes` in `MapGen.Biome` order. Holds climate points, temp class, ground, tree mode, legacy area, tint, map colour; F3 has a `Biome <label>` section each. Step 4 adds per-biome vegetation to this same resource.
- Boss land (area BOSS: boss ground, `density_boss`, no stations) = the fight zone grown by `boss_land_cells` (default 12), not just the zone rect.
- Tint saturation is stored x2 in the tint map alpha, so 0..2 works. Sand and snow use only their own biome tint, not the forest area tint.

## Step 2 built (chunks + 512x512 default)
- **World data is global, visuals + nodes are per chunk.** `MapGen.Result` (land, biome, ground ids, every tree / rock / prop placement, walk grid) is made once per map. `ChunkStreamer` (child of ArenaMap, `scripts/map/chunk_streamer.gd`) builds per chunk of `chunk_cells` (32) cells: the ground picture + foam (`GroundBaker.bake_region` -> `TerrainVisual.set_chunk`), the ResourceNodes / cover rocks, and the floor props (`ChunkDeco`: one `MultiMeshInstance2D` per prop sheet per chunk, a shader reads each picture's rectangle from INSTANCE_CUSTOM; one draw per sheet, no per-prop node). The water stays one big sprite; water collision, FightZone, boss, home and placed stations are not chunked.
- **Streaming rules.** Chunks within `load_radius` (2 = 5x5) of the player load, nearest first, `chunks_per_frame` (1) per frame; beyond `load_radius + unload_margin` (1) they are freed. The 3x3 around the player is built at once on rebuild, `teleport_player` and any jump of more than one chunk. Gathered / broken nodes are remembered by placement index (`ChunkStreamer.broken`): a chunk that comes back does not respawn them (a stump comes back as a stump, `ResourceNode.restore_broken`). `ArenaMap.nearest_node(id, to, prefix)` finds a node in the world data and loads its chunk (demo bot, shot tools). `load_all_chunks()` loads and pins all chunks (the whole-island overview of `tools/retired/map_v2_shots.gd`, tests).
- **Dual grid across chunks.** A corner tile looks at the 4 cells around it, so a chunk bakes the corner tiles [x0, x0+32) (+1 at the far map edge) from the cells one step out; a chunk picture equals the same pixels of the whole-map picture (tests/test_chunks.gd). Tint / shade maps are per chunk with a one-cell margin (shader uniforms `tile`, `map_cells`, `map_margin`). Dirt stamps are painted into every chunk they touch; discs are cached.
- **Global data is fast enough.** MapGen.generate at 512x512: ~49 s -> ~3.9 s headless (200x120: 1.44 s -> 0.38 s). Same maps (digests pinned, tests/test_map_gen_pins.gd): flat arrays instead of Vector2i / Dictionary per cell, span flood fill, walk grid kept and patched (not recomputed), incremental repair flood, buckets for deco spacing, packed-int biome majority. `Params.legacy_tiles` (ArenaMap: off above `legacy_tiles_max_cells` = 40000 cells) skips the old tile dictionaries and dirt patches, which the island picture never reads. `Result.timings` has the ms per stage (`tools/map_profile.gd`).
- **Climate periods** scaled ~2.5x for the 512 island (temp 300, humid 150, rough 100, warp 90 / amp 28), still `@export`.
- **Known limits.** A map slider that rebuilds the world (island, climate, biome fields) costs ~4 s at 512; look sliders re-bake only the loaded chunks. `blocks_boss_path` (station placing near the boss path) floods a 1M-sample grid, ~0.15 s per check at 512. Tiny lakes with a sand rectangle around them near home come from the step 1 beach rule (water step 3).

## Step 3 built (water)
- **Island shape = continentalness** (`MapGen._make_continent`): domain-warped noise (the climate warp, one shared field) mixed with one round blob, faded to ocean over `cont_edge_cells` from the map edge, plus a land ridge along the home -> boss line (`neck_*`) so the island always reaches both. Sea level = the quantile that gives `land_share`. Old `island_noise / falloff / threshold` are gone. Lengths are for 512 and shrink on smaller maps (`_world_scale`).
- **Rivers** = zero line of a ridge noise (`|n| / |grad n| < width`), inland only, wider towards the sea (`river_w_*`, `river_grow_dist`); a piece is kept only if it reaches the sea AND gets `river_inland_min` cells inland (no coast-hugging ditches) and has `river_min_cells`. **Lakes** = top `lake_share` of a lake noise on wet, inland, not-too-rough land. Home and the fight zone stay dry.
- **Shallow vs ocean.** `Result.land` is DRY land only (everything that places things reads it: trees, rocks, props, stations, biomes). `Result.shallow` (rivers, lakes, the first 1-2 ocean cells along the coast, ragged) is walkable water; `Result.walk_land` = dry + shallow is what the walk grid, the water collision, the repair floods and the prune read. Deep ocean is the only wall. `MapGen.WaterKind { NONE, OCEAN, SHALLOW }`, `MapGen.water_kind()`, `ArenaMap.water_kind_at(pos)`. `Result.fresh` = 1 river / 2 lake.
- **Shore + swamp are data.** `BiomeData.shore_ground` (dirt, sand for plains / autumn) is the ground of the 1-2 land cells around a river / lake (`Result.shore`); `BiomeData.fresh_pull_cells` + `fresh_humid_min / rough_max / temp_min / temp_max` let a biome take wet lowland near fresh water (swamp: 10 cells). Ocean beaches stay as in step 1.
- **Swim.** `Swimmer` (`scripts/components/swimmer.gd`) on the Player: feet in SHALLOW -> walk speed x `water_speed_scale` (0.55), signal `water_changed`. `WaterFx` (`scripts/visual/water_fx.gd`, under Visual) listens to it: a shader on the Body sprite tints the part below the waterline (y-sorts with the actor), ripple rings + splashes on the ground layer (z -1), shadow hidden (`SpriteActorVisual.set_shadow_hidden`). Dodge and attacks ignore it.
- **Look.** Shallow water is one more mask (`shallow_mask`, 1 px per cell, LINEAR) in the one big water shader: lighter / greener by `shallow_tint_*`. Shore edges and foam use the existing dual-grid edge windows (shallow = no ground tile). Chunk bakes unchanged (test_chunks). The ground tint map is now LINEAR (biome changes are a one-cell gradient, not square blocks). Trunks and station boxes are checked against every cell they overlap (`MapGen.circle_on_land`, `ArenaMap.rect_on_land`).
- **No ford.** Paths (off by default) never cross rivers; a ford was tried and dropped (the beach-distance rule kept both banks solid).
- **Pipeline order** (`_shape_island`): continent -> open -> connect / carve -> biomes (+ beaches) -> `_make_water` -> `_prune_unwalkable` (now on `walk_land`, also drops cells home cannot reach 4-neighbour) -> areas.
- World data at 512 x 512: ~3.2 s headless (step 2: 3.9 s on the same machine; the climate warp is computed once and the first prune is gone, which pays for the water). `shape.water` ~210 ms. Maps changed again: digests re-pinned for 0038 step 3.
- Known limits: rivers are one noise, so no real downhill flow (no source / delta); at 200 x 120 (tests) water is dense and swamp large; trees on the shore ring stand on sand / dirt (no shore rule for trees yet).

## Water v2 + World map (approved in the `tools/asset_viewer/world_preview.py` preview)
- **Rivers** are 3-5 cells wide (`river_w_inland / river_w_sea` = 1.5 / 2.5 half width). The `river_big_n` (2) longest pieces are widened to a 5-11 wide stretch (`river_big_w_*`): the widening grows outwards from the thin river through cells inside the big half width, up to `river_big_reach` (3) steps, so no loose specks. Widths shrink on a map smaller than 512 (x `max(world scale, 0.4)`).
- **Lakes** (`MapGen._make_lakes`) replace the old lake-noise quantile: `lake_big_n` (3) landmark lakes (radius 9.5-12.5, `lake_big_on_river` = 2 of them centred on a river) and `lake_pond_n` (30) ponds (radius 1.5-4, `lake_pond_wet_min` / `_wet_period`: they cluster where a wetness noise is high; `lake_pond_on_river` = 30 % sit next to a river). A pond is 1-3 merged stretched blobs; every edge is wobbled by noise (`lake_warp`, `lake_shape_period`). A lake over a river cell wins (fresh = 2). Counts and radii shrink on small maps (counts by area, never below 0.4 x). Removed: `lake_period`, `lake_share`.
- **Snowy shore** = snow ground (`snowy.tres` `shore_ground = 6`), no dirt rim.
- **Numbers**: world data 512 x 512 ~3.2 s headless, water stage ~210 ms (budget 4.5 s). Digests re-pinned for 0038 water v2 (test_map_gen_pins, test_ground_bake). test_water: every fresh body that holds a river reaches the sea, >= 12 lake bodies and 2 big ones per seed.
- **F3 Map section is grouped** (`@export_group`: Layout, Chunks, Flat map, Island, Water, Climate, Biomes, Vegetation, Looks, Scene wiring); `TuningPanel` reads the group entries of `get_property_list()` and prints a `[ Group ]` sub-heading. **World map** button (`WorldMapPanel`, `scripts/debug/world_map_panel.gd`): `GroundBaker.world_map_image` = 1 px per cell, shown at `map_width` (400 px) left of the tuning panel with home / boss / player markers; `ArenaMap.rebuilt` signal redraws it after every rebuild (so releasing a map slider shows the new world). Debug only.

## Step 4 built (biome content)
- **One vegetation table per biome, in data.** `BiomeData` (`data/biomes/*.tres`) now holds every number of what grows: tree table (6 rows of model / season / weight), tries, ring, density range, age rule + `max_stage` cap, tree groups, rock groups (sizes, boulder / medium / big weights, grey / brown), lone rocks and copper per 100 cells, bush / flower / foxglove / mushroom / tuft / fern / reed / snow-stump rates and patch numbers, and a second ground mixed by noise (`ground_alt`). F3 shows all of it under `Biome <label>` in groups and rebuilds on drag end (`TuningPanel`: a `BiomeData` slider is a heavy one; `tint_*` stays live). Port of the approved `tools/asset_viewer/biome_looks.py` table; the 0037 Plains / Forest numbers are in `plains.tres` / `forest.tres`, so one code path serves all biomes.
- **Removed:** `BiomeData.tree_mode` (replaced by `forest_role` open / wooded for the f blend and by `tree_tries`), `legacy_area` and the legacy ROCKY area (Area is boss land or FOREST), `Params.tree_tries_forest / tree_tries_plains / plains_ring / fir_share / fir_group_* / plains_old` (now per biome), `ResourceNodeData.density_rocky`. `density_forest` of the old `tree` kind only matters when `trees_on` is off.
- **Trees:** `MapGen._place_trees` loops biomes, one random stream per biome; a try picks a cell of its biome, fades by `f` at an open | wooded border and by local density d, rolls a tree row and an age (capped by `max_stage`). 61 tree nodes (`make_tree_nodes.py`: oak / fir / pine x green, yellow, orange, red, teal, dead, snow x age) with the sheets copied to `assets/game/world/trees/`. Same-biome rule: a group member that would land in another biome is dropped.
- **Rocks and copper:** rock groups are placed with the nodes (`_place_rock_groups`): medium / big pieces are `rock` nodes (mineable), boulders and small stones are deco. Lone rocks / copper by biome (`rock_nodes_per_100`, `copper_per_100`: copper in Rocky and Snowy).
- **Deco:** `BiomeVeg` (`scripts/map/biome_veg.gd`) runs after the ground: stones, bushes, flower patches, foxglove, mushrooms (tree shade), snow stumps, reeds (along water), tufts / ferns, one stream per pass. Result.deco is drawn by `ChunkDeco`; sprites from `PropSet.groups` (`prop_veg.tres`, `prop_rocks.tres`, `prop_stump_*.tres`, `make_veg_sets.py`). Rebuilding the ground drops only deco under paths / camp (`PropSet.any_ground`).
- **Rocky ground** = cobble and dirt mixed by noise (`ground_alt*`), through the existing dual-grid layers.
- **Fixed on the way:** `chunk_deco.gdshader` multiplied the picture with the whole sheet (COLOR already holds the sheet sampled at the quad's UV), so floor props showed only their dark outline pixels since step 2. It now replaces COLOR.
- **Numbers (512 x 512, seed 11, headless):** world data ~3.1 s (budget 4.5 s; step 3: 3.3-3.5 s; deco 0.12 s, was 0.46 s), 2916 nodes (2212 trees: 1175 green, 1037 yellow / orange / red / teal / dead / snow), 16.3k deco, chunk build avg 3.2 ms (max 22 ms), all 256 chunks 0.74 s. Maps changed: digests re-pinned for 0038 step 4.
- **Known limits:** props sit on the ground layer, so the player always walks over a bush (no collision, no y-sort); the autumn / taiga / swamp ground tints (step 1 values) are milder than the preview's; reeds / tufts are small and merge with a green ground (that is the art).
