# 0044 — F3 dock + "debug" group contract (supersedes the F3 layout parts of rule 7 / prototype-v0)

**Status:** Active

## Context
The F3 panel was one 1147-line file. It held ~40 buttons in a flat wall, 100+ sections in a 340 px
scroll list with no search, and a status wall that covered half the game. Vector2/Color could not be
edited. Save/Load (user://tuning.json) and Save rig (.tres) saved to different places with no hint.
Every new feature had to edit that file in three places (target list, button row, status text).
The user said it felt "like flying an airplane".

## Decision
- **Layout** (designed in `tools/f3_mock/`, 3 build→review rounds, approved 2026-10-25 at 8.1/10):
  a 380 px opaque dock on the right with search on top and tabs Tune / Actions / Status. A click-through
  watch card shows pinned status. `F3` cycles off → full → watch only.
- **Contract:** a feature joins group `"debug"` on its own node. Optional methods: `debug_name()`,
  `debug_category()`, `debug_children()` (resources / many-instance things, `{name, object, cat?}`),
  `debug_actions()` (`{label, run, toggle?, danger?, arg?}`), `status_text()`, `debug_heavy(prop)`.
  Its `@export`s appear by reflection. Slider ranges come only from `@export_range`; with no hint the row
  has a number field and scrub, no slider. The panel rescans the group each time the dock opens.
- Only one-per-world nodes join the group. Many-instance things are listed by their owner.
  Cross-node actions live on the arena root (`scripts/arena.gd`, category Run).
- **Persistence:** every F3 edit auto-saves to `user://tuning.cfg` (ConfigFile) with its base value.
  An override whose file value changed since is skipped as stale. Headless runs use a throw-away file.
  The footer shows the count, `Write K to .tres` (loads a fresh copy, sets only those props) and
  `Clear overrides`.
- **Input:** a pointer over the dock never attacks, aims or changes the hotbar slot. Sliders ignore
  the wheel. Dock buttons take no focus. Esc leaves a text field before the pause menu sees it.

## Why
- Search plus folding beats scrolling a 2000-setting list, and typed fields give exact values.
- The contract puts the debug info next to the feature, so the panel never grows again.
- A loud auto-save fixes "what is kept where?" without Save/Load buttons.

## Consequences
- A new feature needs **zero** edits in `scripts/debug/`: add the group plus the methods it needs.
- `@export_range` is now the place for slider ranges (the `range_overrides` dict is gone).
- Persistence keys are section names (`debug_name`). Renaming one orphans its overrides; the footer
  lists unknown keys.
- Tests: `test_f3_input` (input leaks), `test_debug_contract` (every old section/action still exists),
  `test_f3_overrides`, `test_f3_wiring`, `test_f3_dock`.
