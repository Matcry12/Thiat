# 0042 — Death drops instead of the death bag (W6)

**Status:** Partly superseded by [0058](0058-free-weapon-swap-no-weapon-limit.md) (no weapon limit, 3rd weapon rule gone)

Supersedes the bag part of [0039](0039-death-respawn.md). Everything else in 0039 stands (respawn at home, boss reset, deaths counter, no end screen).

## Context
The bag was a single object to walk back to. The user wants Minecraft-style drops: your things lie around where you died.

## Decision
- On death every carried stack (and the cursor stack) leaves the inventory and sprays out as normal loose `Pickup`s with a short arc (`Respawner.spray_*`, `pop_*` exports). Stacks bigger than `max_per_pickup` split into several pickups.
- `drop_share` (1.0) applies to materials, `drop_gear` (true) makes tools, weapons and stations drop whole. `despawn_time` (300 game seconds, 0 = never).
- Walking back uses the existing Collector magnet and `Inventory.add`, so the hotbar rules still apply: a 3rd weapon goes to the bag. The Collector does nothing while the player is dead.
- **Despawn applies to death drops only** (`Pickup.despawn_left`, -1 = never): the simplest correct choice, since a tree's drops should not vanish. `Pickup.death_drop` marks them (F3 status, "Go to nearest drop").
- **Save:** every loose pickup is saved with its position and remaining despawn time (`world.pickups`). `VERSION` is now 2.
- The `DeathBag` code, scene and visual are deleted.

## Why
Reuses the pickup scene, Collector and scatter code; one timer on the pickup instead of a new object type.

## Consequences
- Dying far from home with a full inventory means walking back before the drops vanish (5 min by default).
- A drop that lands in water or on a spot you cannot reach still despawns; no rescue.
- Old version-1 saves (with bags) are rejected: Continue is disabled.
