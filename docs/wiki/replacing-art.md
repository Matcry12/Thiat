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
