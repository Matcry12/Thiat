# BossFight

Top-down 2D action game in **Godot 4.7** (GDScript). A 20-30 minute run on a seeded island:
wake at home, chop trees, mine rocks, fight slimes, craft gear, then beat the boss.

AI models: read [AGENTS.md](AGENTS.md) for the rules. Known problems and clean-up plan:
[docs/wiki/project-status.md](docs/wiki/project-status.md).

## Run

```bash
godot -e .        # open the editor (F5 = play)
godot .           # play
```

Title screen -> `Test yard` (dev builds) gives a tiny map with every tree, rock, station and enemy.
Debug keys in game: `F1` shapes, `F2` slow motion, `F3` tuning dock. Full list: [docs/wiki/debug-keys.md](docs/wiki/debug-keys.md).

## Test

```bash
tools/run_tests.sh --changed        # quick: tests for changed files + smoke test
tools/run_tests.sh tests/test_x.gd  # one test
tools/run_tests.sh                  # full suite, once before commit
```

Failures: `.godot/test_logs/last.txt`. How tests work: [docs/wiki/testing-algorithm.md](docs/wiki/testing-algorithm.md).

## Where things are

| Folder | What |
|---|---|
| `scenes/` | Godot scenes. Main scene: `scenes/title.tscn`, game: `scenes/arena.tscn` |
| `scripts/map/` | World generation, chunk loading, biomes, ground art |
| `scripts/components/` | Reusable parts: health, hitbox / hurtbox, inventory, crafter, guard, dodge |
| `scripts/weapons/`, `scripts/skills/` | Weapon and skill behaviour |
| `scripts/boss/`, `scripts/brains/`, `scripts/enemies/` | Boss attacks, AI brains, slimes + spawner |
| `scripts/visual/`, `scripts/fx/` | How things are drawn; hit effects. Game code never draws |
| `scripts/ui/` | HUD, menus, end screen, bag, crafting book, settings |
| `scripts/world/` | Arena, save game, pickups, trees / rocks, stations, day / night, lights |
| `scripts/debug/` | F1 overlay, F3 dock (dev only) |
| `scripts/items/`, `scripts/audio/`, `scripts/settings/` | Item data classes, sound board, player settings |
| `scripts/demo/` | Old character demos (dev only) |
| `scripts/player/` | `player.gd` (the player root script) |
| `data/` | All numbers and content as `.tres`: weapons, items, recipes, biomes, enemies, sounds |
| `assets/` | Art and sound. `game/` ships, `dev/` test only, `source/` originals, `retired/` unused. Rules: [assets/README.md](assets/README.md) |
| `tests/` | `test_<topic>.gd`, helpers in `tests/support/` |
| `tools/` | Test runner, art + asset scripts (`add_weapon.py`, `pull_artist_art.sh`), screenshot scripts |
| `docs/` | Index: [docs/README.md](docs/README.md) |

## Docs

| Where | What |
|---|---|
| [docs/wiki/design-pillars.md](docs/wiki/design-pillars.md), [v1-design.md](docs/wiki/v1-design.md) | What the game should be |
| `docs/decision/NNNN-*.md` | Why things are built this way. A newer record can replace an older one |
| `docs/wiki/*-algorithm.md` | How a system works (spawning, sound, day / night, ground tiles...) |
| [docs/design/DESIGN.md](docs/design/DESIGN.md) | UI style |
| `docs/reference/` | Outside research, Godot notes |

## Art from the artist

New art arrives in `assets/source/artist_inbox/` via `tools/pull_artist_art.sh` (Google Drive).
Steps: [assets/source/artist_inbox/README.md](assets/source/artist_inbox/README.md).
