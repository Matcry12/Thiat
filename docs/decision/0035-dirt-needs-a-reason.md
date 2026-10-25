# 0035 — Dirt needs a reason

Changes the random forest dirt patches of [0033](0033-map-visuals.md). Map art stays Pixel Crawler only ([0034](0034-map-art-pixel-crawler-only.md)).

## Context
The forest had round dirt patches dropped at random (`dirt_patches` 0.25 per 100 forest cells). They looked like
stains: nothing in the world explained why the dirt was there. The user wants the map built Minecraft style, one
biome at a time, from the ready pack tiles.

## Decision
- **No random dirt.** `dirt_patches` defaults to 0 (the slider stays in F3 Map to compare).
- Dirt appears only where something explains it: an enemy area, the boss area, a set place (camp, paths), or
  ground the player makes (later).
- **The look for those dirt places** is saved, not built yet: dirt fill below, grass above with Pixel Crawler's own
  hole frame, the rimmed variant only (`Floors_Tiles` rows 0-4; rows 5-9 have no rim and must not be mixed in).
  Holes are rectangles, at least 2x2 cells, 3x3+ look best. Preview + the exact tile rules:
  `tools/asset_viewer/dirt_holes_preview.py` -> `docs/demo/dirt_holes_preview.png`.

## Why
- A ground feature without a reason reads as noise. Minecraft puts coarse dirt / paths where something made them.
- The pack's hole frame is the art the author drew for this; no new art code is needed.

- **Boss area = plain dirt** (`MapGen.AREA_GROUND`), pack colours, not the dark tinted "boss grass". The `boss_bright/warm/sat`
  sliders and `ground_boss.tres` no longer show on the island (remove them when the boss area gets its final look).
- One-biome preview: `tools/map_v2_shots.gd ... --grass-only` (whole island forest, no paths, no camp; dirt shore kept).

## Consequences
- Forest is plain grass outside the camp and the paths. Coast, paths, camp are unchanged for now.
- When enemy areas, the boss area or player-made ground get dirt, they use the hole frame from the preview script,
  and go through the piece-sheet check in `.claude/memory/mistakes.md` (2026-10-16) before going on the map.
