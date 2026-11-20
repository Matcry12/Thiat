# 0072 - Food gives timed effects, no hunger bar

**Status:** Active. Replaces [0071](0071-hunger-and-potion.md).

## Context
0071 added a Minecraft-style hunger bar. The user compared Terraria and similar games: food there is a buff, not a chore, and the second bar holds stamina or mana. A drain bar is a chore in a 20-30 min run.

## Decision
No hunger bar. Food gives timed effects held by one `Effects` node on the player; each effect kind is `EffectData`, and items list what they give. Cooked food = Regen (heal per second for a time), raw food = small Regen + Sick (slower). The potion stays the best heal: +50 HP at once, 30 s cooldown. Stacking follows Minecraft: one effect per kind; stronger replaces, same strength keeps the longer time, weaker or no-change is refused and the item is not used. The bar slot under HP is kept for a future mana bar (own design). Full rules: [food-algorithm.md](../wiki/food-algorithm.md).

## Why
- Food becomes preparation before fights (Terraria), not a timer to babysit.
- No-add stacking keeps food from beating the potion when eaten in bulk.
- Effects as data: new foods and new effects without code.

## Consequences
- `Hunger`, the food bar, starving and `food_value` are removed; `Consumer`, potion cooldown and its slot sweep stay.
- Small exception to design-pillars §2 (HP does not regenerate): timed food Regen. Tune down if fights get easy.
- Save stores active effects with time left.
