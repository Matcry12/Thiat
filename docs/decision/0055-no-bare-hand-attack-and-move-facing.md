# 0055 - No bare-hand attack, body faces movement

## Context
Empty hands (empty slot, material, placeable) still punched (fists.tres, damage 6) even though they gather 0 (0048). The body always faced the mouse, even when just walking.

## Decision
- `Loadout.can_attack()` is false with bare hands; `player.gd` ignores the attack input then (placing placeables still works). `fists.tres` stays only as the "hands" pose weapon, it is never swung. The `Fists` F3 section is gone.
- Body facing = move direction. For `face_mouse_hold` s (`Player`, default 3.0, user asked 2-4 s) after a weapon swing, skill, guard, bow charge or place, it faces the mouse. Idle keeps the last facing. F3 `[Player]` shows `facing src: move | mouse 0.42s`. The body only turns left / right (walking up or down keeps the last side); only while facing the mouse does the held weapon point in the full aim direction.
- Aim, hit direction and the weapon picture still follow the mouse (only `visual.set_facing` changed).

## Why
Hands that hit but gather nothing were a loophole around tools. Facing the mouse while walking away looked like moonwalking.

## Consequences
- Craft-station interact is not counted as an action (crafting is a UI window, no world interact key).
- Tests inject the mouse with `player.aim_override`.

## Addendum - tools chop in every direction
The user found the side chop (0050 addendum) could not swing down at a tree or rock below. `data/swing_motions/tool_chop.tres` now has `side_only = false`: axe and pickaxe swing toward the mouse like the sword, the picture and hit path still share one transform, and the tool target hit is unchanged. The `side_*` knobs stay on `SwingMotion` (F3) to switch it back.

## Addendum - held item hidden when idle
Like Tinkerlands, the held weapon / tool / item (`WeaponVisual`, incl. `HeldItem`) is shown only while the player faces the mouse: in use and `face_mouse_hold` s after. `Player.hide_idle_held` (default true, F3) switches it off. Combat is unaffected (the Hitbox is an Area2D, visibility does not change it); the Placer ghost stays visible for aiming a placement.
