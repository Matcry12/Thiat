# Game UI parts (Island Workshop)

Baked by `python3 tools/ui_bake/bake_game_parts.py` (deterministic, $0; helpers are read from `tools/ui_mock/index.html`
at load time, the mock is never edited). Never edit PNGs by hand. Data: `slices.json` (size, `box` = the real element inside the
transparent pad, `slice`/`content` = px of the PNG, `rects`/`layout` = numbers read off the mock). Contact sheet:
`tools/f3_mock/game_shots/game_parts_sheet.png` (every part labelled + 5 screens assembled from parts only).

## Rules
- PNGs are **art scale 1**. Draw at `skin.art_scale` (2): size on screen = PNG size x 2, nearest filter. Nine-patch margins x 2.
- **Organic panels are baked at their real mock size** (8 px pad around the `box`): do NOT stretch them. Use a `TextureRect`
  at PNG size x 2. Only parts with a `slice` in slices.json may be nine-patched (buttons, groove, fill, well, qty box, tooltip, plate, bar fills).
- **No words in the pictures.** Draw words with `skin.ui_font("body"|"bold"|"small")` (`UiFonts`) at 2 x native size (9 -> 18, 5 -> 10).
  Text on paper: `pal_out` / `pal_line`, no outline. Text on dark / button / bar: `pal_cream` + `outline_size = 1` in `pal_out`.
  Disabled button text `pal_muted` + `pal_line` outline. Hovered button text outline `pal_line`.
- Skin fields: `<part>_tex` (picture) only. Nine-patch + content margins are read from `slices.json` by `PixelArt` (scripts/ui/pixel_art.gd, part name = field name without `_tex`): a rebake cannot drift from the code.
- Numbers below are art px, relative to the part's `box` unless noted. Mock positions: `tools/ui_mock/index.html`.

## Slots per screen

### Title (`menu_screen.gd` title menu), canvas 1152x648 = mock 576x324 x2
`title_plaque` + `title_logo` (logo top-left = plaque box +(16,10), minus the 2 px pad) + `title_rope` (mock y = logo top + 37) +
`panel_title` (150x128, centred, mock y=112) with buttons at box (14, 14+26*i), 122 wide x 20 (image h 23):
`button_menu_primary` (Play), `button_menu_disabled` (Continue, no save), `button_menu_idle` / `_hover` / `_pressed` (Settings, Quit);
`menu_arrow` (5x7, ONLY on the hovered / focused button, at button (5,7)). Dim: `dim_color` at `dim_alpha_menu`. "v0.9" body font bottom-left.

### Pause (`pause_menu.gd`) and Settings (`settings_panel.gd`)
Pause: `panel_pause` (170x130; plank is blank: write "Paused" bold, scale 2, CREAM + OUT, centred at box y=4) + 3 buttons
(`button_menu_*` + `menu_arrow`) at box (16, 38+28*i), 138 x 20.
Settings: `panel_settings` (240x128, title "Settings"). Rows (label bold `pal_out` at x=16, y=35 / 56 / 77): `slider_groove` (nine-patch, 100 wide, at x=86, y=row-1+1),
`slider_fill` / `slider_fill_hover` (groove +(2,2), height 4, width = 96 x value), `slider_knob` (8x8 at groove.x+2+fillW-4, groove.y-3), value text at groove.x+112
(bold CREAM+OUT, "60%"); `checkbox_off` / `_on` / `_hover` (14x14 at x=86, y=74); Back = `button_menu_*` 100 x 20 at box (70,96) + arrow.
Dim `dim_alpha_pause`. The HUD hotbar is hidden while these are open.

### HUD (`hud.gd`, `hotbar.gd`, `health_bar.gd`, `ability_bar.gd`, `boss_bar.gd`)
- Hotbar: `hotbar_panel` (223x44 at screen art (6,3)); slots `slot_idle` / `slot_pick` (selected) / `slot_hover` (24x24 incl. 1 px pad, slot is 22) at box (8+23*i, 11);
  icon 16 px at slot +(3,4); key number `small` at slot +(2,2) (`pal_out` selected, else `pal_line`); stack count `small` CREAM+OUT bottom-right, inset 3.
- Abilities (3, step 26, at art (10+26*i, 262)): `ability_frame` 22x22 (icon 16 px at +3,+3; cooldown = `pal_shadow` at `cooldown_alpha` wiping down from the top
  + 1 px CREAM edge + bold seconds), `ability_keycap` 13x11 at frame (5,17), letter bold `pal_out` (Q / E / F).
- Effect icons (`effect_bar.gd`, right of Q/E/F, step 25 from art x 98, y +2): `effect_frame` / `effect_frame_bad` (red debuff) 20x20 with a dark well; effect symbol 12x11 at (4,4) from `assets/game/ui/effects/<id>.png`
  (EffectData.icon); seconds `small` CREAM under it, level badge `small` `pal_goldtxt` at (17-w,13) for level > 1; last `blink_time` s the well gets a `pal_shadow` 50% flash.
- HP bar (mock x=10, y=298, w=120): `hp_frame` (136x26, drawn at art (4,295)); fill area `rects.fill` = (15,5,114,14): `hp_trail` (damage) under `hp_fill`,
  both nine-patch, stretch to the fraction. Number `cur/max` bold CREAM+OUT at `rects.number_centre`.
- Boss bar (bottom centre, only while awake): `boss_frame` (284x28 at art (146,296)); `rects.fill` = (14,10,256,12) holds `boss_fill`; `boss_mark` (3 wide) at 50%
  (`rects.mark`); `boss_plate` (nine-patch, width = name width + 26, 16 tall, bottom 1 px above the bar top, centred) with the name bold CREAM+OUT.

### Bag + crafting book (`bag_panel.gd`, `craft_window.gd`, `item_slot.gd`, `hud_tooltip.gd`)
- Book: `book_cover` (330x136 at art (123,14)). Left page: "Recipes" bold CREAM+OUT at (28,11); 6x4 grid of `slot_idle` / `slot_pick` / `slot_hover` at (12+24*c, 26+24*r) (icon 16 px at +3,+3).
  Right page (x=173): chosen item `slot_sel` at (173,10), name bold at (201,12), type body `pal_goldtxt` at (201,23); `well` (nine-patch, 139 wide, height 4 + 23*rows, +14 with a lock) at (173,36);
  ingredient slots `slot_idle` at well +(4, 2+23*i), `have/need` bold (`pal_okg` / `pal_hp_l`) at slot +(28,8); `lock_banner` (nine-patch, 12 tall, `padlock` at +2,+2, CREAM text at +12);
  description + "Makes N" body `pal_line`. Stepper y=108: `button_small_*` at (173,108) and (215,108) (14 wide), `qty_box` 22x18 at (190,108), Craft `button_small_*` 75 wide at (237,108) (hammer icon + bold text);
  cannot craft: `craft_disabled` + `padlock` at +6,+5 + `pal_muted` text with `pal_line` outline.
- Tabs (left of the book, 26x22, step 24 from y=12, x=-22): `book_tab_active` (31 wide, in FRONT of the cover), `book_tab_idle_1`, `book_tab_idle_2` (BEHIND the cover); icon 16 px at +4,+3 (idle at alpha 0.75). Tab icons: `items_tab_icon.png` (16x16, open chest = all items; source `tools/art_tests/items_tab_icon/draw.py`), hammer = `assets/game/ui/placeholder/hammer.png`.
- Slot states: craftable = full icon; missing items = icon at `missing_icon_alpha` (the mock also greys it); locked by station = faded icon + `padlock` at slot (15,15).
- Bag: `bag_panel` (222x124 at art (177,156)); slots at (8+23*c, 12+23*r), 3x9; `divider_line` (tile, 2 rows) at (8,83), 206 wide; hotbar copy row of `slot_*` at (8+23*c, 90).
  The HUD hotbar hides while the book is open.
- Tooltip: `tooltip` nine-patch (box = text size + 12 x (11 * lines + 6)) + `tooltip_pin` (4x4) at top centre, 1 px above the box.
  Line 1 bold CREAM+OUT, line 2 body `pal_paper`. Follows the mouse at +8,+10 art px, clamped to the screen.

## Known gaps (mock vs parts)
- Stretchable plates / tooltip are straight (the mock bows them 1 px); needed so they can stretch.
- The "missing items" grey icon needs a shader (alpha only here).
- No low-HP fill variant; Craft hover = `button_small_hover`.
