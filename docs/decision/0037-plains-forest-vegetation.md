# 0037 — Plains + Forest biomes, Minecraft-style vegetation placement

**Status:** Active

Builds on [0026](0026-island-generator.md) (island areas), [0034](0034-map-art-pixel-crawler-only.md) (Pixel Crawler only),
[0035](0035-dirt-needs-a-reason.md). Rules: [vegetation-rules.md](../wiki/vegetation-rules.md). Research:
[worldgen-vegetation-research.md](../reference/worldgen-vegetation-research.md).

## Context
Trees were one small sprite, at least ~72 px apart, at a flat density per area: no real forest, no open field, and every
tree the same age. The user wants natural biomes "not too much, not too tight, not too empty", like Minecraft, built one
biome at a time. A $0 picture (`tools/asset_viewer/biome_preview.py` -> `docs/demo/biome_preview*.png`) was agreed first.

## Decision
- The home area (`Area.FOREST`) is split by one smooth noise `f` into two biomes: **Plains** and **Forest**. Rocky / boss
  areas are unchanged for now.
- Placement follows Minecraft: random tries per 16x16-cell block, a try that fails a check is dropped. Forest: only the
  trunk cell (+ 4 neighbours) is exclusive, crowns overlap. Plains: rare lone trees with a free ring.
  At the border each try's chance fades with `f`, so trees thin out as dots instead of a line.
- Trees come from the full Pixel Crawler tree set (catalog `data/maps/tree_catalog.json`): oak + fir, ages sapling ->
  young -> mature small -> mature -> old, picked by local `f` (old in the core, young at the edge, lone plains trees big).
- Every pass (trees, rocks, bushes, flowers, mushrooms, tufts) has its own random stream.
- Built in 3 playable steps: (1) biomes + aged trees, (2) flowers / tufts / mushrooms / bushes / rock groups,
  (3) HP by age + stumps (with [0036](0036-minecraft-gathering.md)).

## Why
Minecraft's data shows density, not shapes, makes biomes read naturally (plains ~200x sparser than forest, per-spot
biome checks). The pack already has every age of tree, so no new art is needed.

## Consequences
- Same seed gives a different map than before; the pinned obstacle hash in `tests/test_ground_bake.gd` is re-pinned once.
- More, bigger trees: tree collision is the trunk only (radius by age); walk checks (`_repair_reach`) still apply.
- F3 Map gets the biome and tree numbers; `[Map]` status shows the biome under the player and trees per age.
