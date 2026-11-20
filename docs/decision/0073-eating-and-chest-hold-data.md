# 0073 - Chest-hold pose and eating numbers are saved data

**Status:** Active.

## Context
The chest-hold pose, eating bob, crumbs and eating timings were `@export`s on three nodes (`HeldItemVisual`, `Consumer`, `EatCrumbs`). F3 "Write to .tres" only works for Resources with a `.tres` file, so tuning them was lost when the game closed. Real art and sounds will also replace the placeholders later.

## Decision
Two Resources, like `BodyRig`: `ChestHoldData` (`data/held_item/chest_hold.tres`, pose + bob, read by `HeldItemVisual.chest`) and `EatingData` (`data/food/eating.tres`, timings + crumbs, read by `Consumer.eating` and `EatCrumbs.eating`). The old per-node exports are removed. `EatingData.crumb_texture` (null = coloured squares) is the one swap point for crumb art. Both show in F3 (`ChestHold`, `Eating`). Swap points are written in [food-algorithm.md](../wiki/food-algorithm.md).

## Why
- F3 tuning can be written to the file and stays.
- New art or sounds change data, not code (AGENTS.md section 5).

## Consequences
- Tests read `held.chest.*` / `consumer.eating.*`. A test that changes a value must `duplicate()` the Resource first, or it leaks into other tests.
- `potion_cooldown` stays on `Consumer` (balance).
