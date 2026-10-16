# 0033 - Map visuals: baked ground, real shore, paths (looks only)

## Context
The island (0026) looked flat: square cell borders, big square dirt blocks, flat water, orange trees in the
green forest. The pack has no shore tiles and no tiles for blobs, only bumpy "hole" frames for rectangles.

## Decision
- **Ground is baked into one picture** (`GroundBaker`) from `MapGen.Result.ground` (a smoothed ground id per cell:
  water / dirt / cobble / grass / boss grass). `TerrainVisual` shows it with three shaders: water (shimmer),
  ground (tint map), foam (pulse). Old TileMap layers are used only when `island_on` is off or a style has no `grounds`.
- **Edges: dual grid (marching squares), one straight edge per pack.** A display tile sits on each cell corner and reads the 4 cells
  around it (16 cases) per layer (dirt 1, cobble 2, grass 3). `GroundData.edge_window` is a 16x16 window of the pack's own sheet
  with the ground on top and the other ground below (border at row 8); it is made mirror symmetric (so neighbours always
  match), rotated for the 4 half planes, and the other cases are alpha AND (one quadrant), OR (three quadrants, diagonals) of
  those. Shape and colour always come from the same pack (`edge_from_fills` only inside one pack). Serene Village's sheet is opaque,
  so its ground is keyed by green pixels (`edge_key`). Seams are tested on pixels: `tests/test_ground_seams.gd`.
  Test picture of every pair/shape: `docs/demo/map_v2_tile_test.png` (`tools/map_v2_tile_test.gd`).
  The first version (per-cell ring tiles + corner pieces, PC shapes with SV colours) produced notches and wrong-way pieces and was removed.
  Coast = dirt layer over water; foam mask made from the piece.
- **Smoothing** (`smooth_passes`) removes 1-cell strips, spikes and checkerboards on the visual ground only.
- **Dirt is stamps, not tiles**: patches, camp and paths are round pixel stamps (`result.dirt_stamps`) painted over the tiles in 3 passes (light rim, dark rim, dirt), so a diagonal path has no stair teeth. A* path smoothed with Chaikin, 3 cells wide.
- **Look-only settings** (paths, camp, patches, smoothing, beach, GroundData edits) re-bake only the ground (`rebuild_ground`); trees, stations and chops stay. Tint = nearest-filtered area tint (follows the smoothed ground) x linear shade map; master `ground_brightness` / `ground_saturation` in the shader (F3 Map). 0.8 / 0.85 was tried to make characters stand out; **the user chose the original look: default 1.0 / 1.0** (`docs/demo/map_v2_brightness.png` shows both). Boss area tuned at 1.0: `boss_bright` 0.7, `boss_sat` 0.3, `boss_warm` 0.22 (grey-brown dead look).
- **Tests**: `test_ground_seams` (pixel seams of all 16 cases, dirt fills hold no grass), `test_ground_bake` (no water cell shows land at its centre, pinned obstacle hash per seed).
- **Paths (old note)**: A* (AStarGrid2D) home -> boss zone, trees and rocks expensive, noise wander; painted on forest grass only; plus
  branches to the rocky border, a camp clearing, a few small organic dirt patches. **Look only**: no speed bonus, blocks nothing,
  walk grid and node placement never read them.
- **Data, not code**: `GroundData` (fills, edge frame, `edge_texture`/`edge_from_fills` = one pack's colours in another pack's
  edge shape), `PropSet.area_weights` (deco per area), `ResourceNodeData.looks_forest/rocky/boss` + `extra_regions`.
  Styles: `data/maps/grass.tres` (default, Pixel Crawler only; `grass_pc.tres` is an identical copy) and `grass_sv.tres` (Serene Village forest/coast/trees + Pixel Crawler rocky/boss). Judge and author found PC-only more cohesive; the user picks.
- Seed safety: the new ground uses its own random stream (seed + 101); legacy patches / `result.dirt` / `result.grass` are still
  generated (they burn the same random numbers, so trees, rocks and spots are identical for a seed). Looks of nodes are picked after placement.

## Why
Cheap (build 812 -> ~1000-1200 ms headless, budget 2000), every look number is `@export` in F3 Map, and a new pack is data.

## Consequences
- Shore bump sits about 5 art px (10 screen px) inside the last land cell; water collision is unchanged, so you can stand a
  hair over the visible waterline. Looks only.
- Legacy `result.dirt/grass/patches` are dead weight on the island (kept for tests / non-island map).
- Serene Village has no inner-corner / blob frames and its soft low-outline art clashes with Pixel Crawler's outlined sprites
  (rocks, bushes, player). SV colours reuse PC edge shapes. Water waves sheet and SV deco are not used yet. Credit: `docs/wiki/credits.md`.
- First build also fills a piece cache (one-time ~100 ms).
