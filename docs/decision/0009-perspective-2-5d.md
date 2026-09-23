# 0009 — Perspective is 2.5D top-down (Soul Knight), not flat overhead

**Date:** 2026-09-23

## Context
[Prototype v0 §1](../wiki/prototype-v0.md) described placeholder art as flat circles and cited
Zombs Royale for the look. That reads as a **pure overhead** view where bodies rotate with aim.
The intended perspective is Soul Knight's: top-down world, but characters drawn **upright**,
facing the camera.

## Decision
**2.5D top-down.** The world (floor, walls, arena) is viewed from above; **characters stand upright
and never rotate with aim.**

- Bodies are upright capsules in placeholder art, not circles seen from above.
- **Only the aim indicator rotates.** Later, sprites flip left/right and the held weapon rotates;
  the body itself does not spin.
- A **ground shadow ellipse** at the feet is what sells the height — it is part of the character,
  not decoration.
- **Combat math is unchanged and stays pure top-down**: positions, distances, arc/cone filters and
  hitboxes all operate on the flat XY plane. Perspective is a rendering concern only.

## Why
- Matches Soul Knight, the supporting reference for this genre ([0001](0001-design-reference-games.md)),
  and what the game is actually meant to look like.
- Upright bodies read far better for a human player: a face and a silhouette are legible where a
  top-down disc is not, and every asset pack in this genre is drawn this way.
- Keeping the hit math flat means the perspective can change again without touching combat.

## Consequences
- The `Visual` node draws an upright capsule + shadow, and exposes `set_aim_angle()` instead of
  having its `rotation` set. Combat scripts still never touch it ([0005](0005-architecture.md)).
- Hitboxes stay flat-plane circles/arcs. **The debug overlay therefore draws the true flat hitbox
  under an upright body** — the shapes will not visually match the sprite, which is correct and
  expected ([prototype-v0 §1b](../wiki/prototype-v0.md)).
- Asset search should be for **top-down 2.5D / Soul Knight-style** packs, not flat overhead ones.
- Y-sorting will be needed once entities overlap (upright bodies must draw in depth order).
  Not required for slice 1 (one dummy); flagged for when multiple enemies exist.
