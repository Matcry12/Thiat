# 0063 - Asset folders by role

**Status:** Active

## Context
`assets/` had 10 top folders mixed by topic. Nothing said which files ship, which are for demos, which are downloaded packs and which nobody uses. `serene_village` was imported by Godot although no code used it. About 30 unused files sat beside used ones. Some code (`PixelArt`) held a path to F3-only art.

## Decision
`assets/` holds only `game/` (in the game), `dev/` (F3 / test mode / demos, never shipped), `source/` (packs, originals, templates; `.gdignore`) and `retired/` (unused or not cleared for release; `.gdignore`; nothing is deleted). Sub-folders keep their old names; `ui/game` became `game/ui/skin` (the baked parts of `InventorySkin`). `tests/test_asset_rules.gd` enforces: top folders, no loose files, code names only `game/` or `dev/`, only demo / debug code names `dev/`, every `game/` file is used (loaded-by-name files are listed in the test), every named path exists. The rules and "where new art goes" are in [assets/README.md](../../assets/README.md).

## Why
The path now answers "does this ship?" without opening the file. The test turns a forgotten file, or a game scene that points at a demo picture, into a red test. `.gdignore` on `source/` + `retired/` keeps Godot from importing files that are not used.

## Consequences
- `PixelArt.F3` is gone; `F3Theme` owns `res://assets/dev/ui/f3/`.
- New art: pick the folder from the table in `assets/README.md`. A file in `game/` that no scene or script names fails the test.
- Python tools write to the new paths. `tools/make_placeholders.py` re-creates the retired placeholder pictures in `game/placeholder/`: move them back to `retired/` after a run.
- `manifest.json` (read by tools only) is in `source/map/pixel_plains/`.
- Uncertain calls: `dev/characters/test3d_hybrid` (no code reads it; kept in dev), `source/ui/placeholder` (only the UI mock reads these 6 icons).
