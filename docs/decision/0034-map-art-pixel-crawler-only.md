# 0034 — Map art: Pixel Crawler only

Supersedes the `grass_sv.tres` option in [0033](0033-map-visuals.md).

## Context
0033 kept two map styles: `grass.tres` (Pixel Crawler only) and `grass_sv.tres` (Serene Village ground
and trees + Pixel Crawler rocks/plants). The map asset viewer (`tools/asset_viewer/`) showed that
`grass_sv` mixes two creators. It also showed that `assets/world/trees_sv.png` is a mixed sheet: the Pixel
Crawler tree sheet with Serene Village trees pasted in the bottom row.

## Decision
All map art (ground, water, trees, rocks, plants, deco, stations) comes from **Pixel Crawler by Anokolisa**.
No Serene Village art is used on the map. The map rework builds on `grass.tres`.

## Why
- One art style: Serene Village's soft, low-outline art clashes with Pixel Crawler's outlined sprites.
- One license: Pixel Crawler needs no credit. Mixing in Serene Village (CC BY 4.0) forces a credit line.

## Consequences
- `grass_sv.tres`, `ground_sv_*.tres`, `tree_sv.tres`, `assets/map/sv_*.png` and `assets/world/trees_sv.png`
  are no longer used. Remove them in the rework. Keep `assets/third_party/serene_village/` as a downloaded pack.
- `grass_pc.tres` is the same as `grass.tres`. Remove it.
- If Pixel Crawler lacks a picture we need, draw it in the Pixel Crawler style (outline, palette). Do not take it from another pack.
- Use the creator filter in the asset viewer to check that new map art is Anokolisa only.
