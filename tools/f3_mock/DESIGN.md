# F3 panel redesign (round 2)

Mock: `index.html` (1152x648, WASD moves the player; `Player.speed` is live). Shots: `shots.py` -> `shots/*.png`. Review: `REVIEW.md`.

## Problems (confirmed in `tuning_panel.gd`)
- ~40 buttons in a flat wall; 85+ sections / 400+ props in one 340 px list; no search, collapse, favourites.
- Clipped value labels; ranges from a 140-line dict + "0..4x current"; no typing. No Vector2 / Color.
- Status = one 20-block wall over the game and the HUD.
- Persistence unclear (Save/Load by hand vs Save rig). A feature = edit 3 places in a 1147-line file.

## Layout
```
+--------------------------------------------------+
| hotbar   [watch card: pinned status + N overrides]|
|                                          +-------+|
|                                          |search ||
|        GAME stays visible                |Tune|Act|Status|
|        (camera shifted by dock/2)        |*Pinned||
|                                          |Categ>Sec>rows|
| abilities / hp                           |footer ||
+--------------------------------------------------+
```
Dock 380 px, right, ~0.95 alpha. Outside the dock mouse and keys go to the game. Status leaves the screen: only blocks you "pin to game" stay, in a click-through card.

## Interactions
- **Search = command palette** (`/` focuses; never auto-focused). Matches actions, status blocks, settings. Name hits rank above section hits; a section name matches only as a whole word ("heal" does not pull `HealthBar`). Settings are live rows. Up/Down, Enter runs an action / opens a status block.
- **Tune**: `*Pinned` (always first; pinned actions + pinned rows, the 5 things you tune all day) > Category (accordion) > Section (sticky header) > `@export_group` > row. Section badges: `.tres`, rebuild mark (section only), orange dot + count.
- **Row** `name | number | slider | reset | pin`. Number is a real field (Enter commits, Esc cancels, Up/Down steps). Drag the name to scrub (Shift fine, Ctrl coarse). Vector2 = two fields, each with a `<->x` / `<->y` scrub handle. Color = swatch + hex (Godot: `ColorPickerButton`). Rows without `@export_range` have no slider (number + scrub only).
- **Heavy rows** (map/biome): slider applies on release; number field applies on Enter / focus-out only (arrows just edit the text, amber). The banner draws one frame, then the rebuild runs (sync, frame freezes), then it shows "last rebuild 3.8 s" for 3 s.
- **Actions**: grouped buttons. Toggles show an `on/off` pill. Pin = attached star. `"danger"` actions (Kill player, Delete save, Restart, Clear overrides) are red and need a second click ("Sure?", 2 s). Optional arg input (Generate seed). `Face left / Face right` for tuning hands.
- **Status**: one live line per block, open for wrapped detail, `pin to game` chip (labelled, not an icon). Pinned blocks sort first.
- **F3 cycles**: full -> watch only (no dock, nothing blocks the game) -> off.

## Keys
`F3` cycle | `/` search | `Esc` leave field/search first | `W A S D` etc. go to the game unless a text field has focus (footer shows "typing: game keys paused"). Cut: Ctrl+Z, Ctrl+1..4, Ctrl+F (F = parry), dock swap, double-click reset.

## Persistence (footer, always visible)
`o 3 overrides   saved in tuning.cfg, re-applied each launch   [Write 3 to .tres] [Clear overrides]`
- Auto-save to `user://tuning.cfg` (`ConfigFile`: native Vector2/Color; section = debug_name, key = prop; pins + pinned-to-game list in the same file). No Save/Load buttons.
- Each override stores `value` and `base` (the .tres/scene value when saved). On start, if the current default != `base`, the override is **skipped** and counted as stale.
- Loud: startup toast "N F3 overrides applied - M stale skipped", permanent `o N F3 overrides` line in the watch card (visible with the dock closed), footer badge, `Clear overrides`.
- **Never applied in headless / test runs** (`DisplayServer.get_name()=="headless"`).
- **Write N to .tres**: load a fresh copy (`ResourceLoader.load(path,"",CACHE_MODE_IGNORE)`), set only the N changed props, `ResourceSaver.save` that copy, drop those keys from the cfg. Replaces `Save rig`. Resources with empty `resource_path` (duplicated / local_to_scene) are session-only: no badge, no Write.
- Footer says what an override can do: "3 can go to .tres, 1 scene-only (cfg; use copy)". Scene-node rows get a copy button (`DisplayServer.clipboard_set("prop = value")`) to paste into the .tscn / script default.
- Stale overrides are named: footer `N stale` tooltip lists `key  cfg 6.2 / file 5.0`, click drops them; `Clear overrides` clears them too.
- Unknown cfg keys (renamed node) are listed in the footer tooltip, not silently dropped.

## Build requirements (Godot input; most important part)
1. **Pointer over the dock = no attack, no aim change, no wheel-to-hotbar.** `player.mouse_over_ui()` must also be true when the hovered control is inside the dock; keep the last aim while hovering (so you can still see the left-facing pose; `Face left/right` actions help).
2. Sliders `scrollable = false`; SpinBox/number fields take the wheel only while focused. Mouse wheel over the dock scrolls the list, never the hotbar.
3. Every dock Button / slider / toggle `focus_mode = FOCUS_NONE` (so Enter/Space never re-press `Kill player`). Only text fields take focus.
4. Esc order gains a first step: **F3 field/search focused -> leave field** (handled in `_input`, before the pause menu's `_unhandled_input`). Update CLAUDE.md section 7 Esc row.
5. Typing gate: `gui_get_focus_owner() is LineEdit` (SpinBox's inner field is a LineEdit). Never auto-focus search when F3 opens.
6. Scrub: Label `gui_input` + `Input.mouse_mode = MOUSE_MODE_CAPTURED` while dragging.
7. Camera offset by `dock_width / 2` while the dock is open (`right_panel_width()` exists), eased.
8. Build rows lazily (only expanded sections / search results, cap ~60); update status text only for open or pinned blocks, not all 20 every frame. Heavy rebuild: show banner, `await process_frame`, rebuild.
9. Tooltip (`tooltip_text`) on every name: full key, range, source file.
10. Status text `autowrap_mode = WORD_SMART`; dock background fully opaque (alpha 1.0) so game art never bleeds through rows. Scroll-to-row leaves room for the sticky headers (`scroll-padding`). Name column takes the spare width (slider ~80 px); status providers: one fact per line, max 48 chars.
11. Toast: top-centre of the game area (left of the dock), 4 s, mouse passes through, never over the boss bar.
12. **Test `tests/test_f3_input.gd` (headless, part of the build slice):** send a mouse press + a wheel event inside the dock; assert no attack started, hotbar slot and aim unchanged, no slider value changed; assert every dock `Button`/`Range` has `focus_mode == FOCUS_NONE`. Requirements 1-3 cannot be seen in a mock, so this test is their only proof.

## Extension contract
A feature adds one group membership and optional methods on its own node; the panel file does not change.
```gdscript
func _ready(): add_to_group("debug")           # 1. @exports reflected automatically
func debug_name() -> String: return "Boss"      # 2. stable persistence key (set it explicitly if saved)
func debug_category() -> String: return "Boss"  # 3. optional, default "Misc"
func debug_actions() -> Array:                  # 4. optional buttons
    return [{"label":"Heal boss","run":heal}, {"label":"Boss passive","toggle":func(): return passive,"run":tog},
            {"label":"Restart","danger":true,"run":r}, {"label":"Generate seed","arg":"int","run":func(v): ...}]
func status_text() -> String: return "idle hp %d" % hp   # 5. optional; already exists on 14 scripts
func debug_children() -> Array: return [{"name":"Biome Forest","object":res}]   # 6. optional: resources / many-instance things
func debug_heavy(prop) -> bool: return true     # 7. optional (replaces _is_heavy)
```
- **Rescan** `get_tree().get_nodes_in_group("debug")` every time the dock opens (no `node_added`: it fires before `_ready`, so before the group join).
- **Only one-per-world nodes join `debug`.** Many-instance things (resource nodes, furnaces, Knockback) are listed by their owner via `debug_children()`.
- Ranges: `@export_range(min,max,step)`; no hint = no slider. One-time sweep `range_overrides` -> `@export_range`, then delete the dict.
- Cross-node actions (Restart, Go to boss, Kill player) live on the arena root (category "Run"), not "Misc". Migrate the 8 status blocks and ~15 actions that sit inside `tuning_panel.gd` to their owners.

Rejected: autoload `Debug.register()` (ready-order, global); descriptor `.tres` per feature (second file to sync); central range dict / name-prefix heavy lists (rot); custom tree widget (use `FoldableContainer` + VBox); JSON (no Vector2/Color); undo stack (per-row reset + Clear overrides); Pins as a tab (folded into Tune); separate palette (search is one); per-row heavy icon (section badge only).
