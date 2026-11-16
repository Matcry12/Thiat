# 0003 — Loadout, hotbar and weapon swapping

**Status:** Partly superseded by [0058](0058-free-weapon-swap-no-weapon-limit.md) (weapon limit, swap cost)

**Date:** 2026-09-22

## Context
Terraria-style free hot-swap makes fights into inventory management and gives an RL boss a non-stationary opponent to train against. Albion-style fixed weapon kits fix that but throw away the item-combo discovery we want. See [0001](0001-design-reference-games.md).

## Decision
**Minecraft-style hotbar, weapon swap gated, everything else free.**

- Hotbar of ~9 slots, number keys / scroll to select. What's in the slot is what's in your hands.
- **At most 2 weapons** may occupy the hotbar. Remaining slots are items: potions, mobility tools (teleport rod, dash gem), throwables, utility.
- **Two separate knobs, both apply** (Terraria's potion-sickness pattern):
  - **Swap cast** — a visible, interruptible window where you are vulnerable and cannot attack.
  - **Swap cooldown** — how long before you may swap *again*. This is what stops swap-tanking.
- **Weapon swap.** Starting values, tune: **0.6s cast, 5s cooldown.** Dodge cancels the cast (and the swap fails).
  - At a 5s cooldown a 30s boss phase allows ~6 swaps, so weaving (bow→sword on approach) stays possible but costly. Raise toward 10s to make the second weapon a phase-answer instead of a combo tool.
- **Armor swap.** Starting values, tune: **1.5s cast, 10s cooldown.** Longer than weapons — armor is the bigger exploit surface (swap to tank right before a telegraphed hit, swap back after).
- **Potions are free to use** but keep their own Terraria-style sickness: healing potions have a long personal cooldown (starting value, tune: **30s**), separate from the swap cooldowns. Buff potions use their own per-potion cooldowns.
- **Bag is locked in combat.** Weapon 3 stays in the pack; only hotbar contents exist during a fight.
- Skills come from the equipped weapon (Albion-style): 2 weapons = 2 kits, and swapping between them mid-fight is itself a skill expression (bow to open, sword when it closes).
- Armor still biases toward a damage type, so a sword+bow loadout means one weapon is off-set and weaker. That is the intended cost of flexibility.

## Why
- Preserves Terraria's build discovery out of combat while making the in-fight kit finite and readable.
- Gives the RL boss a **bounded** opponent: the player's capability set is fixed for the fight, so a policy can learn to punish patterns instead of being whiplashed by a bag of counters.
- The 0.6s swap turns "switch weapon" into a real decision with a cost, instead of a free answer to every attack.
- Easy to loosen later (3rd slot, faster swap); taking swaps away later reads as a nerf.

## Consequences
- RL boss training rotates over loadout archetypes (melee / ranged / hybrid / mobility-heavy), not over "all items".
- Armor swap-tanking is closed by the 10s armor cooldown: you can swap to tank armor for a telegraphed hit, but you are stuck in it for 10s afterward. Verify in playtest that this actually costs more than it gains.
- All four cooldowns (weapon, armor, heal, dodge) must be visible on the HUD — a gated action the player can't see the timer for reads as the game being broken, not as a rule.
- Difficulty dial if tuning needs it: Strict (no bag, 2 weapons) → Default (this) → Loose (bag access via a 3s vulnerable rummage).
