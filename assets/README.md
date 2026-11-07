# assets/ - the folder says what a file is

Only these four folders (and this file) sit in `assets/`. The test `tests/test_asset_rules.gd` checks the rules below.

| Folder | Meaning | Who may load it | New art goes here when... |
|---|---|---|---|
| `game/` | In the real game. Ships to players. | Game code, scenes, data. Demo / debug code too. | The game draws or plays it. Keep the sub-folder by role: `characters/`, `map/`, `ui/`, `audio/`, `fx/`, `stations/`, `world/`. |
| `dev/` | Only for F3 / test mode and demos. Never shipped. | `scripts/debug/`, `scripts/demo/`, `scenes/demo/` only. | Only the F3 dock or a demo uses it (F3 pictures, 3D test characters). |
| `source/` | Downloaded packs, originals, templates. Godot skips it (`.gdignore`). | Nobody in game code. Python tools may read it. | You downloaded a pack, or keep an original file / template. Need a copy in the game? Copy it into `game/`. |
| `retired/` | Unused, or not cleared for release. Godot skips it (`.gdignore`). | Nobody. | Nothing uses it any more. We move it here, we never delete it. |

Rules:
- No loose files at the top of `game/`, `dev/`, `source/`, `retired/`. Use a sub-folder.
- Code and data name only `game/` or `dev/` paths. Never `source/` or `retired/`.
- Game code never names `dev/`. Only demo and debug code does.
- Every file in `game/` must be used. Unused? Move it to `retired/`. A folder loaded by name (fonts, UI parts) is listed in the test, `BY_NAME`.
- Use `git mv` and move the `.import` file with the picture. Then run `godot --headless --import`.

Credit needed for packs: see `source/third_party/README.md`. `retired/stock/` is NOT cleared for release (see its README).
Map art: `game/map/pixel_plains/README.md`. Decision: `docs/decision/0063-asset-folders-by-role.md`.

No export preset exists yet. When one is made, exclude `assets/dev/*`, since Godot would otherwise ship it.
