# 0067 - Day / night cycle

**Status:** Active

## Context
v1 adds survival (hunger, building, night monsters). All of them need a time of day. Order agreed: day/night first.

## Decision
One `DayClock` node owns time (0..1, 12 min day: day 6, dusk 1, night 4, dawn 1). A `CanvasModulate` colour from a data `Gradient` darkens the world; `PointLight2D` lights (one `LightSource` scene) for the campfire, the player's small glow, held and placed torches. Torch = wood + gel at the workbench, never burns out in v1. Time is saved. Other systems only listen: `phase_changed`, `is_night()`. Full rules: [day-night-algorithm.md](../wiki/day-night-algorithm.md).

## Why
- Length and phases from Terraria / Minecraft (long day, shorter night); darkness between Minecraft (shapes visible) and Don't Starve (black), so night feels tense without being unplayable.
- `CanvasModulate` + `PointLight2D` are built into Godot: no shader to keep, and a real light sprite or shader can replace them later (rule 5).
- One owner of time, so night monsters / hunger / sleep plug in by signal.

## Consequences
- Night changes nothing in gameplay yet; it only looks different.
- HUD and F3 sit on CanvasLayers, so they are not darkened.
- Headless tests start with time frozen.
