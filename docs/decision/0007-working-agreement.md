# 0007 — Working agreement: vertical slices, playtest-driven

**Status:** Active

**Date:** 2026-09-23

## Context
Combat quality is decided by feel, which cannot be verified headless (see CLAUDE.md rule 2).
Long build phases followed by one big review would hide bad feel for weeks.

## Decision
We work in **vertical slices**. Each slice is small, playable, and answers one question.

### The loop
1. **I build one slice.** Smallest thing that is actually runnable end-to-end — never a layer
   ("all the components"), always a slice ("you can swing and something reacts").
2. **I hand it over** with exactly three things:
   - *Run it:* the command / how to open it.
   - *Do this:* the 2-3 specific actions to try.
   - *Judge this:* the ONE question the slice exists to answer.
3. **You playtest and answer in plain words.** "Too floaty", "the swing feels late",
   "I can't tell when the parry window is" — feel language, not spec language. Translating that
   into numbers is my job, not yours.
4. **We adjust.** Numbers first, mechanics second, design docs third.
5. Next slice only after the current one feels right. **No stacking unverified slices.**

### Tuning without me
Every feel number (windup, recovery, cooldowns, i-frame length, dash distance, shake amount,
hit-stop duration) is an `@export` on a Resource or node. Three ways to change them, all live:

1. **Godot's Remote inspector** — run from the editor, Scene dock -> Remote tab, edit any `@export`
   while the game runs. Free, works today.
2. **The in-game tuning panel** (`F3`, see [prototype-v0 §1c](../wiki/prototype-v0.md)) — sliders
   over the running game, grouped by system, with save/load/reset to `user://tuning.json`.
3. Editing the `.tres` files directly for permanent changes.

You change numbers yourself; you only need me for behaviour changes. When a tuned set feels right,
save it and tell me — I fold the values back into the `.tres` defaults and the docs.

### Out of range is expected, not a failure
Any slice may reveal the design is wrong. When it does:
- Say so immediately — "this isn't fun" is the single most useful sentence in the project.
- We change the design, update the affected doc in `docs/wiki` and log a decision record.
- **No sunk-cost defence of a written decision.** Every decision doc so far is a starting point,
  not a contract. Superseded decisions get marked superseded, not quietly ignored.

### Scope guard
- I will not add a feature the current slice does not need, even if a later slice will need it.
- I will not polish anything marked throwaway ([prototype-v0](../wiki/prototype-v0.md): arena, HUD,
  placeholder shapes).
- If a slice is growing past "one question", I split it and say so.

### Verification split
- **I verify** it runs: `godot --headless --check-only`, no script errors, no crash on launch.
  I never claim a feel outcome I cannot test.
- **You verify** it feels right. That is the only test that matters for combat, and I cannot run it.

## Why
- A slice that runs is the only honest progress signal; a layer that compiles is not.
- Feel decays fast in the dark — the cost of a wrong design is proportional to how long it went
  unplayed.
- Exported tuning knobs remove me from the tightest iteration loop, which is where I am slowest
  and you are fastest.

## Consequences
- Slices are small enough that throwing one away costs hours, not days. That is the point.
- Expect design docs to be edited often. Churn in `docs/` is healthy here; churn in combat code
  after a slice is signed off is not.
- Blocked on the human step by design: I will stop and wait for a playtest rather than build ahead.
