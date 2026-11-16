# Add a weapon picture

**Status:** Current

## Fast way (one command)

```
python3 tools/add_weapon.py <picture.png> <id> [--kind sword|axe|pickaxe|hoe] [--scale N] [--flip] [--hands 1|2] [--sound blade|tool|bow|<set>] [--name "Display Name"] [--dry-run] [--no-import]
```

`--sound` = the SoundSet in `data/sounds/` (default: sword -> `blade`, axe / pickaxe / hoe -> `tool`). Both are silent on the swing for now; the target makes the hit sound.

- `<id>` is snake_case (`iron_sword`). It never overwrites: if the item, weapon or model exists, it stops.
- Draw the picture pointing **up**, handle at the bottom. The handle is the lower end of the long axis. If the script picked the wrong end, run again with `--flip`.
- `--scale` (default 3) is the Art scale in the model scene. The player body is drawn at 3x, so 3 matches the pixels. A long picture may need 2.
- It makes 4 files: `assets/game/ui/items/<id>.png`, `data/items/<id>.tres`, `data/weapons/<id>.tres`, `scenes/weapons/<id>_model.tscn`. Then it imports the picture.
- It prints the angle, the length in game and which end is the handle. Check those first. `--dry-run` only prints.
- Then look: Test yard, `Tab`, tab `Items`, take the weapon. A proof picture: `tools/new_weapon_proof_shot.gd` (see its first line). Move `MainHandGrip` in the editor if the hand should hold a different spot.

## By hand, in the editor

One rule: **the `MainHandGrip` marker of the model scene is where the hand holds the weapon.**
The swing, the afterimages and the guard all move this point. When the game starts, the picture and the hit area shift so that the Grip sits on the player's hand.

## Steps (example: a new "iron sword")

1. In the FileSystem dock, duplicate `scenes/weapons/wooden_sword_model.tscn` (it is the worked example). Name it `iron_sword_model.tscn`.
2. Open it. Select `Art` and set its Texture to your new picture. Keep `Art` a Sprite2D with Texture Filter = Nearest and a Scale (the example uses 2; decimals like 1.3 work, whole numbers stay sharpest).
3. Put the **hand-grip pixel on the origin** (0,0). In the example the picture is drawn diagonally (handle bottom-left), so `Art` has Rotation 45 degrees and `Offset` = minus the grip pixel (-8.5, -22.5). To fit a new picture: find the pixel on the handle just above the pommel, set Offset to minus its position, then rotate until the blade lies along +x.
   Then open the weapon scene, click `MainHandGrip` (a Marker2D), press **W** and drag it along the sword to where the hand holds it. Press **Ctrl+S**, then **F5** to look in the game. Grip further up the blade = less reach in front of the hand, more behind it. The hit area follows the picture. You can also move `Art` itself. Size is checked in the game, not here.
4. Select `Tip` (a Marker2D) and drag it to the **end of the blade**. It only helps you check the fit. It changes nothing in the game.
5. Do not touch `Hitbox`. Reach and hit area are gameplay numbers (`arc_degrees`, the Hitbox shape), not art.
6. Duplicate `data/weapons/wooden_sword.tres` as `iron_sword.tres`. Set `Model` to your new scene.
7. In the same file, pick `Swing Motion` (for example `data/swing_motions/sword_natural.tres`). Empty = the old snap swing.
8. Start the game, give yourself the sword, press **F1**. A cyan cross shows the grip, a pink dot shows the tip.
   Swing and look: the cross should be on the handle all the time, the dot on the blade end.
   If not, go back to step 3 or 4.
   A white X on the player is the hand: the point where every weapon is held. The weapon's grip sits on it.
9. Press **F5** to check the weapon in the game. Check the size there.

## Notes
- A bigger picture needs no other change. Afterimages copy the real picture, so they fit any size.
- To tune the feel (hand path, wobble, afterimages) open F3 and use the "Swing ..." section. Numbers are live.
- Never move the Hitbox to "fix" the look. Move the picture.

## See it live (size, place, angle)
You do not need the editor to fix how a weapon sits in the hand.

1. Start the game. Hold the weapon (hotbar key `1`-`9`).
2. Press **F3**, tab `Tune`. In the search box type the weapon name (for example `glide`). A tool is called `Tool axe`.
3. Press the action button **Hold weapon still** (tab `Actions`, group `WeaponVisual`). The weapon now stays on screen and the mouse no longer turns it. It points right. To point it elsewhere, use the slider `dev_still_aim_deg` (group `WeaponVisual`: 0 = right, 90 = down, -90 = up). Press **F1** to see the hit area.
4. Open the group `Art fit` and change:
   - `art_scale`: 0 = as the scene has it. 0.05 to 4 = that size. Decimals are allowed (1.3 is fine). Whole sizes (1, 2, 3) stay the sharpest.
   - `art_nudge_x` / `art_nudge_y`: move the picture in px. x goes along the blade, y across it.
   - `art_turn_deg`: turn the picture.
   The picture and the hit area change at once. The grip (the hand) never moves.
5. The `WeaponVisual` status shows `fit: ...`. If the status says `OFF AXIS`, the blade is no longer on the hit line: turn it back.
6. Happy? Press `Write K to .tres` at the bottom. It saves into `data/weapons/<name>.tres` and stays after you close the game.
   Each weapon keeps its own values.

`Hold weapon still` and `dev_still_aim_deg` are only for tuning. It is never saved.

## Two hands
A weapon's `OffHandGrip` marker is where the free hand holds it. Open the weapon scene, click `OffHandGrip`, press **W** and drag it. Ctrl+S, F5. It moves with the swing.
Delete `OffHandGrip` for a one-handed weapon: the free hand then stays on the body. The tool makes `OffHandGrip` for you (`--hands 1` = no `OffHandGrip`): move it by eye. It does not follow `art_scale` in F3: if you change the size, move it too.

## Move where all weapons are held
Every weapon is held at the same point of the character: the `MainHandHold` marker.
Open `scenes/player.tscn`, click `MainHandHold`, press **W** and drag it. Ctrl+S, F5. When the player faces left, the Hand flips to the other side by itself (only x).
While playing: **F3**, tab `Tune`, section `WeaponVisual`, `hand_nudge` moves it live. F1 shows the hand as a white X.
The hand also moves up and down with the body frames by itself (idle, run). Drag it while the body shows idle frame 0. `hand_follow` (F3, section `BodyRig`) = 0 turns this off.
