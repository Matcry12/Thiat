# 0025 — v1 is an open-world prepare-then-fight game

**Status:** Active

## Context

v0 is a combat scratch build: one arena, one boss. The user wants a full playable v1: an open world where
you chop trees, mine, craft weapons and fight the boss. The design pillars said "Combat is the product.
Story/world/meta come later and never constrain the fight" and "progression is boss-gated, not
grind-gated". Gathering is a light form of grind, so this needs a deliberate decision.

## Decision

v1 = one big seeded island (forest, rocky area, boss area) where you gather, craft through 3 stations
(workbench, furnace, anvil), fight area enemies, summon the sleeping boss at an altar and beat it to win.
Full design: [docs/wiki/v1-design.md](../wiki/v1-design.md).

- The world exists **to prepare for the boss** (Terraria style). The boss fight stays the main event.
- Gathering is **light**: a few trees and rocks per tier, never a quota. Real power still comes from
  boss drops.
- Gathering uses the **combat systems** (swing a tool, hit feel), so it practises the fight skill.
- 1 boss in v1; items, recipes, enemies and boss drops are **data**, so boss 2 is content, not systems.

## Why

The user wants a complete game, not only an arena. Keeping the world in service of the fight keeps the
combat pillar true. Building everything as data keeps v2 (boss 2, armor) a content job.

## Consequences

- Pillar "world comes later" is replaced by "the world serves the fight"; [design-pillars.md](../wiki/design-pillars.md) points here.
- New systems: island generator, resource nodes, items/inventory, crafting, generic enemies, boss
  summon, death/respawn, save/load, game frame. Built in slices W1–W11.
- Performance on a big map becomes a real concern (W1).
- Risk: gathering feels like a chore. Guard: the 20–30 min run target, measured in the W11 tune pass.
