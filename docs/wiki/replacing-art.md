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

Your picture is probably not in the right place. Two numbers fix that:

| Setting | What it does |
|---|---|
| **Body Offset** | Moves the picture up/down/left/right |
| **Shadow Offset** | Moves the shadow |

**Important:** the character's **feet** must sit at the node's centre (position 0,0).
The picture is drawn *above* that point.

Example: the placeholder is 44 pixels tall, so Body Offset is `(0, -22)` — half the
height, upward. A 64-pixel-tall knight would use about `(0, -32)`.

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
