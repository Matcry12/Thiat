# 0006 — Controls, and parry as a distinct defensive option

**Date:** 2026-09-23

## Context
[0004](0004-dodge.md) made dodge baseline. Adding a shield/parry on `F` risks a second button
that does the same job (avoid damage), which would make one of them strictly better.

## Decision

### Keybinds (PC, per [0002](0002-pc-first.md))
| Key | Action |
|---|---|
| WASD | move |
| Mouse | aim |
| LMB | attack |
| `Q` | **dodge** |
| `E` | **weapon skill** (comes from the equipped weapon) |
| `F` | **parry** |
| `1` / `2` | weapon slots (swap: 0.6s cast, 5s cooldown) |
| `3`-`9` | items (potions, mobility tools, throwables) |

### Parry, not block
`F` is a **timing window**, not a hold-to-reduce-damage shield.

- Starting values, tune: **0.25s active window**, **0.5s recovery on a miss** (you cannot act),
  **3s cooldown**. HUD-visible like every other cooldown.
- **Success** (an attack lands inside the window): damage fully negated, attacker **staggered
  ~0.8s**, and your shield layer **refunds ~25%**.
- **Failure**: you take the hit *and* eat the recovery — strictly worse than not pressing it.
- Parry does **not** move you. Dodge does.
- Gear tunes the window/cooldown; a shield item widens the window. It never becomes a hold-block.

### The division of labour
- **Dodge (Q)** — avoid. i-frames + repositioning, works against anything including AoE. Safe.
- **Parry (F)** — punish. Tighter window, no movement, only works on a discrete incoming hit,
  but rewards reading the boss with a stagger window to attack into. Greedy.

## Why
- Two defensive buttons must answer different questions or one is dead weight. Avoid-vs-punish
  is the cleanest split and is already proven (Souls, Sekiro, Hollow Knight).
- The stagger reward makes parry *offensive*, so it pays for its risk instead of being a worse dodge.
- A timing window is honest against an RL boss: the policy can learn to bait it with a feint,
  which is interesting pressure. A hold-block would just get spammed, and an RL boss would learn
  to ignore it, making it worthless.
- `Q` for dodge sits under the left hand next to WASD — reachable while moving, unlike Space
  for players who also strafe.

## Consequences
- Not every attack should be parryable. **Unparryable attacks need a distinct visual tell**
  (proposed: the telegraph pulses purple instead of orange->red) or parry becomes a guess.
- Boss design gains a new lever: feints that bait a parry, and attacks that must be dodged.
- v0 scope grows by one mechanic. Parry lands in milestone 2 (alongside dodge), not later,
  because it changes how every boss attack is authored.
- Open: does a successful parry also refund the dodge cooldown? (Probably not — too forgiving.)
