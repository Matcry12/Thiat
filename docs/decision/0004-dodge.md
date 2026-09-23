# 0004 — Dodge is baseline, cooldown-gated

**Date:** 2026-09-22

## Context
[Design pillars](../wiki/design-pillars.md) §2 contradicted itself: "no default dash/roll, mobility is a gear unlock" alongside "universal i-frame dodge", while [0003](0003-loadout-and-swapping.md) assumed dodge exists (it cancels a weapon swap). Necesse has no dodge; Terraria/Souls-likes do.

## Decision
**Dodge is a baseline ability, always available, gated by its own cooldown — not by stamina.**

- Starting values, tune: **0.3s i-frames**, ~2.5 tile burst in the movement direction, **2s cooldown**, visible on the HUD.
- No stamina bar. You cannot chain-roll; the cooldown is the whole limit.
- Cancels a weapon swap in progress (the swap fails, per 0003).
- Gear/accessories tune it (shorter cooldown, longer i-frames, extra charge) but never grant or remove it.

## Why
- Not Souls-like: no stamina economy to manage, so the decision is purely "is this the attack worth spending my dodge on."
- A fixed, visible cooldown is legible to the player *and* trainable against — an RL boss can learn to bait the dodge and punish the 2s window, which is good, fair pressure rather than an unreadable gotcha.
- Resolves the §2 contradiction: dodge is baseline; *movement tools* (teleport rod, dash gem, grapple) remain separate hotbar items with their own cooldowns.

## Consequences
- The dodge cooldown is a primary difficulty knob — raising it makes a boss dramatically harder without touching its moveset.
- Boss attack pacing must be authored against the 2s cooldown: back-to-back unavoidable hits inside 2s are unfair by construction.
- Mobility items must stay distinct from dodge (longer range, longer cooldown, no i-frames) or they trivialize it.
