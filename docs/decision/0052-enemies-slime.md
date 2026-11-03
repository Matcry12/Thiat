# 0052 — World enemies: one enemy setup, slimes first (W5)

## Context
The island has nothing to fight; walking has no risk and no reward. W7 (summon item, healing potion) needs gel.
[v1-design §6](../wiki/v1-design.md) and [survival-ideas §2](../wiki/survival-ideas.md) proposed the rules.

## Decision
- **One enemy setup.** `Enemy` scene = CharacterBody2D + Health + Hurtbox + contact Hitbox + Knockback + `Visual` slot + a brain.
  Every number lives in an `EnemyData` resource (`data/enemies/*.tres`): HP, speeds, aggro / leash radius, contact damage,
  drop table, spawn biomes + weight, pack size. A new enemy = new data + maybe a new brain, never a new codebase.
- **Slime brain:** wanders near its spawn spot; player in aggro range → hops at them (squash windup = telegraph, then a lunge);
  contact damage only during the hop; gives up past the leash and goes back. Dies → drops `gel` as normal `Pickup`s.
- **Visual slot:** the enemy emits state (`idle`, `windup`, `hop`, `land`, `hit`, `die`) + facing; `EnemyVisual` draws a placeholder
  blob, or plays an `AnimatedSprite2D` when the data gives `SpriteFrames`. Real art = data swap, zero code.
- **Spawner** (Minecraft "where"): per-biome lists from `EnemyData.biomes`, packs of 1–3, only off-screen inside loaded chunks,
  cap near the player, never inside `safe_radius` of home or a station, despawn far away when not fighting.
- **Not saved.** Enemies respawn; save files are unchanged.

## Why
Reuses the hit feel, knockback, pickups and biome data we already have. Boss guards (W10) are the same setup with new data.

## Consequences
- Slimes now hurt the player outside the boss fight; death drops (0042) become a real cost.
- Starting numbers are guesses; tune in F3.
