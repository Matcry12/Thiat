# 0065 - The player has a visible hand

Supersedes the "no hands" part of [0048](0048-no-hands-held-item-icon.md). `HeldItemVisual` and bare hands gathering nothing stay.

## Context
Weapons and items floated next to the body, with nothing holding them. The user drew `hand.png` on the idle sheet's canvas (idle frame 2 only): 4x4 px, the body's pixel size.

## Decision
- One picture, `assets/game/characters/pixel_plains/hand.png`, on a new `MainHandArt` node (`HandVisual`). It only reads where things are. Combat never touches it.
- Where it sits: on the weapon's grip while the weapon shows and through a swing; at the lower edge of a held material or placeable; at rest otherwise (below). Hidden on death. It never turns.
- Second hand: `OffHandArt`. While the weapon shows and its model scene has a `OffHandGrip` marker, it holds that point, over the weapon, and moves with the swing. No `OffHandGrip` (one-handed swords, bow, fists; the katana is the only two-handed sword) or weapon hidden: it rests on the `OffHandRest` marker.
- At rest (idle, run, weapon hidden, bare hands) the hands sit on both sides of the body: holding hand on `MainHandRest` (-15,-5.5), in front of the body; free hand on `OffHandRest` (15,-5.5), behind the body. They follow the body frames only, rounded to whole body pixels, so nothing slides. While running they also swing like arms, one step per body frame (`run_swing`): opposite ways, and the hand coming forward rises 3 px. Plain up-and-down and plain left-and-right were tried first and looked wrong. Their x mirrors when the body turns. These points never change where a weapon is held.
- It moves with the body frames through the `MainHandHold` point (`BodyRig.hand_follow`), so one picture is enough for idle and run.
- `MainHandHold` moved from (-6,-2) to (-3,-5.5), lower than the spot the user drew (-14.5), which looked too high. Same height as the rest spots. Every weapon is held there now.

## Why
A round hand needs no per-frame drawing: only its height changes between frames, and that is already measured. No new data for the same result.

## Consequences
- Every number is in F3: sections `MainHandArt` and `OffHandArt` (`hand_on`, `hand_scale`, `hand_z`, `hold_z`, `item_offset`, `rest_nudge`, `run_swing`, `use_off_grip`).
- During a swing the hand follows the grip path, away from the body. It floats, with no arm.
- A hand with different shapes per frame would replace this node, same inputs.
