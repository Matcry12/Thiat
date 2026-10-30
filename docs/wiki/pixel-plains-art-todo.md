# Pixel Plains — art you need to draw

The pack (SnowHex, free) has: light + dark grass, orange dirt with grass edges, pink/white flowers,
green tufts, boxy green/lime trees (4 sizes), 1 stump, logs, hedges. Everything below is missing.
Preview: `docs/demo/pixel_plains_preview.png` (grey boxes = missing). Re-run:
`godot --headless --script tools/pixel_plains_dump.gd -- <out.json> 11 75 256` then
`python3 tools/asset_viewer/pixel_plains_preview.py <out.json> docs/demo/pixel_plains_preview.png`.

16 px grid. "Edge block" = same 4x4-tile layout as the pack's dirt-on-grass block
(`New Basic Tiles Free.png`, tile col 8 row 6): fill, outer edges, outer corners, inner corners.

## Ground (edge block each)

| Piece | Used for | Draw |
|---|---|---|
| Deep water | Ocean | fill (2-3 variants) + edge block vs sand |
| Shallow water | Rivers, lakes, coast shallows | fill + edge block vs grass, vs sand, vs dirt (beach/lake dirt ring) |
| Sand | Beaches, lake/coast shore | fill + edge block vs grass |
| Snow | Snowy biome | fill + edge block vs grass |
| Cobble | Paths, camp | fill + edge block vs grass |
| Boss ground | Boss arena | fill + edge block vs grass |

Grass/dirt are COMPLETE (16/16 cases each, table in `tools/asset_viewer/pixel_plains_tiles.py`,
picture `docs/demo/pixel_plains_ground_table.png`). Layer order dirt < light grass < dark grass;
map rule: dark grass never touches dirt — a 1-cell light grass ring between them (not art to draw).
New grounds should follow the same pattern: one edge block per neighbouring layer only.

## Trees (5 ages each: sapling, young, small, mature, old; dead = small, mature, old only)

| Model | Pack has | Draw |
|---|---|---|
| Oak (boxy) | green | orange, yellow, snow, dead |
| Fir | — | green, teal, dead |
| Pine | — | green, orange, red, yellow, dead |
| Stumps | 1 stump | 3 sizes x oak / fir / pine (9) |

Total new trees: 4x5-2 + 3x5-2 + 5x5-2 = 54 sprites (+ snow stump).

## Rocks

| Piece | Used for | Draw |
|---|---|---|
| Rock node | Mine for stone | 1 (~1 tile) |
| Copper ore rock | Mine for copper | 1 (~1 tile) |
| Cover rocks / boulders | Block movement | grey + brown, a few each |
| Small stones | Ground deco | grey + brown, a few each |

## Small plants (count = variants the game picks from)

| Group | Pack has | Draw |
|---|---|---|
| bush_green | hedge piece | 2 |
| bush_yellow / orange / red | — | 2 each |
| deadbush | — | 2 |
| flower_0..3 (orange, white, blue, yellow) | pink + white | 5 per colour |
| foxglove | — | 3 |
| mushroom | — | 4 |
| tuft_green | ~7 | up to 17 (fewer is fine) |
| tuft_yellow / tuft_brown | — | a few each |
| fern green / yellow / brown | — | 3 each |
| reed green / yellow / brown | — | 3 each |

Also: map border bushes (`MapStyle.border`), campfire — current art still works, swap later.
