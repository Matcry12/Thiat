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

## 5. Build for replacement, never for the placeholder

Everything visible right now is placeholder — circles, capsules, wedges, ugly bars. **None of it
may be load-bearing.** Before writing any visual or content code, ask: *when this becomes a pixel
sprite / a real level / a real weapon, is this a swap or a rewrite?* If it is a rewrite, restructure
before continuing.

Concretely, every time:

- **Visuals live in their own node and nothing reaches inside.** Combat emits state
  (`state_changed`, `set_aim_angle`, `on_weapon_state`); the visual node decides what to draw.
  Replacing a `Polygon2D`/`_draw()` with an `AnimatedSprite2D` must touch **zero** combat code.
- **Every effect gets a slot, not a special case.** A swing, a hit flash, a telegraph is its own
  node driven by data + signals — so it can be swapped for a sprite, shader or trail later.
- **Timings and numbers live in data (`WeaponData` / `@export`), never in art.** When a real
  animation arrives, the art is stretched to fit the tuned timing — the timing is never changed to
  fit the art. `speed_scale = anim_length / data_duration`.
- **No number that affects feel is a hardcoded constant.** It is an `@export`, so it reaches the
  inspector and the F3 tuning panel.
- **Name things by role, not by shape.** `Visual`, `SwingArc`, `Telegraph` — never `WhiteCircle`,
  `RedRect`.
- Placeholder is a **stand-in with a defined interface**, not a prototype to be rewritten. Writing
  something that will have to be rebuilt from scratch when art arrives is the failure this rule exists
  to prevent.

## 6. How to talk to me (the user)

Write so it can be understood **without reading the code**.

- **English level B1, B2 at most.** Short sentences. Common words. One idea per sentence.
- **Always give an example.** Not "the visual layer lacks a contract" but "if you drop in a sprite,
  nothing tells you which functions it must have - like buying a plug without knowing which socket
  it fits."
- **Explain the problem before the solution.** What breaks, when it breaks, what the user would
  actually see on screen.
- **No jargon without a plain-words explanation right next to it.** "Y-sorting (which character is
  drawn in front when two overlap)".
- **Say what it means for the game**, not what it means for the code. "Two enemies will overlap
  wrong" beats "the draw order is undefined".
- Keep tables and short lists. Avoid long paragraphs.
- Code snippets only when the user asks for code, or when a file must be edited by hand.

If an explanation needs the user to understand the code to follow it, it is the wrong explanation -
rewrite it.

## 7. Project: BossFight (Godot 4.7 top-down combat + RL bosses)

**Stack**
- Game: **Godot 4.7**, GDScript (`~/.local/bin/godot`). Scenes in `scenes/`, scripts in `scripts/`
  (components / weapons / brains), weapon data as `.tres` in `data/weapons/`.
- RL: Python in `rl/` (godot_rl_agents + stable-baselines3), training-only. Shipped inference is
  JSON weights + a GDScript matmul — **the official ONNX node is .NET-only**
  ([0008](docs/decision/0008-rl-inference.md)).

**Read before design or code work**
- [docs/wiki/design-pillars.md](docs/wiki/design-pillars.md) — the combat/boss/item system.
- [docs/wiki/prototype-v0.md](docs/wiki/prototype-v0.md) — v0 scope, architecture, debug/tuning tools.
- [docs/decision/](docs/decision/) — 0001..0008. Settled; supersede with a new record, never ignore.
- [docs/reference/godot/](docs/reference/godot/) — Godot 4 combat patterns, juice recipes, RL notes.

**How we work** ([0007](docs/decision/0007-working-agreement.md))
- Vertical slices, one question each, playtested by the user before the next slice starts.
- Every feel number is an `@export` (live-tunable via `F3` panel / Remote inspector). Never hardcode one.
- Debug keys: `F1` hitboxes + timing, `F2` 0.25x slow-mo, `F3` tuning panel.

**Verify (rule 2, made concrete)**
- GDScript change → `godot --headless --check-only --script <file>` (the PostToolUse hook runs this
  automatically and blocks on parse errors); `godot --headless --quit` to boot the project.
- Python change → `pytest rl/` and a short smoke run of the env.
- Gameplay feel (hit timing, dodge windows) can't be verified headless — say so, ask the user to playtest.

**Godot rules**
- `.godot/`, `*.import`, `*.uid` are generated. Never edit.
- Prefer editing `.tscn` via the editor semantics you know; when editing by hand, keep `[gd_scene ... format=3]` and node paths intact and re-check with `--check-only`.
- Combat logic lives in code (state machines, hitboxes), not in scattered signal connections inside `.tscn`.
- Boss RL: observation/action spaces get documented in `docs/wiki/rl-spaces.md` when RL work starts
  (not yet written — v0's boss is hand-scripted).
