# 0040 — Game frame: title, pause, settings (W8)

**Status:** Partly superseded by [0043](0043-ui-island-workshop.md) (placeholder look)

Implements [v1-design §9](../wiki/v1-design.md) (save / load is W9, win screen is W7).

## Context
The game booted straight into the arena. There was no way to pause, change volume or shake, or quit cleanly.

## Decision
- **Boot scene = `scenes/title.tscn`**: Play (new run, new random seed: `ArenaMap.retry_seed = 0`, then load the arena),
  Continue (greyed until W9), Settings, Quit. Tests and tools still load `arena.tscn` directly.
- **`MenuScreen`** is the one menu page (title, button list, settings swap-in). Title and pause menu both use it.
  Placeholder look, every size / colour an `@export` (CLAUDE.md §5).
- **Pause = `Esc`** (new `pause` action). `PauseMenu` (in the arena, `process_mode = ALWAYS`) sets `get_tree().paused`.
  Esc order: settings page -> back; open bag / crafting window -> close it, no pause; F3 text box focused -> leave it; else pause / resume.
  Menu: Resume, Settings, Quit to title (also resets `Engine.time_scale`).
- **`SettingsPanel`** (shared): master volume, screen shake, fullscreen. `GameSettings` saves them to `user://settings.cfg`
  (ConfigFile), loads once on boot, and applies them: volume -> master bus, shake -> `HitFx.shake.shake_strength`, fullscreen -> window mode.
- F3 `[Frame]` status: paused / page, volume, shake, fullscreen, file state.

## Why
One menu component and one settings owner keep title and pause identical and make a real skin a swap.
Shake maps to the existing `shake_strength` (0 = off), so F3 and the player's setting are the same number.

## Consequences
- An arena started directly applies the saved settings too (so a saved shake of 0 silences shake in tests that load the arena).
- The F3 panel and world freeze while paused (the tree is paused); they work again on resume.
- W9 enables Continue; W7 changes the win flow (the win screen can reuse `MenuScreen`).
