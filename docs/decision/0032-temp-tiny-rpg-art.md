# 0032 - Temporary art: Tiny RPG Soldier (player) and Orc (boss)

**Date:** 2026-10-16 - **Builds on** [0028](0028-3d-rendered-characters.md) (BodyRig) and [0005](0005-architecture.md).

## Context
The user wanted real pixel-art characters for playtests. The free "Tiny RPG Character Asset Pack" (zerie, itch.io) has a Soldier and an Orc, 100x100 cells, side view only (faces right). Licence: game use and edits OK, **no redistribution, no AI training**. The repo is local only. This art is **temporary**.

## Decision
- **Player = Soldier**, through the existing `BodyRig`: `data/body_rigs/tiny_soldier.tres` (frames, `body_position`, `body_scale` 2, shadow, weapon / hand scale, run-cycle frames). `player.tscn > Visual > rig` points at it. Old rigs (`blocky`, `soft_body`, `drawn_art`) load by swapping that one resource.
- **Side-only sets are supported by `SpriteActorVisual`:** a SpriteFrames with `idle_side` but no `idle_front` never goes "front" (left = flip). Clips: `idle_side`, `run_side` (Walk), `hit_side` (Hurt), `death_side` (not wired to anything yet).
- **Run cycle frames in the rig:** `BodyRig.landing_frames` / `lift_frames` (empty = the visual's blocky values). Walk has 8 frames, so the dust puffs and shadow dips are on 3, 7 and 1, 5.
- **Boss = Orc**, in `BossVisual` (own `Body` + `Shadow` nodes in `boss.tscn`, frames `assets/characters/tiny_rpg/orc_frames.tres`). Exports: `body_frames`, `body_position`, `body_scale` (3 now, whole number), `shadow_*`, `attack_anims`, `strike_frame`, `recover_frame`, `hurt_time`. Clear `body_frames` and the old placeholder circle is back.
- **Attack timing stays in data.** `BossAttack` emits `phase_changed(action, phase, duration)`; `Boss` forwards it to `visual.set_attack_phase`. The clip is split into windows: telegraph = frames before `strike_frame`, active = `strike_frame` .. `recover_frame`, recovery = the rest. Each window is stretched over the attack's own `telegraph_time` / `active_time` / `recovery_time` (same idea as `speed_scale = clip length / data duration`). Changing a time in F3 changes the animation speed, never the reverse. Hitboxes and attack areas are untouched.
- **Boss reactions:** `idle` / `run` from the boss's velocity, facing flips toward the player, `hit` clip on a hit (only when not mid-attack: a hit does not stagger it), `death` on defeat.
- **Files.** Pack copy, untouched: `assets/third_party/tiny_rpg/` (+ `LICENSE-NOTE.md`, and a `.gdignore`: Godot does not import it). Used by the game: `assets/characters/tiny_rpg/` (Orc sheets copied as they are; Soldier strips with the baked shadow removed by `tools/tiny_rpg_unshadow.py`, rows >= 55, since the pack's "no shadow" Soldier folder still has one; the SpriteFrames).
- **Charge and ring.** The charge ACTIVE window is `distance / speed` (`BossAttack._window_time`); the Orc loops the `run` clip for it (`loop_active_actions`, `dash_run_speed`) and the real RECOVERY signal ends it. A charge keeps facing its lane (`BossAttack.facing_dir`). The ring re-signals TELEGRAPH and ACTIVE for its second blast, so the Orc winds up and strikes twice.
- **Flip.** The feet sit 0.5 art px right of the cell centre; `feet_x_px` flips the sprite offset with the facing, so the feet stay on the shadow. The rest of the sideways shift in the attack frames is the art's own lunge (the body leans 7 px in frames 1-2), mirrored correctly.
- **Scale options** (the user decides): `docs/demo/tiny_rpg_scale_compare.png` (A Soldier 2 / Orc 4 now, B both 3, C Soldier 2 / Orc 2, D both 4), made by `tools/tiny_rpg_shots.gd` + `tools/tiny_rpg_compare.py`.

## Double sword?
The Soldier's idle, walk, hurt and death frames hold **no sword** (only the Attack frames show one, and we do not use them). So our 2D sword and hands are the only sword. Our hand discs sit beside the Soldier's own drawn arms: a little busy but readable, so they stay, small (`hand_radius` 2 in the rig). If it bothers you, set `hand_radius` lower in the rig.

## Why
Real art to judge size and feel now; nothing else changed. A swap, not a rewrite (CLAUDE.md section 5).

## Consequences / how to swap back
- Player: open `scenes/player.tscn`, `Visual > Rig`, pick `blocky.tres` (or `soft_body.tres`, `drawn_art.tres`).
- Boss: `scenes/boss.tscn`, `Visual > Body Frames`: clear it for the circle, or point it at another SpriteFrames with `idle`, `run`, `hit`, `death` and the clips in `attack_anims`.
- Before sharing or publishing the repo: delete `assets/third_party/tiny_rpg/` and `assets/characters/tiny_rpg/` (licence: no redistribution).
- Known art limits: side view only (no front / back), the Orc is small and wide (22x15 px), our slam telegraph (radius 110) is much bigger than the axe.

## Update: the user picked scale option B (both 3)
- Soldier rig: `body_scale` 3, `body_position` (0,-18), `shadow_scale` 0.9, `visual_scale` / `slash_scale` 1.0 (sword in proportion to the bigger body), `hand_radius` 3, `hand_rest_*` (7,+-14). Orc `BossVisual`: `body_scale` 3, `body_position` (0,1), `shadow_scale` 1.3 (shadow offset (0,22) unchanged, feet stay on it). The Orc is now about 66x45 px, smaller than its 64 px hurtbox is wide.
- Hitboxes, hurtboxes, attack areas and the sword's hitbox are unchanged (visual only). Images re-taken at the real game zoom (1).
