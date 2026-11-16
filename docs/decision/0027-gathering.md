# 0027 - Gathering with bare hands (W2)

**Status:** Active

## Context
v1 needs trees, rocks and copper you gather ([0025](0025-v1-open-world.md)). The player has no tool yet
(tools come in W3/W4), but W2 must already be playable: punch a tree, pick up wood.

## Decision
- **Hands are a weapon.** `data/weapons/fists.tres` is a `WeaponData` with `gather_damage` and `tool_power`.
  Key `3` calls `Loadout.toggle_hands()`: the weapon is put away and back at once, no cast, no cooldown.
- **Gatherable = physics layer 32.** The node's `Hurtbox` sits on it. `Hitbox._try_hit` calls
  `take_gather_hit(weapon, source)` on it, so the swing code is the same as in combat.
- **No `Health` on nodes.** `ResourceNode` keeps its own `hp`, so combat code (shields, armor, knockback) never sees a tree.
- **Nodes live in `Result.obstacles`** with a `node` key, so the map, reach check and placement use one list.
  They are also in group `map_obstacle` (collision) and `resource_node`.
- **Inventory API kept for W3:** `add / count / items / item / clear` + `changed`. W3 swaps the inside for slots.
- **Items:** `ItemData` (wood, stone, copper_ore). Drops fly out as `Pickup`; the player's `Collector` pulls them in.

## Why
- No exploit with the free holster: swapping to the other weapon (key 2) is still the normal swap with cast + cooldown ([0003](0003-loadout-and-swapping.md) rules unchanged). Only hands <-> last weapon is free, and hands do almost no combat damage (1 vs the armored dummy, armor floor).
- Layer 32 and `take_gather_hit` mean combat code does not change at all.
- Without `Health`, a tree cannot be hit by a boss attack or an arrow by accident.

## Consequences
| Limit | What you see |
|---|---|
| No respawn | A broken tree stays a stump; a broken rock is gone until `New map` |
| No stack limit | You can carry 9999 wood (W3 adds slots) |
| Key 3 is temporary | W3 puts hands in the slots and key 3 goes away |
| Copper needs power 1 | Fists clink, no damage, until a pickaxe (W3/W4) |
| Copper is a circle | Placeholder colour, no art yet |
| Density changes in F3 | Apply on the next `New map`, not live |
