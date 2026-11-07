# 0049 - Natural sword swing (grip path, wrist, afterimages, alternating side)

## Context
The sword turned on a fixed pivot and jumped to the end of the arc in one frame, with a crescent slash drawn on top. It read
as a clock hand, not an arm. The approved look (`tools/art_tests/swing_styles/render_natural.py`, "B + arm + wrist") moves the hand on curves,
lets the blade lag behind the hand, wobbles on recovery, and leaves fading copies of the blade.

## Decision
- New resource `SwingMotion` (`scripts/visual/swing_motion.gd`, shared file `data/swing_motions/sword_natural.tres`): every number is an `@export`
  (grip points, curve controls, angle pads, wrist lag, wobble, afterimage count / alpha / interval, `crescent_on`, `alternate`, `alternate_reset_time`, `alternate_return_time`).
- `WeaponData.swing_motion` (null = the old swing, untouched). Set on `wooden_sword` and `copper_sword` only.
- `WeaponVisual` draws a COPY of the model's `Art` on its own node `SwingArt` and hides the original. The model, `SwingPivot` and `Hitbox`
  keep the old pivot path, so reach, hit area, sweep and timing are exactly as before (proved by `tests/test_natural_swing.gd`).
- `SwingGhosts` (afterimages) is its own node, fed only by `WeaponVisual` poses. `SwingFx` crescent is off when `crescent_on` is false.
- Alternate: every other swing is mirrored across the aim line (grip y and angle sign). The blade rests on the side it ended on, the windup starts from there;
  after `alternate_reset_time` without swinging it eases back (`alternate_return_time`) and the next swing goes the first way again.
- F3: section "Swing Sword Natural" (all numbers, live), `WeaponVisual` status line `swing: phase  dir  grip  ghosts`.

## Why
Art moves, hitbox does not: the look can change (or become a real sprite animation) without touching combat. The hit arc is a symmetric
cone around the aim, so a mirrored picture never disagrees with it.

## Consequences
- While a sword is held the model's own `Art` node is hidden; tools reading its transform still work, tools reading `visible` do not.
- The picture's rest pose (REST grip) differs from the hitbox pivot (0,0) by a few px. Visual only.
- A later sprite animation replaces `SwingMotion.pose()`; timing stays in `WeaponData`.

## Addendum: drawn slash "P3" replaces the code smear
- `SwingSlash` (own node, `scripts/visual/swing_slash.gd`, art in `assets/game/fx/slash/`) is driven only by `WeaponVisual`. While active it sits on the live grip, scaled so
  the art's outer edge reaches the blade tip, inner radius cut by a tiny shader, newest end on the blade. f1 shows once the blade has turned 67 deg since active began, f2 at 150 deg.
  At active end it freezes (position + angle) and plays f3, then f4 fading (`slash_fade_time` 0.08 s), then hides. Mirrored swings flip the sprite.
- All numbers are `SwingMotion` "Slash art" fields (`slash_*`), live in F3. `smear_on` is now false by default (the code smear stays as an option); sword copies stay off.
- Timing: wooden + copper sword `active` 0.13 (was 0.10), `recovery` 0.24 (was 0.20); windup unchanged. Spec = `tools/art_tests/swing_styles/render_trails_b2.py`.

## Addendum 3 - the slash is a RIBBON, the sword gets the top lift (B)
- Problem: the fixed crescent sprite was only placed + rotated on the grip, so it drifted off the real blade path (mirrored / lifted swings, `screen_offset`).
- `SwingRibbon` (`scripts/visual/swing_ribbon.gd`, child of `WeaponVisual`, driven only by `tick()`): every frame it samples `SwingMotion.swing_path` + `screen_shift` (the picture's and the hit sweep's maths)
  `ribbon_steps` times from `t - ribbon_tail_t` (clamped at active start) to `t`, builds the band between `ribbon_inner` (share of the Tip length) and the tip, and draws it as a textured strip. Outer edge = blade tip, always.
- Look = the drawn art, unwrapped once offline (`tools/art_tests/slash_smear/unwrap_ribbon.py` -> `assets/fx/slash/ribbon_f1..f4.png`, x = along the arc, newest end at x=0, y = inner -> outer, nearest filter).
  f1 early / f2 late in active; after active the band freezes on the final path and shows f3 then f4 fading (`slash_fade_time`); it never swings back. Mirrored / left aim need no special case (the geometry comes from the real path).
- `SwingMotion.slash_mode` "ribbon" (default, sword) | "sprite" (the old `SwingSlash`, unchanged). F3 `slash:` status shows mode + frame + degrees covered.
- Option B kept: `top_lift_px = 40` in `data/swing_motions/sword_natural.tres` (the live sword). The demo-only `sword_natural_a/b.tres` are deleted.

## Addendum 4 - ribbon shape, user-picked by demo (C + D + G)
- Shape: crescent taper `ribbon_taper_power/skew`, tail limited by `ribbon_tail_deg`, texture mapped by degrees (`ribbon_px_per_deg`).
- C, pointed tail: the tail narrows to a point on the outer edge over `ribbon_tail_taper_deg` (40) with `ribbon_tail_power` (1.25), even when the band is short (first frames).
- D, no sliding: `ribbon_pivot_lock` 0 = the band stays exactly where the blade passed (a lock > 0 pulled the old part onto the moving hand, so the trail slid with the sword). `ribbon_pivot_anchor` kept as a knob; anchor < 1 with lock > 0 lifts the front off the blade (known, unused).
- G, wide head: `ribbon_head_fill` 1 keeps the blade end full width while active; pointed only in the fade. `ribbon_head_fill_release` (1 = off) had no visible effect in the demo.
- Proof: `tools/art_tests/swing_styles/{tail_point,trail_anchor,head_fill}/`. Each step judged by a fresh Opus reviewer before the user saw it.
