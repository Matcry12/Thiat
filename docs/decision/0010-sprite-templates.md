# 0010 — Placeholder art is real sprite files, not code drawing (the template)

**Date:** 2026-09-23

## Context
Slice 1 drew the player, enemy and sword with `_draw()` calls in code. That looked fine, but it
broke the promise of [0005](0005-architecture.md) / CLAUDE.md rule 5: swapping in real art would
have meant rewriting code, not replacing a file. A review found five gaps (no contract for a sprite
node, no movement state, no facing, shadow trapped inside the body script, no Y-sorting).

## Decision
**Everything visible is a real image file (PNG) shown by a sprite node, from day one — including
placeholders.** Placeholder art is a white box, a circle, a simple shape: but it is a *file*.

This makes a **template**:

| To add | You provide | Code needed |
|---|---|---|
| A weapon | 1 PNG + 1 `.tres` of numbers | none |
| An enemy | 1 PNG + 1 `.tres`/scene | none |
| An item | 1 PNG + 1 `.tres` | none |

Supporting pieces, built once:
- **`ActorVisual`** — the contract every character visual implements (`set_move_state`,
  `set_facing`, `set_weapon_state`, `set_aim_angle`). Placeholder and final sprite both satisfy it,
  so combat code never changes.
- **Movement state is published** (`idle` / `run`) so a sprite can play the right animation.
- **Facing is published as a direction** (left/right flip, or an 8-way name), not a raw angle.
- **Shadow is its own node**, so replacing the body keeps the shadow.
- **Y-sorting on**, so overlapping upright bodies draw in the right order (2.5D, [0009](0009-perspective-2-5d.md)).
- **The weapon is a sprite on a pivot that rotates through the swing** — how real games do it, and
  closer to a real animation than a drawn wedge.

## Why
- Replacing art becomes **replacing a file**, which the user can do alone in seconds — no code, no me.
- It is the same operation as the final swap, so the promise is *tested continuously* instead of
  being verified for the first time the day real art arrives.
- It turns content into data: more weapons, enemies and items cost no engineering.
- Pixel-art project settings (nearest-neighbour filter, 2D snapping) become a one-time switch when
  real art arrives, not a refactor.

## Consequences
- Placeholder PNGs live in `assets/game/placeholder/` and are clearly marked as such.
- A real asset pack is dropped into `assets/`, files are pointed at, positions/scale nudged in the
  inspector via `@export` offsets. Nothing else.
- Accepted cost: a sprite node plus an image file is slightly more setup than a `draw_circle()` call.
  That cost is paid once and repaid on every asset change.
