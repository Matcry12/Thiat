# Pickaxe structure (Terraria Copper/Iron/Silver/Gold 16x16 share one layout; Molten/Cactus same, scaled)
Measured from char grids (A = outline). Iron used for numbers; others identical within 1 px.
- Outline: FULL dark outline on all sides (top-left too). Every ref. -> we switch pickaxe to full outline.
- Handle: line x+y=15, from (0,15) to (10,5): ONE core px per row (staircase), flanked by 1 darker px each side
  = 3 px wide per row incl. flanks. Length visible ~11 rows. Bottom 2 rows = darker tip/grip. Passes UNDER head.
- Handle pokes 2 px past head top-right: cells (13..14, 1..2), x+y=15 -> handle end visible beyond head.
- Head = ONE band perpendicular to handle, centred on handle axis (ends at x+y=8 and 23, mid 15.5). Symmetric.
  Bounding box x6-15, y0-9 = 10x10 = ~60% of icon (not 1/3!). Handle meets head at band middle, rows 5-6.
- Head 3 parts (fill, excl. outline), iron rows:
  top arm  r1 x7-11, r2 x9-12, r3 x10-13, r4 x11-14: 4-5 px wide, shifts +1 px/row (45 deg), length 4 rows
  bend     r4-r5 (x14): right edge stops shifting; arm turns from 45deg to vertical
  down arm r5 x12-14, r6 x13-14, r7-r8 x14 (1-2 px), length 4 rows, nearly vertical, tip r9 x14
- Top arm tip: pointed, row0 outline cap only 3 px (x7-9), tip leans out left of the handle line.
- Thickness across band: ~4 px horizontal = ~2.8 px perpendicular; down arm thins to 2 then 1 px (taper to a point).
- Highlight: 1 px bright stripe along inside-top-left of the band (rows 1-4), darker 1 px on lower-right edge. Down arm mostly dark.
- Gap: handle core ends 1 px before head outline (row 5-6: empty px between handle flank and head outline).
- Tinkerlands (hotbar crop): same: arc over top, short flat tip left at top, hooks down on right, handle through middle.
- Copper_Hammer contrast: block head, no taper, both ends equal thickness, no hooked down arm, ends 90deg to handle.
RECIPE: 1px handle + flanks (x+y=15); head band len ~15 diag (x+y 8..23), 4px wide, top arm 45deg 4 rows,
 down arm vertical 4 rows tapering 3->1; full outline; stub of handle 2px past head top.
