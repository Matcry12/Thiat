# CLAUDE.md — Operating Plan

This file is the **plan**. Read it, follow it, every task.

## 1. Spawn an agent, or do it yourself?

Before starting any task, ask this **first**:

> Should this be delegated to an agent, or done inline?

- **Delegate** (spawn a subagent on the *lowest capable model*) when the work is:
  multi-file, repetitive, a search sweep, a refactor, drafting, or anything that
  would dump lots of output into this context. Keep only the *conclusion* here.
  - `haiku` — lookups, mechanical edits, per-item classification, bulk work.
  - `sonnet` — standard implementation, drafts, refactors, multi-file edits.
  - `opus` — planning, architecture, review/critique only. **Not the doer.**
- **Do it yourself** only for: trivial single edits, one command, a quick answer,
  or config in `.claude/**` / `CLAUDE.md` / `docs/**`.

Default bias: **delegate the doing, keep the deciding.**

## 2. Always verify before reporting

Never report a task as done on assumption. Before any "it works" claim:

1. Read the code that changed.
2. **Run it** if it can be run (build, test, execute, lint).
3. Only then report — with the actual evidence (output, exit code, test result).

If it failed, say so plainly with the output. No hedging, no "should work".

## 3. Learn from mistakes — never repeat one

When the user points out a mistake:

1. Append it to `.claude/memory/mistakes.md` as a one-line rule (other topics: `preferences.md`, `godot-gotchas.md`).
2. All `.claude/memory/*.md` are auto-loaded every session (SessionStart hook), so past mistakes
   are always in front of you. Check it before acting.

## 4. Keep files tidy — never drop them loose

Before creating or saving any file, find the folder it belongs in. If none fits,
create a proper one first, then place it. **Root stays clean** — no stray files.

- `docs/wiki/` — durable knowledge, how-things-work notes.
- `docs/decision/` — decision records, `NNNN-<slug>.md`: Context / Decision / Why / Consequences. Write one whenever a choice changes how the project is built (the decision-detector hook reminds you).
- `docs/reference/` — external material (PDFs, playbooks, specs).

## 5. Project: BossFight (Godot 4.x top-down combat + RL bosses)

**Stack**
- Game: Godot 4.x, GDScript. Scenes in `scenes/`, scripts beside their scene, shared logic in `scripts/`.
- RL: Python in `rl/` (godot_rl_agents + stable-baselines3). Trained policies exported to ONNX and loaded in Godot for release; Python is training-only.

**Verify (rule 2, made concrete)**
- GDScript change → `godot --headless --check-only -s <script>` or `godot --headless --quit` on the project; run GUT/gdUnit4 tests if present.
- Python change → `pytest rl/` and a short smoke run of the env.
- Gameplay feel (hit timing, dodge windows) can't be verified headless — say so, ask the user to playtest.

**Godot rules**
- `.godot/`, `*.import`, `*.uid` are generated. Never edit.
- Prefer editing `.tscn` via the editor semantics you know; when editing by hand, keep `[gd_scene ... format=3]` and node paths intact and re-check with `--check-only`.
- Combat logic lives in code (state machines, hitboxes), not in scattered signal connections inside `.tscn`.
- Boss RL: observation/action spaces are documented in `docs/wiki/rl-spaces.md` — update it when they change.
