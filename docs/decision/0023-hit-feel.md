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

## Amendment — slice 2 (2026-10-04)
- **Knockback is gameplay, not an effect.** A `Knockback` component on actors (move_and_collide, decay),
  with its own on/off, separate from the Hit FX master switch. Strength per hit type lives in the
  `HitFxProfile.knockback` field.
- **User decision:** normal enemies get real knockback; **the boss gets none** — its body never moves from
  hits, only its Visual jolts (`recoil_px`). Keeps its attacks and charges predictable.
- Player: 20 px shove when hit (dodge not cancelled), 12 px slide on a block, one shove on a guard break.
- Swing step: `WeaponData.step_distance` (sword 8, bow 0).
- The training dummy walks back to its spot after a short pause, so knockback does not turn combos into a chase.
- **Known risk:** a player holding guard at the aggro-zone edge can be slid out by repeated blocks and trigger
  the leash (boss heals). Watch in playtest; fix by clamping shoves at the zone edge if it happens.
