# 0001 — Reference games for combat design

**Status:** Active

**Date:** 2026-09-22

## Context
BossFight is a Godot 4 top-down 2D combat game with hard bosses (some RL-driven). Research notes on three games live in `docs/reference/game-design/`.

## Decision
- **Necesse is the primary reference** — top-down movement, aiming, melee arcs, "how we play" (moment-to-moment feel and controls).
- **Terraria is the reference for bosses and items** — boss roster design (phases, enrage rules, multi-part bosses, new attacks per difficulty tier), item/accessory/loadout system.
- **Soul Knight is a supporting reference** — same genre space, used for mobile-friendly control ergonomics (auto-aim, simple inputs, telegraph grammar).

## Why
Necesse already solved top-down combat readability in the same perspective we use. Terraria's bosses are the most memorable in the genre and its item system gives progression depth. Soul Knight shows how to keep that playable on a phone.

## Consequences
- Design questions default to "what does Necesse do?" first, Terraria for boss/item questions, Soul Knight when a mobile constraint appears.
- Conflicts between the three are resolved in `docs/wiki/design-pillars.md`.
