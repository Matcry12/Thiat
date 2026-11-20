# 0071 - Hunger bar, food and the healing potion

**Status:** Active

## Context
The artist delivered food (bread, pork, soup, sausage) and a healing potion. They were plain materials. The user asked for a food bar and a potion that heals. Before this, hunger was "skipped by choice" (backlog) and out of v1 (v1-design §10).

## Decision
A temporary first design. One `Hunger` node on the player owns `food` (0..100, drains 10/min). Empty bar: lose 1 HP every 4 s, never below 1 HP. No HP regen from food. Food and potion are used with the attack click on the selected hotbar slot; `ItemData.food_value` / `heal_value` decide what an item does. Potion: +50 HP, 30 s personal cooldown, shown on the HUD. Respawn = full bar. `food` is saved. Full rules: [food-algorithm.md](../wiki/food-algorithm.md).

## Why
- Steady drain (Don't Starve) is easier to read than Minecraft's hidden exhaustion.
- Starving stops at 1 HP (Minecraft Normal): it adds danger without a surprise death spiral.
- HP still does not regenerate (design-pillars §2); the potion is the healer, with Terraria's cooldown.
- Values live on the item data, so a new food is a new `.tres`.

## Consequences
- Hunger is now part of v1. Backlog line and v1-design §10 updated.
- Save gets a `food` field; old saves load with a full bar.
- Later: eat time, cooking, Well Fed buff (food-algorithm "Later").
