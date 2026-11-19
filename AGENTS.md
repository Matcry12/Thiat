# AGENTS.md — rules for any AI model working here

Read this first, whatever tool you are (Claude, Codex, Gemini, Cursor...).
New to the project? Start with [README.md](README.md) (what the game is, how to run and test,
where the code is), then [docs/wiki/project-status.md](docs/wiki/project-status.md) (known problems).

Names like `pixel-artist`, `slice-judge`, "Opus" / "Sonnet" and "hook" are Claude Code setup
(`.claude/agents/*.md`, `.claude/hooks/`). Other tools: read those files as plain instructions, and
where a rule says "another model judges", ask a different model or a person to review.

Section numbers match the old `CLAUDE.md`, so references like "CLAUDE.md §5" in code comments
and decisions point here. `CLAUDE.md` now holds only Claude-specific setup (§1, agent routing).

Before writing code, read §9 (how to write code: think first, keep it simple, change only what you must).

## 0. Hard rules that tools enforce for Claude (follow them by hand)

- Never create files in the repo root. Allowed there: `README.md`, `AGENTS.md`, `CLAUDE.md`,
  `project.godot`, `.gitignore`, `.gitattributes`, `LICENSE`, `pyproject.toml`, `requirements.txt`,
  `export_presets.cfg`.
- Never edit `.godot/`, `*.import`, `*.uid` (generated).
- Run tests only through `tools/run_tests.sh` (or `timeout 60 godot ...`), never a bare `godot --script`.
- After every `.gd` edit: `godot --headless --check-only --script <file>`.
- A change that alters how the project is built gets a decision record in `docs/decision/`.
  Every decision and wiki page has a `**Status:**` line under its title. A new record that replaces an
  old one also updates the old one's Status line. Then run `python3 tools/docs_index.py` (rebuilds `docs/README.md`).

## 2. Always verify before reporting

Never report a task as done on assumption. Before any "it works" claim:

1. Read the code that changed.
2. **Run it** if it can be run (build, test, execute, lint).
3. **Test the user's steps too.** If the report tells the user to set something in the editor, load
   the scene headless and confirm that value actually reaches the running game.
4. **Get a second judge**, unless the change is small: 1-3 code files, no new system, not save format,
   map generation or shared combat code ([0062](docs/decision/0062-test-levels-by-change-size.md)). A small
   change needs no builder and no judge: Quick tests, then report. After any bigger change, spawn a reviewer agent with **fresh context,
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
2. **Read every `.claude/memory/*.md` at the start of a session** (Claude Code loads them by a
   SessionStart hook; other tools must read them by hand). Check them before acting.

## 4. Keep files tidy — never drop them loose

Before creating or saving any file, find the folder it belongs in. If none fits,
create a proper one first, then place it. **Root stays clean** — no stray files.

- `docs/wiki/` — durable knowledge, how-things-work notes.
- `docs/decision/` — decision records, `NNNN-<slug>.md`: Context / Decision / Why / Consequences. Write one whenever a choice changes how the project is built (the decision-detector hook reminds you).
- `docs/reference/` — external material (PDFs, playbooks, specs).
- `assets/` — only `game/` (ships), `dev/` (F3 / demos), `source/` (packs, originals; `.gdignore`), `retired/` (unused; `.gdignore`). New art: pick by role, unused files go to `retired/`, never delete ([assets/README.md](assets/README.md), 0063, `tests/test_asset_rules.gd`).
- Media (png / mp4 / gif) in `docs/demo/` and `tools/art_tests/` is local only, not in git (`.gitignore`). One-off scripts live in `tools/retired/` (`.gdignore`).

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

Debug keys: `F1` shapes (hitboxes, ranges, areas), `F2` slow motion 0.25x, `F3` live tuning dock
(cycles full -> watch only -> off). Also `1`-`9` hotbar, `Tab`/`I` bag + crafting book, `+`/`-` zoom,
`Esc` pause, `R` retry after a boss win, title `Test yard` (dev builds).
**Full list of what each key shows: [docs/wiki/debug-keys.md](docs/wiki/debug-keys.md). Keep it current** -
a change that adds an F3 row, F1 shape or debug button updates that page in the same change.
**When adding any feature, the same slice must also:**

1. **Expose every number as `@export`** — on a Resource or a node. The F3 panel reflects over
   `@export` properties, so a new number appears automatically. A hardcoded feel constant is a bug.
2. **Show the new state in F3** — a new cooldown, phase, flag or counter must be visible while
   playing. If the player cannot see why something happened, it cannot be tuned.
3. **Draw the new shape in F1** if it has a hitbox, range or area.
4. **Leave a way to trigger it on demand** where that is not trivial (a key to spawn the enemy, to
   force a boss phase, to refill health).
5. **Debug hook pattern ([0070](docs/decision/0070-debug-hook-pattern.md)):** game code only exposes state (group `debug` + `debug_*` methods, `DebugFlags.shapes_on`); it never looks up a debug node by name or path.

Test mode is dev-build only and never shipped, but it is never an afterthought either: the reason
every number in the design docs says "starting value, tune" is that the panel is how they get
resolved.

## 8. Project: BossFight (Godot 4.7 top-down combat + RL bosses)

**Stack**
- Game: **Godot 4.7**, GDScript (`godot` on PATH). Scenes in `scenes/`, scripts in `scripts/`,
  data as `.tres` in `data/`. Code map: [README.md](README.md).
- RL (planned, `rl/` does not exist yet): Python (godot_rl_agents + stable-baselines3), training-only. Shipped inference is
  JSON weights + a GDScript matmul — **the official ONNX node is .NET-only**
  ([0008](docs/decision/0008-rl-inference.md)).

**Read before design or code work**
- [docs/wiki/design-pillars.md](docs/wiki/design-pillars.md) — the combat/boss/item system.
- [docs/wiki/prototype-v0.md](docs/wiki/prototype-v0.md) — v0 scope and architecture (done plan; slice log now in [v1-design.md](docs/wiki/v1-design.md) §13).
- [docs/decision/](docs/decision/) — 0001..0070 (0068 unused). Settled; supersede with a new record, never ignore.
- [docs/reference/godot/](docs/reference/godot/) — Godot 4 combat patterns, juice recipes, RL notes.
- [docs/reference/godot/engine-versions/](docs/reference/godot/engine-versions/) — Godot 4.4–4.7 API changes (breaking, deprecated). Check before using an API that may be newer than 4.3.
- UI work: [docs/design/DESIGN.md](docs/design/DESIGN.md) (style "Island Workshop", decision 0043). Apply it;
  new looks are designed in the web mockup `tools/ui_mock/` first (shots: `tools/ui_mock/shots.py`).
- Pixel art (items, icons, props, ore rocks): the `pixel-artist` agent ([.claude/agents/pixel-artist.md](.claude/agents/pixel-artist.md))
  draws it by hand as char grids in `tools/art_tests/<topic>/` ($0, Pixel Crawler style). Opus checks every
  render before the user sees it.
- "Add this weapon / tool" from a picture (artist art arrives in `assets/source/artist_inbox/`): run `python3 tools/add_weapon.py <picture.png> <id> [--kind sword|axe|pickaxe|hoe] [--scale N] [--flip] [--hands 1|2]` (`--dry-run` first: check the handle end). Never make the files by hand, no builder or judge needed. Then `tools/run_tests.sh tests/test_item_files_complete.gd tests/test_asset_rules.gd`; the user checks it in `Test yard`, book tab `Items`.
- Map / world work: [docs/wiki/world-gen-plan.md](docs/wiki/world-gen-plan.md) and
  [docs/wiki/vegetation-rules.md](docs/wiki/vegetation-rules.md). Any new look gets a $0 preview picture first
  (`tools/asset_viewer/*.py`) that the user approves before it is built.
  Map art lives in `assets/game/map/pixel_plains/`. Map art changed → update `assets/game/map/pixel_plains/README.md` in the same change.

**How we work** ([0007](docs/decision/0007-working-agreement.md))
- **Algorithm first, then build.** Before building any game system (spawning, loot, AI, progression, world gen), study how
  the reference games solve it (Minecraft, Terraria, the ones in [0001](docs/decision/0001-design-reference-games.md)), write
  the algorithm down in `docs/wiki/<system>-algorithm.md` (sources table + our rules + tuning), get the user's OK, then build
  to that page. Never build a system just to "match" a request. Example: [enemy-spawning-algorithm.md](docs/wiki/enemy-spawning-algorithm.md).
- Vertical slices, one question each, playtested by the user before the next slice starts.
- Every feel number is an `@export` (live-tunable via `F3` panel / Remote inspector). Never hardcode one.
- Debug keys: `F1` hitboxes + timing (boss attack areas, charge lane, FightZone, rocks), `F2` 0.25x slow-mo, `F3` tuning panel (+ boss trigger buttons).

**Verify (rule 2, made concrete)**
- GDScript change → `godot --headless --check-only --script <file>` (Claude runs this by hook after
  every edit; other tools: run it yourself); `godot --headless --quit` to boot the project.
- Tests ([testing-algorithm.md](docs/wiki/testing-algorithm.md)). Quick, every fix round: `tools/run_tests.sh --changed`
  (tests naming the changed files + the real-arena smoke test) or `tools/run_tests.sh tests/test_x.gd ...`. Full, once just
  before commit, in the background (Claude hook enforces it; others: do it anyway): `tools/run_tests.sh` (8 at a time, `-j N`, slowest 15 printed).
  Never run it again to read a failure: `.godot/test_logs/last.txt` has the output. After a fix: `--failed`, then `--changed`
  (a fix can break a test that passed); a fix in shared code gets one more Full. Tests use a 192-cell map unless on the
  `REAL_MAP` list in `run_tests.sh` (a new test that needs its own map size goes there; `--real-map` = the runner sets no small
  map, a test can still set its own). `KNOWN_RED` tests run and show but do not fail the run. Each test gets its own
  `user://` and `--fixed-fps 60`, so parallel runs (and other worktrees) never clash.
- Run a test script through `run_tests.sh` or with `timeout 60 godot ...`. Never a bare `godot --script`: it can hang
  forever (Claude hook blocks it).
- Python change → `pytest rl/` and a short smoke run of the env.
- Gameplay feel (hit timing, dodge windows) can't be verified headless — say so, ask the user to playtest.

**Godot rules**
- `.godot/`, `*.import`, `*.uid` are generated. Never edit.
- Prefer editing `.tscn` via the editor semantics you know; when editing by hand, keep `[gd_scene ... format=3]` and node paths intact and re-check with `--check-only`.
- Combat logic lives in code (state machines, hitboxes), not in scattered signal connections inside `.tscn`.
- Boss RL: observation/action spaces get documented in `docs/wiki/rl-spaces.md` when RL work starts
  (not yet written — v0's boss is hand-scripted).

## 9. How to write code

From [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills/blob/main/CLAUDE.md),
adapted. These rules work if diffs get smaller, fewer rewrites happen, and questions come before
mistakes, not after. For a trivial task, use judgment.

**Think before coding.** Do not guess and do not hide confusion.
- Say your assumptions. If unsure, ask.
- Two ways to read the request? Show both, do not pick one silently.
- A simpler way exists? Say so. Push back when it is right to.

**Simplicity first.** The least code that solves the problem.
- No features, abstractions or error handling nobody asked for. 200 lines that could be 50: rewrite.
- Two project rules are NOT "extra" and always apply: every feel number is an `@export` (§7), and
  visuals / effects sit in their own node (§5). Those are requested, not speculative.

**Surgical changes.** Touch only what the task needs.
- Do not "improve" nearby code, comments or formatting. Match the existing style.
- Unrelated dead code or mess: mention it (or add it to [project-status.md](docs/wiki/project-status.md)), do not fix it.
- Remove only what YOUR change made unused. Every changed line traces back to the request.
- Clean-up work from `project-status.md` §4 is its own task, done when asked, never on the side.

**Goal first, then loop until checked.** Turn the task into a check you can run.
- "Fix the bug" -> write a test that shows it, then make it pass. "Refactor X" -> tests green before and after.
- Several steps: write a short plan, each step with its check: `1. <step> -> check: <test / command>`.
- Checks run through `tools/run_tests.sh` (§8). Feel cannot be checked headless: say so (§8).
