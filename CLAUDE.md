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

**Which model for which job** ([0017](docs/decision/0017-model-routing.md)). In this project
`sonnet` = **Sonnet 5.5** (set in `.claude/settings.json`), `opus` = Opus 5.5.

| Job | Model | Why |
|---|---|---|
| Plan a slice, split it into tasks, decide design | Opus (main loop) | Deciding is where mistakes cost most |
| Build a slice / feature, write tests, refactor | Sonnet 5.5 agent | Normal coding; tested and judged after |
| Judge Sonnet's work (rule 2.4) | Opus agent, fresh context | A weak judge hides bugs; nobody sees them until playtest |
| Judge work Opus did itself | Sonnet 5.5 agent | Different eyes matter more than strength |
| Hard bug (flaky, timing, "can't reproduce") | Opus agent | Opus 5.5 was 2x faster on our debug test; both fixed it |
| Lookups, file sweeps, blind grading, mechanical edits | Haiku agent | Cheap and enough |
| Explain to the user | Opus (main loop) | It holds the conversation |

**Escalate, don't retry blind:** if a Sonnet agent fails the same task twice (tests red, or the
judge confirms a real bug twice), give that task to an Opus agent. Note it in the slice log.

**Slice log = the real-world score.** When a slice is done, add one line under that slice in
`docs/wiki/prototype-v0.md`: who built it, what the judge found, what the user found. After a few
slices this tells us where each model is weak — better data than a lab test.

## 2. Always verify before reporting

Never report a task as done on assumption. Before any "it works" claim:

1. Read the code that changed.
2. **Run it** if it can be run (build, test, execute, lint).
3. **Test the user's steps too.** If the report tells the user to set something in the editor, load
   the scene headless and confirm that value actually reaches the running game.
4. **Get a second judge.** After any non-trivial change, spawn a reviewer agent with **fresh context,
   on a different model than the one that did the work** (Opus wrote it → Sonnet judges; Sonnet
   wrote it → Opus judges). Give it the request, the diff, and this file. It judges: does the change
   do what was asked, does it break a rule here (one owner, build for replacement, test mode), and
   are there bugs the tests miss. Fix what it confirms; tell the user what it found — including
   "nothing".
5. Only then report — with the actual evidence (output, exit code, test result, judge verdict).

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

## 7. Test mode is part of every feature

Nothing is "done" until it can be **seen and changed while the game runs**. Test mode is not a
side tool — it ships with the feature, in the same slice.

Debug keys (keep this table current):

| Key | Shows |
|---|---|
| `F1` | Hitboxes, hurtboxes, attack phase, reach wedge |
| `F2` | Slow motion (0.25x) |
| `F3` | Status + live tuning panel (the Minecraft F3 equivalent). Boss status + buttons: `Phase 2`, `-> slam/spread/charge/ring` (force that attack next, ignores cooldown + phase), `Boss passive` (stands still, no attacks), `Heal boss`, `Heal player`, `Restart` |
| `F4` | Cycle the swing effect style (none / slash / trail / afterimage / particles) - temporary demo |
| `R` | Retry — only after the player died or the boss was defeated (not a debug key) |

**When adding any feature, the same slice must also:**

1. **Expose every number as `@export`** — on a Resource or a node. The F3 panel reflects over
   `@export` properties, so a new number appears automatically. A hardcoded feel constant is a bug.
2. **Show the new state in F3** — a new cooldown, phase, flag or counter must be visible while
   playing. If the player cannot see why something happened, it cannot be tuned.
3. **Draw the new shape in F1** if it has a hitbox, range or area.
4. **Leave a way to trigger it on demand** where that is not trivial (a key to spawn the enemy, to
   force a boss phase, to refill health).

Test mode is dev-build only and never shipped, but it is never an afterthought either: the reason
every number in the design docs says "starting value, tune" is that the panel is how they get
resolved.

## 8. Project: BossFight (Godot 4.7 top-down combat + RL bosses)

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
- Debug keys: `F1` hitboxes + timing (boss attack areas, charge lane, FightZone), `F2` 0.25x slow-mo, `F3` tuning panel (+ boss trigger buttons), `F4` swing effect style (demo).

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
