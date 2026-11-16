# Vegetation rules (built, per biome)

**Status:** Current

Since 0038 step 4 every biome grows its own mix. **All numbers live in `BiomeData`** (`data/biomes/<biome>.tres`, script
`scripts/map/biome_data.gd`); F3 shows them under `Biome <label>`, grouped `[ Trees ]` `[ Rocks ]` `[ Bushes ]` `[ Flowers ]`
`[ Mushrooms and tufts ]` `[ Water edge and snow ]` `[ Ground mix ]`, and a slider rebuilds the map when you let go.
The shared numbers (border band, age numbers, clearings, density noise) are `ArenaMap` > Vegetation.
The look was agreed first in `tools/asset_viewer/biome_looks.py` (picture `docs/demo/biome_looks_sheet.png`, `world_full.py` for the island);
the game code is a port of that table. Based on Minecraft worldgen data ([research](../reference/worldgen-vegetation-research.md))
and the Pixel Crawler sprite catalog (`data/maps/tree_catalog.json`, picture `docs/demo/tree_catalog.png`).
"Block" = 16x16 cells. "Try" = one random spot; a try that fails a check is dropped, never moved.

## 1. The biomes (starting values, tune in F3)
| Biome | Trees (model, colour) | Per block: tries / groups | Extras |
|---|---|---|---|
| Plains | oak green, lone, 3 cells free | trees 0.5, rock groups 1, flower patches 0.8 (50 flowers), bushes 0.5 | grass tufts 1 per 16 cells |
| Forest | oak green 90%, fir green 10% (fir seeds groups of 3-5) | trees 14, rocks 0.5, bush patches 1 (6 tries), flowers 0.125 (only in clearings) | mushrooms 5 in tree shade, clearings |
| Taiga | fir green 65%, pine green 35% | trees 12, rocks 0.6, bushes 0.4, flowers 0.25 | mushrooms 10, ferns |
| Autumn | oak yellow / orange, pine yellow / orange / red | trees 10, rocks 0.3, bush patches 1 (yellow / orange / red) | mushrooms 6, brown + yellow tufts |
| Snowy | oak snow 40%, fir teal 40%, dead oak / fir | trees 6, rocks 0.5 | snow stumps 0.4, brown tufts (rare) |
| Rocky | dead pine / oak, mature or old only | trees 0.5, **rock groups 2.6 (2-5 medium / big)** | dead shrubs, brown tufts, stone + dirt ground |
| Swamp | oak green 60%, dead oak 40% | trees 4, foxglove clumps 0.5 | mushrooms 7, reeds along water, ferns |
| Beaches | nothing | | |

- **Where a biome starts** is the climate map (0038 step 1). A try only counts on a cell of its own biome; a plant only on its biome's own
  ground, never on a shore cell, a path / camp stamp, water or boss land. Tries per block are spread over the biome's cells of that block
  (a half-Plains block gets half the Plains tries). Tall things never stand on water or the shore ring; reeds are the exception.
- **Plains | wooded border** (`forest_role`): where an open biome (Plains) touches a wooded one (Forest, Taiga ...), the tree chance fades with
  `f` across `band_lo..band_hi`, so trees thin out as dots, never as a line. `f` also caps the local density there (young trees at the edge).
- **Local density d** = a smooth noise between `dens_lo` and `dens_hi` (period `veg_density_period`). It picks the age, gates bush patches
  (`bush_d_lo / hi`) and, with `fade_by_density`, thins tries.
- **Age**: `age_rule` 0 = forest rule (d > `age_core` 50% old, else mature; d > `age_mid` mature, 20% small; below: young 50%, sapling 30%,
  small 20%); 1 = fixed weights `age_w_*` (Plains 70% mature / 30% old; Rocky 60 / 40). `max_stage` (0 sapling .. 4 old) caps it: set pines to 3
  to stop them growing old later. A tree whose colour has no such age (dead firs have no saplings) takes the nearest age that exists.
- **Tree table**: up to 6 rows `treeN_model` (1 oak, 2 fir, 3 pine), `treeN_season` (0 green, 1 yellow, 2 orange, 3 red, 4 teal, 5 dead,
  6 snow), `treeN_weight`. Every combination the art has is a choppable node: `tree_<model>[_<season>]_<age>` (`make_tree_nodes.py`).
- **Rock groups**: a group = `rock_mid_min..max` middle pieces + `rock_small_min..max` small stones within `rock_spread`. Middle piece kind by
  weight: boulder (16 px, decoration), medium or big (a **rock node** you can mine). Group colour grey or brown (`rock_brown_share`). Lone mineable
  rocks by `rock_nodes_per_100`, copper by `copper_per_100` (Rocky, Snowy). Boss land keeps `density_boss`.
- **Peaked offset** (patches): add two random numbers (each -half..+half): most land near the centre, few at the rim, like Minecraft flower patches.
- **Tufts**: chance `tuft_p` per cell, x2 within 2 cells of a trunk or 1 of a rock. Weights pick tuft / fern in green / yellow / brown.
- **Ground**: Rocky mixes cobble and dirt by noise (`ground_alt`, `ground_alt_share`, `ground_alt_period`).

## 2. Order of passes
Big things first, small things fill around them. Each pass has its own random stream (adding a pass never moves another).
1. Clearings (forest-like biomes, 1 per 1600 cells, radius 3-5)
2. Trees, per biome (`MapGen._place_trees`, stream `SEED_TREE_BIOME + biome`)
3. Rock groups: mineable pieces in the node phase (`_place_rock_groups`), stones in `BiomeVeg`
4. Bushes, flower patches, foxglove, mushrooms, snow stumps, reeds, tufts (`scripts/map/biome_veg.gd`, drawn by `ChunkDeco`)

## 3. Art
Tree nodes: `data/resource_nodes/treepp_*.tres` (the Pixel Plains oaks; the old `tree_*` nodes, `prop_veg` and `prop_stump_*` are retired to `assets/retired/data/`). Floor props: `prop_rocks` and the `prop_pp_*` sets, sprites by
name in `PropSet.groups`. Props are on the ground layer (no collision, no y-sort with the player); within a chunk each sheet is drawn lowest-on-screen last.

## 4. Not covered yet
Fallen logs, seasons that change over time, player-planted saplings growing, props that collide (bushes), landmarks.
