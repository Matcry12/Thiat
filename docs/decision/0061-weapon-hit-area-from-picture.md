# 0061 - Weapon hit area from the picture

## Context
Each melee model scene had a hand-typed `RectangleShape2D` (wooden sword 56 x 9.56, sword1 50 x 9.56) and a hand-set `Tip` marker. A longer or new sword picture did not change what the sword hits (0011, 0028, 0050).

## Decision
When a model is built (`WeaponVisual._rebuild_model`), and again whenever a `hit_*` number changes (WeaponData emits `changed`, so F3 edits are live), `WeaponHitFit.apply` measures the `Art` picture in model space (origin = grip, blade along +x; Art offset / rotation / scale, `region_rect` and `AtlasTexture` honoured):
- length = farthest visible pixel centre along +x + `hit_tip_margin` (8). Visible = alpha above `hit_alpha_min` (0.5);
- width = median blade thickness along the blade + `hit_width_margin` (2.5), never below `hit_min_width` (9). The median keeps a crossguard from widening it;
- the shape is a duplicate (scene SubResources are shared); the `Tip` marker x is set to the measured tip. The scene's hand-set shape and Tip are remembered, so `hit_auto_fit` off puts them back;
- the shape's y stays the scene's hand-set y. If the measured blade centre is more than `hit_axis_warn_px` (4) away from it, the status adds `OFF AXIS: fix Art rotation/offset` and a warning is logged once per picture.
Exports live in WeaponData group `Hit area from picture`. Measures are cached per texture + Art transform + alpha. No Art / texture / non-rectangle shape = hand shape, no error.

**Plainly: length and width are automatic. The grip and the angle (Art `offset` and `rotation`, so the blade lies on +x with its grip at the origin) are still set by hand for each new picture.** A picture whose blade is not on +x gets a box that mostly misses; the OFF AXIS note is the only help.

## Why
A new picture needs no typing for size, and the F1 area and the Tip-driven slash / ribbon / ghosts agree with the picture. Margins are data so the feel stays tunable in F3.

## Consequences
- Hit sizes (old -> new): wooden sword 56 x 9.56 -> 56.1 x 9.5; sword1 50 -> 50.4 x 9.5; copper sword 56 x 9.56 -> 60.3 x 12.5 (width +31%); axes -> 63.9 x 15.5 (width +62%); pickaxes -> 57.5 x 11.
- The axe's blade now reaches 63.9 px against `tool_target_reach` 64: the blade alone nearly covers what the target assist did. Not retuned.
- Tip moves to the real tip: wooden / sword1 < 0.5 px; copper sword 49 -> 52.3; axes 50 -> 55.9; pickaxes 44 -> 49.5. The ribbon size reads `_tip`, so tool ribbons grow about 12% and the copper one about 7%.
- Copper sword: its measured blade centre is 2.4 px from the hand-set line (y = -1); under the 4 px warn limit, so no warning, and the shape keeps y = -1.
- `BodyRig.visual_scale` still never touches the hit area (measured at rig scale 1).
- Limit: the blade must run along +x; no flip / hframes.
- `tests/test_weapon_hit_fit.gd`. `test_weapon_model_geometry` expects the new shape size and `hit_pos` (0.04 px: shape centre is length / 2).
