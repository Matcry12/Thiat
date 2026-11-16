# 0002 — PC first, mobile deferred

**Status:** Active

**Date:** 2026-09-22

## Context
[Decision 0001](0001-design-reference-games.md) pulled Soul Knight in as the mobile-ergonomics reference, and [design-pillars](../wiki/design-pillars.md) let a "max 4 inputs" mobile budget filter Terraria's boss complexity before it reached the player.

## Decision
Build for **PC (keyboard + mouse, gamepad second)** first. Mobile is a later port, specced in its own decision doc when we get there.

- Manual aim (mouse cursor) is *the* control scheme, not a default with an auto-aim alternative.
- No input-count budget constrains design right now.
- Mobile notes stay in the pillars page as a **deferred** section — reference material, not a live constraint.

## Why
Designing to a 4-input touch budget before the combat even exists trades away boss complexity for a platform we aren't shipping on yet. PC lets us find the fun first; the mobile port then adapts a known-good design instead of pre-shrinking an unknown one.

## Consequences
- Soul Knight's role narrows to the **red-ground telegraph grammar** and the **shield+HP two-layer defense** — both platform-neutral and kept.
- Auto-aim, virtual sticks, and the input budget are out of scope until a mobile decision doc exists.
- Terraria boss complexity is no longer filtered through a touch budget; the only filter left is "no jump-arc / platforming dodges" (we are top-down).
- Risk accepted: a PC-native design may need real rework to fit touch later. That is the deliberate trade.
