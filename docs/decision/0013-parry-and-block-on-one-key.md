# 0013 — Parry and block share one key; the shield is an effect, not an item

**Status:** Partly superseded by [0014](0014-shield-is-a-bar-that-breaks.md) (block is a breaking bar), [0015](0015-block-is-a-sword-pose.md) (block shown as sword pose)

**Date:** 2026-09-25
**Supersedes:** part of [0006](0006-controls-and-parry.md) — "Parry is a 0.25s timing window
(**not** a hold-block)". Hold-block now exists. Everything else in 0006 stands.

## Context

Slice 3 is the third and last piece of defence (move, dodge, parry). While specifying it, two
things changed.

**1. Parry alone is too binary.** A 0.25s window with a hard punish on a miss means a new player
has exactly one defensive option against a telegraphed attack, and it is the hardest one. Dodge
covers "get out of the way" but has a 2s cooldown, so between dodges there is nothing to do but
guess. A player who cannot yet read the telegraph has no safe move at all.

**2. The visual decided the mechanic, in a good way.** The first plan was to animate the weapon
into a block pose. The user rejected it for a better reason than aesthetics:

> "it's not the shield item, it's present how we block by our weapon, but it help us not to care
> about animation too much"

An abstract shield effect in front of the player says "you blocked" without saying *which weapon*.
One effect covers the sword, the bow, the hammer and everything after them — where a weapon pose
would need new art per weapon, forever, for a 0.25s flicker nobody looks at directly.

## Decision

### One key, two modes

| Input | Mode | Result |
|---|---|---|
| **Tap F** | Parry | 0.25s window. Success = 0 damage + attacker staggered 0.8s. |
| **Hold F** | Block | No timing needed. 30% chip damage, 40% move speed, cannot attack. |
| Release after the window with no hit | Recover | 0.5s dead time, then ready. |

Block is the panic option: always available, always weak, and it costs you the tempo — you cannot
attack while holding it. Parry is the skill option: risky, and it hands you a free hit. Neither
dominates, which is the point.

### No stamina — the cost is the lost tempo

[0004](0004-dodge.md) chose cooldown-gating over a stamina bar. A block meter would reintroduce
stamina through the back door. Block is instead limited by what it takes away (attacking, speed),
not by a resource. If block turns out to be abusable, the fix is raising `block_chip`, not adding a
bar.

### Parry and block are directional

The shield effect appears in front of the player, facing the mouse. So it must only stop what comes
from the front — `parry_arc_degrees`, default **180** (the half you face). A visible plate on your
left that stops a hit from your right is a lie the game would have to keep telling.

The width is an `@export` on a slider, not an argument to settle here: 360 blocks everything and
removes aiming, 90 demands precision. Ship 180, tune it in F3 in the first ten seconds of play.

### Purple breaks both

[0006](0006-controls-and-parry.md) already defined unparryable attacks with a purple tell. Those
now break **block** as well as parry. This is what keeps dodge relevant once block exists: a purple
attack has exactly one answer, and it is `Q`.

### The shield is one slot with three looks

`GuardVisual` is its own node and knows only three calls — `on_guard_state()`, `on_parry_success()`,
`set_aim_angle()`. It never reads `Guard`; the player mirrors the arc width onto it. Parry = bright
and thin, block = dim and solid, success = a white flash. Replacing the `_draw()` arc with a sprite
or a shader touches zero combat code (CLAUDE.md rule 5).

### Damage still has one entry point

`Health.take_damage()` grew two optional arguments — `source` (who hit, for the direction test and
the stagger) and `parryable`. It asks an optional sibling `Guard` for the fraction of damage that
gets through. Every existing caller keeps working because both arguments default.

`Guard` staggers the attacker by duck-typing (`source.has_method("stagger")`), so the RL boss later
needs no interface to inherit from — it only needs the method.

## Consequences

- **The fight now has three answers, not two.** Read it → parry. Can't read it → block and lose
  tempo. Purple → dodge. That is a decision every attack, which is what makes a boss fight a fight.
- **Weapon variety costs nothing defensively.** Adding the bow adds no block art.
- **Aim now matters while defending.** Previously aim only pointed the swing. This is an intended
  increase in difficulty, and it is a slider if it is too much.
- **`Attacker` gained a `STAGGER` phase.** The boss brain will have to handle being interrupted —
  better to find that now than after the brain exists.
- **Risk: block could be strictly better than parry** if the chip damage is too low. That is a
  number, watched in playtest, not a design flaw to pre-solve.

## The question slice 3 answers

> **Can you feel when the parry window is open?**

If the 0.25s cannot be felt, no amount of reward tuning matters — everyone will just hold F, and
the parry is dead content.
