# Item icons (temporary art + template)

Status (2026-10-25): user "acceptable". These are the **temporary** bag icons in the game now, and the
**template** for training an AI icon model later.

- In game: `assets/ui/placeholder/{pickaxe,copper_pickaxe,axe,copper_axe,sword,copper_sword,wooden_sword}.png`
  (16x16, loaded by `data/items/*.tres`; swapping a PNG needs no code change).
- Source: `tools/art_tests/items/icon_lab.py` (hand-placed 16x16 diagonal grids, tier = metal ramp swap;
  wood icons use their own pale ramp `WOOD_ICON`). Run `python3 icon_lab.py <out_dir>` from that folder.
- Template set: `tools/art_tests/items/icons_final/` (4 tools x iron / copper / stone / wood + `labeled.png`).
- Recipes (measured from references): `tools/art_tests/items/recipes/`.
- Held (in hand) sprites are separate: `tools/art_tests/items/draw_tools.py` (16 px wide, upright).

## Recipe in short
Full dark outline, 1 px handle core on the diagonal flanked by outline, cloth wrap at the bottom, light
top-left / dark bottom-right. Head ~55-60 % of the icon. Pickaxe head = arch across the handle top
(flat top arm, bend, short down arm); axe = small poll + waist + fanned edge; shovel = 4 px blade along the
handle, dark dish; sword = pointed blade with fuller, brass guard + blue gem, leather grip.

## How they were made
A drawer agent measured reference sprites (Terraria pickaxes / axes / swords, Minecraft shovels), wrote the
recipe, drew; a separate reviewer compared to the references and gave exact pixel edits. Guessing without
references failed ~8 rounds. Reference sprites are other games' art: study only, never shipped or committed.
