# 0046 — Ground levels: step vs flat borders, made from the pack's edge shapes

## Context
Pixel Plains has edge pieces for only two pairs (light grass on dirt, dark on light grass). New grounds (sand, snow, water)
were first made by recolouring dirt, which put every one of them BELOW grass: snow looked like holes cut in the grass, and
sand next to water had no art at all. Height between grounds is not a property of the material: beach sand is lower than
grass, but desert sand is level with it.

## Decision
- Every map cell has a **level** (data from the biome / area, tunable). Material priority only breaks ties.
- **Different level → step border:** the pack's `light_on_dirt` quarter shapes, the higher ground draws its outline +
  highlight, its shadow falls down-right onto the lower ground in the LOWER ground's shade colour.
- **Same level → flat border:** the same quarter shapes, no shadow; the outline pixels become the upper fill 8% darker
  (the "quiet edge", user pick 2b/5b of the border demo).
- **Flat beach (sand = water level):** outline pixels → animated white foam, shadow pixels → water (demo panel 3b).
- Snow lies on top of grass (step) at a biome edge; inside a snowy biome snow and grass are level (flat).
- Water for now: one flat shallow colour + foam dashes + bank band on top/left banks only; no deep area yet.

## Why
One rule makes every ground pair from the 16 pack edge cases the pack already has, so no new edge art is needed and every
edge keeps the pack's notch rhythm and corner cuts. It also fills the missing sand↔water edge.

## Consequences
- Prototype: `tools/art_tests/recolour/borders.py` (`border(upper, lower, mode, roles)` + layered dual-grid render),
  demo `borders_demo.png/gif`; `minimap.py` uses snow-on-top and flat water. Not in the game yet.
- The game's GroundBaker needs a per-cell level and a role-remap pass (pixel role → colour) when this is ported.
- Colours for sand outline / water shade / foam are first picks; tune by eye.
