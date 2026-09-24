# 0012 — Weapon behaviours: a few motions, many weapons

**Date:** 2026-09-24

## Context
Attack style belongs to the weapon, not the player: a sword sweeps, a spear thrusts, a hammer
slams, a bow shoots. Research into Soul Knight's roster
([soul-knight-weapons.md](../reference/game-design/soul-knight-weapons.md)) found that a large,
varied roster is built from a **small number of motions** plus data. The wiki's own trivia makes
the point: the Spear changed from a sweeping weapon to a thrusting one by changing a number.

## Decision
Weapons are defined at three levels. Only the third costs engineering time.

| Level | What differs | Cost per weapon |
|---|---|---|
| 1. Numbers | reach, damage, speed, timings | a new `.tres` — seconds |
| 2. Modifier flags | burn, pierce, knockback, lifesteal, crit | a new `.tres` — seconds |
| 3. New motion | boomerang, chain lightning, summon | one new behaviour script — once |

**Modifiers are not behaviours.** `pierce_count`, `status_effect`, `knockback`, `lifesteal_pct`
and `crit_chance` are flags any behaviour reads, so "flaming piercing spear" is data, not code.

**Build order for behaviours** (from the research):

1. `arc` — sweep. **Done** (the current sword); it is the reference implementation of
   [0011](0011-hitbox-lives-on-the-weapon.md).
2. `thrust` — the blade lunges forward instead of rotating. Smallest possible addition; proves
   the model.
3. `projectile` — a travelling hitbox from a muzzle point. **The boss needs this too**, so it pays
   twice.
4. `spread` — the projectile script in a loop (`projectile_count`, `spread_degrees`). Shotguns.
5. `charge` — a hold-to-release wrapper around 1–4.
6. `beam` — sustained tick damage. Lowest priority.

A genuinely unique legendary weapon may have its own one-off script. That is an escape hatch, not
the norm: the healthy mix is roughly 80% numbers, 15% modifier flags, 5% new motion. If every
weapon is special, the model has bought nothing.

## Why
- Cost then scales with the number of **motions**, not the number of weapons. Six scripts cover
  most of a roster.
- It keeps [0005](0005-architecture.md) honest — `WeaponData.behavior` already existed for exactly
  this and only had one value.
- Building `projectile` early serves both player weapons and boss attacks.

## Consequences
- `WeaponData` grows a shared block (damage, timings, energy cost, crit) plus per-behaviour blocks
  (arc/thrust, projectile/spread, charge, beam). Unused blocks sit at defaults and cost nothing.
  The field sketch is in the research doc §8.
- The existing arc sword is unchanged; new behaviours are added beside it.
- Each behaviour must still honour 0011: its hit area is a shape carried by the weapon, never a
  number compared against an angle.
- Per CLAUDE.md rule 7, every new behaviour ships with its numbers in F3 and its shape drawn in F1.
