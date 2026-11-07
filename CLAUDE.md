# CLAUDE.md — Operating Plan

This file is the **plan**. Read it, follow it, every task.

## 1. Spawn an agent, or do it yourself?

Before starting any task, ask this **first**:

> Should this be delegated to an agent, or done inline?

- **Delegate** (spawn a subagent on the *lowest capable model*) when the work is:
  multi-file, repetitive, a search sweep, a refactor, drafting, or anything that
  would dump lots of output into this context. Keep only the *conclusion* here.
  - `haiku` — lookups, mechanical edits, per-item classification, bulk work.
  - `sonnet` — standard implementation, drafts, refactors, multi-file edits.
  - `opus` — planning, architecture, review/critique only. **Not the doer.**
- **Do it yourself** only for: trivial single edits, one command, a quick answer,
  a small change (rule 2.4), or config in `.claude/**` / `CLAUDE.md` / `docs/**`.

Default bias: **delegate the doing, keep the deciding.**

**Which model for which job** ([0017](docs/decision/0017-model-routing.md)). In this project
`sonnet` = **Sonnet 5.5** (set in `.claude/settings.json`), `opus` = Opus 5.5.

| Job | Model | Why |
|---|---|---|
| Plan a slice, split it into tasks, decide design | Opus (main loop) | Deciding is where mistakes cost most |
| Design question, "what should this be?" | `design-panel` skill: 5 `design-*` Sonnet agents in parallel, Opus merges | The user is new to design; several views beat one ([0051](docs/decision/0051-agent-team.md)) |
| Build a slice / feature, write tests, refactor | `godot-builder` (Sonnet 5.5), several in parallel by file (`build-slice` skill) | Normal coding; tested and judged after |
| Judge Sonnet's work (rule 2.4) | `slice-judge` (Opus), fresh context, one per builder as it lands | A weak judge hides bugs; nobody sees them until playtest |
| Judge work Opus did itself | `slice-judge` with `model: sonnet` | Different eyes matter more than strength |
| Hard bug (flaky, timing, "can't reproduce") | Opus agent | Opus 5.5 was 2x faster on our debug test; both fixed it |
| Exact steps + an auto-check (`--check-only`, tests), text only: renames across files, same `@export` / F3 line in N scripts, test scaffolds from written cases, N items / recipes from a table, doc table updates | DeepSeek flash (`ds`, `deepseek:deepseek` skill; thinking is always on, `--effort` does nothing); fails twice -> Sonnet | ~1/50 of Sonnet's cost; Sonnet decides once, `ds` fills each row in parallel |
| Lookups, file sweeps, blind grading, mechanical edits with no check, anything with pictures | Haiku agent | Cheap and enough |
| Explain to the user | Opus (main loop) | It holds the conversation |

**Escalate, don't retry blind:** if a Sonnet agent fails the same task twice (tests red, or the
judge confirms a real bug twice), give that task to an Opus agent. Note it in the slice log.

**Slice log = the real-world score.** When a slice is done, add one line under that slice in
`docs/wiki/prototype-v0.md`: who built it, what the judge found, what the user found. After a few
slices this tells us where each model is weak — better data than a lab test.

## 2. Always verify before reporting

Never report a task as done on assumption. Before any "it works" claim:

1. Read the code that changed.
2. **Run it** if it can be run (build, test, execute, lint).
3. **Test the user's steps too.** If the report tells the user to set something in the editor, load
   the scene headless and confirm that value actually reaches the running game.
4. **Get a second judge**, unless the change is small: 1-3 code files, no new system, not save format,
   map generation or shared combat code ([0062](docs/decision/0062-test-levels-by-change-size.md)). A small
   change needs no builder and no judge: Quick tests, then report. After any bigger change, spawn a reviewer agent with **fresh context,
   on a different model than the one that did the work** (Opus wrote it → Sonnet judges; Sonnet
   wrote it → Opus judges). Give it the request, the diff, and this file. It judges: does the change
   do what was asked, does it break a rule here (one owner, build for replacement, test mode), and
   are there bugs the tests miss. Fix what it confirms; tell the user what it found — including
   "nothing".
5. Only then report — with the actual evidence (output, exit code, test result, judge verdict).

If it failed, say so plainly with the output. No hedging, no "should work".

## 3. Learn from mistakes — never repeat one

When the user points out a mistake:

1. Append it to `.claude/memory/mistakes.md` as a one-line rule (other topics: `preferences.md`, `godot-gotchas.md`).
2. All `.claude/memory/*.md` are auto-loaded every session (SessionStart hook), so past mistakes
   are always in front of you. Check it before acting.

## 4. Keep files tidy — never drop them loose

Before creating or saving any file, find the folder it belongs in. If none fits,
create a proper one first, then place it. **Root stays clean** — no stray files.

- `docs/wiki/` — durable knowledge, how-things-work notes.
- `docs/decision/` — decision records, `NNNN-<slug>.md`: Context / Decision / Why / Consequences. Write one whenever a choice changes how the project is built (the decision-detector hook reminds you).
- `docs/reference/` — external material (PDFs, playbooks, specs).

## 5. Build for replacement, never for the placeholder

Everything visible right now is placeholder — circles, capsules, wedges, ugly bars. **None of it
may be load-bearing.** Before writing any visual or content code, ask: *when this becomes a pixel
sprite / a real level / a real weapon, is this a swap or a rewrite?* If it is a rewrite, restructure
before continuing.

Concretely, every time:

- **Visuals live in their own node and nothing reaches inside.** Combat emits state
  (`state_changed`, `set_aim_angle`, `on_weapon_state`); the visual node decides what to draw.
  Replacing a `Polygon2D`/`_draw()` with an `AnimatedSprite2D` must touch **zero** combat code.
- **Every effect gets a slot, not a special case.** A swing, a hit flash, a telegraph is its own
  node driven by data + signals — so it can be swapped for a sprite, shader or trail later.
- **Timings and numbers live in data (`WeaponData` / `@export`), never in art.** When a real
  animation arrives, the art is stretched to fit the tuned timing — the timing is never changed to
  fit the art. `speed_scale = anim_length / data_duration`.
- **No number that affects feel is a hardcoded constant.** It is an `@export`, so it reaches the
  inspector and the F3 tuning panel.
- **Name things by role, not by shape.** `Visual`, `SwingArc`, `Telegraph` — never `WhiteCircle`,
  `RedRect`.
- Placeholder is a **stand-in with a defined interface**, not a prototype to be rewritten. Writing
  something that will have to be rebuilt from scratch when art arrives is the failure this rule exists
  to prevent.

## 6. How to talk to me (the user)

Write so it can be understood **without reading the code**.

- **English level B1, B2 at most.** Short sentences. Common words. One idea per sentence.
- **Always give an example.** Not "the visual layer lacks a contract" but "if you drop in a sprite,
  nothing tells you which functions it must have - like buying a plug without knowing which socket
  it fits."
- **Explain the problem before the solution.** What breaks, when it breaks, what the user would
  actually see on screen.
- **No jargon without a plain-words explanation right next to it.** "Y-sorting (which character is
  drawn in front when two overlap)".
- **Say what it means for the game**, not what it means for the code. "Two enemies will overlap
  wrong" beats "the draw order is undefined".
- Keep tables and short lists. Avoid long paragraphs.
- Code snippets only when the user asks for code, or when a file must be edited by hand.

If an explanation needs the user to understand the code to follow it, it is the wrong explanation -
rewrite it.

## 7. Test mode is part of every feature

Nothing is "done" until it can be **seen and changed while the game runs**. Test mode is not a
side tool — it ships with the feature, in the same slice.

Debug keys (keep this table current):

| Key | Shows |
|---|---|
| `F1` | Hitboxes, hurtboxes, attack phase, reach wedge, rock/tree collision circles (yellow), gather hurtbox circles (green), collector magnet + pickup circles around the player (cyan), loaded chunk borders (thin blue, 0038 step 2) |
| `F2` | Slow motion (0.25x) |
| `F3` | Cycles full -> watch only -> off. Full = the dock on the right (380 px, the camera slides left): search box (`/` focuses it, `Esc` leaves a field), tabs `Tune` (pinned rows, then category > section > `@export_group` > row; number field + slider + `↺` reset + pin; heavy map rows apply on release / Enter and show a "Rebuilding map…" / "last rebuild X.X s" banner), `Actions` (grouped buttons; red ones - Kill player, Delete save, Restart, Clear overrides - need a second click "Sure?" within 2 s), `Status` (one row per status block, open for detail, `pin to game`), and a footer: "● N overrides (K to .tres, S scene-only)", `Write K to .tres`, `Clear overrides`, a `N stale` button (tooltip lists them, click drops them). Every F3 edit is an override saved at once in `user://tuning.cfg` (value + base, re-applied at each start, skipped as stale if the file changed; never applied or kept in headless runs; toast "N F3 overrides applied - M stale skipped"); scene-only rows get a copy button (`prop = value`); `Write K to .tres` puts the changed values into a fresh copy of each resource file (replaces Save / Load / Reset / Save rig). Watch only = no dock, a click-through card top-centre with the pinned status blocks and "● N F3 overrides". The old top-left status wall is gone. Below: Map: seed box + `Generate`, `New map`. Boss status (idle/engaged/returning) + buttons: `Phase 2`, `-> slam/spread/charge/ring` (force that attack next, ignores cooldown + phase), `Boss passive` (stands still, no attacks), `Heal boss`, `Heal player`, `Restart`. Map: seed in status, `New map` button (new random seed), map sliders rebuild live. Hit feel: `[Hit FX]` status (trauma, hit-stop frames left, last hit type); sections `HitFx` (master + per-layer switches), `HitStop` (`hitstop_scale`), `CameraShake` (`shake_strength`, 0 = off), `HitSound`, one `Hit <type>` section per profile in `data/hit_fx/`; buttons `Test sword hit`, `Test parry`, `Test player hit`, `Test kill FX`, `Test boss hit`, `Test lunge`, `Test charged arrow`, `Test node hit`, `Test node pop` (nearest tree / rock / copper / station; stations too: wrong tool = wobble + knock, pickaxe = pop into the bag, profiles `station_knock_*` / `station_pickup_*`) (effects only, no HP change, no movement). Chop / break feel for trees, rocks, copper (0057; rocks: same reaction, grey chips, less sway, stone sounds; per-profile `sway_scale`, `leaf_scale`, `picture_chips`): section `NodeReaction` with groups `ChopSway` (sway_deg / sway_max_mult / freq / damping), `ChopDebris` (chips + leaves counts, speeds, pop height, bounce, life) and `TreePop` (pop_scale, pop_hold, burst counts), `HitFx.reaction_on`, per-profile `reaction` + `pitch_gain` (bigger hit = more sway, debris, pitch as HP falls; `Hit tree_break`); `[Gather]` status adds `reaction:` (last chop hp %, sway deg, chips, leaves) Slice 2: `HitFx` switches `recoil_on`/`sparks_on`/`numbers_on`; sections `HitSparks`, `DamageNumbers`, and the new per-hit fields (`knockback`, `recoil_px`, `spark_*`, `number_size`); `[Knockback (gameplay)]` status (last shove per actor), one `Knockback <Actor>` section each (`enabled`, `knockback_scale`, `resistance`, `decay_rate`), buttons `Knockback on/off` (movement only, separate from Hit FX) and `Dummy to spot`; sword/bow `step_distance` in their weapon sections. HUD (0030, supersedes the top-right placement of 0024): hotbar + bag top-left, ability icons (dodge / skill / guard) above the health bar bottom-left, boss bar bottom centre (only while the boss is awake: `BossBar.set_awake`); no words in the HUD, names and the HP number only in the hover tooltip. Sections `HUD` (margins), `HealthBar` (`trail_delay`, `trail_speed`, `low_threshold`), `Hotbar`, `InventorySkin` (sizes, fonts, tooltip, health / boss bar looks, placeholder colours); button `Hurt player 20`; while the dock is open the boss bar keeps clear of it and of the left blocks. The boss has no Knockback: it only jolts visually. F1 also draws the last knockback vector (orange, 0.6 s). Run juice: `Visual` section has a `Shadow` group (`shadow_on`, `shadow_min_scale`, `shadow_min_alpha`); new `RunDust` section (`dust_on`, counts, size, life, colour); `Visual` status line shows `shadow` scale + `dust` puffs alive; 3D body (0028): status adds `facing: front|side (flipped)` + hit time left, `Visual` section group `Directional body` (`front_half_angle_deg`, `facing_hysteresis_deg`, `landing_frames`, `lift_frames`, `hit_time_scale`, `flip_deadzone`, `directional_lift_px`). Per-character fit (0028): section `BodyRig` (`visual_scale`, `slash_scale`, `weapon_pivot_offset`, `shadow_scale`, `body_position`, `soft_edges` + `soft_edge_width` = turned weapon picture drawn with softened pixel edges, off = nearest; `WeaponVisual` status starts `soft: on|off`: weapon pictures, never hitboxes; no hands since 0048, section `HeldItem` = the icon of a material / placeable in the hand: `icon_scale`, `grip_offset`); footer `Write K to .tres` writes the live BodyRig back into its `data/body_rigs/*.tres` (kept after the game closes), and the `Visual` status keeps its `rig ...` line. Map section is grouped (`@export_group`: Layout / Chunks / Island / Water / Climate / Biomes / Vegetation / Looks, shown as `[ Group ]` sub-headings; heavy sliders rebuild on release) and the `World map` button toggles a ~400 px picture of the whole island left of the tuning panel (biome colours, river / lake / shallow / ocean blues, home white, boss red, you yellow; redraws after every rebuild). Water v2 (0038): `Map` Water group has `river_w_*`, `river_big_*`, `lake_big_*`, `lake_pond_*`, `lake_warp`, `lake_shape_period`, `lake_gap`. Island (W1, 0026): `Map` section has the island sliders (`island_on`, `island_*`, `coast_cells`, `home_clear_cells`, `corridor_half`, `home_offset_*`) and the climate ones (0038: `climate_*` periods / warp / lookup weights, `biome_smooth_passes`, `biome_min_blob`, `beach_min/max`, `cold_beach_t`, `home_calm_*`, `calm_*`, `forest_margin`, `boss_land_cells`; they rebuild the map) plus one `Biome <label>` section per biome (climate points, `temp_class`, `ground`, and since 0038 step 4 ALL vegetation, grouped `[ Trees ]` `[ Rocks ]` `[ Bushes ]` `[ Flowers ]` `[ Mushrooms and tufts ]` `[ Water edge and snow ]` `[ Ground mix ]`: tree table `tree1..6_model/season/weight`, `tree_tries`, `age_rule`, `max_stage`, rock groups, bush / flower / mushroom / tuft / reed / stump rates, `ground_alt`; these rebuild the map on drag end; `tint_*` and the map colour are live; data in `data/biomes/*.tres`); `[Map]` status shows the area + biome + temperature / humidity / roughness / f under the player, `biome % of land`, land %, rocks, deco, build ms; buttons `Go home`, `Go to boss`, `Biome map` (toggles a see-through colour per cell over the world, `biome_map_alpha`). Biomes + trees (0037, step 1): `Map` Vegetation group has `band_lo/hi`, `tree_fade_*`, `veg_density_period`, `rock_group_radius`, `fir_group_radius`, `age_*`/`core_old`/`mid_small`/`edge_*`, `clearing_*`, `tree_home_clear`, `trees_on`, `veg_on` (rebuild the map); `[Map]` status also shows trees per age; one `Node tree_<oak|fir>_<age>` section each (radius, hp). Map looks (0033): `smooth_passes`, `beach_cells`, `path_*`, `camp_radius`, `dirt_patch*`, `*_bright/_warm/_sat` per area, `shade_*`, `foam_*`, `shimmer_*`, `wave_strength` (tint / foam / shimmer are live, the rest rebuilds); status shows path cells + ground picture ms. Chunks (0038 step 2, map is 512x512 by default): `[Map]` status shows chunks loaded / total (+ queued), chunk build ms (last / avg / max; avg ground / props / nodes), nodes alive, deco alive, world-data ms; `Map` sliders `chunk_cells`, `load_radius`, `unload_margin`, `chunks_per_frame`. Water (0038 step 3): `Map` sliders `cont_*` / `land_share` / `neck_*` (island shape), `river_*`, `lake_*`, `shore_cells`, `shallow_min/max` (rebuild), `shallow_tint_*` (live shallow-water colour); `Biome <label>` sections get `shore_ground` and `fresh_pull_cells` + `fresh_*` (swamp near water); `[Map]` status line `water: river / lake / shallow cells`, biome name says river / lake / coast shallows; `Swimmer` (`water_speed_scale`) and `WaterFx` (band, ripple, splash numbers) sections, `[Player]` status line `in water: yes/no  speed x...`. Gathering (W2): `[Gather]` status (holstered, gather_damage / tool_power, last node hit, item counts, pickups on ground); sections `Collector` (`magnet_radius`, `magnet_speed`, `pickup_radius`, `scatter_radius`), `Node tree` / `Node rock` / `Node copper` (HP, drops, `reset_delay`, `drop_needs_tool`, densities; density applies on the next `New map`), `Player.hold_to_gather`, `Player.face_mouse_hold` + `Player.hide_idle_held` (held weapon / tool / item shown only in use + that hold; 0055; `[Player]` status `facing src: move|mouse Ns`, `pending slot: N|-` (0058); bare hands do not attack, no `Fists` section); buttons `Break nearest node`, `Give 10 each` (materials only), `Clear items` (materials only). Inventory (W3, 0029): status block `[Inventory]` (selected slot + what it holds, hands, slots used/36, bag open / closed / locked, cursor stack); sections `Inventory` (`lock_in_boss_fight`), `Item wood` / `Item stone` / `Item copper_ore` (`max_stack`), `Tool stone_axe` / `Tool stone_pickaxe` (gather_damage, tool_power, tool_kind, swing timings), `Node tree` / `Node rock` / `Node copper` now also have `preferred_tool` + `tool_bonus`, `BagPanel` (look + hint time); buttons `Give axe`, `Give pickaxe`, `Fill bag`. Crafting (W4, 0031): status block `[Crafting]` (stations in range, recipes shown, what you hold to place + spot ok / refused (water, node, station, boss, player), last placed, every furnace's input / progress / output, last craft); sections `Crafter`, `Placer` (`place_distance`, `grid_px`, ghost colours), one `Recipe <id>` per recipe (`result_count`, `order`), one `Smelt <id>` per smelt recipe (`smelt_time`), `Tool copper_axe` / `copper_pickaxe`, `InventorySkin` group "Crafting window"; `craft_radius` is on each station scene's `CraftStation`; buttons `Give W3 kit` (wooden sword, bow, axe, pickaxe: the start kit is only a wooden sword now), `Give materials (20 each)`, `Place workbench here`, `Place furnace here`, `Place anvil here` (free, same placing rules), `Finish smelting` (all furnaces). F1 also draws every station's `craft_radius` (magenta, thicker while you are inside), its body (yellow) and pickup hurtbox (green). Natural sword swing (0049): section `Swing Sword Natural` (grip points / curve controls, `windup_angle_pad`, `end_angle_pad`, `wrist_lag_power`, wobble, `ghost_*`, `crescent_on`, group `Slash art` (`slash_mode` ribbon | sprite, `ribbon_steps`, `ribbon_inner`, `ribbon_tail_deg`, `ribbon_tail_taper_deg`, `ribbon_tail_power`, `ribbon_pivot_lock`, `ribbon_head_fill`, `ribbon_textures`, `top_lift_px` in Grip path, `slash_on`, `slash_scale`, `slash_inner_cut`, `slash_head_f1..f4_deg`, `slash_show_f1/f2_deg`, `slash_fade_time`, `slash_freeze_after_active`; the drawn slash is on by default, `smear_on` off), `alternate`, `alternate_reset_time`, `alternate_return_time`; live, visual only); `WeaponVisual` status `swing: phase  dir: first|reversed  grip  ghosts  slash: hidden|f1..f4|frozen f3/f4`. Death (W6, 0039 + 0042): status block `[Death]` (deaths this run, respawn timer / alive, death drops on the ground + items + soonest despawn); sections `Respawner` (`respawn_delay`, `drop_share`, `drop_gear`, `despawn_time`, `fade_time`, group `Spray`: `max_per_pickup`, `spray_min/max`, `drop_scale`, `pop_height`, `pop_time`); buttons `Kill player` (a real death, ignores dodge / guard), `Go to nearest drop`; Hit area follows the swing (0050): a SwingMotion weapon hits where the blade picture passes (grip points, `aim_bias_deg`, `screen_offset` move it too); weapon field `hit_follows_blade` (false = whole path tried on the first active frame, true = poses tried frame by frame as the blade moves); Hit size from the picture (0061): weapon group `Hit area from picture` (`hit_auto_fit`, `hit_tip_margin`, `hit_width_margin`, `hit_min_width`, `hit_alpha_min`, `hit_axis_warn_px`; live); `WeaponVisual` status ends `hit: auto LxW tip T [OFF AXIS] | manual | -`; F1 draws the new size. F1 shows the real swept area outline (white), the swept hit shapes (red) and the last pose bright, no old wedge for these weapons. Tools (0050 addendum): axe / pickaxe swing toward the mouse in every direction since 0055 (`side_only` off; the `Side chop` group: `side_only`, `side_tilt_max_deg`, `side_deadzone_deg`; status adds `side: right|left tilt N`) and a target hit (weapon group `Tool target`: `tool_target_reach`, `tool_target_cone_deg`, `tool_target_hit_t` (when in active the hit lands, 0..1); `[Weapon]` status `tool target: name px | none`; F1 orange reach arc + cone and a ring on the targeted node). F1 draws nothing new (the pickups' own circles are the Collector's). Save (W9, 0041): status block `[Save]` (file + size, last save time + result, autosave countdown, play time); `SaveGame` node in the arena (`autosave_interval`, 0 = off; saves also on Save & quit and window close, never while dead, boss engaged or in a test run); buttons `Save now`, `Load save` (reloads the arena like title Continue), `Delete save`; F3 `[Frame]` unchanged |
| `1`-`9` / mouse wheel | Select a hotbar slot (W3). Always instant, any number of weapons (0058); a press during a swing / guard / dash / skill is applied when it ends. Empty slot or material = bare hands. Not a debug key |
| `Tab` / `I` | Bag panel (3x9) under the hotbar; click = pick up / place, right click = half, shift click = hotbar <-> bag (or ore into an open furnace). Opens ONE centred crafting book (0045): left page = recipe grid (lit = craftable, dim = missing items, padlock = station not near); click an icon = choose it; right page = item, ingredients have/need, `makes N`, `< n >` count and `Craft` (puts it on the cursor, click a slot to put it down; shift + Craft = straight into the bag); side tabs Craft / Furnace / Anvil (dimmed when that station is not near); bag + a hotbar copy below; the top-left hotbar hides meanwhile (also during pause / settings). Locked while a boss is engaged. Not a debug key |
| `+` / `-` (also keypad, `=` = `+`) | Camera zoom in/out, clamped `zoom_min`..`zoom_max` (ArenaMap exports; F3 `[Map]` status shows zoom). Not a debug key |
| `/` | Focus the F3 dock's search field (only while F3 is open; never auto-focused). While any text field has focus the game keys are paused. Not a debug key |
| `Esc` | Pause menu (Resume / Settings / Save & quit). Order: F3 text field / search focused -> leave it (the dock handles it first); settings page -> back; open bag / crafting window -> close it; else pause or resume (W8, 0040). Not a debug key. F3 `[Frame]` status shows paused + volume / shake / fullscreen |
| `R` | Retry — only after the boss was defeated (not a debug key). Player death no longer shows it: you respawn at home (W6, 0039) |
| Title `Test yard` | Dev builds only (0056): the normal game on a tiny flat fixed map (`TestYard.cells`, default 64) with every Pixel Plains tree (season x age), rocks, copper, 3 stations, dummy, slime near home; no save, no natural spawning, boss off the map. F3 `[Test yard]` status (size, nodes alive / total, stations, slimes, last reset) + `Reset yard` (regrow, respawn, re-reads the layout exports). Item picker: the book (`Tab` / `I`) gets a 4th side tab `Items` with every item in `data/items` (a new `.tres` shows up by itself), 24 icons a page, `<` `>` when there are more; left click = full stack, right click = 1, into the inventory (no room = drops at the player). `CraftWindow` Text group `items_title`, `items_note`; F3 `ItemPicker` status (items, pages, tab, last taken). Not a debug key |

**When adding any feature, the same slice must also:**

1. **Expose every number as `@export`** — on a Resource or a node. The F3 panel reflects over
   `@export` properties, so a new number appears automatically. A hardcoded feel constant is a bug.
2. **Show the new state in F3** — a new cooldown, phase, flag or counter must be visible while
   playing. If the player cannot see why something happened, it cannot be tuned.
3. **Draw the new shape in F1** if it has a hitbox, range or area.
4. **Leave a way to trigger it on demand** where that is not trivial (a key to spawn the enemy, to
   force a boss phase, to refill health).

Test mode is dev-build only and never shipped, but it is never an afterthought either: the reason
every number in the design docs says "starting value, tune" is that the panel is how they get
resolved.

## 8. Project: BossFight (Godot 4.7 top-down combat + RL bosses)

**Stack**
- Game: **Godot 4.7**, GDScript (`~/.local/bin/godot`). Scenes in `scenes/`, scripts in `scripts/`
  (components / weapons / brains), weapon data as `.tres` in `data/weapons/`.
- RL: Python in `rl/` (godot_rl_agents + stable-baselines3), training-only. Shipped inference is
  JSON weights + a GDScript matmul — **the official ONNX node is .NET-only**
  ([0008](docs/decision/0008-rl-inference.md)).

**Read before design or code work**
- [docs/wiki/design-pillars.md](docs/wiki/design-pillars.md) — the combat/boss/item system.
- [docs/wiki/prototype-v0.md](docs/wiki/prototype-v0.md) — v0 scope, architecture, debug/tuning tools.
- [docs/decision/](docs/decision/) — 0001..0051. Settled; supersede with a new record, never ignore.
- [docs/reference/godot/](docs/reference/godot/) — Godot 4 combat patterns, juice recipes, RL notes.
- [docs/reference/godot/engine-versions/](docs/reference/godot/engine-versions/) — Godot 4.4–4.7 API changes (breaking, deprecated). Check before using an API that may be newer than 4.3.
- UI work: [docs/design/DESIGN.md](docs/design/DESIGN.md) (style "Island Workshop", decision 0043). Apply it;
  new looks are designed in the web mockup `tools/ui_mock/` first (shots: `tools/ui_mock/shots.py`).
- Pixel art (items, icons, props, ore rocks): the `pixel-artist` agent ([.claude/agents/pixel-artist.md](.claude/agents/pixel-artist.md))
  draws it by hand as char grids in `tools/art_tests/<topic>/` ($0, Pixel Crawler style). Opus checks every
  render before the user sees it.
- Map / world work: [docs/wiki/world-gen-plan.md](docs/wiki/world-gen-plan.md) and
  [docs/wiki/vegetation-rules.md](docs/wiki/vegetation-rules.md). Any new look gets a $0 preview picture first
  (`tools/asset_viewer/*.py`) that the user approves before it is built.
  Map art lives in `assets/map/pixel_plains/`. Map art changed → update `assets/map/pixel_plains/README.md` in the same change.

**How we work** ([0007](docs/decision/0007-working-agreement.md))
- **Algorithm first, then build.** Before building any game system (spawning, loot, AI, progression, world gen), study how
  the reference games solve it (Minecraft, Terraria, the ones in [0001](docs/decision/0001-design-reference-games.md)), write
  the algorithm down in `docs/wiki/<system>-algorithm.md` (sources table + our rules + tuning), get the user's OK, then build
  to that page. Never build a system just to "match" a request. Example: [enemy-spawning-algorithm.md](docs/wiki/enemy-spawning-algorithm.md).
- Vertical slices, one question each, playtested by the user before the next slice starts.
- Every feel number is an `@export` (live-tunable via `F3` panel / Remote inspector). Never hardcode one.
- Debug keys: `F1` hitboxes + timing (boss attack areas, charge lane, FightZone, rocks), `F2` 0.25x slow-mo, `F3` tuning panel (+ boss trigger buttons).

**Verify (rule 2, made concrete)**
- GDScript change → `godot --headless --check-only --script <file>` (the PostToolUse hook runs this
  automatically and blocks on parse errors); `godot --headless --quit` to boot the project.
- Tests ([testing-algorithm.md](docs/wiki/testing-algorithm.md)). Quick, every fix round: `tools/run_tests.sh --changed`
  (tests naming the changed files + the real-arena smoke test) or `tools/run_tests.sh tests/test_x.gd ...`. Full, once just
  before commit, in the background (a hook enforces it): `tools/run_tests.sh` (8 at a time, `-j N`, slowest 15 printed).
  Never run it again to read a failure: `.godot/test_logs/last.txt` has the output. After a fix: `--failed`, then `--changed`
  (a fix can break a test that passed); a fix in shared code gets one more Full. Tests use a 192-cell map unless on the
  `REAL_MAP` list in `run_tests.sh` (a new test that needs its own map size goes there; `--real-map` = the runner sets no small
  map, a test can still set its own). `KNOWN_RED` tests run and show but do not fail the run. Each test gets its own
  `user://` and `--fixed-fps 60`, so parallel runs (and other worktrees) never clash.
- Run a test script through `run_tests.sh` or with `timeout 60 godot ...` (the same hook blocks a bare `godot --script`).
- Python change → `pytest rl/` and a short smoke run of the env.
- Gameplay feel (hit timing, dodge windows) can't be verified headless — say so, ask the user to playtest.

**Godot rules**
- `.godot/`, `*.import`, `*.uid` are generated. Never edit.
- Prefer editing `.tscn` via the editor semantics you know; when editing by hand, keep `[gd_scene ... format=3]` and node paths intact and re-check with `--check-only`.
- Combat logic lives in code (state machines, hitboxes), not in scattered signal connections inside `.tscn`.
- Boss RL: observation/action spaces get documented in `docs/wiki/rl-spaces.md` when RL work starts
  (not yet written — v0's boss is hand-scripted).
