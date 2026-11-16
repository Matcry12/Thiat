# 0069 - Ground tile set: every border, foam and water pixel is in a picture

**Status:** Active

## Context
Borders between grounds, the beach foam and the water were drawn by code (`PixelPlainsBaker._compose`, two shaders, ~30 colour / number exports). Those pixels were in no file, so an artist could not redraw them (CLAUDE.md rule 5). Plan and sources: `docs/wiki/ground-tileset-algorithm.md`.

## Decision
- Layered dual grid: each ground sheet (`ground/<g>.png`, dirt .. snow) holds 14 edge tiles + a flat base tile in its free cells (0..3, rows 1..4), slot = corner mask. `ground/foam.png` holds 8 foam frames per sand mask, `ground/water.png` the flat water cell and 16 wave-mark variants (8 frames each).
- `_compose` only stacks pictures: lowest ground = base slot (water: the flat cell), each higher ground (by priority) = its edge slot over it. Code still picks which tile, the ground order, the fill hash, the mark hash, the frame. The colours, the foam pattern and the marks are pixels.
- `tools/bake_ground_art.gd -- tiles` drew the pictures once from the old look (`PixelPlainsBaker._layer`); its numbers (quiet darken, foam colour, lit pixels, mark lightness) are constants of that tool only.
- Deleted: steps (levels, `level_*`, `border_kind`), bank band, foam dashes, ~30 exports (`quiet_darken`, `water_*`, `foam_colour`, `band_*`, `beach_foam_lit`, `dash_*`, `mark_len/light/block`). `all_flat` stays only so the python reference test can still ask for the pack's own pairs. Under an edge the lower ground is a flat colour (slot 15), so version 1 looks the same.
- Open-water wave marks moved to new spots (16 variants, same density, length, 8-frame loop): the old GPU float `sin()` hash cannot be copied.
- F3 > Pixel Plains > "Reload ground pictures" reads the PNGs from disk; F3 `[Map]` cell report shows the corner's layers.

## Why
Same as Terraria / Stardew / RPG Maker: code picks the tile, every pixel is in a sheet. Redrawing a border or the water is now a swap, not a rewrite.

## Consequences
- Screen is pixel-identical (`tools/ground_screen_hash.gd`, 24 hashes, wave marks excluded) except the wave marks. The ground image itself changed: water base is now opaque in mixed corners.
- Re-running `-- tiles` overwrites hand-drawn slots.
- If cliffs / steps come back: a new set of sheets with shadow, own decision.
- Per-biome ground is built: `biomes/<biome>/ground/*` via `BiomeArt`, per-file fallback to the base folder, the corner cache key carries each cell's biome. The open-water shader stays base-only.
