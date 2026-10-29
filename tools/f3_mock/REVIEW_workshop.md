# Review: F3 dock in "Island Workshop" style (workshop.html, variants A / B)

Reviewer: fresh Opus, harsh game-UX pass. Shots: `shots_workshop/{a,b}_*.png` (all 18 read), compared with
`game_shots/1_default.png` (current dock) and `docs/design/shots/{parts,settings}.png` (the style).
Scale: 8+ done, 6-7 improve, <6 remake. Criteria order: readability, style fit, game cover, clutter.

## Scores

| Shot | A paper journal | B leather ledger | Main problem |
|---|---|---|---|
| tune_bodyrig | 6 | 7 | Only ~9 rows visible (current dock: ~18). Slider 55 px with a huge knob: position means nothing |
| map_heavy | 5 | 6 | `chunks_…_frame` row half hidden under the sticky Map header + banner; `shallow…amount`, `climate_octaves` cut |
| search_hand | 6 | 7 | Good: hit highlight, section above name. A: red-on-tan hit text is weak. 2-line rows = 6 hits visible |
| actions | 5 | 5 | One fat 3D button per line: 8 actions fill the whole view. Current dock wraps them. Star is a separate chip |
| status | 6 | 7 | Detail block in pixel small caps is tiring to read; `wooden_sword idl` clipped behind the `On game` chip |
| danger_sure | 5 | 5 | "Sure? click again" is light red vs red: the armed state barely differs from idle. No timer shown |
| watch_only | 7 | 7 | Same in both. Card is fine; 4 short caps lines read OK. Sits top-centre over the play area |
| widgets | 6 | 7 | `dus…ur` (dust_colour) is unreadable: the swatch stole the name column. Bool toggle good |
| write_popup | 5 | 5 | Paths run into the right border; dark popup on dark (B) / over busy rows (A) gets lost; `(% copy)` missing glyph |
| **Average** | **5.7** | **6.2** | |

## Winner: B (leather ledger)

- **Contrast.** Cream text with an outline on dark leather is the style's own rule for text on cover. It reads faster
  than A's `LINE` brown on tan paper. Changed rows in gold pop out; in A the gold dot is the only signal.
- **Covers the game less.** A puts a 380x620 bright tan block next to the green map; the eye keeps jumping to it.
  B is dark and stays back, like the current dock.
- **Still clearly Island Workshop.** Leather cover, plank tabs, bronze buttons, paper footer card, outlined cream text.
- A's only real win: it looks more like the pause / settings screens. Not worth the readability cost for a tool
  you read 100 times an hour.

## The four worries

1. **Middle ellipsis (`shallow…amount`).** Not OK as the default. A dev scans names, and the cut part is often
   the part that tells two siblings apart (`river_w_inland` vs `river_w_sea`). Tooltip does not help scanning.
   Use it only as a last resort (name over ~28 chars), after the slider shrinks and long names wrap.
2. **Pixel small caps for long status text.** OK for 1-3 word labels (counts, `.tres`, `pin to game`). Not OK for
   8-line detail blocks or the popup body: all caps removes word shapes, so a dev reads letter by letter.
   Use the mixed-case Body font there.
3. **110 px footer.** Too big: 17% of the dock height for 2 buttons and a hint. Text wraps badly
   ("3 to .tres, 2 scene-only (% / copy)"). Key hints belong in the search placeholder or a tooltip.
4. **Organic edges on a dense panel.** Fine as done: only the outer cover bows, rows and grids stay straight.
   Keep it that way; do not add bowing to rows or section headers.

## Fix list for B (ranked)

1. **Row density.** Row height ~30 -> 20-22 px (less padding, same font). Section headers ~26 -> 20 px.
   Target: 15+ setting rows visible in Tune at 1152x648 (current dock shows ~18).
2. **Footer to one line, ~40 px.** `● 5 overrides · 3 .tres · 2 scene · 1 stale  [Write 3] [Clear]` with 16 px small
   buttons (DESIGN.md small button). Details (what is scene-only, stale list) go in the tooltip. Drop the key hints.
3. **No default middle ellipsis.** Name column gets the spare width; slider shrinks to ~40 px with a 4x8 knob
   (or is hidden when the name is long); Color rows go 2-line like Vector2 (name on line 1, swatch + hex below);
   a name that still does not fit wraps to a 2nd line. Ellipsis only past ~28 chars.
4. **Status detail and popup body in mixed-case Body font**, not small caps. One-line summary next to the chip:
   tail-ellipsis it before the chip (no overlap), or make the chip a small pin icon so the summary has room.
5. **Actions: wrap 2-3 per line** with 16 px small buttons; put the pin star inside the button's right end
   (one shape, not button + chip). Goal: Player + World groups both visible without scrolling.
6. **Danger armed state must look different:** cream fill + red outline + red text, and a 2 s shrinking bar
   inside the button, label `Sure? 2s`. Idle danger stays red.
7. **Sticky headers must not cover rows.** Scroll padding = height of the sticky stack (category + section + banner);
   the rebuild banner pushes content down instead of overlaying the first row.
8. **Write popup:** use a paper (`PAPER`) card on the dark dock so it separates; wrap long paths (or show
   `body_rigs/tiny_soldier.tres`); keep 10 px inside the border; fix the missing copy glyph (shows `%`).
9. **Category vs section vs row hierarchy:** in B the three browns are too close. Category = raised plank (lighter
   `COVER_L` + lip), section = flat text with a 1 px `LINE` rule, rows = flat dark. You should tell them apart in a blink.
10. **Search placeholder** is cut by the `/` keycap (`statu…`). Shorten to `Search` and keep the keycap, or move
    the keycap outside the field.

Not a fix, a note: watch card + toast both sit top-centre over the play area; acceptable since the toast lasts 4 s,
but keep the toast from stacking under the card for longer than that.

## Round 2 (B only, after the 10 fixes)

| Shot | R1 | R2 | Note |
|---|---|---|---|
| tune_bodyrig | 7 | 8 | ~17 rows visible, one-line footer. Done |
| map_heavy | 6 | 7 | Banner no longer hides a row. 2-line names (`shallow_tint_ / amount`) break the row rhythm; heavy badge glyph on `Map` unreadable |
| search_hand | 7 | 7 | `hand_sway_speed` wraps here but fits in Tune: the name column is narrower in search |
| actions | 5 | 6 | Wrapped flow + star inside the button: good. Idle text cream on tan `PAGE`: low contrast, hard to scan |
| danger_sure | 5 | 7 | Armed state now clearly different. No visible 2 s shrinking bar |
| status | 7 | 7 | Mixed-case detail: much better. `Player Health HP…` cut; `fps 7.0` wraps to an orphan line |
| watch_only | 7 | 7 | Unchanged; fine |
| widgets | 7 | 6 | Colour row on 2 lines: good. Typing hint wraps to 4 lines and is clipped by the footer edge. Hex field uses a bigger bold font than the number fields |
| write_popup | 5 | 7 | Paper card separates well, paths fit, body readable. Hierarchy is upside down: file names are lighter than the prop lists; title not bold |
| **Average** | **6.2** | **6.9** | |

Fixes landed: 1 rows, 2 footer, 3 no ellipsis, 4 Body font, 5 action flow, 6 danger, 7 sticky overlap, 8 popup, 10 search placeholder.
Partly: 9 hierarchy (category plank vs section still close, but OK now).

### Remaining fixes (ranked)

1. **Idle buttons:** follow the "text on paper" rule: bold `OUT` text, no outline, on the `PAGE` fill (or keep cream text and use a `COVER_L` fill). Applies to actions, `Changed only`, `Collapse all`.
2. **Typing hint out of the footer:** show it as one amber line under the search field (or an amber border on the focused field). The footer stays one line.
3. **Status summaries get room:** unpinned chip = a small pin icon (not `pin to game` text); only pinned blocks show the `On game` chip. Then `HP 100/100` fits. Detail lines max ~40 chars, so nothing wraps alone (`fps 7.0`).
4. **Footer override pill:** text is dark on the brown pill and hard to read. Use cream + `OUT` outline, or plain gold text with no pill.
5. **One name-width rule everywhere:** search rows and Tune rows use the same name column. Wrap only when the name is wider than that, break after `_`, and indent the 2nd line ~8 px so it reads as one name.
6. **Write popup hierarchy:** title bold `OUT`; file names bold `OUT` (they are the headings), with the folder kept short (`body_rigs/tiny_soldier.tres`); prop lists in `LINE` below.
7. **Hex field:** same font and height as the number fields.
8. **Heavy badge on section headers:** use the same rebuild glyph as the banner (`⟳`); the current one reads as a stray arrow. Add the 2 s shrinking bar to the armed danger button.

## Round 3 (B only, after the Round 2 fixes)

| Shot | R2 | R3 | Note |
|---|---|---|---|
| tune_bodyrig | 8 | 8 | Unchanged; done |
| map_heavy | 7 | 8 | Hanging indent makes 2-line names read as one. Heavy badge now `⟳`, same as the banner |
| search_hand | 7 | 8 | Same name width as Tune; `hand_sway_speed` fits |
| actions | 6 | 7 | Idle text is dark on tan now: readable. Still ~1.5 buttons per line; the right third of the dock is empty |
| danger_sure | 7 | 7 | Armed look is clear. The 2 s bar sits on top of the label's lower part (`?`, `2s`) |
| status | 7 | 7 | Summaries fit (`HP 100`). Unpinned chip is a star in a box: it reads as "favourite" (the Tune star), not "pin to game". Detail block is now 11 lines tall |
| watch_only | 7 | 7 | Unchanged; fine |
| widgets | 6 | 8 | Typing hint is one line under search; hex matches the number fields |
| write_popup | 7 | 8 | Clear hierarchy: folder small, file bold, props below. Done |
| **Average** | **6.9** | **7.6** | |

All 8 Round 2 fixes landed.

### Remaining fixes (ranked)

1. **Danger bar:** move the 2 s bar under the label, inside the bottom lip (2 px tall, full button width), so it never crosses the text. Or grow the button 2 px for it.
2. **Action packing:** fill each line before wrapping (greedy flow, 4 px gap). Goal: 3 short buttons per line (`Heal player`, `Heal dummy`, `Go to boss` should share lines). Keep the group order inside each group.
3. **Pin-to-game glyph:** use a pin or "card" glyph, not a star. The star already means "pin to Pinned" in Tune and Actions; two meanings for one glyph confuses.
4. **Status detail height:** put two short facts on one line when both fit (`frame 4/6  fps 7.0`, `visual_scale 1.00  hand r 4.5`). Target max ~8 lines for Player.
5. **Toggle "off" pill** (`Biome map OFF`): the dark pill inside a tan button looks like a hole. Use a small cream/`LINE` pill with the bold `OUT` text, gold when on.
6. **Seed field:** the `seed` placeholder is right-aligned, tiny caps, and low contrast. Use left-aligned Body text in `LINE`, the same as the search placeholder.
