# 0058 - Weapon swap is free and instant, no weapon limit

**Date:** 2026-11-05
**Supersedes:** the weapon parts of [0003](0003-loadout-and-swapping.md) (max 2 weapons, 0.6 s cast, 5 s cooldown),
"The swap" in [0016](0016-weapons-are-scenes-and-swap-is-gated.md), the max-weapons, select and wheel-wait rules of [0029](0029-inventory.md).

## Context
The user played with the swap cast + cooldown and the 2-weapon limit and wants both gone. The hotbar should simply
hold what you put there, and pressing a key should put it in your hands at once.

## Decision
- **Every hotbar select is instant**, weapon or not. `Loadout.swap_cast`, `swap_cooldown`, the cast state and its HUD fill are deleted (not set to 0).
- **No weapon limit.** `Inventory.max_hotbar_weapons` and `can_place` are deleted. All 9 hotbar slots may hold weapons; a weapon picked up goes to the hotbar first.
- **The wheel has no wait.** `Player.wheel_settle` only existed to stop scrolling from starting a cast. Deleted.
- **A swap cannot end a swing early.** A press during a swing (also guard, dash, skill) is remembered and applied the moment it ends; the hotbar highlight moves at once. Without this, tapping `2` `1` would skip the swing's recovery for free, which would remove the attack speed rule.
- Kept: each weapon's own skill cooldown, the bag locked in a boss fight, armor and potion rules of 0003 (not built yet).

## Why
A direct user request after feeling the game. Removing the code is simpler than keeping two zeros that nothing needs.

## Consequences
- **Swapping costs nothing in a fight.** "Bow to open, sword when it closes" is free, and it is no longer a decision with a price.
- **More weapons = more skills in a row.** Skill cooldowns are per weapon, so 9 weapons = 9 skills back to back. If a playtest says this is too strong, the first answer is one shared skill cooldown, not the old swap cost.
- **The RL boss loses the "bounded opponent"** of 0003 (a finite, fixed kit in each fight). RL training must rotate over bigger loadouts; the hotbar still limits the kit to 9 and the bag stays locked.
- No cost means nothing to show: the "cooldown HUD" rule in design-pillars no longer covers weapon swap.
