# 0011 — The hit area lives on the weapon, not in numbers

**Date:** 2026-09-24

## Context
Slice 1 computed melee hits from numbers on `WeaponData`: a circle of `reach` around the player's
feet, filtered by `arc_degrees` around the aim direction. The weapon *sprite* was placed by a
different set of numbers (`hand_distance`, `rest_angle_degrees`, `art_angle_degrees`, sprite offset).

Nothing linked the two. The drawn sword and the area that actually hit visibly disagreed, and the
only remedy was a human tuning six numbers by eye until two independent systems happened to line up
— which broke again with every new weapon. Research
([melee-authoring.md](../reference/godot/melee-authoring.md)) confirms this is not how Godot
projects do it.

## Decision
**The `Hitbox` becomes a child of the blade sprite, and its shape is drawn in the editor to match
the art.**

- `Hitbox` (Area2D) is reparented under `WeaponVisual/Blade`, so it inherits the blade's position
  and rotation for free. Sword swings → hit area swings with it.
- Its `CollisionShape2D` is authored visually in the 2D editor, sized over the blade.
  **What you see is what hits.**
- `Hitbox` stops computing angles and distances. It becomes a plain overlap check plus the
  existing once-per-swing de-duplication.
- `WeaponData.reach` is **removed** — the shape defines reach.
- `WeaponData.arc_degrees` is **kept**, but its meaning is now "how far the blade sweeps during the
  active frame" — a motion property that genuinely drives where the hit area travels.
- The drawn telegraph wedge is removed. The visible blade *is* the telegraph now.

## Why
- Two sources of truth for one concept is the defect. Making the hit area part of the weapon
  removes the disagreement **by construction**, not by tuning.
- Adding a weapon becomes: drop in a picture, drag the shape over the blade, type damage and
  timings. No invisible numbers to guess.
- It is what the engine is built for: transforms already propagate to children.
- It keeps [0005](0005-architecture.md) intact — balance numbers stay in `WeaponData`, shapes and
  placement move to the scene, which is the standard split.

## Consequences
- `tests/test_arc_filter.gd` tested the angle maths and is deleted with it. Replaced by a test that
  the hitbox is parented to the blade and only deals damage during the active frame.
- Hit detection now depends on the blade actually sweeping through the target, so the swing motion
  is gameplay, not decoration. A visual change to the swing is a balance change — intended.
- A weapon with no sprite (a spell, a shockwave) still works: give its hitbox a shape; nothing
  requires a texture.
- Reach can no longer be changed with a slider. It is changed by resizing the shape in the editor,
  which is the point.

## Amendment (2026-09-24) — the melee shape is now generated, not hand-drawn

The hit area still lives on the weapon and is still a real shape — that part of the decision is
unchanged. What changed: for melee, a hand-dragged `RectangleShape2D` was a clumsy way to describe
a sweep and gave no numeric control. A sweep is naturally a **sector** (a pie slice): an arc angle
plus a radius.

- `SectorShape` (`scripts/components/sector_shape.gd`, `@tool extends CollisionPolygon2D`) builds
  the polygon from `WeaponData.arc_degrees` + `WeaponData.radius`. The numbers still GENERATE the
  one shape that both F1 shows and physics tests against — there is still exactly one owner, it is
  just computed instead of dragged.
- `Hitbox` moved from `WeaponVisual/Blade` to `WeaponVisual` itself (the hand pivot). It rotates
  with aim but not with the blade's own windup/active/recovery swing animation — that swing is
  what the sector's `arc_degrees` already represents numerically, so letting the shape also
  physically swing with the blade would double-count the same motion.
- Accepted trade-off: `radius` is just a number, so a sloppy value can stop matching the blade
  art's length (a short blade with a huge radius, or the reverse). This is deliberate — F1 draws
  the real generated polygon every frame, so the mismatch is visible immediately. Catching that
  mismatch on sight is the whole point of the debug view, not a gap in it.
- A hand-authored shape (like the enemy's `CollisionShape2D` strike circle) still works — `Hitbox`
  and the debug overlay accept either a `CollisionShape2D` or a `CollisionPolygon2D` child. Nothing
  requires a weapon to be a sector.
