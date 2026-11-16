# 0045 — Island Workshop UI in the game; crafting book with a Craft button (supersedes the UI part of 0031)

**Status:** Active

## Context
The Island Workshop style (0043) existed only as a web mockup. It was ported to Godot: our pixel
fonts, baked PNG parts, title / pause / settings, HUD, bag + crafting book, tooltip and the F3 dock.
The approved book design has a right page with a `< n >` count and a `Craft` button. That is not the
0031 rule "click a lit icon = the item lands on the cursor". The user chose the book design (2026-10-26).

## Decision
- **Crafting:** clicking a recipe icon only chooses it. `Craft` makes the chosen count onto the cursor
  (the same held-stack rules as 0031); shift + `Craft` sends it straight into the bag. The button is lit
  only when the Crafter would really make it. Side tabs Craft / Furnace / Anvil are dimmed when that
  station is not near. The rest of 0031 (stations, placing, furnace, Crafter decides) is unchanged.
- **Art pipeline:** `tools/ui_bake/*` bakes the mockup's drawing code to `assets/game/ui/skin/` and
  `assets/dev/ui/f3/` (+ `slices.json` for margins). Fonts go to `assets/game/ui/fonts/` (BMFont, `UiFonts`).
  Bakes are deterministic. Screens read textures from `InventorySkin` slots and margins from `slices.json`.
- **One helper:** `scripts/ui/pixel_art.gd` (nearest 2x upscale with one cache, 9-slice, pixel labels).
  Every screen uses it.
- **Scale:** integer only (art_scale 2 at 1152x648); text outline is one skin colour and size.
- **Fonts:** pixel fonts for titles, tabs, buttons and short labels. F3's dense text (names, numbers,
  status) uses a clean font (user: the pixel font is hard to read there).

## Why
- The user approved the book look and picked the Craft button over the older click-to-cursor rule.
- Baking from the mockup keeps the game and the mockup the same; a rebake cannot drift because
  margins come from `slices.json`, not hand-copied numbers.

## Consequences
- A new screen: design it in `tools/ui_mock/`, add parts to the bake, use `PixelArt` + skin slots.
- Rebake after changing the mockup, then `godot --headless --import`.
- The old placeholder skin fields (flat colours, bar sizes) are removed; F3 shows only live ones.
