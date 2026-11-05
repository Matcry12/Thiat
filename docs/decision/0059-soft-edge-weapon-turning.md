# 0059 - Weapon pictures turn with soft edges

## Context
Weapon pictures turn to any aim angle. With nearest sampling at 2 screen pixels per art pixel, the edges turned into saw teeth and the drawing seemed to change at each angle. The user compared turning methods on their own sword (`tools/art_tests/weapon_look/methods.png`). They do not want to redraw, shrink or edit their art. Short redraws, fixed poses and a closer camera were all shown and refused.

## Decision
- Pictures still turn freely, but a shader (`scripts/visual/soft_pixel.gdshader`) keeps each art pixel a solid square and blends only its border over about one screen pixel.
- It covers everything the player holds: the model's Art (weapons, tools, bow), the SwingArt copy, the swing ghosts and the held item icon (materials, placeables).
- `BodyRig.soft_edges` (default on) and `soft_edge_width` are the two F3 values. Off gives the old nearest look.
- Art files, weapon size and hit areas do not change.

## Why
It works on any existing or future weapon picture with no extra drawing. The user judged it in the real game and kept it.

## Consequences
- Sword pixels are still smaller than the body's. This fixes the turning, not the pixel size difference.
- The shader must replace `COLOR`, not multiply it, because `COLOR` already holds the nearest sample. The node's modulate is read in `vertex()`.
- Ghosts stay a pure tint when `ghost_white` is 1.
- The tests check the wiring only. Colours were measured from a render, so a colour bug in this shader would not fail a test.
