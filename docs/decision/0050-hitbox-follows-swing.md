# 0050 - The sword's hit area follows the swing animation

## Context
0049 made the sword picture move on curves (grip path, wrist lag, alternate side, `aim_bias_deg`, `screen_offset`) but kept the hit area on the old
fixed-pivot 120 deg wedge. The player saw one thing and was hit-tested against another: a dummy the blade passed through could be missed, one far from the blade could be hit.

## Decision
- `SwingMotion.swing_path(t, half_deg, flip)` is the ONE pure function for the ACTIVE path: grip (aim frame, unscaled) and blade angle, aim_bias included.
  Both `WeaponVisual` (picture; via `biased()` + `pose()`, same maths, windup/recovery bias easing unchanged) and `Hitbox.motion_poses()` use it, so they cannot drift.
  `screen_offset` (screen px) is converted into the aim frame by each caller.
- `Hitbox.motion_poses`: the hit shape, read relative to the model origin (the grip), placed at the sampled grip + angle. A weapon with `swing_motion` hits ONLY through this sweep;
  the node's own polled overlap (old pivot) is off for it. Weapons without a motion keep the old arc exactly (fists, axe, pickaxe; bow has no hitbox).
- `WeaponData.hit_follows_blade` (default false): false = snap, the whole path is tried on the first physics frame of active (as before). true = progressive:
  `WeaponHolder` calls `Hitbox.advance_sweep(t)` every physics frame of active, trying every pose between last frame's t and this one (no gaps). Swords use `sweep_samples` 24 (12 left gaps along the path).
- Swing side owner: `WeaponHolder` (`swing_flip`, decided in `_start_attack` with `SwingMotion.next_flip(prev, seconds_idle)`). The Hitbox reads `swing_flip` from the holder's write;
  `player.gd` forwards it to `WeaponVisual.set_swing_flip()` before each state. Combat never reads the picture; the picture only follows. (Rest-side easing back after the reset time stays visual only.)
- F1: motion weapons no longer draw the white wedge; they draw the outline of the real swept area, the red swept poses, and the last pose as the live hit shape (the model's own Hitbox node is not drawn: it deals no damage).

## Why
What the player sees is what hits. One function + one side owner means a tweak to grip points, `aim_bias_deg` or `screen_offset` moves picture and hit area together.

## Consequences
- Amends 0049 "visual only": `SwingMotion` grip points, `aim_bias_deg`, `screen_offset` are now gameplay data. Timing still lives in `WeaponData`.
- Limit: hitboxes are never scaled by the rig, so the hit path uses grip positions of `visual_scale` 1; with `visual_scale != 1` the picture's grip path is scaled and can differ a little.
- `SwingFx` crescent (off for motion weapons) still reads the old `arc_poses`; unchanged.
- `tests/test_swing_sweep.gd` now clears the sword's motion to keep covering the old arc; the motion sweep is `tests/test_hit_follows_swing.gd`.

## Addendum - tools: side chop + target hit
Axes and pickaxes (`data/weapons/{stone,copper}_{axe,pickaxe}.tres`) now use one shared motion, `data/swing_motions/tool_chop.tres`, with `hit_follows_blade = true` and their own models (`scenes/weapons/<tool>_model.tscn`).
- **Side chop**: `SwingMotion.side_only` (+ `side_tilt_max_deg`, `side_deadzone_deg`) snaps the picture AND the hit path to right or left, leaning up to 35 deg toward the real aim. The tool always rises over the head and lands on screen, never up / down. `WeaponVisual.set_aim_angle` does the snap, so picture and hit share one node (rule held). The side never flips mid-swing. An aim on the exact opposite side eases the tilt to 0 (folded, no jump).
- **Target hit**: `WeaponData.tool_target_reach` / `tool_target_cone_deg` (0 = off; tools only). `WeaponHolder.find_tool_target()` picks, at the start of the swing, the unbroken `ResourceNode` inside reach (user to node edge) and the cone around the REAL aim (a node that likes the tool wins over a closer one that does not). At `tool_target_hit_t` (default 0.6) of the active phase, or at the end of active if sooner, it gets ONE gather hit through `Hitbox.hit_gather_target` -> `take_gather_hit` (same path as a blade hit); the node is counted in the swing, so the blade cannot hit it again. No target = the blade alone decides. Enemies are never targeted. The step forward (`step_distance`) leans toward the target node, else along the real aim.
- **Why**: the player does not watch a tool swing, they watch the tree. With a side-only picture, a tree above the player would be "missed" while the cursor is on it. Picture / hit mismatch is accepted for tools only; the sword keeps "what you see is what hits".
- F3 `[Weapon]` status shows `tool target: <name> <px> | none`; F1 draws the reach arc + cone (orange) and a ring + line on the target.
