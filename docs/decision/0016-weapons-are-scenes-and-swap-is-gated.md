# 0016 — Each weapon is its own scene; swapping is gated

**Date:** 2026-09-28
**Builds on:** [0003](0003-loadout-and-swapping.md) (the loadout rules), [0011](0011-hitbox-lives-on-the-weapon.md)
(the hitbox lives on the weapon), [0012](0012-weapon-behaviours.md) (behaviours), and
[0015](0015-block-is-a-sword-pose.md) (per-weapon guard pose).

## Context

Slice 3a adds a second weapon (a bow) and swapping between them. Its question:

> **Is the 5s swap cooldown interesting or annoying?**

Until now there was one weapon, and its picture (`Blade`) and hit area (`Hitbox`) were children of
the **player** scene, placed by hand by the user. A second weapon cannot reuse those nodes. It would
need a different grip, a different picture and a different hit area (or none, for a bow). Rewriting
their positions on every swap would put code in charge of values the user owns — the "two owners"
bug this project has hit five times.

## Decision

### A weapon is a small scene of its own (a "model")

`WeaponData.model` points to a scene whose **root is the grip**. It holds:

| Child | What | Who places it |
|---|---|---|
| `Art` | the weapon's picture | the user, by dragging |
| `Hitbox` (optional) | the melee hit area — a sword has one, a bow does not | the user |
| `Muzzle` (optional) | where projectiles start | the user |

Swapping frees the old model and loads the new one under `SwingPivot`. Code never writes anything
inside a model. The sword's existing values were **moved** into `scenes/weapons/sword_model.tscn`
unchanged, and `tests/test_weapon_model_geometry.gd` checks that the sword's on-screen position and
hit area match the pre-refactor numbers exactly, at three aim directions.

The model is the unit of replacement: real pixel art for a weapon means editing its model scene,
with no effect on the player scene or any combat code. Picture orientation (`art_angle_degrees`) and
the rest pose moved with it — the angle is baked into `Art`, and `rest_angle_degrees` is on
`WeaponData`, because a bow is held differently from a sword.

### Projectiles are the third behaviour

As planned in 0012: at the start of ACTIVE, an `arc` weapon turns on its hitbox, and a
`projectile` weapon spawns its `projectile_scene` at the Muzzle, along the aim. The arrow checks the
**segment** it travelled each step with a raycast, so a fast arrow can't skip through a target in
one frame. Damage still goes through `Health.take_damage()`. Two behaviours are a `match`; they
become separate scripts at the third.

The bow needs no swing code at all: `arc_degrees = 0` and `rest_angle_degrees = 0` mean it simply
points at the mouse. That is decision 0012's "80% numbers" rule, working as intended.

### The swap (0003's numbers, now built)

`Loadout` is a component that never reads input, like `Dodge` and `Guard`:

- **0.6s cast** — you can't attack. A dodge or guard press cancels it, and no cooldown is charged.
- **5s cooldown** after a swap completes.
- Starting a swap cancels a swing in progress.
- Keys `1` / `2`. At most 2 weapons.

## Consequences

- **Adding a weapon is a data file and a model scene.** No code, unless it is a new motion.
- **The boss gets projectiles for free** — the same behaviour fires its ranged attacks in slice 4.
- **The swap cost is two numbers in F3.** If playtest says "annoying", the answer is a smaller
  `swap_cooldown`, not a redesign.
- **To edit a weapon's art or hitbox, open its model scene.** The player scene shows the current
  weapon but never saves it, so dragging it there does nothing lasting.
