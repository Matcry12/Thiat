# artist_inbox/ - art from the artist's Google Drive

A copy of the artist's Drive folder. Godot skips it (it is under `source/`, which has `.gdignore`).
Nothing in the game loads from here.

## Get new art

```bash
tools/pull_artist_art.sh          # copies only new / changed files from Drive
tools/pull_artist_art.sh --dry-run  # shows what would come, copies nothing
```

One-time setup: install rclone (`sudo apt install rclone`), then `rclone config` -> new remote
named `artist`, type `drive`, log in with the Google account that sees her folder. Put the folder
name in `DRIVE_FOLDER` at the top of the script.

The script never deletes here. If she removes a file on Drive, the old copy stays.

## Move a picture into the game

The inbox is the "as delivered" original. The game uses a copy:

1. Pick the role folder in `assets/game/` (`characters/`, `map/`, `ui/`, `fx/`, `stations/`, `world/`).
2. Copy the file there with a snake_case name (`copper_pickaxe.png`, not `Pickaxe FINAL v2.png`).
3. Weapons / tools: use `tools/add_weapon.py <inbox file> <id>` instead (it makes all the files).
4. Run `godot --headless --import`, then `tools/run_tests.sh tests/test_asset_rules.gd`.

Keep her sub-folders as she made them. Agree with her on one simple layout, for example
`<role>/<name>.png` (+ the `.aseprite` next to it).
- What each file is for and what is still missing: [docs/wiki/artist-art-status.md](../../../docs/wiki/artist-art-status.md).
