# 0051 - Our own agent team: design panel, parallel builders, judge

## Context
We looked at Claude-Code-Game-Studios (MIT, 49 agents, 72 skills). Its agents fit a big studio
(GDD for every system, sprints, director sign-offs) and its skills need its own scripts and config,
so copying them does not work here. The user is new to game design and wants several views on a
design question, and wants builds to go faster by running agents side by side.

## Decision
- **Design panel** (`design-panel` skill): five read-only Sonnet agents, `design-core` (loop and
  feel), `design-systems` (numbers, economy), `design-player` (new player's eyes), `design-world`
  (map and pacing), `design-critic` (the case against). They answer the same question in parallel
  without seeing each other. Opus merges: agree / disagree table / my pick / the user's decision.
- **Build** (`build-slice` skill): Opus splits a slice by file ownership; several `godot-builder`
  (Sonnet) agents build in parallel; a fresh `slice-judge` (Opus) reviews each piece as soon as it
  lands. Full test suite once at the end.
- From the studio repo we kept only ideas: its design frameworks (loops, flow, sink/faucet), its
  GDScript checklist, and its Godot 4.4-4.7 docs (`docs/reference/godot/engine-versions/`).

## Why
Several fresh views show a beginner the trade-offs one answer hides. Parallel builders cut wall
time; judging each piece as it lands means no agent waits. Short project-specific agents follow our
rules (5, 7) that the generic ones do not know.

## Consequences
- Agents live in `.claude/agents/`, skills in `.claude/skills/`; both load at session start.
- A panel costs about 5 Sonnet runs. Drop members that do not apply.
- Two builders must never own the same file; shared files (arena scene, F3 panel) go to one task.
