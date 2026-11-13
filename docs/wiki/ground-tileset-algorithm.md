# Ground tile-set algorithm

How every ground pixel on screen comes from a picture you can redraw. Today the borders, the beach foam and the water are drawn in code
(`PixelPlainsBaker._compose`, `terrain_anim.gdshader`, `terrain_water_flat.gdshader`), so those pixels are in no file. Decisions: [0046](../decision/0046-ground-levels-and-borders.md),
[0047](../decision/0047-ground-all-flat.md). Code: `scripts/map/pixel_plains_baker.gd`. Rule: CLAUDE.md 5 (build for replacement).

## Sources
| Question | Terraria | Stardew Valley | RPG Maker MV/MZ | Godot 4 terrains / dual grid / Wang |
|---|---|---|---|---|
| Who picks the tile | Code ("tile framing"): looks at 8 neighbours, picks a frame on the sheet | The map maker, by hand in Tiled | Editor autotile: 4 quarter tiles chosen from neighbours | TileSet terrain "Match Corners and Sides" (47 blob) or "Match Corners" (16); dual grid (jess::codes "Draw fewer tiles", Townscaper): a tile sits on the corner of 4 cells, 16 shapes |
| Many grounds | Most sheets have "merge with dirt" frames; other pairs just touch | One hand-drawn transition tile per pair | Layers: the upper autotile has alpha, the lower one shows through | One tile per combination grows fast, so people use one layer per terrain, drawn in order (layered dual grid) |
| Variants | 3 random frames per shape | Hand-placed | None (one per shape) | Several tiles per shape, picked by probability |
| Animated water / shore | Liquid sheets, frames drawn by code | Water frames from a sheet, cycled by code | A1 water autotiles: 3 frames side by side on the sheet | Atlas animation: frame columns on the sheet |
| Code vs art | Code picks, every pixel is in a sheet | Same | Same | Same |

All four agree: **code picks which tile and which frame, every pixel is in a picture.** We take the layered dual grid (16 corner shapes,
one set per ground, drawn in priority order). It is exactly what `_compose()` already does, so the first version can be baked from it.

## What is on screen today (all_flat = true)
| Thing | Drawn by | In a picture? |
|---|---|---|
| Corner of one ground (fill) | `_fill`: a cell of `ground/<g>.png`, hash picks plain / variant | yes |
| Corner of 2-4 grounds | `_compose`: lowest ground = flat fill colour; each higher ground = pack `light_on_dirt` shape, roles fill / highlight → fill, outline → fill 8% darker; colours from the swatch | **no** |
| Sand over water (beach) | same, outline → sand fill + foam mask, shadow → water colour | **no** |
| Beach foam | `terrain_anim.gdshader` kind 1: lit if `(x+y-f) mod 8 < 6`, 8 frames | **no** |
| Shore water | kind 3: flat water colour | **no** |
| Open water + wave marks | `terrain_water_flat.gdshader`: flat colour, marks by a float `sin` hash per 32 px block | **no** |
| Foam dashes, bank band, steps | `_dash`, band code, step roles | **not on screen**: they need `water_step` / different levels, never true with all_flat (test: "no dashes") |

## Our rules
**1. Pictures (one set per ground).** In each `ground/<g>.png` (dirt, grass_light, grass_dark, sand, snow) an edge block sits in the free cells (0..3, 1..4).
Slot `s` = cell (s % 4, 1 + s / 4). `s` = corner mask: NW 1, NE 2, SW 4, SE 8. A bit is set when that cell is **this ground or a higher one**.

| Slot | Meaning |
|---|---|
| 0 | empty (never used) |
| 1..14 | edge overlay: this ground's shape; alpha 0 = what is below shows |
| 15 | base: this ground when it is the lowest in a mixed corner (today a flat fill) |

Cobble and gravel have no edge block: their borders use dirt / sand, as today.

| File | Layout | Pixels |
|---|---|---|
| `ground/foam.png` | 8 frames left to right, each a 4×4 block of 16 px slots (512×64); slot = sand mask | foam colour where lit, else transparent |
| `ground/water.png` | cell (0,0) = flat water (base in mixed corners, and open water with no mark); below it, one row per mark variant: 8 frames of 32×32 (256 wide) | every water pixel |

**2. Priority.** water 1 < sand 2 < dirt 3 < light 4 < dark 5 < snow 6 (`prio_*`, data). Sand is only ever above water, so the sand set is always a beach set.

**3. One corner (4 cells, NW NE SW SE).**

| Case | What is drawn |
|---|---|
| 4 × same land | fill tile, unchanged (`hash(corner, seed + 100 + ground)` picks plain / variant) |
| 4 × water | nothing; the water sprite shows |
| 2-4 grounds | sort grounds by priority → slot 15 of the lowest → for each higher ground g: slot[mask of cells with prio ≥ g] of g, drawn over it (overwrite where alpha > 0). Sand also writes its foam slot into the animation mask; a later layer that draws a pixel clears its foam |

Possible mixed corners: 6⁴ − 6 = 1290. All of them are built from 5 × 14 edge tiles + 6 base tiles + 14 × 8 foam tiles. The cache key stays the same `Vector4i`.
`land` (used by `drawn_land_at` → swimming / spawning) = pixels drawn by a non-water layer, as today.

**4. Borders by kind.**

| Kind | Today | Tiles |
|---|---|---|
| flat (land / land) | quiet outline | the upper ground's slots 1..14 (does not depend on the lower ground) |
| foam (sand / water) | outline = sand fill + foam, shadow = water | sand slots 1..14 (shadow pixels left transparent: water base below is the same colour) + `foam.png` |
| step | only with all_flat off | not baked. If cliffs come back: one more set per ground with shadow, own decision |

**5. Animation.** Frame `f = floor(TIME × anim_fps) mod 8`, as today.
- Foam: animation mask pixel = (R 1, G, B = x, y of the pixel in frame 0 of `foam.png`). The shader samples `foam.png` at x + f × 64. The pattern is tile-local (tiles start on multiples of 16), so 8 frames per slot are exact.
- Water: the water sprite shader samples `water.png`. Block = 32 px aligned to the tile grid (as today). `h = int hash(block, seed)`; mark if `h % 1000 < chance × 1000`; variant = `(h >> 10) % K`; phase = `(h >> 20) & 3`; frame = `(f + 2 × phase) mod 8`. K = number of rows in the picture: add a row, get a variant.
- Mixed corners draw the flat water slot, so marks stay off the shore (today: kind 3).

**6. Code vs picture.** Code: which corner, which ground order, mask, fill hash, mark hash, frame number, `land`. Picture: every pixel colour, including foam colour and mark brightness.
Exports that only fed code colours (`quiet_darken`, `foam_colour`, `beach_foam_lit`, `mark_light_*`, `water_hl/outline/shade`) are read once by the bake tool, then removed from the game. The swatch stays the bake tool's input only.

## Bake the current look once
`tools/bake_ground_art.gd -- tiles` (new mode). It only writes the new slots, `foam.png` and `water.png`; fill cells are never touched.
1. Refactor first: split `_compose` into `_layer(ground, mask) → {img, foam}` plus stacking. The old whole-island hash (`_ground_hash_tmp.gd`, seeds 1/11/42) must not change.
2. The tool writes `_layer()` output into slots 1..14, a flat fill into slot 15, and the foam rule `(x+y-f) mod 8 < beach_foam_lit` × 8 frames into `foam.png`.
3. Water: flat slot = `water_fill`. Mark variants: 16 rows drawn by the same rule (position, length 3-5, shift, light a/b per frame).

| Part | Pixel-identical? |
|---|---|
| Edges, base tiles, beach foam (all 8 frames), shore water | **yes, on screen**. The ground image changes (water base now opaque), so the old hash changes; use the screen hash below |
| Open-water wave marks | **no**. Today's hash is GPU float `sin()`, can't be copied on CPU and may differ between GPUs. Closest: same density, length and animation; positions come from 16 variants |
| Dashes, band, steps | not on screen today, nothing to match |

## Biomes later
`assets/game/map/pixel_plains/biomes/<biome>/ground/*.png` (+ `foam.png`, `water.png`), same layout. Each file falls back to the base folder when it is missing.
Each layer of a corner takes the biome of the first cell (NW, NE, SW, SE) holding that ground; fill tiles take the NW cell. The cache key gains the biome.

## F3 / F1
- F3 → Pixel Plains → "Reload ground pictures". Reads the PNGs with `Image.load_from_file` (no editor re-import needed), clears the cache and rebuilds the chunks.
- F3 cell report (`report()`): adds the corner's layers, e.g. `water base | sand slot 6 + foam | light slot 4`.
- F1 slot numbers over tiles: skipped; add it if redrawing shows a need.

## Test plan
| Check | How |
|---|---|
| Refactor is pure | old whole-island hash identical before / after step 1 |
| Screen identical | new `tools/ground_screen_hash.gd`: per chunk start with water colour, put the ground image over it, add lit foam for frame f; 3 seeds × 8 frames = 24 hashes. Old decoder (kinds 1/2/3) on HEAD = new decoder (foam.png) after the switch |
| Pixels come from the picture | test: paint one pixel of light slot 6 in memory, the corner with mask 6 shows it |
| Seams | existing "four pieces equal the whole" test, kept |
| Land | `drawn_land_at` agrees with layer alpha on a beach corner |
| Sheets | existing "sheets load" test + the new files |

## Risks
- Tile count is small (70 + 6 + 112 + 16×8). A redraw must keep alpha 0 where the lower ground should show, or it covers it.
- Foam colour via shader uniform vs PNG pixel: both 8-bit sRGB, expected equal; one screenshot compare to be sure.
- Re-running `-- tiles` overwrites hand-drawn slots (same warning as today's tool).
- Biome lines will look hard (no blend) at biome borders.

## Files that change
`scripts/map/pixel_plains_baker.gd`, `scripts/map/pixel_plains_ground.gd`, `scripts/map/terrain_anim.gdshader`, `scripts/map/terrain_water_flat.gdshader`,
`scripts/map/terrain_visual.gd`, `data/maps/ground_pixel_plains.tres`, `tools/bake_ground_art.gd`, new `tools/ground_screen_hash.gd`,
`assets/game/map/pixel_plains/ground/*.png` + `foam.png` + `water.png`, `assets/game/map/pixel_plains/README.md`, `tests/test_pixel_plains_ground.gd`, a new decision record (next free number).
