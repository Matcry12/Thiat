---
name: BossFight UI — "Island Workshop"
version: 1.0 (approved 2026-10-25, user score 8/10)
source_of_truth: tools/ui_mock/index.html   # live mockup; every value below is read from it
screenshots: docs/design/shots/             # title, hud, pause, settings, book, book_locked, parts
art_scale: 2                                # 1 UI art pixel = 2 screen pixels; canvas 576x324 -> 1152x648
decision: docs/decision/0043-ui-island-workshop.md
---

# DESIGN.md — BossFight UI

Read this before any UI work. It says **what the UI looks like and why**, so new screens are
*applied* from it, not re-designed. If a value here and the mockup disagree, the mockup wins: fix this file.

## 1. Overview

**Feel:** a cozy, hand-made crafting journal on a survival island. It uses warm tan paper in thick
leather-brown covers. Outlines are soft plum-brown, never black. Bronze clips, rope lashings and moss
sit on the corners.

**Mood words:** warm, hand-made, sturdy, readable.

**Inspiration (feel only, never copy pixels):** a cozy-RPG reference screenshot the user picked. It has
tan panels, an open-book crafting window and glossy gem-capped bars.

**Our own identity on top of that:**
- **Island rope:** lashed corners, a rope book binding, a rope frame on the HP bar, and slack rope lines.
- **Orc bone tusks** on the boss bar.
- **Wooden plank headers** in place of ribbons.
- **Moss sprigs** in the Pixel Crawler grass greens.

**Natural rule (user requirement):** nothing big is a perfect rectangle. Outer silhouettes bow 1–3 px
and have corners of different sizes. Each has one small chip, uneven stitching and slack rope.
**But** grids, text baselines, slider tracks and click areas stay straight and aligned, because
readability wins. All irregularity is **seeded per element**, so it never flickers and always looks
the same.

## 2. Colors

All colours are flat. There are no gradients except the stepped gloss rows on bars. Each name is a role.

| Token | RGB | Role |
|---|---|---|
| `OUT` | 62,36,39 | Outline of everything (plum-brown, **never pure black**) |
| `LINE` | 118,64,65 | Inner lines, secondary text on paper, deckle edge |
| `PAPER_L` | 234,208,170 | Paper highlight / top lip / key plate |
| `PAPER` | 214,179,142 | Paper card fill (main panel surface) |
| `PAGE` | 198,153,125 | Page shade, idle button fill, slot top shadow |
| `SLOT` | 207,165,131 | Slot fill |
| `RIM` | 182,127,104 | Slot border, stitches, selected fill |
| `WELL` / `WELL_D` | 182,127,104 / 161,108,88 | Recessed area (ingredient well, slider groove) |
| `COVER_L` / `COVER` / `COVER_D` | 150,84,62 / 126,64,48 / 86,42,38 | Leather/wood cover frame, planks, tabs, tooltip |
| `BRZ_L` / `BRZ` / `BRZ_D` | 240,186,98 / 198,138,53 / 134,84,52 | Bronze clips, selected frame, primary button |
| `ROPE_H` / `ROPE_L` / `ROPE_D` | 222,190,128 / 196,160,96 / 134,84,52 | Rope strands (3-px twist period) |
| `CREAM` | 252,242,222 | Text on dark or on buttons (always with an `OUT` outline) |
| `GOLDTXT` | 244,200,76 | Sub-titles / item type ("Station", "Tool") |
| `MUTED` | 150,104,86 | Disabled text only |
| `OKG` | 150,214,96 | "You have enough" counts |
| `HP_L` / `HP` / `HP_D` | 255,128,104 / 222,52,52 / 150,26,44 | Player health, "not enough" counts |
| `BOSS_L` / `BOSS` / `BOSS_D` | 208,136,255 / 150,66,206 / 88,30,140 | Boss health |
| `TRACK` | 52,26,44 | Empty bar track, ability well |
| `SHADOW` | 20,10,14 | Drop shadows (alpha 0.45), cooldown wipe |
| Moss `g` / `G` / `d` | 132,168,72 / 92,128,60 / 52,78,44 | Moss sprig (matches the map grass) |
| Tusk bone `y` + `CREAM`/`PAPER` | 214,186,128 | Tusk tips |
| Damage trail | 255,176,150 | "Hit just taken" part of the HP bar |

**Dim behind menus:** `[26,14,20]` at 0.50–0.55 alpha over the live game.

## 3. Typography

All fonts are our own pixel fonts, drawn in code (glyph tables in the mockup). There is no licence and
no credit line.

| Style | Spec | Use |
|---|---|---|
| **Body** | 5 px wide, caps 7 rows, x-height 5, descenders 2, mixed case (`UP` + `LO` tables) | Labels, descriptions, tooltip line 2 |
| **Bold** | Body with every stroke doubled sideways; wide letters `m w M W` use the `BOLD` table, **not** doubled | Buttons, titles, names, numbers in bars |
| **Small** | 3x5 digits/letters (`SMALL`) | Slot key numbers, stack counts, key hints |
| **Display** | Bold at scale 2 (headers) or scale 4 (logo) | Plank titles, logo |
| **Logo bands** | Scale-4 bold, 3 colour bands per glyph: rows 0–2 `CREAM`, 3–4 `GOLDTXT`, 5–6 `[214,150,56]`, with a 1-px `BRZ_L` seam | Title "BossFight" |

**Rules**
- Text on paper: `OUT` or `LINE`, no outline.
- Text on cover, button, map or bar: `CREAM` with a 1-px `OUT` outline (including diagonals).
- Letter gap is 1 px (bold: 1 px after the doubled stroke). Line step is 11 px for body.
- Players read **B1 English**: short words, sentence case ("Save & quit", not "SAVE AND QUIT").

## 4. Shape & elevation

| Level | How it is drawn | Used for |
|---|---|---|
| **Sunken** | 1-px dark top/left line (`PAGE`/`WELL_D`) and a light bottom line (`PAPER_L` at 0.5) | Slots, wells, slider groove |
| **Flat** | Fill with an `OUT` or `LINE` outline | Paper card, tabs |
| **Raised** | Fill, a lighter 1-px top lip, 2 darker bottom rows, then 2–3 rows of `OUT` base under it | Buttons, keycaps |
| **Floating** | Raised, plus 2 rows of `SHADOW` at 0.45, offset (+1, +2) | Panels, planks, tooltip |

**Corner radii:** a "radius" is a stair of pixels cut from the corner: `1`→[1], `2`→[2,1], `3`→[3,1,1],
`5`→[5,3,2,1,1]. Big panels shuffle `[1,2,3,5]` across their 4 corners, so no two corners are the same.
Buttons pick 2 or 3 per corner.

## 5. Natural / hand-made techniques (the "organic" kit)

These are all in the mockup as helpers. Re-use them; don't invent new ones.

| Helper | What it does |
|---|---|
| `organicBox(x,y,w,h,seed,o)` | Builds a 0/1 mask. Edges **bow outward** with a sine curve of depth `B=clamp(round(w/55),1,3)`. Held ±1 px steps change every 8–20 px and are 0 at least half the time. Corners get different radii, and one 3x2 **chip** sits ≥12 px from a corner. It only grows *outward*, so the content grid stays put. Colour by distance to the edge: d0 `OUT`, d1 lit (top/left) or dark (bottom/right), deeper base. |
| `paintMask` | Paints any mask with that distance rule. Used by planks and the boss frame. |
| `stitches(x0,x1,y,seed)` | Hand-sewn dashes: step 3–5 px, dash 2 px (3 px 30% of the time), 10% skipped. Top and bottom rows use different seeds. |
| deckle (in `panel`) | Paper bottom edge: 0/1 px offsets held 2–5 px. |
| `ropeLine(x,y,w)` | Slack rope: sags `S=clamp(round(w/50),1,3)` px on a parabola. The twist follows the curve. Knots at both ends. |
| `ropeWrap` | 3 diagonal rope bands across a corner, plus a tail 6–10 px long that swings 1 px out and ends frayed. |
| `grain(x,y,w,h,seed,…)` | Sparse wood dashes plus one knot, on cover, plank and inactive tabs. |
| `brackets(x,y,w,h)` | Corner kit: **2** bronze clips, **1** rope wrap and **1** moss sprig, placed by seed. Under a plank header, the top corners are clips. |

**Seeds:** use `hs(stableString)`, a hash of the position and size, or the element id. Never use `Math.random()`.

## 6. Components

All sizes are in art pixels (×2 on screen).

### Panel (`panel`)
- **Cover:** an `organicBox` cover with drop shadow.
- **Paper card:** inset 4 px, with a `LINE` outline, a `PAPER_L` top row, a `PAGE` bottom row and a deckled bottom edge.
- **Stitches:** at y+8 and y+h-9.
- **Corners:** always paired with `brackets()`.
- **Content:** starts ≥10 px inside the outer edge.

### Plank header (`plankHeader`) — replaces ribbons
- **Size:** panel width + 12 (6 px past each side), 22 px tall.
- **Shape:** one 1-px step at 40–60% of the width. The left end is cut on a slant, the right end has a 2-step notch.
- **Wood:** 2 drifting grain lines, 1 knot, and 2x2 nails 5 px from each end.
- **Title:** bold scale 2, `CREAM` with `OUT` outline, centred and straight.

### Button (`button`) — wooden block
- **Height:** 20 for menus, 16 for small buttons.
- **Shape:** corner radii 2 or 3 per corner. The base has 2 `OUT` rows plus a 3rd under one seeded half. The top lip is slightly uneven.
- **States:**

| State | Fill | Lip | Bottom | Text |
|---|---|---|---|---|
| Idle | `PAGE` | `PAPER` | `COVER_L` | `CREAM` + `OUT` outline |
| Hover | `[226,196,160]` | `CREAM` | `COVER_L` | `CREAM` + `LINE` outline, gold ▶ arrow at the left (menus) |
| Pressed | Moves down 1 px | | | |
| Primary | `BRZ_L` | `[252,224,150]` | `BRZ_D` | `CREAM` + `OUT` outline |
| Disabled | `[170,132,110]` | `PAGE` | `RIM` | `MUTED` + `LINE` outline, no hover, no click area |

- **Only one** arrow shows at a time (the hovered or focused button).

### Slot (`slot`, 22 px; grid step 23–24)

| State | Look |
|---|---|
| Idle | `SLOT` fill, `RIM` border, `PAGE` top shadow, light bottom line |
| Hover | Border `BRZ_L` |
| Pick | Chosen recipe or selected hotbar slot: 2-px `BRZ_L` frame + 4 bronze corner dots |
| Sel | Darker `RIM` fill with an `OUT` border (the recipe icon on the detail page) |

- **Icons:** 16 px, at +3,+3 (hotbar/bag +3,+4).
- **Key number:** `SMALL` font at top-left +2,+2 (`OUT` when selected, else `LINE`).
- **Stack count:** `SMALL` font, `CREAM` + `OUT`, bottom-right, inset 3 px.
- **Craftable:** full icon. **Missing items:** icon at 0.4 alpha, grey. **Locked by station:** faded icon plus a 6x6 padlock bottom-right.

### Well (`well`)
`WELL` fill with a `LINE` outline and dark top/left. Used for the ingredient list and the slider groove.

### Bars
- **HP (`hpBar`):** 14 px glossy fill inside a **rope frame**, with the strand phase shifting every 20–35 px.
  - Heart socket: 14x16, bronze, at the left.
  - Rope knots at both ends.
  - Gloss: `HP_L` top row, plus a second row at 0.45, then `HP_D` on the 2 bottom rows.
  - Damage trail: `[255,176,150]`.
  - Number `cur/max`: bold `CREAM` + `OUT`, centred.
- **Boss (`bossBar`):** 12 px glossy fill in a bronze frame whose top edge bows 1 px.
  - **Tusks:** two bone tusks at the ends, not mirror images (the right one is a row shorter and chipped). Each base is wrapped in 3 rope bands.
  - **Phase 2 mark:** a 1-px `CREAM` tick with an `OUT` border at 50%.
  - **Name plate:** a small `organicBox` sitting on the bar, with notched `COVER_D` tails.

### Ability (`ability`, 22 px)
- **Frame:** `COVER_L` frame with a sunken well and a 16 px icon.
- **Cooldown:** `SHADOW` 0.45 wipes down from the top, with a 1-px `CREAM` edge and the seconds in bold `CREAM` in the middle.
- **Keycap:** 13x11 `PAPER_L` with a bold `OUT` letter, overlapping the bottom. Keys come from `project.godot`: dodge **Q**, skill **E**, guard **F**.

### Slider / checkbox
- **Slider:** carved groove with a `BRZ` fill and a `PAPER_L` lip. The knob is an 8x8 paper block. The value is shown at the right, 12 px away, in `CREAM` + `OUT`. Volume and Shake both show as %.
- **Checkbox:** 14x14 `SLOT` box with a bronze tick.

### Tooltip (`tooltip`) — pinned torn note
- **Shape:** `organicBox` (`B=1`, radii [1,3,2,1]) in `COVER_D`, with a deckled bottom and a bronze pin at the top centre.
- **Text:** line 1 bold `CREAM` + `OUT` (name); line 2 `PAPER` (type, count).
- **Position:** follows the mouse at +8,+10, clamped to the screen.

### Rope line, tabs
- **`ropeLine`:** under the logo, as the book binding (vertical, same curve), and as dividers.
- **Book tabs:** on the left edge. The active tab is `PAPER`, joined to the page and shaped like a bookmark with a gold marker. Inactive tabs are `COVER_L` with the icon at 0.75.

## 7. Layouts (screens)

| Screen | Layout |
|---|---|
| **Title** | Live map behind, dim 0.5. Logo (scale 4, bands) on a wood-grain plaque with lashed corners. `ropeLine` under it. Menu panel 150x128 centred: **Play** (primary) / Continue (disabled without a save) / Settings / Quit. `v0.9` bottom-left. |
| **HUD** | Hotbar top-left on a panel (9 slots, step 23). Abilities bottom-left, above the HP bar. Boss bar bottom centre, **only while the boss is awake**. Nothing else on screen. |
| **Pause** | Dim 0.55. Panel 170x130 with a plank header "Paused". Buttons Resume / Settings / Save & quit (`pw-32` wide, 28 px step). |
| **Settings** | Panel 240x128, plank header. Rows: Volume %, Shake %, Fullscreen ☐. Back button 100 wide, centred. |
| **Bag + crafting** | **Open book** at the top (330x136), tabs on the left (Craft / Furnace / Anvil). Left page: "Recipes" grid, 6 columns × 4 rows. Right page: chosen item (icon, name, type in gold), ingredient well (`have/need`, green or red), a one-line description, "Makes N", and a stepper `< n >` plus the **Craft** button. Bag panel below (3×9) with a hotbar copy row. **The HUD hotbar hides while the book, pause or settings is open.** |

## 8. Do's and don'ts

**Do**
- Outline with `OUT` plum-brown; keep every edge crisp, with no anti-aliasing and no blur.
- Make big silhouettes organic (`organicBox`), and keep grids and text straight.
- Seed every irregularity; the same screen must draw the same way every frame.
- Show every state: idle, hover, pressed, selected, disabled, locked.
- Keep every size, colour and timing as a named value. When it moves to Godot it becomes an `@export` on the skin resource (F3 panel), per CLAUDE.md §5 and §7.

**Don't**
- Use black (`#000`) outlines or pure white text.
- Use perfect rectangles for panels, or the same corner four times.
- Use random noise for "natural": steps must be held for 6+ px or they read as a glitch.
- Put words in the HUD other than the boss name and the HP number (see decision 0043).
- Copy the reference's pixels, corner clips or gem sockets one to one.

## 9. Applying it to Godot (next step, not done yet)

- Every helper here is deterministic pixel drawing. The plan is to **bake** frames, slots, buttons,
  planks and bars to PNG 9-slices, plus the font as a bitmap font, using a $0 script. These plug into the
  existing `InventorySkin` texture/font slots (`data/ui/inventory_skin.tres`), so no combat code changes.
- Organic outer edges cannot stretch, so bake each panel **at its real size**. Use 9-slice only for the
  straight inner paper.
- Port in vertical slices: (1) font + pause / settings / title, (2) HUD bars + hotbar + abilities,
  (3) bag + crafting book. The user approves each slice in game.
