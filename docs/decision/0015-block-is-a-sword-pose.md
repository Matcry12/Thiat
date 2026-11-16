# 0015 — Blocking is shown by a sword pose; the shield becomes a weapon later

**Status:** Active

**Date:** 2026-09-28
**Revises:** the *visual* of [0013](0013-parry-and-block-on-one-key.md) and
[0014](0014-shield-is-a-bar-that-breaks.md). The mechanics are untouched: tap F to parry, hold F to
block, a shield bar that breaks, purple breaks it, 180° directional.

## Context

After playing with the shield icon, the user reframed what a shield is:

> "shield is a sup weapon or weapon we will des in future, for know when blocking, player will
> doing a pose to defend, may be let the sword up and front to mouse?"

A shield icon appearing from nowhere implies a shield the player owns. If shields are going to be
real equipment later — an off-hand item with its own stats — showing one now promises something the
loadout doesn't have yet (the same "don't lie about the inventory" worry from 0013).

0013 had rejected a weapon pose because of *"animation work for every weapon"*. That worry does not
hold in this codebase: the sword is not animated with frames, it is a rotation that code eases
between target angles. A guard pose is **one more target angle**.

## Decision

- **Hold F → the sword snaps into a guard pose**: raised across the attack line, edge toward the
  mouse. Release → it drifts back to rest.
- **The pose is one number per weapon**: `WeaponData.guard_angle_degrees` (default **-90**, relative
  to the aim). A hammer or spear later gets its own number, not its own animation.
- **How fast it moves is a feel number** on `WeaponVisual`: `guard_raise_time` 0.06s,
  `guard_lower_time` 0.12s, `guard_ease` 0.4. The raise must finish well inside the 0.25s parry
  window, otherwise the sword is still moving when the parry has already landed — a test asserts it.
- **The shield icon and crack overlay are hidden, not deleted** (`GuardVisual.show_shield`, default
  off). The art, the crack pattern and the slot come back when the shield becomes an off-hand
  weapon.
- **Kept:** the glow arc (it shows the exact width you cover, which the sword alone cannot), the
  shield bar in the HUD, and the shard burst on break.

## Consequences

- **The only place shield health now shows is the HUD bar.** The cracks were the in-world gauge;
  they are hidden with the icon. If players lose track of the bar mid-fight, the fix is a tint or
  shake on the sword as the bar drops — cheap, and not built until a playtest asks for it.
- **The hitbox rides on the same pivot as the blade** (0011), so it moves into the guard pose too.
  It is inactive while guarding (you cannot attack), so this deals no damage — but a future
  "counter from guard" move would start from this pose, which is convenient.
- The earlier memory rule "prefer a shared effect over per-weapon animation" is narrowed, not
  dropped: a pose that is **one number** is fine; anything needing per-weapon **frames** still
  defaults to a shared effect.

## Amendment (2026-09-28): a pose is three numbers, and it can be previewed

User: *"each weapon gonna have special pose to defend ... I want to custom that pose"*. An angle
alone can't express a spear pushing its guard out, or a hammer pulling in to the body. So a guard
pose is now three numbers on `WeaponData`: `guard_angle_degrees`, `guard_forward` (toward the mouse)
and `guard_side` (across it). They are floats rather than a Vector2 so that they show up as F3
sliders.

`WeaponVisual.preview_guard_pose` (editor only) shows the pose in the editor while the numbers are
being edited. This works around the fact that the pose otherwise only exists while F is held in a
running game.

**`SwingPivot`'s whole transform is now code-owned** — rotation *and* position. To move the hand,
drag `WeaponVisual`; to move the grip, drag `Blade`. Never drag `SwingPivot`.

## Parked: the shield icon (2026-09-28)

User: *"remove the shield, we're not using it, just saving for future"*. The icon and crack overlay
are gone from the scene and from `guard_visual.gd`. The **shield bar** (what blocking drains, shown
in the HUD, breaks at 0) is a different thing and is still in use — untouched.

**Update (same day): the art is deleted too** — user: *"the pexel one we dont need that"*. Nothing
shield-shaped is left in the project except the shield *bar* mechanic. If it is ever wanted back,
the last working version of everything (art, generator, code, scene, test) is commit `a365828`:

```bash
git show a365828:scripts/visual/guard_visual.gd
git show a365828:tools/make_placeholders.py      # shield() and crack_overlay()
git checkout a365828 -- assets/placeholder/shield.png assets/placeholder/shield_cracks.png
```

Lessons from it that still apply when it returns: cracks are a **child** of the shield (one
position, owned by the user); cracks set **alpha only** because they inherit the shield's tint; the
crack layer must assume **nothing** about the shield texture under it.

## Amendment (2026-09-28): the shield bar is a curve next to the player

User: *"a curve bar that show shield bar"*. Given the choice, they picked a **separate arc** over
merging it into the glow. That keeps one job per shape: the glow shows *which side* is protected,
and the curve shows *how much* shield is left. (Merged, a half-empty glow would look like
half-protected.)

- `CurveBar` (`scripts/visual/curve_bar.gd`) is **generic**: a 0..1 value drawn along a circle.
  It is a `@tool`, so you can drag it and shape it (radius / start / span / colours) in the
  editor. Code writes only `value`, `visible` and `modulate`. The same script can later show a
  dodge cooldown or a boss charge.
- As `GuardVisual/GuardBar`, it is **shown** while guarding, while broken, and while refilling. It
  is **hidden** when full and idle, so it doesn't sit on screen all the time. It turns **red**
  while broken, so an empty bar reads as "no guard", not just "low".
- `GuardVisual.set_tank_fill()` is back, and now drives the bar (duck-typed `value`, so a
  `TextureProgressBar` or a sprite ring can replace it).
- The HUD shield bars are **gone** (user: "remove the shield bro"). The curve is the only
  shield display. The HUD shows HP and the dodge cooldown.

## Amendment (2026-09-28): the guard bar is merged into the guard arc

User, reconsidering: *"what about merge into the guard?"* — they chose to merge the bar into the glow
arc, the option turned down earlier. The reason it was turned down (a half-empty arc would look
half-protected) is solved by drawing the arc's full width as a dim **track** that never shrinks;
only the bright **fill** drains, toward the aim line from both ends.

- `CoverArc` now has `value` (guard left) and `track_color`. It is one curve with two jobs: where
  you are protected, and how much guard is left.
- `GuardVisual` shows it while guarding, while broken (red, `broken_color`) and while refilling
  (dim, `refill_modulate`). It is hidden when full and idle.
- `CurveBar` and the `GuardBar` node are deleted — nothing else used them.
