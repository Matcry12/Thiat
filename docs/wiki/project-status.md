# Project status and problems (2026-11-16)

**Status:** Current

A health check of the whole repo, made before a clean-up. Read this first if you are new
(human or AI model). It says what exists, what is messy, and the order to fix it.

## 1. What the game is today

- Godot 4.7, GDScript, top-down 2D, PC. A 20-30 minute run on a seeded island.
- You wake at home, chop trees, mine rocks, fight slimes, craft a copper sword, then fight the boss.
- Built: combat (swing, dodge, skill, parry / block), weapons as data (`data/weapons/*.tres`),
  hand-scripted boss, big procedural island with biomes, gathering, inventory, crafting,
  death + respawn, save / load, title / pause / settings, sound, day / night, test yard.
- Debug tools: `F1` shapes, `F2` slow motion, `F3` live tuning dock.
- Not done: W7 boss progression (altar + summon item), W10-W11. W5 slimes not playtested yet.
  RL boss is only a plan (`rl/` folder does not exist).

Size: 27,600 lines of GDScript (314 files), 124 tests, 68 decision records, 25 wiki pages.

## 2. Where the code is

| Folder | Lines | What it owns |
|---|---|---|
| `scripts/map/` | 7,900 | World generation, chunk loading, biomes, ground art |
| `scripts/ui/` | 3,600 | HUD, crafting window, inventory look, settings |
| `scripts/visual/` | 2,850 | How the player / weapons / swings are drawn |
| `scripts/components/` | 2,350 | Health, hitbox, inventory, crafter, guard, dodge |
| `scripts/debug/` (+`f3/`) | 3,050 | F3 dock, tuning panel, world map panel |
| `scripts/fx/` | 1,300 | Hit flash, sparks, hit-stop, shake, damage numbers |
| `scripts/world/` | 1,100 | Pickups, trees / rocks, stations, day / night, lights |
| `scripts/enemies/` | 900 | Enemy, spawner, slime brain |
| `scripts/` root | 2,070 | 10 loose files: `player.gd`, `boss.gd`, `arena.gd`, `hud.gd`, menus, save |
| small ones | | `weapons/`, `boss/`, `skills/`, `items/`, `audio/`, `settings/`, `brains/`, `demo/` |

## 3. Problems, worst first

### A. A new AI model cannot find its way in (HIGH)

| Problem | What happens |
|---|---|
| No `README.md` or `AGENTS.md` in the root | Other tools (Codex, Gemini, Cursor...) do not read `CLAUDE.md`. They start blind. |
| `CLAUDE.md` mixes everything | Claude model routing, how to talk to you, project rules and a 16,000-character F3 table on **one line** (line 138). Hard to read for any model. |
| Rules live only in Claude hooks | "Run tests only via `tools/run_tests.sh`", "no loose files in root" are enforced by `.claude/` hooks. Another model never sees them. |
| Key knowledge only in `.claude/agents/*.md` | The judge checklist and the pixel-art method exist nowhere else. |
| `docs/README.md` is old | Lists 8 of 68 decisions, misses most wiki pages. No "where is code X" map. |
| Wrong facts in `CLAUDE.md` | Says decisions "0001..0051" (there are 68), links `rl/`, `docs/wiki/rl-spaces.md`, `docs/assets/PNA-art/` - none exist. |

### B. Old docs look current (HIGH)

- Superseded decisions are not marked. Example: 0003 still says "max 2 weapons, 5 s swap
  cooldown", but 0058 removed that. A reader cannot tell.
- `prototype-v0.md` header says "nothing built, next: slice 1". It is the biggest doc (425 lines).
- `.claude/memory/project.md` says "art is circles forever" - wrong since real pixel art came.
- ✅ (fixed 2026-11-16: every page has a Status line) Done plans still look open: `hit-feel-plan.md`, `world-gen-plan.md`, `docs/superpowers/plans/`.
- ✅ (backlogs merged into `backlog.md`) Same topic in several pages: 4 backlogs (`ideas`, `survival-ideas`, `playtest-todo`,
  `pixel-plains-art-todo`); 2 ground-tile pages; 4 art-pipeline pages (some for removed routes).
- `.claude/memory/` is 22 KB, about 3x its own size limit, and repeats `CLAUDE.md`.

### C. Giant files (HIGH for map, MED for the rest)

| File | Lines | Mixed jobs | Split into |
|---|---|---|---|
| `scripts/map/map_gen.gd` | 2,877 | island, biomes (1,650 lines alone), deco, ground | one file per stage |
| `scripts/map/arena_map.gd` | 2,018 | map queries, chunk building, F3 code | state, chunk build, debug part |
| `scripts/ui/craft_window.gd` | 1,034 | layout, look, recipe logic | view + recipe logic |
| `scripts/debug/f3/dock.gd` | 1,006 | state, pins, drawing, input | state + drawing |

Example of the cost: to change one biome rule, a model must load 2,877 lines. It often edits
the wrong part or adds a copy of something that already exists.

### D. Folders that do not say what is inside (MED)

- 10 loose scripts in `scripts/` root (`player.gd`, `boss.gd` while `scripts/boss/` exists, ...).
- `scenes/` does not mirror `scripts/` (stations split between `scenes/stations/` and `scenes/world/`).
- Debug code mixed into game code: `enemy_spawner.gd:63` looks up `../DebugOverlay` by name;
  F3 code sits inside `arena_map.gd`. About 26 game scripts mention F3 / debug.
- `scripts/demo/` and `scripts/map/test_yard.gd` sit next to shipped code.
- Same idea in two places: `scripts/brains/` vs `enemies/slime_brain.gd`; data classes spread
  over `items/`, `world/`, `weapons/`; one-file folders in `data/` (`ui`, `lights`, `smelting`, `day_night`).
- `tests/` is 124 files flat, no sub-folders.

### E. Repo is heavy with throw-away media (MED)

| Folder | Size | What it is |
|---|---|---|
| `docs/demo/` | 96 MB | Videos and screenshots for you, not docs |
| `tools/art_tests/` | 36 MB | Old experiments (`swing_styles/` alone 33 MB of mp4) |
| `docs/wiki/` | 13 MB | Mostly screenshots |
| `tools/` top level | 85 files | Many one-off `*_shots.gd` scripts, no list of real tools vs throw-away |

Git history is 170 MB. Every clone and every worktree pays for it.

### F. Small things (LOW)

- `run_tests.sh`: comment lists 2 known-red tests, but `KNOWN_RED=""`.
- Asset names mixed: `Idle-Sheet.png`, `idle.png`, `Idle_Down.aseprite`; spaces in pack names.
- `assets/game/map/temp/rocks_temp.png` - a "temp" file in shipped art.
- `.claude/eval-harness/` - finished model test, now noise.
- Decision 0068 is missing (0067 -> 0069).

## 4. Clean-up plan (one step at a time, game runs after each)

| # | Step | Risk | Size |
|---|---|---|---|
| 1 ✅ | Root `README.md` (what, run, test, code map) + `AGENTS.md` (rules for any model, incl. hook rules in plain words) | none | small |
| 2 ✅ | Slim `CLAUDE.md`: F3 table -> `docs/wiki/debug-keys.md`; model routing -> `.claude/` only; fix wrong facts | none | small |
| 3 ✅ | `docs/README.md` = full index; add `Status: superseded by NNNN` to old decisions; mark done plans; merge backlogs into one | none | medium |
| 4 | Move `docs/demo/`, big `tools/art_tests/` media out of git (Drive), delete one-off shot scripts into `tools/retired/` | low | small |
| 5 | Move 10 root scripts into folders (`player/`, `boss/`, `ui/`, `debug/`...) | low (paths in scenes) | medium |
| 6 | Pull debug code out of game code (one debug hook pattern) | medium | medium |
| 7 | Split `map_gen.gd`, then `arena_map.gd` (tests must stay green, same seed = same map) | medium | large |
| 8 | Split `craft_window.gd`, `f3/dock.gd`; group `tests/` by system | low | medium |

Done 2026-11-16: steps 1-3 (README, AGENTS.md, debug-keys page, decision status lines, wiki status lines, one `backlog.md`, decision 0041 restored - it was emptied by mistake in commit 5e5f93a).

Steps 1-4 change no game code. They help most, for the least risk. Do them first.

## 5. Art from the artist (Google Drive)

Ready now:

- Inbox: `assets/source/artist_inbox/` (Godot skips it). Its `README.md` has the steps.
- Pull: `tools/pull_artist_art.sh` copies only new / changed files from Drive. Never deletes.
- One-time setup: `sudo apt install rclone`, `rclone config` (remote `artist`, type `drive`),
  then set `DRIVE_FOLDER` in the script.
- Into the game: copy to `assets/game/<role>/` with a snake_case name; weapons via
  `tools/add_weapon.py`; run `tests/test_asset_rules.gd`.

To agree with the artist (stops naming mess at the source):

- Folder per role on Drive: `characters/`, `items/`, `map/`, `ui/`, `fx/`.
- Names: `snake_case`, no spaces, no `final_v2`. Example: `copper_pickaxe.png` + `copper_pickaxe.aseprite`.
- Animations: one sheet per action, `<name>_<action>.png` (`slime_idle.png`), frame size in the folder README.
- If files get big (many `.aseprite`), think about Git LFS before the repo grows more.
