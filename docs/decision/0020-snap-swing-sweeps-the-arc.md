# 0020 — A snapping swing sweeps the arc in one frame

**Status:** Active

**Date:** 2026-10-01

Amends [0011](0011-hitbox-lives-on-the-weapon.md).

## Context
The sword now looks like Soul Knight's: the blade pulls back, then SNAPS to the end of the arc
in about one frame, and a slash effect shows the path it travelled. But the `Hitbox` hangs on the
blade (0011), so it snapped too. A target in the middle of the arc was never touched - the hit
area jumped from the start to the end and skipped it. What you see (a slash across the whole arc)
no longer matched what hit.

## Decision
- The shape is still drawn on the blade (0011). Reach still comes from that shape.
- On the first physics frame of ACTIVE, `WeaponHolder` calls `Hitbox.sweep_arc()`. It tries the
  hitbox's own shape at `WeaponData.sweep_samples` angles from -arc/2 to +arc/2 around the grip, using
  `intersect_shape` with the hitbox's layer/mask. Every target found is hit once (the existing
  once-per-swing list).
- For the rest of ACTIVE the normal overlap check continues at the blade's end position.
- The math reads only the aim node's transform (it includes the left-aim mirror), the pivot
  position, and the shape's pose relative to the pivot. It never reads the blade's current angle,
  so it does not depend on the picture.
- The visual never writes into the Hitbox. F1 draws the swept poses during ACTIVE.

## Why
- Hit follows picture: the slash shows the arc, and the whole arc hits.
- Combat owns hit areas; the visual node stays a picture.
- An earlier try (rotating the Hitbox from `WeaponVisual` to fake the old sweep) made a visual node
  change gameplay and made the hit secretly differ from the slash. Rejected.

## Consequences
- Targets anywhere in the arc are hit at the START of ACTIVE, not progressively over 0.1 s.
  Windup / active / recovery data are unchanged.
- `WeaponData.sweep_samples` (default 12, about 8 deg apart) is a tuning number. Very thin shapes or tiny
  targets could slip between samples; raise it if that happens.
- Enemy `Attacker` hitboxes do not call `sweep_arc()` and are unchanged.
- Test: `tests/test_swing_sweep.gd` (both ends, middle, outside, aim right and left).
