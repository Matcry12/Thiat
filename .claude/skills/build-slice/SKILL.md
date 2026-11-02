---
name: build-slice
description: Build a planned BossFight slice fast - split it into tasks by file ownership, run several godot-builder agents in parallel, judge each piece with a fresh slice-judge as soon as it lands, fix, then one full test run. Use when the user says build / implement a slice or feature that touches more than one file.
---

# Build a slice

Main loop (Opus) plans, splits and reports. It does not write the code.

## 1. Split (main loop)
- One line of intent to the user first (CLAUDE.md global rule), then go unless they object.
- Cut the slice into tasks. Each task: goal, **files it owns** (no file in two tasks), what done
  looks like, decision records to read.
- Shared files (e.g. `arena.tscn`, the F3 panel) go to ONE task, or to a last small task after the
  others land.
- A task that needs another task's result waits; everything else starts now.
- Tiny or mechanical pieces: `ds` (DeepSeek) per the global routing table, with a check, if
  `~/.config/deepseek/api_key` exists; else a Haiku agent.

## 2. Build in parallel
Launch every ready task in ONE message: one `godot-builder` agent each (Sonnet). Keep their names so
fixes go back to the same builder with `SendMessage` (it keeps its context).

## 3. Judge as each lands (pipeline, not batch)
When a builder reports, launch a fresh `slice-judge` on its diff right away (Opus; use
`model: sonnet` if Opus wrote it). Give it the request, the builder's report and the changed files.
Do not wait for the other builders.

## 4. Fix
- Confirmed findings -> back to the same builder. Re-judge only what changed.
- Same task fails twice (tests red, or the judge confirms a real bug twice) -> give it to a fresh
  Opus agent. Note it in the slice log.
- Stop review rounds when the findings become small; let the playtest decide.

## 5. Finish
- `tools/run_tests.sh` (full suite) once, after all pieces are in.
- Screenshots if anything visual changed (an Opus/Claude agent looks at them).
- Report to the user in B1 English: what changed in the game, test result, what the judges found
  (including "nothing"), what must be playtested.
- Add the slice log line in `docs/wiki/prototype-v0.md` (who built, what the judge found).
- Commit only when the user says "commit".
