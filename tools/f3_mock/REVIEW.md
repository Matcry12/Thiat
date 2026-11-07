# F3 panel redesign - review

Reviewer: fresh eyes, studio dev-tools lens. Inputs: `DESIGN.md`, `index.html`, `shots/1..9`, `f3_before.png`,
`scripts/debug/tuning_panel.gd`, `scripts/player.gd`, `project.godot` input map.

Verdict: **right direction, ship after fixes.** The big moves are correct (status off the game, search first,
one dock, footer that says what is saved). The real risks are not in the pictures: Godot input leaks
(clicks swing the sword, sliders eat the mouse wheel), and a silent `tuning.json` that will make
"I changed the .tres and nothing happened" the #1 bug report.

Before (`f3_before.png`): **2/10**. 40 buttons + a status wall over half the game; nothing findable.

## 1. Scores per state

| # | State | Score | Why (concrete) |
|---|---|---|---|
| 1 | Tune default | 7 | Calm, game visible. But 3 clicks deep before any value (Category > Section > row), and "Player > Player" is a stutter. The dock is see-through: the sand/water stripe at x~1080 runs through every row like a fake scrollbar. |
| 2 | Tune BodyRig | 7 | Rows are good: number + slider + changed dot + reset. Vector2 rows (`hand_nudge`, `hand_idle_front`, `body_position`) have no slider and no visible scrub hint - and these are the values the user tunes most (hand positions). |
| 3 | Search "hand" | 7 | Best flow in the mock: type 4 letters, edit in place. Bugs: Vector2 rows overflow - the reset arrow is cut and the pin star is gone (`hand_idle_front`, `hand_idle_back`). Hint line wraps to 2 lines. |
| 4 | Search "heal" | 7 | Actions first, Enter runs: correct. Noise: 3 `HealthBar` settings match because the section name contains "heal". Rank section-name matches below name matches, or only match section names on whole words. |
| 5 | Actions | 7 | Grouped, readable. Problems: `Kill player`, `Delete save`, `Restart` look the same as `Heal player` (one stray click loses a run / the save). Toggle dots are tiny and grey/green is hard to read. Pin star sits on the button corner and covers text. `Restart` under Boss is the wrong home. |
| 6 | Status | 6 | One-line summaries are a big win. But expanded blocks are a wall again and the `Player` block clips horizontally (`hand r 4.`). The eye icon does not say "float on game"; most users will not find the watch card. |
| 7 | Pins | 6 | 70% empty dock. `hand_idle_front` row clipped again. Fine as a concept, but a whole tab for 5 rows is heavy. |
| 8 | Map heavy | 7 | Rebuild banner is the right idea. But the heavy icon on almost every row is noise (mark the section, not 20 rows). `biome_smooth_pas...` truncated. In the real game a sync rebuild freezes the frame, so the "3.8 s" progress bar cannot animate - it can only show before/after. |
| 9 | Watch only | 8 | Clean, game fully playable, 3 useful lines. Missing: no sign that `tuning.json` overrides are active (see hole H6). |

Average of the new states: **6.9** -> "improve", not "remake".

## 2. Usability holes a dev hits in the first 5 minutes

Checked against the real code, not only the mock.

- **H1 - Clicking the dock swings the sword.** `player.gd` polls `Input.is_action_just_pressed("attack")`.
  `mouse_over_ui()` (line 206) only returns true while the **bag** is open. So every slider drag in F3 is
  also an attack (and with `hold_to_gather`, a continuous gather). The design says "everything outside the
  dock passes to the game" but never says the inside must NOT. Fix in the contract: `mouse_over_ui()` must
  also be true when the hovered control is inside the dock.
- **H2 - Aim follows the mouse into the dock.** Tuning `hand_idle_front` vs `hand_idle_back` needs the body to
  face left and right. With the dock on the right, the mouse is always right of the player, so the body
  always faces right. You can never see the left-facing pose while you drag. Needs an "aim lock" while the
  pointer is over the dock (keep last aim), plus a `Face left / right` action.
- **H3 - Mouse wheel.** Godot `HSlider` and `SpinBox` change value on wheel by default. Scrolling the list
  with the wheel will silently change whatever slider passes under the cursor. Also the wheel is the hotbar
  selector (`player.gd`), so scrolling the dock may also switch weapons. Set `scrollable = false` on sliders,
  ignore wheel on SpinBox unless focused, and block wheel -> hotbar while hovering the dock.
- **H4 - Focus stealing.** Godot buttons take focus on click (`focus_mode = ALL`). After clicking
  `Kill player`, Enter/Space re-presses it. Every dock button and slider: `focus_mode = FOCUS_NONE`. Only text
  fields take focus.
- **H5 - Key conflicts.**
  - `Ctrl+1..4` (tabs): the hotbar polls `slot_1..9` with non-exact matching, so Ctrl+1 also selects slot 1. Cut it.
  - `Ctrl+F` (search): `F` is `parry`. Ctrl+F will raise the guard. Keep only `/`.
  - `Esc`: the pause menu uses `_unhandled_input`. The panel must eat Esc in `_input` while a field has focus,
    and the CLAUDE.md Esc order must gain a step: "F3 field/search focused -> leave field".
  - Do NOT auto-focus the search box when F3 opens, or the first `W` goes into the box and the player stops.
  - Typing gate is `gui_get_focus_owner() is LineEdit` - SpinBox's inner field is a LineEdit, so that part works.
- **H6 - `tuning.json` silently overriding `.tres` on next launch: yes, confusing.** Scenario: you tune
  `hand_radius` to 6.2 (auto-saved). Next day you open `tiny_soldier.tres` in the editor and set 5.0. You launch:
  the game shows 6.2. Nothing tells you why. Also: headless tests and `--check-only` boots on this machine load
  the same `user://` file, so test results depend on yesterday's tuning. Fixes:
  1. Store the base value next to each override (`{value, base}`). On start, if the file/scene default != base,
     **skip** that override and list it as "stale (file changed)".
  2. On start, if any override was applied: a 4 s toast "7 F3 overrides applied (tuning.json)" AND a permanent
     `o 7` badge in the watch card (visible even with the dock closed).
  3. Never auto-apply in headless / test runs (`DisplayServer.get_name() == "headless"` or a test flag).
- **H7 - Write to .tres writes more than it says.** `ResourceSaver.save(r, path)` (today's `Save rig`) writes the
  whole live resource, including runtime-only fields (`BodyRig.save_note` today) and any value you did not
  choose. "Write 2 to .tres" must: load a fresh copy (`ResourceLoader.load(path, "", CACHE_MODE_IGNORE)`), set only
  the N changed props, save that copy, then drop those keys from `tuning.json`.
- **H8 - `.tres` detection via `resource_path` misses duplicated resources.** Weapons/rigs that are
  `duplicate()`d or `local_to_scene` have an empty `resource_path` -> no badge, no Write. Either the owner exposes
  the source path, or the doc must say "duplicated resources are session-only".
- **H9 - Heavy props on Enter / Up-Down.** "Applies on release" covers sliders. The number field: every Up/Down
  step on `land_share` = one 3.8 s rebuild. Heavy rows apply on Enter or focus-out only; arrow steps just edit
  the text.
- **H10 - Rebuild feedback in Godot.** If the rebuild is synchronous, the banner never draws. Show the banner,
  `await get_tree().process_frame`, then rebuild, then show "last rebuild 3.8 s" for 3 s.
- **H11 - Double-click name = reset** sits on the same handle as drag-to-scrub. A quick click-click while trying
  to nudge resets the value. The reset arrow already exists. Cut the double-click.
- **H12 - Translucent dock.** Game art bleeds through the list (trees at y~490, the coast stripe). Make the dock
  background ~0.94 alpha.

## 3. Extension contract

Mostly good and minimal: one group + optional duck-typed methods, no autoload, no registry file. That is the
right size. `status_text()` already exists on 14 scripts, so the convention is real, not invented. Issues:

- **`node_added` will miss nodes.** It fires when a node enters the tree, which is **before** its `_ready()`.
  The design puts `add_to_group("debug")` in `_ready()`, so the signal arrives before the node is in the group.
  Simpler and correct: rescan `get_tree().get_nodes_in_group("debug")` each time the dock opens (and on a
  `tree_exiting` of a listed node). No `node_added` listener at all. On a 512x512 chunk map it would also fire
  for thousands of props.
- **Multi-instance nodes need a rule.** `resource_node.gd` (thousands), `furnace.gd` (N), `knockback.gd` (one per
  actor) all have `status_text()`. If someone adds them to `debug`, the panel gets hundreds of sections. Rule:
  only one-per-world nodes join `debug`; many-instance things are listed by their owner via `debug_children()`
  (today's `_knockback_status_text` / furnace list pattern).
- **Resources can't join groups** - `debug_children()` covers it. Good. Category is inherited from the parent.
- **Keys must be stable.** `tuning.json` keys = `debug_name() + "." + prop`. Default `debug_name()` = node name is
  fragile (renaming a node orphans the saved key silently). Show orphaned keys in the footer ("2 unknown keys").
- **Ranges: `@export_range` hint is right, but the migration is the work.** Today 19 `@export_range` vs 1124
  `@export`, plus a 140-line `range_overrides`. "No hint -> soft range from current value" breaks at 0 (range
  0..0) and lies. Ponytail: **no hint -> no slider**, number field + scrub only. Convert `range_overrides` to
  `@export_range` once (mechanical sweep), then delete the dict.
- **Persistence format: use `ConfigFile`, not JSON.** JSON can't hold `Vector2`/`Color` (the mock adds both).
  `ConfigFile` stores native Variants, section = target, key = prop, human-readable. Also kills the custom
  `save_value()` hack. Pins and watched blocks go in the same file.
- **`debug_actions()` dict shape** is fine. Add one optional key: `"danger": true` (red style + hold-to-confirm or
  confirm pop) for Kill / Delete save / Restart.
- **Migration reality:** 8 status blocks and ~15 actions are written **inside** `tuning_panel.gd` today
  (`_gather_status_text`, `_inventory_status_text`, `_crafting_status_text`, `_give`, `_fill_bag`,
  `_break_nearest_node`, ...). They must move to their owners. Cross-node actions (`Restart`, `Go to boss`,
  `Kill player`) need one named home (the arena root), not "Misc".
- **Build cost:** 400 rows x (label + SpinBox + slider + 2 buttons) = ~2500 Controls. Build rows only when a
  section is expanded or a search shows them (cap search at ~60 rows). Update status text only for expanded
  or watched blocks, not all 20 every frame (today it formats all every frame).
- **Godot fit:** all doable in 4.7 GDScript. `get_property_list()` gives `hint` + `hint_string`
  ("min,max,step[,or_greater]") and `PROPERTY_USAGE_GROUP`/`SUBGROUP` entries in order. `FoldableContainer` exists.
  Vector2 = 2 SpinBox, Color = `ColorPickerButton` (don't hand-roll hex). Scrub = Label `gui_input` +
  `Input.mouse_mode = CAPTURED` while dragging (otherwise the cursor hits the screen edge).

Over-engineered / cut for v1:
- `Ctrl+Z` undo stack: per-row reset + Revert all cover it. Add later if asked.
- `Ctrl+1..4` tab keys: conflicts (H5), mouse is enough.
- Left/right dock swap button: no stated pain. Cut, or keep only if the camera offset (below) is not done.
- Pins as its own tab: fold pins into the top of Tune ("Pinned" pseudo-section, always first). One tab less.
- Per-row heavy icon: mark the section header only; show "applies on release" only while dragging.

Missing (cheap, real pain):
- **Camera offset**: with a 380 px dock, the player is not centred in the visible game area. Shift the camera
  by `dock_width / 2` while the dock is open (`right_panel_width()` already exists).
- Long names: tooltip with full name + range + file on hover (mock has it; keep it in Godot via `tooltip_text`).

## 4. Ranked fix list (exact changes)

1. **Block game input under the dock.** Design: "Pointer over the dock = no attack, no aim change, no wheel-to-
   hotbar." Implement via `player.mouse_over_ui()` returning true when the hovered control is inside the dock;
   keep last aim while hovering. (H1, H2, H3)
2. **Kill wheel + focus traps.** All dock sliders `scrollable = false`; all buttons/sliders `focus_mode = FOCUS_NONE`;
   SpinBox takes wheel only while focused. Add to DESIGN "Keys" as a rule. (H3, H4)
3. **Make overrides loud and safe.** Store `{value, base}`; skip + flag stale overrides when the file default
   changed; start-up toast "N F3 overrides applied"; `o N` badge in the watch card; no auto-apply in headless/tests.
   Footer gets `[Clear overrides]` next to Revert all. (H6)
4. **Write-to-.tres writes only the listed props** to a fresh `CACHE_MODE_IGNORE` copy, then removes them from the
   overrides file. Replace the current `Save rig` code path. (H7)
5. **Fix key map:** drop `Ctrl+1..4`, drop `Ctrl+F`, keep `/`. Never auto-focus search on open. Esc in `_input`
   while a field is focused; add that step to the CLAUDE.md Esc order. (H5)
6. **Vector2 rows:** give each axis a scrub handle with a visible `<>` cursor/hint, and fix the overflow in
   search/pins (name column shrinks with ellipsis, reset + pin always visible). Add `Face left` / `Face right`
   actions next to BodyRig. (shots 2, 3, 7)
7. **Contract: replace `node_added` with rescan-on-open**; add the "one-per-world nodes only, many-instance via
   `debug_children()`" rule; default `debug_name()` must be set explicitly for anything that persists.
8. **Ranges: no hint -> no slider.** Delete "soft range from current value". One-time sweep `range_overrides` ->
   `@export_range`, then delete the dict.
9. **Persistence = `ConfigFile`** (`user://tuning.cfg`), native Vector2/Color, pins + watch list in the same file.
   Drop `save_value()`.
10. **Danger actions:** `"danger": true` in `debug_actions()`; red outline + confirm for Kill player, Delete save,
    Restart, Revert all. Move `Restart` to a `Run` group with `Save now` / `Load save`.
11. **Heavy props:** heavy mark on the section header only; number field applies on Enter / focus-out only;
    banner draws one frame before a sync rebuild and then shows "last rebuild 3.8 s". (H9, H10)
12. **Visual polish:** dock alpha ~0.94 (no bleed); wrap status text (`autowrap_mode = WORD_SMART`); rename the eye
    icon to a labelled `pin to game` toggle; fold Pins into the top of Tune; search ranks name hits above
    section-name hits; camera offset by half the dock width; cut double-click reset and `Ctrl+Z`.

---

## Round 2

Inputs: the updated `DESIGN.md` (round 2, with the "Build requirements" list), `index.html`, `shots/1..9` (new names).

### Scores

| # | State | R1 | R2 | Why |
|---|---|---|---|---|
| 1 | Tune default | 7 | 8 | `Pinned` comes first with actions and rows; `Character` replaces "Player > Player"; the override badge and the footer are clear. The bleed stripe is still there (see F1). |
| 2 | Tune BodyRig | 7 | 8 | Vector2 rows now have `<->x` / `<->y` scrub handles, and reset + pin are always visible. |
| 3 | Pinned + categories | 6 | 8 | Folding Pins into Tune was right. The whole tree fits on one screen, and change dots show per category. |
| 4 | Search "hand" | 7 | 8 | No overflow any more. Names are cut with "..." (`hand_idle_fr...`), which is OK because the tooltip shows the full name. |
| 5 | Search "heal" | 7 | 9 | HealthBar noise is gone. Actions come first and Enter runs. |
| 6 | Actions | 7 | 8 | `Kill player` is red, toggles have an on/off pill, the pin star is attached to the button, and Face left/right were added. The seed field still reads as a label (F7). |
| 7 | Status | 6 | 8 | The labelled `pin to game` / `on game` chip is clear, and text now wraps. Pinned blocks are marked with a side bar. |
| 8 | Map heavy | 7 | 7 | The rebuild mark is now on the section only, and the banner says "last rebuild 3.8 s". Two problems: the sticky header covers the `CHUNKS` sub-heading, and `biome_smooth_pas...` is still cut off. Also, 4 overrides but "Write 3 to .tres", with nothing saying why (F2). |
| 9 | Watch only | 8 | 9 | The camera is centred again and `4 F3 overrides` stays visible with the dock closed. |

Average **8.1**, so "done" for the mockup.

### Did the round-1 fixes land?

| R1 fix | Status |
|---|---|
| 1 Block game input under the dock | In DESIGN as build requirement 1. A browser mock cannot show it, so it needs a test (F8). |
| 2 Wheel / focus traps | Build requirements 2-3. Same as above: needs a test. |
| 3 Loud, safe overrides | Landed: `{value, base}`, stale overrides skipped, toast, watch-card badge, `Clear overrides`, nothing applied in headless runs. Gap: which override went stale is not shown anywhere (F3). |
| 4 Write only the listed props | Landed: fresh copy loaded with `CACHE_MODE_IGNORE`, then the keys are dropped from the cfg. |
| 5 Key map | Landed: only `/` is left, search is never auto-focused, and Esc leaves the field first. |
| 6 Vector2 rows + Face left/right | Landed. |
| 7 Rescan on open, one-per-world rule, explicit `debug_name` | Landed. |
| 8 No hint = no slider | Landed. The DESIGN mentions the one-time sweep. |
| 9 ConfigFile | Landed. |
| 10 Danger actions | Landed: red style + "Sure? click again" for 2 s. Restart moved to the "Run" category. |
| 11 Heavy rows | Landed. |
| 12 Polish | Mostly landed. **Bleed not fixed:** at 0.95 alpha the sand/water stripe at x~1080 still runs down every row in every shot, and a tree shadow shows at y~490 in shots 3-5. |

### Remaining fixes (ranked)

1. **F1 Opaque dock.** Set the dock background to alpha 1.0 (`rgba(15,17,22,1)`, `StyleBoxFlat.bg_color.a = 1`). At 0.95 you still see the game through the rows. The game is already visible left of the dock.
2. **F2 Explain overrides that cannot go into a .tres.** Footer text: "4 overrides: 3 can be written to .tres, 1 is kept in the cfg only (scene node)". On scene-node rows (for example `Map.land_share`), add a `copy` button that puts `land_share = 0.55` on the clipboard (`DisplayServer.clipboard_set`), so the value can be pasted into the `.tscn` or into the script default. Without this, scene-node overrides stay in the cfg forever.
3. **F3 Show which override went stale.** The toast says "1 stale skipped", but nothing names it. In the footer tooltip, list each stale key as `name  cfg 6.2 / file 5.0  [drop]`. `Clear overrides` also clears the stale ones.
4. **F4 Move the toast.** Today it sits bottom-centre: that is where the boss bar goes, and it overlaps the dock edge by about 6 px. Put it top-centre under the watch card, inside the game area (`x < 1152 - dock_width`). It shows for 4 s and lets the mouse pass through.
5. **F5 Sticky header must not cover content.** When a section header sticks, the list below starts under it (pad by the header height). The `CHUNKS` sub-heading in shot 8 is cut today.
6. **F6 Name column width.** In Tune rows, make the slider about 80 px instead of about 108 px and give the name column the rest, so `biome_smooth_passes` fits. Status providers keep one fact per line, at most 48 characters: `rig ... hand r` + `4.5` wraps in the middle of a value pair today.
7. **F7 The seed arg must look like a field.** Give it a border, the placeholder `seed`, and the same height as the button next to it. Today `1-9999` in grey reads as a label.
8. **F8 Prove the build requirements with one test.** Add `tests/test_f3_input.gd` (headless). It sends a mouse press and a wheel event at a point inside the dock, then asserts: no attack started, hotbar slot unchanged, aim unchanged, no slider value changed. It also asserts that every dock `Button`/`Range` has `focus_mode == FOCUS_NONE`. Requirements 1-3 cannot be seen in a mockup, so this test is the only proof they were built.

Verdict round 2: **mockup approved (8.1).** Fix F1-F7 in the mockup or during the build. F8 is part of the build slice, not optional.
