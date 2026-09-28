# 0014 — The shield is a bar that breaks, and damage is a shared pattern

**Date:** 2026-09-28
**Revises:** [0013](0013-parry-and-block-on-one-key.md) — block was "30% chip damage". It is now a
depleting bar. Tap-to-parry / hold-to-block and the directional arc are unchanged.

## Context

0013 shipped and the mechanic worked, but the user's verdict was:

> "at the parry, I see that it works good, just the visual isnt good enough"

Chip damage had two problems, one felt and one visible.

**Felt:** 30% of every hit is an invisible tax. There is no moment where blocking stops working, so
there is no decision — you hold F and slowly lose. Nothing tells you *when* to stop blocking.

**Visible:** a coloured arc is not an object. It cannot look damaged, so the state of your defence
had nowhere to live on screen.

A bar fixes both at once: it is a resource you can watch, and it gives the art something to show.

## Decision

### Hold F drains a bar; the bar breaks

| Situation | Result |
|---|---|
| Blocking, hit ≤ bar | bar -= damage, you take **0** |
| Blocking, hit > bar | bar → 0, only the **leftover** reaches you, shield **breaks** |
| Broken | cannot guard at all for `break_recovery`; the bar regrows from 0 |
| Purple (unparryable) | full damage **and** the shield breaks instantly |
| Not guarding for `tank_regen_delay` | the bar refills at `tank_regen_rate`/sec |

**Parry still costs nothing.** That is the whole balance: parry is free but demands timing; block
is free of timing but spends a resource that can run out at the worst moment.

`block_chip` is deleted. Every change in this project so far has removed a number rather than added
one, and this one removes the number that was hardest to feel.

### One shield bar on screen, not two

`Health` already had a passive `shield` pool that absorbs before hp. Two shield bars — one you hold
up, one you simply own — would be unreadable. The player's `shield_max` is set to **0**, so the
held shield is the only shield. `Health.shield` stays in the code for armor items later; it is
simply unused by the player for now.

### Damage is a PATTERN, not a damaged sprite

The user's framing, and it is the important part:

> "we will got a shield and a pattern broken so we could apply the broke to all different shield
> instead"

So: `shield.png` is the object, `shield_cracks.png` is a **separate transparent layer drawn on
top**, and its opacity follows the bar. A full bar shows no cracks; an empty bar shows them fully.

The consequence is the reason to do it: a wooden shield, an iron shield and a magic shield need
**no cracked versions of their own**. One overlay covers every shield this game will ever have. So
`guard_visual.gd` may not assume anything about the texture underneath — no per-texture sizes, no
hardcoded offsets, no reading the shield sprite to build the crack sprite.

This is the same rule that chose an effect over a weapon pose in 0013, applied one level further
in. It is now the project's default for anything that decorates a swappable object.

### The visual is still only a slot

`GuardVisual` gained `set_tank_fill()` and `on_break()` and still knows nothing about `Guard` — the
player wires the signals. Replacing both PNGs with real art is a file swap; replacing the shard
burst with a particle system touches no combat code.

## Consequences

- **Blocking is now a decision with a clock.** "18 left, do I risk one more or dodge?" did not
  exist before.
- **Guard break is a new punish**, and it is the first state where the player is defenceless for a
  fixed time. That is a real difficulty spike — `break_recovery` is the dial.
- **One number decides whether parry survives:** `tank_regen_rate`. Refill too fast and nobody will
  ever risk a parry. Watched in playtest; it is an F3 slider, not an argument to settle here.
- **Purple attacks got scarier** — they now cost you the shield as well as the health. Good: purple
  must mean "dodge", not "guess".
- The crack overlay only *draws* damage; it cannot remove pixels from the shield beneath it. If
  chunks genuinely missing is wanted later, the upgrade is a small mask shader using the same
  overlay texture — the art does not change.

## The question this still has to answer

> **Can you feel when the parry window is open?**

Unchanged from 0013, and still unanswered by playtest. The bar makes blocking readable; it does
nothing for the parry window, which is the thing that has to feel right.

## Amendment (2026-09-28): the shield is a status icon, plus a direction hint

After playing it, the user dragged the shield to the **middle of the player** and asked for it to
"show status of defending". It is no longer a plate held out in front.

That created a gap: the guard still only covers the side you face (`parry_arc_degrees`, 180), and
a centred, upright icon cannot show which side that is. A hit from behind would land while the
player is clearly blocking, which feels like the game is cheating. Offered three options; the user
chose **front only, plus a hint**:

- **Shield icon** — upright, wherever the user dragged it. Says *that* you are defending and, through
  the cracks, *how much* shield is left. `GuardVisual.face_aim` (default off) turns it back into a
  plate held in front if a future shield art wants that.
- **CoverArc** — a separate node that turns with the aim and spans exactly `parry_arc_degrees`. Says
  *where* you are protected. Its width is mirrored from `Guard` every frame, so the F3 slider moves
  the hint and the real protected side together. It can be swapped for a glow sprite and still
  turn, because `GuardVisual` only sets its rotation, visibility and tint.

Also fixed while doing this: the cracks were a *sibling* of the shield with their own position,
so they stayed behind when the shield was dragged. They are now a *child* — one position, and it
belongs to the user.
