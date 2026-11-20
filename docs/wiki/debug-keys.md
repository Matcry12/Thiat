# Debug keys and test mode (F1 / F2 / F3)

**Status:** Current

The full list of what each key shows. Moved out of `CLAUDE.md` (one 16,000-character line) on 2026-11-16.
**Keep it current:** a feature that adds an F3 row, F1 shape or debug button updates its key's section here, in the same change.
How to use F3 as a player: [how-to-tune.md](how-to-tune.md). Rules for new features: `AGENTS.md` §7.

## `F1`

Hitboxes, hurtboxes, attack phase, reach wedge, rock/tree collision circles (yellow), gather hurtbox circles (green), collector magnet + pickup circles around the player (cyan), loaded chunk borders (thin blue, 0038 step 2; only when F3 `DebugOverlay.show_chunk_borders` is on, default off), light radius circles (orange, 0067)

## `F2`

Slow motion (0.25x)

## `F3`

- Cycles full -> watch only -> off.
- Full = the dock on the right (380 px, the camera slides left): search box (`/` focuses it, `Esc` leaves a field), tabs `Tune` (pinned rows, then category > section > `@export_group` > row; number field + slider + `↺` reset + pin; heavy map rows apply on release / Enter and show a "Rebuilding map…" / "last rebuild X.X s" banner), `Actions` (grouped buttons; red ones - Kill player, Delete save, Restart, Clear overrides - need a second click "Sure?" within 2 s), `Status` (one row per status block, open for detail, `pin to game`), and a footer: "● N overrides (K to .tres, S scene-only)", `Write K to .tres`, `Clear overrides`, a `N stale` button (tooltip lists them, click drops them).
- Every F3 edit is an override saved at once in `user://tuning.cfg` (value + base, re-applied at each start, skipped as stale if the file changed; never applied or kept in headless runs; toast "N F3 overrides applied - M stale skipped"); scene-only rows get a copy button (`prop = value`); `Write K to .tres` puts the changed values into a fresh copy of each resource file (replaces Save / Load / Reset / Save rig).
- Watch only = no dock, a click-through card top-centre with the pinned status blocks and "● N F3 overrides".
- The old top-left status wall is gone.
- Below: Map: seed box + `Generate`, `New map`.
- Boss status (idle/engaged/returning) + buttons: `Phase 2`, `-> slam/spread/charge/ring` (force that attack next, ignores cooldown + phase), `Boss passive` (stands still, no attacks), `Heal boss`, `Heal player`, `Restart`.
- Map: seed in status, `New map` button (new random seed), map sliders rebuild live.
- Hit feel: `[Hit FX]` status (trauma, hit-stop frames left, last hit type); sections `HitFx` (master + per-layer switches), `HitStop` (`hitstop_scale`), `CameraShake` (`shake_strength`, 0 = off), `Sound` (SoundBoard: `enabled`, `volume_db`, `pitch_variation`, `voices`; one `Sound <set>` section per `data/sounds/*.tres`, one per cue; status `[Sound]`: last event, plays, voices busy, silent slots; button `Test sound` cycles sets + slots), one `Hit <type>` section per profile in `data/hit_fx/`; buttons `Test sword hit`, `Test parry`, `Test player hit`, `Test kill FX`, `Test boss hit`, `Test lunge`, `Test charged arrow`, `Test node hit`, `Test node pop` (nearest tree / rock / copper / station; stations too: wrong tool = wobble + knock, pickaxe = pop into the bag, profiles `station_knock_*` / `station_pickup_*`)
- (effects only, no HP change, no movement).
- Chop / break feel for trees, rocks, copper (0057; rocks: same reaction, grey chips, less sway, stone sounds; per-profile `sway_scale`, `leaf_scale`, `picture_chips`): section `NodeReaction` with groups `ChopSway` (sway_deg / sway_max_mult / freq / damping), `ChopDebris` (chips + leaves counts, speeds, pop height, bounce, life) and `TreePop` (pop_scale, pop_hold, burst counts), `HitFx.reaction_on`, per-profile `reaction` + `pitch_gain` (bigger hit = more sway, debris, pitch as HP falls; `Hit tree_break`); `[Gather]` status adds `reaction:` (last chop hp %, sway deg, chips, leaves)
- Slice 2: `HitFx` switches `recoil_on`/`sparks_on`/`numbers_on`; sections `HitSparks`, `DamageNumbers`, and the new per-hit fields (`knockback`, `recoil_px`, `spark_*`, `number_size`); `[Knockback (gameplay)]` status (last shove per actor), one `Knockback <Actor>` section each (`enabled`, `knockback_scale`, `resistance`, `decay_rate`), buttons `Knockback on/off` (movement only, separate from Hit FX) and `Dummy to spot`; sword/bow `step_distance` in their weapon sections.
- HUD (0030, supersedes the top-right placement of 0024): hotbar + bag top-left, ability icons (dodge / skill / guard) above the health bar bottom-left, boss bar bottom centre (only while the boss is awake: `BossBar.set_awake`); no words in the HUD, names and the HP number only in the hover tooltip.
- Sections `HUD` (margins), `HealthBar` (`trail_delay`, `trail_speed`, `low_threshold`), `Hotbar`, `InventorySkin` (sizes, fonts, tooltip, health / boss bar looks, placeholder colours); button `Hurt player 20`; while the dock is open the boss bar keeps clear of it and of the left blocks.
- The boss has no Knockback: it only jolts visually.
- F1 also draws the last knockback vector (orange, 0.6 s).
- Run juice: `Visual` section has a `Shadow` group (`shadow_on`, `shadow_min_scale`, `shadow_min_alpha`); new `RunDust` section (`dust_on`, counts, size, life, colour); `Visual` status line shows `shadow` scale + `dust` puffs alive; 3D body (0028): status adds `facing: front|side (flipped)` + hit time left, `Visual` section group `Directional body` (`front_half_angle_deg`, `facing_hysteresis_deg`, `landing_frames`, `lift_frames`, `hit_time_scale`, `flip_deadzone`, `directional_lift_px`).
- Per-character fit (0028): section `BodyRig` (`visual_scale`, `slash_scale`, (the Hand point is a `MainHandHold` marker in `scenes/player.tscn`: drag it in the editor; its x mirrors when the body faces left; `hand_follow` in `BodyRig` 0..1 = how much it follows the body frames up/down, 0 = off), `WeaponVisual` section `hand_nudge` (live offset on top of `MainHandHold`; the status `fit:` line ends `hand x,y` = the final value; F1 draws a white X there), a weapon's `MainHandGrip` marker in its model scene = where the hand holds it, section `MainHandArt` = the visible hand, on the grip / held item, at rest on the `MainHandRest` marker (`hand_on`, `hand_scale`, `hand_z`, `hold_z`, `item_offset`, `rest_nudge`, `run_swing`; status `hand: on|off at grip|item|rest`; 0065), section `OffHandArt` = the free hand: on a weapon's `OffHandGrip` marker (model scene; no marker = one-handed; F1 draws a second cyan cross), at rest on the `OffHandRest` marker, behind the body (same fields + `use_off_grip`; status `at off_grip|rest`), `shadow_scale`, `body_position`, `soft_edges` + `soft_edge_width` = turned weapon picture drawn with softened pixel edges, off = nearest; `WeaponVisual` status starts `soft: on|off`: weapon pictures, never hitboxes; no hands since 0048, section `HeldItem` = the icon of a material / placeable in the hand: `icon_scale`, `grip_offset`, chest hold of non-glowing items = own section `ChestHold` (`data/held_item/chest_hold.tres`, "Write to .tres"): `offset_x`, `hand_y`, `rest_overlap`, `icon_size` (icon canvas size in world px: items look the same size as in the bag), `hand_min_spread`, `z`, eating bob `bob_px`, `bob_hz` (item + both hands, whole px); `HeldItem` status ends `mode: chest|side  bob: eating|-`; section `Eating` (`data/food/eating.tres`, "Write to .tres"): `eat_time`, `eat_gap`, `eat_sound_every`, `eat_move_mult`, crumbs `crumb_texture` (set in the .tres or editor, not shown in F3; empty = coloured squares), `crumb_every`, `crumb_count`, `crumb_px`, `vel_x`, `vel_y_min/max`, `gravity`, `life`, `start_y_frac`, `z`, `max_crumbs`; section `EatCrumbs` status `crumbs alive`; section `Consumer` status `eating: yes|no N%  gap Ns`; hand status `at chest`); footer `Write K to .tres` writes the live BodyRig back into its `data/body_rigs/*.tres` (kept after the game closes), and the `Visual` status keeps its `rig ...` line.
- Map section is grouped (`@export_group`: Layout / Chunks / Island / Water / Climate / Biomes / Vegetation / Looks, shown as `[ Group ]` sub-headings; heavy sliders rebuild on release) and the `World map` button toggles a ~400 px picture of the whole island left of the tuning panel (biome colours, river / lake / shallow / ocean blues, home white, boss red, you yellow; redraws after every rebuild).
- Water v2 (0038): `Map` Water group has `river_w_*`, `river_big_*`, `lake_big_*`, `lake_pond_*`, `lake_warp`, `lake_shape_period`, `lake_gap`.
- Island (W1, 0026): `Map` section has the island sliders (`island_on`, `island_*`, `coast_cells`, `home_clear_cells`, `corridor_half`, `home_offset_*`) and the climate ones (0038: `climate_*` periods / warp / lookup weights, `biome_smooth_passes`, `biome_min_blob`, `beach_min/max`, `cold_beach_t`, `home_calm_*`, `calm_*`, `forest_margin`, `boss_land_cells`; they rebuild the map) plus one `Biome <label>` section per biome (climate points, `temp_class`, `ground`, and since 0038 step 4 ALL vegetation, grouped `[ Trees ]` `[ Rocks ]` `[ Bushes ]` `[ Flowers ]` `[ Mushrooms and tufts ]` `[ Water edge and snow ]` `[ Ground mix ]`: tree table `tree1..6_model/season/weight`, `tree_tries`, `age_rule`, `max_stage`, rock groups, bush / flower / mushroom / tuft / reed / stump rates, `ground_alt`; these rebuild the map on drag end; `tint_*` and the map colour are live; data in `data/biomes/*.tres`); `[Map]` status shows the area + biome + temperature / humidity / roughness / f under the player, `biome % of land`, land %, rocks, deco, build ms; buttons `Go home`, `Go to boss`, `Biome map` (toggles a see-through colour per cell over the world, `biome_map_alpha`).
- Biomes + trees (0037, step 1): `Map` Vegetation group has `band_lo/hi`, `tree_fade_*`, `veg_density_period`, `rock_group_radius`, `fir_group_radius`, `age_*`/`core_old`/`mid_small`/`edge_*`, `clearing_*`, `tree_home_clear`, `trees_on`, `veg_on` (rebuild the map); `[Map]` status also shows trees per age; one `Node treepp_oak_green_<age>` section each (sapling / young / mature / old: radius, hp).
- Map looks (0033): `smooth_passes`, `beach_cells`, `path_*`, `camp_radius`, `dirt_patch*`, `*_bright/_warm/_sat` per area, `shade_*`, `foam_*`, `shimmer_*`, `wave_strength` (tint / foam / shimmer are live, the rest rebuilds); status shows path cells + ground picture ms.
- Chunks (0038 step 2, map is 512x512 by default): `[Map]` status shows chunks loaded / total (+ queued), chunk build ms (last / avg / max; avg ground / props / nodes), nodes alive, deco alive, world-data ms; `Map` sliders `chunk_cells`, `load_radius`, `unload_margin`, `chunks_per_frame`.
- Water (0038 step 3): `Map` sliders `cont_*` / `land_share` / `neck_*` (island shape), `river_*`, `lake_*`, `shore_cells`, `shallow_min/max` (rebuild), `shallow_tint_*` (live shallow-water colour); `Biome <label>` sections get `shore_ground` and `fresh_pull_cells` + `fresh_*` (swamp near water); `[Map]` status line `water: river / lake / shallow cells`, biome name says river / lake / coast shallows; `Swimmer` (`water_speed_scale`) and `WaterFx` (band, ripple, splash numbers) sections, `[Player]` status line `in water: yes/no  speed x...`.
- Gathering (W2): `[Gather]` status (holstered, gather_damage / tool_power, last node hit, item counts, pickups on ground); sections `Collector` (`magnet_radius`, `magnet_speed`, `pickup_radius`, `scatter_radius`), `Node treepp_oak_green_*` / `Node rock` / `Node copper` (HP, drops, `reset_delay`, `drop_needs_tool`, densities; density applies on the next `New map`), `Player.hold_to_gather`, `Player.face_mouse_hold` + `Player.hide_idle_held` (held weapon / tool / item shown only in use + that hold; 0055; `[Player]` status `facing src: move|mouse Ns`, `pending slot: N|-` (0058); bare hands do not attack, no `Fists` section); buttons `Break nearest node`, `Give 10 each` (materials only), `Clear items` (materials only).
- Inventory (W3, 0029): status block `[Inventory]` (selected slot + what it holds, hands, slots used/36, bag open / closed / locked, cursor stack); sections `Inventory` (`lock_in_boss_fight`), `Item wood` / `Item stone` / `Item copper_ore` (`max_stack`), `Tool stone_axe` / `Tool stone_pickaxe` (gather_damage, tool_power, tool_kind, swing timings), `Node treepp_oak_green_*` / `Node rock` / `Node copper` now also have `preferred_tool` + `tool_bonus`, `BagPanel` (look + hint time); buttons `Give axe`, `Give pickaxe`, `Fill bag`.
- Crafting (W4, 0031): status block `[Crafting]` (stations in range, recipes shown, what you hold to place + spot ok / refused (water, node, station, boss, player), last placed, every furnace's input / progress / output, last craft); sections `Crafter`, `Placer` (`place_distance`, `grid_px`, ghost colours), one `Recipe <id>` per recipe (`result_count`, `order`), one `Smelt <id>` per smelt recipe (`smelt_time`), `Tool copper_axe` / `copper_pickaxe`, `InventorySkin` group "Crafting window"; `craft_radius` is on each station scene's `CraftStation`; buttons `Give W3 kit` (wooden sword, bow, axe, pickaxe: the start kit is only a wooden sword now), `Give materials (20 each)`, `Place workbench here`, `Place furnace here`, `Place anvil here` (free, same placing rules), `Finish smelting` (all furnaces).
- F1 also draws every station's `craft_radius` (magenta, thicker while you are inside), its body (yellow) and pickup hurtbox (green).
- Natural sword swing (0049): section `Swing Sword Natural` (grip points / curve controls, `windup_angle_pad`, `end_angle_pad`, `wrist_lag_power`, wobble, `ghost_*`, `crescent_on`, group `Slash art` (`slash_mode` ribbon | sprite, `ribbon_steps`, `ribbon_inner`, `ribbon_tail_deg`, `ribbon_tail_taper_deg`, `ribbon_tail_power`, `ribbon_pivot_lock`, `ribbon_head_fill`, `ribbon_textures`, `top_lift_px` in Grip path, `slash_on`, `slash_scale`, `slash_inner_cut`, `slash_head_f1..f4_deg`, `slash_show_f1/f2_deg`, `slash_fade_time`, `slash_freeze_after_active`; the drawn slash is on by default, `smear_on` off), `alternate`, `alternate_reset_time`, `alternate_return_time`; live, visual only); `WeaponVisual` status `swing: phase  dir: first|reversed  grip  ghosts  slash: hidden|f1..f4|frozen f3/f4`.
- Death (W6, 0039 + 0042): status block `[Death]` (deaths this run, respawn timer / alive, death drops on the ground + items + soonest despawn); sections `Respawner` (`respawn_delay`, `drop_share`, `drop_gear`, `despawn_time`, `fade_time`, group `Spray`: `max_per_pickup`, `spray_min/max`, `drop_scale`, `pop_height`, `pop_time`); buttons `Kill player` (a real death, ignores dodge / guard), `Go to nearest drop`; Weapon fit (live): every weapon / tool section has group `Art fit` (`art_scale` 0..4, decimals allowed, whole sizes stay sharpest, `art_nudge_x/y`, `art_turn_deg`; 0 = the scene's own picture; the hit area follows; section = the weapon's file name, tools `Tool <id>`); button `Hold weapon still` (WeaponVisual, dev only, never saved) keeps it shown idle and frozen in aim; slider `dev_still_aim_deg` sets that aim (0 = right); `WeaponVisual` status last line `fit: xN nudge x,y turn d still: on|off aim N`; `Write K to .tres` saves it into `data/weapons/<id>.tres`; Hit area follows the swing (0050): a SwingMotion weapon hits where the blade picture passes (grip points, `aim_bias_deg`, `screen_offset` move it too); weapon field `hit_follows_blade` (false = whole path tried on the first active frame, true = poses tried frame by frame as the blade moves); Hit size from the picture (0061): weapon group `Hit area from picture` (`hit_auto_fit`, `hit_tip_margin`, `hit_width_margin`, `hit_min_width`, `hit_alpha_min`, `hit_axis_warn_px`; live); `WeaponVisual` status ends `hit: auto LxW tip T [OFF AXIS] | manual | -`; F1 draws the new size.
- F1 shows the real swept area outline (white), the swept hit shapes (red) and the last pose bright, no old wedge for these weapons.
- Tools (0050 addendum): axe / pickaxe swing toward the mouse in every direction since 0055 (`side_only` off; the `Side chop` group: `side_only`, `side_tilt_max_deg`, `side_deadzone_deg`; status adds `side: right|left tilt N`) and a target hit (weapon group `Tool target`: `tool_target_reach`, `tool_target_cone_deg`, `tool_target_hit_t` (when in active the hit lands, 0..1); `[Weapon]` status `tool target: name px | none`; F1 orange reach arc + cone and a ring on the targeted node).
- F1 draws nothing new (the pickups' own circles are the Collector's).
- Save (W9, 0041): status block `[Save]` (file + size, last save time + result, autosave countdown, play time); `SaveGame` node in the arena (`autosave_interval`, 0 = off; saves also on Save & quit and window close, never while dead, boss engaged or in a test run); buttons `Save now`, `Load save` (reloads the arena like title Continue), `Delete save`; F3 `[Frame]` unchanged.
- Ground pictures (0069): section `Pixel Plains` has the button `Reload ground pictures` (reads `ground/*.png`, `foam.png`, `water.png` from disk, rebuilds the map, no editor re-import), the `[Map]` cell report shows the corner's layers (`water base / sand slot 6 + foam / light slot 4`); borders, foam and water are pixels of those pictures, the old step / band / dash exports are gone.
- Day / night (0067): status `[DayClock]` (hh:mm, phase, day N, lights on / total, level, time_scale, frozen); section `DayClock` (`time_scale`, `frozen`) + `DayNightData` (day length, phase fractions, `start_time`, tint gradient, `light_fade_power`); sections `Light campfire` and `Light player glow` (`radius`, `base_energy`, `color`, `flicker_*`, `night_only`; a light is in F3 only when its `f3_label` is set, torches are not); buttons `Skip to dawn / day / dusk / night`, `Freeze time` (frozen by default in test runs); F1 draws each light's radius (orange circle, from the DebugOverlay); damage numbers and the biome map sit on their own camera-following canvas so night does not darken them; HUD: a sun / moon dial under the hotbar, day + clock in its hover tooltip

## `1`-`9` / mouse wheel

- Select a hotbar slot (W3).
- Always instant, any number of weapons (0058); a press during a swing / guard / dash / skill is applied when it ends.
- Empty slot or material = bare hands.
- Not a debug key

## `Tab` / `I`

- Bag panel (3x9) under the hotbar; click = pick up / place, right click = half, shift click = hotbar <-> bag (or ore into an open furnace).
- Opens ONE centred crafting book (0045): left page = recipe grid (lit = craftable, dim = missing items, padlock = station not near); click an icon = choose it; right page = item, ingredients have/need, `makes N`, `< n >` count and `Craft` (puts it on the cursor, click a slot to put it down; shift + Craft = straight into the bag); side tabs Craft / Furnace / Anvil (dimmed when that station is not near); bag + a hotbar copy below; the top-left hotbar hides meanwhile (also during pause / settings).
- Locked while a boss is engaged.
- Not a debug key

## `+` / `-` (also keypad, `=` = `+`)

- Camera zoom in/out, clamped `zoom_min`..`zoom_max` (ArenaMap exports; F3 `[Map]` status shows zoom).
- Not a debug key

## `/`

- Focus the F3 dock's search field (only while F3 is open; never auto-focused).
- While any text field has focus the game keys are paused.
- Not a debug key

## `Esc`

- Pause menu (Resume / Settings / Save & quit).
- Order: F3 text field / search focused -> leave it (the dock handles it first); settings page -> back; open bag / crafting window -> close it; else pause or resume (W8, 0040).
- Not a debug key.
- F3 `[Frame]` status shows paused + volume / shake / fullscreen

## `R`

- Retry — only after the boss was defeated (not a debug key).
- Player death no longer shows it: you respawn at home (W6, 0039)

## Title `Test yard`

- Dev builds only (0056): the normal game on a tiny flat fixed map (`TestYard.cells`, default 64) with every Pixel Plains tree (season x age), rocks, copper, 3 stations, dummy, slime near home; no save, no natural spawning, boss off the map.
- F3 `[Test yard]` status (size, nodes alive / total, stations, slimes, last reset) + `Reset yard` (regrow, respawn, re-reads the layout exports).
- Item picker: the book (`Tab` / `I`) gets a 4th side tab `Items` with every item in `data/items` (a new `.tres` shows up by itself), 24 icons a page, `<` `>` when there are more; left click = full stack, right click = 1, into the inventory (no room = drops at the player).
- `CraftWindow` Text group `items_title`, `items_note`; F3 `ItemPicker` status (items, pages, tab, last taken).
- Not a debug key

## Food and effects (0072)
- F3 sections `Effects` (under Character; no exports, numbers live in `data/effects/*.tres` and item grants) and `Consumer` (`potion_cooldown`).
- Status: `Effects` = each effect, level, time left, current speed multiplier; `Consumer` = potion cooldown left, last refusal ("full" / "cooldown" / "no change").
- HUD effect icons: F3 section `EffectBar` (`lead_art`, `top_art`, `pitch_art`, `blink_time`, `blink_hz`, `blink_alpha`); icons sit right of Q/E/F; pictures `assets/game/ui/effects/<id>.png` (set as `icon` in the effect .tres), frames `effect_frame` / `effect_frame_bad` in the skin; hover tooltip "Regeneration II - 8 s".
- Buttons (Effects): `Give Regen` (II, 10 s), `Give Sick` (15 s), `Clear effects`.
- Test yard: a stack of each food and healing potions lies in a row south of home (`TestYard` exports `food_ids`, `food_stack`, `food_spacing`, `food_row_offset`).
