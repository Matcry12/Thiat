# Vegetation placement research (Minecraft Java 1.21.x data + 2D practice)

Data: misode/mcmeta `data` branch (latest vanilla JSON; includes fallen trees / leaf litter, so 1.21.5+).
Base: https://github.com/misode/mcmeta/tree/data/data/minecraft/worldgen  (`placed_feature/`, `feature/`, `biome/`)
Chunk = 16x16 blocks. Tree = ~5-7 tall, canopy ~5x5 (similar to our 2-6 cell trees, so numbers port ~1:1 per 16x16 cells).

## 1. Trees per 16x16 area (placement attempts per chunk; actual < attempts, see 2.)
| Biome | Attempts/chunk | Variant mix (rolled in order, rest = default) | Source file |
|---|---|---|---|
| Plains / Sunflower plains | 0.05 (1 chunk in 20) | 33% fancy oak, 1.25% fallen oak, else oak | placed_feature/trees_plains, feature/trees_plains |
| Meadow | 0.01 (1 in 100, `rarity_filter` 100) | 50% fancy oak, 50% super birch | trees_meadow, meadow_trees |
| Forest | 10 (+10% chance of 11) | 20% birch, 10% fancy oak, 1.25% fallen oak, else oak | trees_birch_and_oak_leaf_litter |
| Birch forest | 10 (+10%) | birch only (1.25% fallen) | trees_birch |
| Flower forest | 6 (+10% -> 7) | 20% birch, 10% fancy oak, else oak | trees_flower_forest |
| Dark forest | 16 | 2.5% brown / 5% red huge mushroom, 67% dark oak (2x2 trunk), 20% birch, 10% fancy oak, else oak | dark_forest_vegetation |
| Taiga | 10 (+10%) | 33% pine, else spruce, 1.25% fallen | trees_taiga |
| Old-growth pine taiga | 10 (+10%) | ~31% mega pine, 33% pine, 2.6% mega spruce, else spruce | trees_old_growth_pine_taiga |
| Savanna | 1 (+10% -> 2) | 80% acacia, else oak | trees_savanna |
| Windswept hills / forest | 0.1 / 3 | - | trees_windswept_hills |
Density ratio: plains 0.05 : savanna 1 : flower forest 6 : forest/taiga 10 : dark forest 16. Plains is ~200x sparser than forest, not "forest minus a bit".

## 2. Pipeline (every tree feature, same order)
1. `count` (weighted_list, e.g. 10 w9 / 11 w1) or `rarity_filter` (1/N chance) = attempts per chunk.
2. `in_square` = each attempt gets a uniform random x,z inside the chunk (pure random, no grid, no Poisson).
3. `surface_water_depth_filter` max 0 = no trees in water.
4. `heightmap OCEAN_FLOOR` = snap to ground.
5. `biome` filter = attempt dies if the biome AT THAT SPOT does not list the feature (per-spot, not per-chunk).
6. `*_checked` = `would_survive(sapling)`: needs soil, free trunk cell, no solid block in trunk column. Canopies may overlap; trunks may not. Failed attempts are simply lost, so dense forests self-thin and leave holes.
Selector: `random_selector` tries each variant chance in order, falls to default. Sunflower plains and plains share trees_plains; difference is flowers only.
There is NO min-distance rule between trees, no noise density in trees (noise is used for flowers/grass: `noise_threshold_count`).

## 3. Flowers / bushes / rocks
| Thing | Rule | Source |
|---|---|---|
| Plains flowers | `noise_threshold_count` (noise cut -0.8: 15 below, 4 above) then `rarity_filter` 32; each patch = 64 tries, offset trapezoid +-6 xz (peaked at centre, so dense core, sparse rim) | placed_feature/flower_plains |
| Default flowers (forest) | 1/32 chunks, 64 tries, +-7 xz; poppy:dandelion 2:1 | flower_default |
| Meadow | every chunk, 96 tries, +-6 xz | flower_meadow |
| Flower forest | 3 patches x 1/2 chance per chunk, 96 tries, +-6 | flower_flower_forest |
| Forest tall flowers | 1/7 chunks, 0-1 clump (flower forest 0-3), 96 tries, +-7 | forest_flowers |
| Sunflower | 1/3 chunks, 96 tries, +-7 (sunflower plains) | patch_sunflower |
| Bush | 1/4 chunks, 24 tries, +-5 (plains, forest) | patch_bush |
| Mossy boulder | `forest_rock` count 2/chunk, `block_blob` of mossy cobblestone (blob radius grows from a seed, small blobs 1-3 blocks), only on forest_rock_can_place_on soil; old-growth taiga | forest_rock |
Patch trick: pick ONE centre, scatter N tries with trapezoid offset -> blob dense at centre, ragged edge, many tries fail (air check).

## 4. Why edges look natural from above (partly my inference from the data)
- Biome = smooth 6-noise climate (temperature, humidity, continentalness, erosion, weirdness, depth), 1.18+ blends borders: https://www.minecraft.net/en-us/article/minecraft-1-18-pre-release-1
- Biome filter is per spot: attempts are drawn chunk-wide, then kept only on matching ground. At a border you get random speckles whose count follows area share. No hard line, no blob outline.
- Forest 10/chunk is only ~4% of cells; failed `would_survive` + random overlap make clumps AND holes. Plains still gets a rare lone tree. Nothing is a regular grid.
- Variant mix is per tree, so birch/oak/fancy oak intermix instead of one-species patches.

## 5. 2D practice
- Red Blob: trees = blue noise; tree at local max of noise within radius R; vary R per biome for density: https://www.redblobgames.com/maps/terrain-from-noise/ . Prefer Poisson disc / jittered grid over high-freq Perlin.
- Variable-radius Poisson disk (accept if dist >= r1+r2; per-sample radius; boundary band; cluster mode): https://arxiv.org/pdf/2008.05567
- Density map from fBm noise x Poisson disk, plus separate exclusion density fields (paths, water): https://arxiv.org/pdf/2511.02417
- Place voids first, then plants in descending radius (big first, small fill gaps): https://arxiv.org/pdf/2111.06014 (AlphaGarden VARPOD)
- Succession (big core / small edge / saplings): no 2D game write-up found; derive from density map (rule 6).

## 6. Rules to copy (cell = 16 px, trees 2-6 cells tall)
1. Never grid, never blobs: roll N random attempts per 16x16 block, drop the ones that fail checks. [pipeline 1-2, MC placed_feature JSON]
2. Density per biome from the table: scrub/plains 0.05-1, open woodland ~6, forest ~10, dense ~16 attempts per 256 cells (about 0.3-6% of cells). Keep plains non-zero. [trees_plains vs trees_*]
3. Check biome at the attempt spot, not the chunk, so borders speckle. Blend biome weights with smooth noise. [`biome` modifier]
4. Fail attempts on blocked trunk cell / water / path / structure; do NOT add min-distance inside forest, only trunk exclusivity (canopies overlap, sort by y). [would_survive]
5. Pick species per tree with ordered chance list (20% / 10% / default) so mixes stay mixed. [random_selector]
6. Size by local density d (noise, 0-1): tree height = lerp(2..4 at edge, 4..6 core) + jitter; at d<0.3 spawn saplings (2 cells) and bushes, at d>0.7 tall trees. Add Red Blob R = base / d for spacing. [Red Blob R-per-biome; arxiv 2008.05567 radius per sample]
7. Clearings: before trees, stamp 1-3 void discs per ~40x40 cells (and around camp/path/boss arena); subtract from density. [VARPOD voids]
8. Flowers as patches: choose centre, 64-96 tries with triangular offset +-6 cells, only on free grass, ~1 patch per 8-32 chunks (higher in meadow = every chunk). [flower_plains/meadow]
9. Bushes: 1/4 chunks patch of 24 tries +-5, near forest edge/plains. [patch_bush]
10. Boulders: ~2 seeds per chunk only in rocky/taiga-like area, grow 1-3 cell blob on valid ground (mossy variant); use as clearing-edge decor. [forest_rock]
Caveat: Minecraft is 3D heightmap; heightmap/sapling soil checks map to "ground cell free" in 2D. Some figures (flower_plains noise branch) came via fetched JSON summaries; verify exact `noise_threshold_count` in the file before copying.
