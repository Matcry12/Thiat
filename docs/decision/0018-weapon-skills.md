# 0018 — Weapon skills (the E key)

**Status:** Active

## Context
Slice 3b asks: does each weapon's E skill give a clear reason to swap to it?
Sword and bow each need one skill. More weapons (and their skills) come later.

## Decision
- A skill is a **scene** whose root extends `Skill` (`scripts/skills/skill.gd`).
  `WeaponData.skill` points at it, `WeaponData.skill_cooldown` sets its cooldown.
  A new skill = a new scene. No `match` on weapon names anywhere.
- `SkillSlot` (a component on the player, never reads Input) instances each
  weapon's skill once, as an ownerless child (so `player.tscn` never saves it),
  and keeps the cooldown **per weapon**. Swapping away and back neither resets
  nor shares cooldowns.
- Cancel rules:
  - Bow charge: a dodge or guard that **fires** cancels it, and the cooldown is
    **refunded** (a cancelled skill did not happen, like `cancel_swap`).
    A refused dodge/guard press cancels nothing.
  - A weapon swap **finishing** cancels any active skill (refunded).
  - Lunge: **not cancellable.** It is 0.15 s and moves the body itself, so dodge
    and guard presses are simply refused while it runs (two things must not drive
    the body at once). Weapon swap is refused then too.
- E is refused while guarding, dashing, swap-casting, mid-swing, or with a skill
  already active. Attack is refused while a skill is active.
- Sword: **Lunge Slash** (dash ~140 px in 0.15 s, hits each target once, no
  i-frames). Bow: **Piercing Shot** (0.5 s charge at half speed, then one arrow
  that passes through targets, once each, and stops on walls). `Projectile`
  got a `pierce` flag via `setup()`, not a copy of the script.
- Test mode: all numbers are `@export` on the skill scene root (F3 panel, one
  section per weapon skill). F3 status lists both weapons' skill state and
  cooldown. F1 draws the equipped skill's reach (orange line). HUD shows
  `E: <name> ready` / `E: 3.2s`.

## Why
Skills as scenes follow decision 0016 (weapons are scenes) and keep "new skill,
zero changes elsewhere". Per-weapon cooldowns are what make swapping a tactic:
use the sword skill, swap, use the bow skill. Refunding a cancelled charge
keeps dodge/guard as safe escapes.

## Consequences
- The charge has no visual yet; a visual node can listen to the skill later.
- The lunge hit area is its own `Area2D` (layer 8, mask 4), not `Hitbox`,
  because `Hitbox` takes damage from a `WeaponData`, and a skill owns its damage.
- Cooldown starts at the press and runs during the skill.
