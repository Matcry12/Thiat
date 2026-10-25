# Replacing art — the 3 steps

Everything you see in the game is a **picture file** (PNG). Nothing is drawn by code.
So changing art = changing a file. No programming.

## Step 1 — put your picture in the project

Copy your PNG into `assets/`. Example: `assets/knight/knight.png`.

## Step 2 — point the game at it

Open `scenes/player.tscn` in Godot. Click the **Visual** node.
In the Inspector on the right, drag your PNG onto **Body Texture**.

That is it. Your picture is now the player.

## Step 3 — nudge the position

Your picture is probably not in the right place. **Drag it** — do not type numbers.

Click the **Body** node under Visual, then drag it in the middle view until it looks right.
Same for **Shadow**.

Nothing in the code moves these sprites, so what you drag is what you get.

**Important:** the character's **feet** must sit at the node's centre (position 0,0).
The picture is drawn *above* that point.

Example: a 44-pixel-tall character is dragged up by about 22 pixels, so its feet land on the
node's centre. A 64-pixel-tall knight is dragged up about 32.

Why the feet: the game decides who is drawn in front by the **Y position of the feet**.
Feet in the wrong place = a character standing behind another one is drawn in front.

---

## Other things you can replace

| What | Where | Setting |
|---|---|---|
| Enemy | `scenes/dummy.tscn` → Visual | Body Texture |
| Shadow | any Visual node | Shadow Texture |
| Sword | `scenes/player.tscn` → WeaponVisual | Blade Texture |
| Boss | `scenes/boss.tscn` (later) | Body Texture |

## Rules for weapon pictures

- The weapon must **point right** in the image file.
- The **handle must be on the left edge** — that is where the hand holds it.
- If it looks wrong, adjust **Blade Offset** and **Hand Distance** on the WeaponVisual node.

## Adding a new weapon (no code)

1. Put the picture in `assets/`
2. In Godot: right-click `data/weapons/` → New Resource → **WeaponData**
3. Fill in the numbers (damage, windup, active, recovery, arc, reach)
4. Save as `data/weapons/greatsword.tres`

Done. No programming.

## What still needs me

- A new **behaviour** (a boomerang that comes back, a chain-lightning weapon)
- A new **animation type** (walk cycles with 8 directions instead of left/right flip)
- Anything that changes how combat works

Everything else — pictures, numbers, positions — is yours.

---

## Making placeholder art yourself

`tools/make_placeholders.py` draws every placeholder picture. The sword is written as a
**character grid** — you can edit the shape without knowing how to draw:

```
"......KKK................."
"......KGK................."
"KRHHHHKGKWWWWWWWWWWWWWWK.."
```

`K` = black outline, `G` = gold guard, `H` = brown grip, `R` = red gem,
`W` = light blade, `B` = blue blade, `.` = transparent.

Change the letters, run `python3 tools/make_placeholders.py`, and the picture updates.

**Never use stock images from the internet** (Dreamstime, Shutterstock and similar).
They are watermarked and not licensed for a game. Free and safe sources: Kenney.nl (CC0),
itch.io asset packs, or art you make yourself.

## Weapon art drawn diagonally

Most downloaded weapon icons are drawn **diagonally** (blade pointing up-right), not flat.
That is fine — do not rotate or redraw the picture.

On the **WeaponVisual** node set **Art Angle Degrees** to the angle the blade points inside the
image file:

| Art in the file | Art Angle Degrees |
|---|---|
| Points right | `0` |
| Points up-right (diagonal) | `-45` |
| Points up | `-90` |

The code cancels it out, so the swing still follows your mouse correctly.

Then fix the grip position with **Offset** on the Blade sprite: the handle must sit at the pivot.
For a diagonal sword the handle is the **bottom-left** of the picture, so Offset is roughly
`(-6, -(height - 6))`.

## Hotbar and bag (slots, panel, icons)

One file holds the whole look: `data/ui/inventory_skin.tres` (an `InventorySkin`). Open it in the
Inspector. Empty texture = the grey placeholder. Put a PNG in and the look changes; no code change.

| What | Field in `inventory_skin.tres` | Notes |
|---|---|---|
| Slot frame (hotbar and bag, same one) | `slot_texture` | Stretched as a nine-patch; `slot_patch_margin` = the border size in px |
| Frame of the selected slot | `slot_selected_texture` | Drawn on top, `selected_grow` px bigger than the slot; `selected_patch_margin` |
| Bag panel background | `bag_panel_texture` | Nine-patch; `bag_patch_margin`, and `bag_pad` = space between the border and the slots |
| "Locked" picture on slots | `lock_texture` | Empty = a dark tint |
| Dodge / skill / guard icon (bottom-left) | `dodge_icon`, `skill_icon`, `guard_icon` | Empty = a plain square in `dodge_color` / `skill_color` / `guard_color`. Same slot frame; the cooldown is a dim that drains |
| Hover name box | `tooltip_texture`, `tooltip_patch_margin`, `tooltip_pad`, `tooltip_font_size`, `tooltip_color`, `tooltip_offset` | Empty texture = flat panel (`tooltip_bg`, `tooltip_border`) |
| Health bar | `bar_frame_texture`, `bar_fill_texture`, `bar_frame_patch_margin`, `health_bar_width` / `health_bar_height`, `health_fill_color`, `health_low_color`, `health_trail_color` | Frame is a nine-patch |
| Boss bar | `boss_bg_texture`, `boss_fill_texture`, `boss_bar_width_fraction`, `boss_bar_height`, `boss_fill_color`, `boss_phase2_color`, `boss_marker_color` / `boss_marker_width`, `boss_fade_time`, `boss_flash_time` | Hidden until the boss wakes |
| Slot size and gap | `slot_size` (44) and `slot_gap` (6) | One number each; the hotbar and the bag lay themselves out |
| Count / key number text | `font`, `count_font_size`, `count_color`, `key_font_size`, `key_color` | |
| Item icon | `icon` on the item file in `data/items/` (`ItemData`) | Placeholders live in `assets/ui/placeholder/` (16 x 16): replace the PNG or point `icon` at your own. No icon = a coloured square (the item's `color`). Weapons without an icon show their model's `Art` sprite |

The slot itself is the scene `scenes/ui/item_slot.tscn`. Its child nodes are named by job (`Frame`,
`SelectedFrame`, `Icon`, `Count`, `KeyLabel`, `LockOverlay`), so you can restyle or replace a child
in the editor. All of it is also live-tunable in F3 (`InventorySkin` section).

The HUD has no text words. The health bar is `HealthBar` (`fill_texture` and `frame_style` slots as before) and shows its number only in the hover tooltip. Where the blocks sit: `margin_x`, `margin_y` on the `HUD` node (F3 section `HUD`).

## Stations (workbench, furnace, anvil) and the crafting panel

**Station art.** Each station is a scene in `scenes/stations/` (`workbench.tscn`, `furnace.tscn`, `anvil.tscn`). Click the root node and look in the Inspector:

| What | Field on the station root | Notes |
|---|---|---|
| The picture | `art` (a whole PNG) + `art_region` (the rectangle inside it) + `pixel_scale` | Today: copies of the Pixel Crawler sheets in `assets/stations/`. Change `art_region` to pick another look on the sheet, or point `art` at your own PNG and set `art_region` to its full size |
| Placeholder | `color` | Shown as a plain box while `art` is empty |
| Size on the ground | the scene's `CollisionShape2D` (and the `Hurtbox/CollisionShape2D` a little bigger) | One owner: the placing check and the ghost box read the body shape. The picture is never the body: resize the shapes, not the art |
| Craft distance | `CraftStation` child: `craft_radius` | F1 draws it as a magenta circle |
| Inventory icon | `data/items/workbench.tres` (and `furnace`, `anvil`): `icon` | Today a slice of the same sheet |
| Furnace progress bar (in the world) | `Visual/ProgressCue` on `furnace.tscn`: `bar_size`, `bar_offset`, `bg_color`, `fill_color`, `glow_color` | A small bar above the furnace and a warm glow on the picture while it smelts. Replace the node with a sprite or particles and nothing else changes |

The anvil picture is a small drawn placeholder (`assets/stations/anvil.png`, 32 x 20): none of the Pixel Crawler anvil sheets shows a plain anvil. Replace the file (or `art` / `art_region`) when you have one.

The ghost colours are on the player's `Placer` node: `ok_color`, `bad_color`, `outline_ok`, `outline_bad`, `outline_width`.

The art sits with its feet on the bottom edge of the footprint, centred. If your picture is taller, nothing else needs to change.

**Crafting window skin** (same file as the bag: `data/ui/inventory_skin.tres`, group "Crafting window"). `Tab` / `I` opens one centred window: a grid of recipe icons on top, bag and a hotbar copy below.

| What | Field | Notes |
|---|---|---|
| Whole window background | `window_texture`, `window_patch_margin`, `window_pad`, `window_gap` | Nine-patch. Empty = flat `window_color` / `window_border` |
| Crafting / furnace area frame | `section_texture`, `section_patch_margin`, `section_pad`, `craft_area_height` | Empty = flat `section_color` / `section_border` |
| Recipe icons | `craft_slot_size`, `craft_slot_gap`, `craft_grid_columns`, `craft_grid_rows` | The icons are the same `ItemSlot` scene as the hotbar, so the slot frame art shows here too |
| Lit / dim / flash | `craft_lit_color`, `craft_dim_color` (45% alpha), `craft_lit_backdrop` (light square), `craft_dim_backdrop` (dark square), `craft_flash_color`, `craft_flash_time` | Lit and dim never depend on the art's own colours: a lit icon sits on a light square, a dim one on a dark square and is faded. Flash = clicked while dim |
| Held stack (cursor, bag and crafting) | `cursor_offset`, `cursor_scale`, `cursor_shadow_size`, `cursor_shadow_color`, `cursor_shadow_offset` | Drawn offset from the pointer, a bit bigger, with a soft shadow: it reads as lifted |
| Ingredient icons in the hover | `tooltip_icon_size`, `craft_short_color`, `craft_enough_color` | The need count is white, or red when you are short |
| Furnace tab | `furnace_slot_size`, `furnace_arrow_width`, `furnace_arrow_height`, `furnace_arrow_color`, `furnace_fill_color` | Input slot, a drawn progress arrow that fills, output slot |
| Tabs and station marker | `tab_size`, `craft_tab_icon` (hammer), `hand_icon` (hand), `tab_color`, `hand_color`, `furnace_tab_glow_color`, `furnace_tab_pulse_speed` | Placeholder PNGs `hand.png`, `hammer.png` in `assets/ui/placeholder/`. The marker only shows when there are no tabs. The Furnace tab pulses while the furnace works. The furnace tab and the marker show the station's item `icon` (found through the recipes) |

New copper tools use the stone tool models, tinted: `model_tint` on the weapon file in `data/weapons/` (white = as drawn). When you have real copper art, point `model` at it and set `model_tint` back to white.

## Temporary Tiny RPG art (Soldier player, Orc boss)

Both are stand-ins ([0032](../decision/0032-temp-tiny-rpg-art.md)). Licence: no redistribution, so the pack stays out of anything you publish.

| What | Where | Notes |
|---|---|---|
| Player body | `data/body_rigs/tiny_soldier.tres` (set on `player.tscn > Visual > Rig`) | `sprite_frames`, `body_position` (feet on the shadow), `body_scale` (3 now; whole numbers keep pixels crisp), `landing_frames` / `lift_frames` for a longer run cycle. Needs clips `idle_side`, `run_side`, `hit_side`; add `idle_front`, `run_front`, `hit_front` for a real front view |
| Boss body | `boss.tscn > Visual` (`BossVisual`): `body_frames`, `body_position`, `body_scale` (3 now), `shadow_scale`, `shadow_position` | Clips: `idle`, `run`, `hit`, `death` + one per attack in `attack_anims` |
| Boss attack animation | `attack_anims` (action -> clip), `strike_frame`, `recover_frame`, `hurt_time` | Telegraph / active / recovery of the attack (set on each `BossAttack` node) are stretched over the frames. Never change an attack's time to fit the art |
| Back to the old look | Player: pick `blocky.tres` as the rig. Boss: clear `body_frames` | Placeholder circle returns |

New character with a side view only: make a SpriteFrames with `idle_side` / `run_side` / `hit_side` and a BodyRig that points at it. The frames are 100x100 cells here: put the feet on the shadow with `body_position`, not by editing the art.


## Island ground, water and trees (data only)

| What | Where |
|---|---|
| Which pack: whole map look | `ArenaMap.style` -> `data/maps/grass.tres` (Pixel Crawler only, [0034](../decision/0034-map-art-pixel-crawler-only.md)) |
| A ground (fills, edge frame, layer) | `data/maps/ground_*.tres` (`GroundData`); list order in `MapStyle.grounds`: dirt, cobble, grass, boss grass |
| Water tile | `MapStyle.water_texture` + `water_fills`; shimmer / foam numbers in F3 Map |
| Trees by biome and colour | `data/resource_nodes/tree_<model>[_<season>]_<age>.tres`, made by `tools/asset_viewer/make_tree_nodes.py` from `data/maps/tree_catalog.json`; which tree a biome grows = its tree table in `data/biomes/*.tres` (0038 step 4). The old `tree` kind only stands on the boss land (`looks_boss`) |
| Floor props (flowers, tufts, bushes, stones, reeds, snow stumps) | `data/maps/prop_veg.tres`, `prop_rocks.tres`, `prop_stump_*.tres`, made by `tools/asset_viewer/make_veg_sets.py`: sprites are named in `PropSet.groups` (`bush_green`, `flower_2`, `stone_grey` ...), which biome grows which = `BiomeData` |
Credits for third-party art: [credits.md](credits.md).
