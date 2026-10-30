# 0047 — Ground is all flat (supersedes the level part of 0046)

## Context
0046 gave every cell a level: different levels = step border (outline + shadow), same level = flat border.
On the real map (seed 11) the steps looked chaotic: dark outlines and shadows everywhere, edges that read as glitches.

## Decision
All cells sit on one level. Every border is a flat border; sand next to water is a flat beach with foam.
The level code stays behind one switch, `PixelPlainsGround.all_flat` (default `true`, F3 → Levels).

## Why
User compared levels vs flat (docs/wiki/shots/all-flat/compare.png) and a flat mini map mockup
(tools/art_tests/recolour/flat_minimap.png) and picked flat.

## Consequences
- The pack's own raised-edge pairs (dark / light grass, grass / dirt) are flat too: every mixed corner goes through the flat compose path (tile sheet docs/wiki/shots/all-flat/tileset.png).
- No step shadows, no sand banks, no snow-edge steps on the map. The `level_*` exports only matter with `all_flat` off.
- Tests keep checking the level rules with `all_flat = false`, so the steps still work if we want them back (e.g. for cliffs).
