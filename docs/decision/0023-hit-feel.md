# 0023 — Hit feel: effects listen, global hit-stop

## Context
Hits make almost no impact on screen (the boss flashes for 0.05 s; nothing when the player is hit). The user asked for
research before building. Research: [hit-feel-research.md](../reference/game-feel/hit-feel-research.md),
plan: [hit-feel-plan.md](../wiki/hit-feel-plan.md).

## Decision
- One `HitFx` hub listens to existing signals (`Health.damaged`, `Guard.parried/blocked`, `Boss.phase_changed`,
  `defeated`) and sends effect nodes a hit description. Combat code emits; it never calls effects.
- Per-hit-type numbers live in `HitFxProfile` resources; every number is an `@export` in F3, with master and
  per-layer switches and a shake-strength slider (0 = off, also the accessibility option).
- Hit-stop is **global** (short `time_scale` dip, real-time timer, restores the previous scale so F2 slow-mo
  survives, longest-wins with a cap). The player is never frozen by being hit.
- `Health.damaged` gains hit info (source, direction) without breaking existing connections.
- Slice one: flash for all actors, hit-stop, sound, trauma shake. Playtest, then sparks/numbers/specials.

## Why
Effects as listeners keep art swaps cheap (§5). Global hit-stop needs no per-actor freeze code and is the
proven Nuclear Throne approach.

## Consequences
- Bullets also pause during hit-stop.
- Audio enters the project (CC0 or generated), behind one node.
