# In-game UI review (Island Workshop port)

## F3 round 1

Compared game_shots/1..7 with shots_workshop/b_*. Zoom crops: nearest 2x. Scaling itself is OK: parts are whole-texel 2x
nearest (f3_theme.gd `tex`/`box`), no blur. The ugliness comes from layout, the pixel font on buttons, and the frame top.

| Shot | Target | Score | Main problems |
|---|---|---|---|
| 1_default | b_tune_bodyrig | 5 | Empty plank 0-60 px on top; `Collapse` button jammed under the tabs; "2327 settings" line wastes a row; footer buttons overflow |
| 2_bodyrig | b_tune_bodyrig | 4 | BodyRig is not open: shot shows the same as 1 (Player open). Shot proves nothing. Rows have no slider on most numbers |
| 3_search_hand | b_search_hand | 6 | Clean, roomy rows - good. No match highlight, no "N actions · N status · N settings" line, sliders missing on number rows |
| 4_actions | b_actions | 5 | Pixel label text wider than the button art (caps cut, "Biome map  off" text runs over edge); empty band above Run; no pin star; seed field plain |
| 5_status | b_status | 6 | Readable body text (user wish, good). `On game` chip text overflows chip; pin icons faint; header summaries tiny + grey, hard to read |
| 6_watch_only | b_watch_only | 6 | Card is a flat rounded rect, not the organic plank edge; fine readable text; good |
| 7_map_rebuilt | b_map_heavy | 5 | Banner is a flat yellow bar (mock: plank note with icon); Map rows cut off, group label "LAYOUT" floats with no rows visible; Collapse jam again |

### Fix list (ranked)

1. **Empty plank on top of the dock.** dock_frame.png's header plank is drawn as a separate empty strip, the search sits under it.
   Mock: the search field IS inside the top plank. Fix in dock.gd layout: put the search box into the plank area
   (content_margin_top of the frame = plank inner top, not below it) or bake a frame with a thin top rail. Gains ~50 px.
2. **Pixel-font button text overflows its art** (Write 1, Clear, Kill player, Biome map off, On game, Collapse). Text is
   the Bold pixel font with outline 2 at 2x; button content margins are smaller than the caps. In f3_theme.gd `_button`:
   use the button part's slices.json content margins + 4 px side padding, set `outline_size` 1 (mock uses a 1 px dark
   edge, not a fat one), and let buttons size to text (no fixed min width). Never clip text.
3. **Pixel font outline too heavy everywhere** (tabs, headers, buttons look bold+blurred blob vs mock's crisp 1 px).
   Lower outline to 1 at 2x or drop outline on light-on-dark bands, keep it only on cream buttons.
4. **`Collapse` button jammed under tabs, overlapping the tab bar bottom.** Move it into the count line ("2327 settings ...
   Collapse all") as a small text-link / chip, right aligned, with 6 px gap below tabs. dock.gd tab header row.
5. **Sliders missing on number rows** (only hand_radius has one). Mock: every ranged number = field + slider. prop_row.gd:
   show slider whenever a range hint or a sane default range exists (min..max from hint, else 0..2x value).
6. **Shot 2 is wrong**: open Character > BodyRig in the shot script, else the main target is untested.
7. **Rebuild banner and toast are flat boxes** (7, and the top-centre card in 1-7). Use the note.png / banner.png
   9-slice with the organic edge, as in the mock. Same for watch card in 6.
8. **Wasted rows**: empty band above `Run` in Actions; "LAYOUT" group label stuck at the bottom with no row (needs
   keep-with-next). Small: add `min rows after a group header = 1` or scroll the header with its first row.
9. **Header right-side summaries** (fps, wooden_sword, 8 SECTIONS) are tiny grey on brown - lift to `muted` cream
   colour at body size -1, not dim.
10. **Search: no match highlight** in names (mock greens the matched part). Keep the clean font, colour the match.

### Shared cause for the port builders (menus / HUD / book)

- Do NOT size 9-slice parts by stretching pixel-font text into fixed art: let the container grow from content margins
  in slices.json. Every overflow above is "fixed-size art + text that does not fit".
- Keep whole-integer scale (2x nearest) - that part is right; do not change it.
- Pixel font: headers/tabs/buttons only, outline 1. Body text: the clean font (user wish).
- Organic-edge parts (planks, notes, banners) must be the baked texture, never a StyleBoxFlat rounded rect.
- Check every shot actually shows the state it is named after.

## Menus round 1

Ports are close to the targets: same layout, crisp 2x nearest, baked planks/corners used, no seams, no blur.
What is left is mostly text outline and one value bug.

| Shot | Target | Score | Main problems |
|---|---|---|---|
| port_title | title.png | 8 | Button labels: outline darker and about 1 px fatter than mock; "Continue" disabled text too dark (mock: soft muted brown on grey) |
| port_pause | pause.png | 8 | Same header/button outline weight; otherwise matches |
| port_settings | settings.png | 7 | **Shake shows 100% with the knob at half** (mock: 50%); checkbox shown empty (known); header outline heavy |

### Fix list (ranked)

1. **Shake % is wrong.** settings_panel.gd:138 prints `current_shake * 100`, but the slider goes 0..`shake_max` (2.0),
   so 1.0 = knob at middle = "100%". Show the slider position: `value / shake_max * 100` (or make the slider 0..1 and
   scale in GameSettings). The player reads "100%" and thinks shake is max.
2. **Outline too heavy and too dark** on headers ("Paused", "Settings") and button labels. menu_screen.gd `label()` /
   button code (l.113-120): outline colour = `pal_out` (near-black); mock uses the dark wood brown. Use the brown, and
   1 art px (= 2 screen px at 2x, check you are not getting 3). Same rule as F3 fix 3.
3. **Disabled button text** ("Continue"): lighter muted brown text + light outline, as in the mock, so it reads "off",
   not "dirty".
4. **Fullscreen checkbox**: shot must show the real state; also confirm the checked art (tick) renders at 2x with no
   offset (mock tick is centred in the box).
5. Shots are on a flat green. Re-shoot over the arena once before sign-off: the plank edges and the shadow under the
   panels must still read against trees and water (the mock proves the look; the port must too).

### Shared cause (for HUD / book ports)
- Same as F3: outline weight/colour is the one repeated miss. Put ONE outline colour + size in InventorySkin /
  the palette and use it everywhere; no per-script `pal_out` near-black.
- Any % / number label must show what the control shows (read it from the control, not a different source).

## F3 round 2

Better: search in the plank (empty strip gone), Collapse is a link, BodyRig shown, Actions start right under the tabs,
button text no longer runs past the caps. Still below the mock, mainly in the buttons and the sticky headers.

| Shot | Score | Note |
|---|---|---|
| 1_default | 6 | Top fixed. Pinned/rows fine |
| 2_bodyrig | 6 | Sticky header bugs (fix 1); first row is cut in half under the BodyRig header |
| 3_search_hand | 6 | No match highlight yet |
| 4_actions | 6 | Buttons still cramped vertically (fix 2) |
| 5_status | 6 | Pin icons faint (not done) |
| 6_watch_only | 6 | Card still a flat box |
| 7_map_rebuilt | 6 | "LAYOUT" orphan at the bottom (keep-with-next not done) |

### Fix list (ranked, max 6)

1. **Sticky headers overlap wrong** (2_bodyrig). The pinned Character band stops about 10 px before the right edge, so
   the "3" of the row below shows through after "8 SECTIONS". The BodyRig sticky header covers the top of the first row:
   you see `x 0  y -18` with no name. Fix: sticky bands = full content width (to the scrollbar), opaque; scroll so the
   first visible row starts *below* the sticky stack (offset the scroll by the stack height), never under it.
2. **Buttons cramped top/bottom** (4_actions, footer). The pixel caps fill the whole face: the text touches the top
   bevel and sits on the bottom lip. Mock buttons have about 3 art px air above and below. Add vertical padding
   (content_margin top/bottom from slices + 2 art px) or use label size one step smaller on F3Button. Side pad is fine now.
3. **Outline colour**: F3 `out_color` (dock.gd:237 -> f3_theme `look.out`) must read InventorySkin
   `text_outline_color` / `text_outline_size` (inventory_skin.gd:819-820), one source. The current near-black outline
   is what makes "Kill player", "Restart", "Write 1", "Clear" look heavy and smeared.
4. **"Collapse all" is too loud**: bright gold in the pixel font at header size, louder than the active tab. Make it
   muted cream, clean font, body size; gold only on hover.
5. **Not done from round 1, still needed**: search match highlight (3), keep-with-next for group labels (7), brighter
   pin icons (5).
6. **Watch card / rebuild banner still flat boxes** (6, 7, top-centre card): use note.png / banner.png 9-slice.

## Book round 1

Book, bag, slots and hotbar copy match the mock well (layout, 2x nearest, baked cover and slots, counts). Remaining
problems are the right page layout, the tabs and debug leaking into the shots.

| Shot | Target | Score | Main problems |
|---|---|---|---|
| port_book | book.png | 6 | "Makes 1" collides with the stepper row; only 1 side tab; header icon wrong |
| port_book_locked | book_locked.png | 6 | Description dropped, "Makes 1" half hidden behind the stepper |
| port_furnace | book.png (furnace tab) | 5 | Code-drawn wedge arrow; empty page; slots float with no labels or progress |
| port_tooltip | book.png (Wood tooltip) | 7 | Fine; edge is straight-ish vs the mock's plank edge, and the pin sits on the slot above |
| port_book_clean | - | 6 | Clean font: smaller, reads fine, but looks foreign on the book page |

**Clean vs pixel on the description:** the pixel version (port_book) reads better here. It is 1-2 short lines on a
big cream page, not dense text, and it matches the mock. Keep the clean font for dense text (F3, long tooltips).

### Fix list (ranked, max 8)

1. **Debug leaks into every shot**: white "weapon: idle / last damage / guard: ready" text top-left, F1 circles
   (green/yellow rings on trees), and a thin chunk line across the screen at y about 323. The old status wall should be
   gone (CLAUDE.md F3 row). Find who still draws that label; take shots with F1 off. Can't judge the look with it on.
2. **Right page: "Makes 1" overlaps the stepper** (book, locked). Lay it out as a VBox: title, ingredient well (height
   from content), lock band, description (expand, clip / drop), then the stepper row anchored to the bottom. If there
   is no room, drop the description but keep "Makes 1" (or show it as "x1" in the stepper). Never overlap.
3. **Side tabs**: mock has 3 category tabs (workbench, bars, weapons) stacked on the left; port shows 1 (2 in furnace).
   Also the tab overlaps the start of the "Recipes" header. Use book_tab_active / book_tab_idle_1/2 for each category,
   and give the header 4 art px gap from the tab joint.
4. **Header icon**: mock "Recipes" header has a small hammer; port uses the big workbench-plank icon, too wide and it
   crowds the word (known marker-icon gap). Use the small hammer / station icon at 1 slot-icon scale.
5. **Furnace page**: baked arrow (not code-drawn wedge), label under each slot ("Ore" / "Bar"), a progress fill
   inside or under the arrow, and centre the row in the page. Right page is fine.
6. **"<" button at count 1** shows the pressed/odd look; use button_small_disabled.png so it reads "can't go lower".
7. **Ingredient well**: with 2 ingredients it eats the page. Row height 1 slot + 2 art px gap, not 1.5 slots.
8. **Tooltip**: offset so the pin never covers the slot above; use the plank edge of tooltip.png at 2x (check
   `tooltip_texture` is set, not the StyleBoxFlat fallback, in hud_tooltip.gd:139-147).

## HUD round 1

Layout, frames, heart, rope caps, horns, name plate, keycaps: all close to the mock and crisp. The big miss is the
fills.

| Shot | Score | Main problems |
|---|---|---|
| port_hud | 6 | HP and boss fills are flat single-colour slabs (mock: light top gloss band + darker bottom); hotbar numbers small |
| port_hud_p2 | 5 | Phase-2 orange is a flat slab too and clashes with the warm frame; same small numbers |

**Root cause found:** `assets/ui/game/hp_fill.png` and `boss_fill.png` are baked as ONE flat colour (every row
(222,52,52) / (150,66,206)). The gloss was lost in the bake, so no code can bring it back, and phase 2 (a modulate
tint) is flat for the same reason.

### Fix list (ranked, max 8)

1. **Re-bake the fills with shading** (owner: ui-bake, `tools/ui_bake/` -> `assets/ui/game/hp_fill.png`,
   `boss_fill.png`, `hp_trail.png`). Bake as a light/neutral ramp (top 1-2 art px highlight, body, bottom 2 art px
   shade, like the mock) and tint it with `modulate` in code, so the purple, the orange phase 2 and the low-HP pulse all
   keep the gloss. Check by printing one column of pixels: it must not be one colour.
2. **Phase-2 colour** (owner: inventory_skin.gd `boss_phase2_color`, used by boss_bar.gd:42): the orange is too close to
   the frame wood. Use a hot red-orange with the gloss from fix 1, or keep purple and flash it; it must read "angrier",
   not "a different bar".
3. **Hotbar slot numbers too small** (owner: item_slot.gd, bag builder; hotbar.gd only places it): mock digit is about
   1.5x bigger with an outline. Use the pixel small font at 2x + `text_outline_color` from the skin.
4. **HP number position** (owner: health_bar.gd): in the mock the number is right-aligned inside the fill with a dark
   ring; port sits on the fill/trail edge and loses contrast on the pink trail. Use the skin outline (size 1) and keep a
   fixed position, not tied to the fill end.
5. **Boss name plate** (owner: boss_bar.gd + boss_plate.png): mock plate has small dark end brackets on both sides;
   port plate is a plain rect. Check the 3-part cap draw (hud_art.gd `cap`) uses the plate's caps, not the middle only.
6. **Boss bar height on screen** (owner: boss_bar.gd / hud.gd margin): port sits ~20 px higher than the mock bottom
   margin; match the HP bar baseline so the bottom row lines up.
7. **Cooldown number on the dodge icon** (owner: ability_bar.gd): fine; make sure the icon is dimmed under the number
   like the mock (port icon stays full bright under "2" in p2 "1").
8. Shots: add one with a full hotbar (items + counts) so ItemSlot states are checked in the HUD, not only in the bag.

## F3 round 3

Clear step up. Sticky bands are opaque and full width, rows start below them, buttons have air, the outline is the skin
brown, Collapse is quiet, pins read, LAYOUT has rows. The dock now looks like the mock family.

| Shot | Score | Note |
|---|---|---|
| 1_default | 7 | Clean. Pinned + Character read well |
| 2_bodyrig | 7 | Sticky fix works; group label "WEAPON + HANDS" well spaced |
| 3_search_hand | 7 | Highlight there, but cream text on a gold box is low contrast |
| 4_actions | 6 | Buttons stack one per row: right half of the dock is empty |
| 5_status | 7 | "fps: 43 frame: 23...." is cut by the On game chip |
| 6_watch_only | 7 | note.png card ok; the pin floats 1-2 px above the card, detached |
| 7_map_rebuilt | 7 | Good |

### Fix list (max 5)

1. **Actions flow** (dock.gd Actions builder / its FlowContainer): "Go to boss", "Biome map off", "World map", "Reset
   stats" each take a full row though two fit. Check the flow width = content width (not the old narrower width) and
   the button min width = text + pad only. Mock: 2-3 buttons per row.
2. **Search highlight contrast** (prop_row.gd / name label): cream on gold box is hard to read. Use dark wood text
   (`text_outline_color`) on the gold box, or no box and gold text, like hand_radius's gold name.
3. **Status summary cut** (f3_status_view.gd): the header summary loses to the chip. Give the summary the free width
   and drop words, not digits: show "fps 43" only, full line in the open block.
4. **Watch card pin** (f3_watch_card.gd / `draw_nail`): place the pin so it overlaps the card top by 2 art px, as in
   note.png in the mock, not floating above it.
5. **Remaining polish**: "Biome map  off" has a double space (button label); `generate` seed field placeholder is the
   only clean-font, low-contrast item in Actions; give it the field_pending/field look and "seed" placeholder like the
   mock.

Verdict: F3 is at "improve" (7). Fixes 1-2 should bring it to 8.

## Book round 2

Big step: 3 tabs, dimmed locked recipes, hammer header, furnace with arrow + Ore/Bar labels, tooltip.png. Now in the
mock family.

| Shot | Score | Note |
|---|---|---|
| port_book | 6 | "Makes 1" still touches the stepper (0 px gap); "<" still pressed-looking |
| port_book_locked | 7 | Stacks fine; "Tool makes 1" both gold in one line reads as one word |
| port_furnace | 7 | Good; arrow thin (2 art px) next to 2x slots |
| port_tooltip | 6 | Tooltip says Wood but the pin points at the ore slot (3rd) |
| port_hotbar_states | 6 | Digits 1.8x now sit on the item icons ("1" on the sword, "4" on the wood) |

### Fix list (max 5)

1. **Tooltip pin on the wrong slot** (hud_tooltip.gd): pin x must be the hovered slot centre, clamp the card, not the pin.
   Today the "Wood" card points at copper ore: the player reads it as the wrong item.
2. **Hotbar digits overcorrected** (item_slot.gd): 1.8x covers the icon. Use about 1.3x, top-left inside the slot
   border (2 art px in), with the skin outline; never over the icon's box.
3. **"Makes 1" vs stepper** (book_ui.gd / craft_window.gd, port_book): the stacked page still has 0 px between the
   last text line and the stepper. Min 4 art px gap; if not enough room, drop the description, as in the locked shot.
   Better: do what locked does everywhere ("makes 1" on the subtitle line) but in the muted colour, not gold.
4. **"<" at count 1** (craft_window.gd): still not the button_small_disabled look. Same fix as round 1, still open.
5. **Ingredient well** (not done): one slot row + 2 art px gap per ingredient. This frees the room fix 3 needs.

Smaller: furnace arrow 3-4 art px thick to match the slot weight.

## HUD round 2

Gloss is back (fill column now 206/255/228/.../167/206/128/128: highlight, body, shade), plate brackets, dimmed
cooldown icon, HP number readable. port_hud now matches the mock.

| Shot | Score | Note |
|---|---|---|
| port_hud | 8 | Done. Purple boss vs red player reads at a glance |
| port_hud_p2 | 6 | Phase-2 red-orange is the same hue family as the player's HP bar: two red bars on one row |
| port_hud_hotbar | 6 | Digits 1.8x stick out over the slot frame and touch the icons |

### Fix list (max 5)

1. **Phase-2 colour clashes with player HP** (inventory_skin.gd `boss_phase2_color`): in a fight the player must
   never wonder which red bar is theirs. Keep the boss in its own family: deep magenta / hot pink (about #d0306e) or
   a brighter, angrier purple + the flash. Not red, not orange.
2. **Hotbar digits too big** (item_slot.gd, same as Book round 2 fix 2): about 1.3x, inside the slot border.
3. **Baseline**: not needed. On screen the boss bar bottom is within ~3 px of the HP bar bottom; nobody sees it.
4. Cooldown number on the dodge icon: the thin lines through "-2-" read as a strike-through. If that is the sweep,
   draw it behind the number or as a dark veil from the top, not a line across the digit (ability_bar.gd).
5. Nothing else. After 1-2, HUD is done (8).
