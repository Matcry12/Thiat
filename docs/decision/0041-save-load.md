# 0041 — Save / load (W9)

**Status:** Partly superseded by [0042](0042-death-drops.md) (death bags -> saved pickups)

Implements [v1-design §9](../wiki/v1-design.md). One slot.

## Context
A run is 20-30 minutes of gathering and crafting. Quitting must not lose it.

## Decision
- One file `user://save.json`, plain JSON with a `version` (now 1). `SaveGame` (node in the arena) owns it.
- **The island is not stored.** Stored: the seed, the `ArenaMap` exports that differ from the scene (F3 tuning), and what
  changed on it: gathered nodes (placement index into `MapGen.Result.obstacles`, which is stable for a seed + settings and
  does not depend on loaded chunks; plus the obstacle count as a sanity check), placed stations (furnaces with input / progress /
  output), death bags, the 36 inventory slots + cursor stack + selected slot, player position + HP, deaths, play time, boss defeated.
- **When:** autosave every `autosave_interval` (60 s, 0 = off), pause -> Save & quit, window close request. Refused while the player
  is dead, the boss is engaged, or under a test run (`BOSSFIGHT_TEST_SEED`). Written to `save.json.tmp`, then renamed.
- **Continue** (title) is enabled only when `read_save()` finds a valid file. It sets `ArenaMap.retry_seed` + `pending_settings`, loads the
  arena, and `SaveGame.apply()` puts the changes back. Play = a new run; the old save is overwritten by the first autosave / quit.
- Missing, corrupt, wrong-version or incomplete file: Continue disabled, a `push_warning`, never a crash.

## Why
Seed + diff keeps the file small and tied to the one world generator. Placement indices already existed for chunk streaming
(`ChunkStreamer.broken`), so unloaded chunks need no special case.

## Consequences
- Changing world generation or tree / rock data makes old saves' gathered nodes wrong: bump `VERSION` (or the obstacle-count check skips them with a warning).
- Not saved: loose pickups on the ground, boss HP (it is always reset and idle when saving), F3-only tuning of biome / ground resources.
- Loading a save whose boss was defeated shows the "Boss defeated" end screen again (W7 changes the win flow).
- The settings file (0040) stays separate.
