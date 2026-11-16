# 0062 - Test levels, and work sized by the change

**Status:** Active

## Context
A small change spent minutes on tests. `--changed` picked 75 of 110 tests after an edit to `player.gd`, the full suite took 296 s, most of it building the whole island in each test, and some sessions ran it many times. Numbers and sources: [testing-algorithm.md](../wiki/testing-algorithm.md).

## Decision
- **Quick level, every fix round:** `tools/run_tests.sh --changed` = tests that name the changed file, plus `tests/test_smoke_arena.gd` (real arena, real island size).
- **Full level, once just before commit:** `tools/run_tests.sh`. Most tests use a 192-cell map; on the `REAL_MAP` list in that script the runner sets no small map. `--real-map` does that for every test (a few tests still set their own size).
- **After a fix from a Full run:** `--failed`, then `--changed`. A fix in shared code gets one more Full run.
- **Small change** (1-3 code files, no new system; not save format, map generation or shared combat code): no builder, no judge, Quick level, no Full run until commit. Anything bigger keeps builder, judge and one Full run.
- Failed runs are read from `.godot/test_logs/`, and `--failed` runs only those tests. `KNOWN_RED` tests still run and show, but do not fail the run.
- Hook `guard-godot.py` blocks `godot --script` without `timeout`, and a foreground Full run under a short limit.

## Why
Game teams keep small fast tests close to the developer and leave heavy tests to a later gate (Factorio, Rare, Riot). Godot itself starts in 0.4 s, so the cost is our island, not our test runner. That is why we did not move to GUT or gdUnit4.

## Consequences
- A bug reached only through a scene can pass Quick and be caught by Full at commit.
- A small change gets no second reviewer, so the playtest may find more. If that happens often, lower the limit.
- A new test that needs the big island fails on the small map; add it to `REAL_MAP`.
- This changes CLAUDE.md rule 2.4 and the Verify section.
