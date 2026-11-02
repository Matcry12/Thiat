---
name: design-panel
description: Get several design views on one BossFight design question at once (core loop, numbers, new player, world, devil's advocate), then merge them into one table the user can decide from. Use when the user asks a design question, wants "multiple views", is unsure how a mechanic should work, or before planning a slice that adds a new mechanic.
---

# Design panel

The user is new to game design and wants several views, not one answer. The panel members are
agents in `.claude/agents/design-*.md`. Main loop (Opus) only asks, merges and explains.

## 1. Frame the question (main loop)
One paragraph: the question, what exists today (from code/docs you already know), and any limits
the user gave. If the question is vague, ask ONE clarifying question first.

## 2. Pick members, launch in ONE message (parallel)
Default all five. Drop members that clearly do not apply (say which and why in one line):

| Agent | Ask it when |
|---|---|
| `design-core` | always |
| `design-systems` | numbers, items, crafting, progression, balance |
| `design-player` | anything the player sees, controls, learns, or fails at |
| `design-world` | map, biomes, travel, where things are |
| `design-critic` | always |

Each gets the same framed question. Never show one member another's answer (fresh views).

## 3. Merge (main loop) — B1 English, short
1. **Where they agree** — 1-3 bullets. Safe defaults.
2. **Where they disagree** — a table: `Option | Who wants it | What you would see in game | Risk`.
3. **My pick** — one line, which option and why.
4. **Your decision** — the one or two questions only the user can answer (use the answer buttons).

Keep each member's full text out of the reply; quote a line only when it decides something.

## 4. After the user decides
- Write a decision record in `docs/decision/NNNN-<slug>.md` if it changes how the game works.
- Ideas the user parks go to `docs/wiki/ideas.md`.
- Then plan the slice (`build-slice` skill).
