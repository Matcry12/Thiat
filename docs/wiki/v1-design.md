# BossFight v1 — design

**Status:** Current

*Agreed with the user 2026-10-05 (brainstorm, 8 questions). Decision: [0025](../decision/0025-v1-open-world.md).
v0 (the combat scratch build) is [prototype-v0.md](prototype-v0.md). All numbers are starting values — tune in F3.*

## 1. The game in one paragraph

You wake up at home on an island with a wooden sword. You explore, chop trees, mine rocks and fight
slimes. You craft tools, smelt copper, forge a copper sword, craft a summon item, wake the sleeping boss
at its altar and beat it. Beating it wins the game. One run: **20–30 minutes**.

**What the world is for:** preparation for the boss (Terraria style). The boss fight stays the main event.

## 2. The choices (and why)

| # | Question | Choice | Why |
|---|---|---|---|
| 1 | What is the world for? | Prepare for the boss | Keeps the combat we built at the centre |
| 2 | How many bosses? | 1 now, built so boss 2 is new data, not new systems | Complete game soon, no rebuild in v2 |
| 3 | World shape | One big seeded island, fixed size (~8–10x today's arena), water/cliff edge | Reuses MapGen + seeds; endless world doesn't fit a 30 min game |
| 4 | Death | Soft: respawn at home, keep gear, drop part of materials at the death spot (pick them up again), boss heals | You want to retry, but death still costs something |
| 5 | Gathering | Swing a tool at it, like combat | Reuses hitbox + hit feel; gathering practises the fight skill |
| 6 | Crafting | ~12 recipes, 3 stations, tiers below | Small but real progress |
| 7 | World enemies | One type per area, slimes first | Each area has its own danger; enemies teach dodging |
| 8 | Meeting the boss | Boss sleeps in its area; summon item at the altar wakes it | Clear goal, recipe guides you, nobody stumbles in by accident |

## 3. World

- **Island**, seeded (same seed = same island). Edge = water (or cliffs). Size ~8–10x the current arena,
  so home → boss is a 1–2 minute walk.
- **Areas** (placed by the generator, distance from home grows):
  | Area | Ground | Resources | Enemy |
  |---|---|---|---|
  | Forest (near home) | grass | trees, small rocks | slime |
  | Rocky | stone / dirt | big rocks, copper ore | tougher enemy (bat or rock golem) |
  | Boss area (far) | dark / special | rare item for the summon | elite guards, altar, sleeping boss |
- **Home point** (campfire): where you start and respawn.
- Resources **do not** respawn in v1 unless playtest shows you run out (then: slow regrow).

## 4. Gathering

- Trees and rocks are **resource nodes**: they have HP and take hits like a dummy. Each hit shakes the node
  and throws chips (our hit-feel system). At 0 HP they break and drop items on the ground.
- **Tool power gates resources:** hands chop trees slowly; copper ore needs a stone pickaxe or better.
  A hit with the wrong tool gives a "clink" and no damage — so the player sees *why*.
- Items on the ground: walk over to pick up (small magnet range).

## 5. Items, inventory, crafting

**Materials:** wood, stone, copper ore, copper bar, gel (slimes), rare boss-area item, boss drop.

| Tier | Station (crafted from) | Recipes |
|---|---|---|
| 0 start | — | wooden sword (start), hands |
| 1 | **Workbench** (wood) | wooden axe, stone pickaxe, wooden bow, arrows, furnace |
| 2 | **Furnace** (stone + wood) | copper ore → copper bar (**timed**, 3 s each, runs by itself: [0031](../decision/0031-crafting.md)) |
| 2 | **Anvil** (copper bars) | copper sword, copper axe, copper pickaxe |
| — | Workbench | healing potion (gel) — or a later alchemy station |
| 3 | Anvil | summon item (copper + gel + rare item); 1–2 boss weapons from the boss drop |

- **Stations are placed in the world** by the player (one simple "place this here" action on a grid;
  this is *not* a building system). You craft when standing near a station.
- **Inventory:** the hotbar becomes ~9 slots; a bag opens with `Tab`/`I`. Weapons, tools, potions and materials
  go in any mix, and every swap is instant ([0058](../decision/0058-free-weapon-swap-no-weapon-limit.md)). Bag is locked during the boss fight.
- **Everything is data:** `ItemData` and `RecipeData` resources (like `WeaponData`). Boss 2 = new rows.

## 6. Enemies

- One generic **enemy** setup (Health, Hurtbox, Knockback, a small brain, a drop table) — slimes, the rocky
  enemy and the guards are data + a brain each, not three separate codebases.
- Spawned by area, capped per area, re-spawn slowly away from the player.

## 7. Boss progression

- The boss **sleeps** in its area. A normal visit does not wake it (and hitting it does nothing).
- Use the **summon item at the altar** → the fight starts. The leash we built still works
  (leave → it heals and sleeps again, the item is used up — tune: maybe refund it).
- Beating it drops the **boss drop** → craft boss weapons → **win screen** (time, deaths). After the win
  you can keep playing.

## 8. Death

Respawn at home after a short delay. Keep weapons and tools. Everything you carry (materials, tools, weapons) sprays out as loose items at the death spot (Minecraft style, [0042](../decision/0042-death-drops.md)); they vanish after 5 min; walking over them picks them up. The boss resets.

## 9. Game frame

Title (Play / Continue / Settings / Quit), pause on `Esc` (Resume / Settings / Save & quit), settings
(volume, shake strength, fullscreen), win screen. **Save and load:** the world seed + what changed
(broken nodes, placed stations, loose pickups), the inventory, the player position, boss defeated.

## 10. Not in v1

Armor and accessories, boss 2, building / placing blocks, hunger bar (food gives effects instead, 0072), day/night, farming, NPCs, minimap,
fuel for the furnace. (Armor + boss 2 = v2.) Smelting itself is timed: see [0031](../decision/0031-crafting.md).

## 11. Build order — slices

Each slice is **playable on its own** and is playtested before the next one starts (working agreement,
[0007](../decision/0007-working-agreement.md)). Every slice: Sonnet builds, Opus judges, test mode in F3,
video, slice log line.

| # | Slice | Playable result | Art needed (placeholder until then) |
|---|---|---|---|
| W1 | **Big island** — generator grows to an island with areas, water edge, home point; boss moved far away; camera + performance on a big map | Walk the whole island, see the areas | water edge tiles, stone/dark ground |
| W2 | **Resource nodes + pickups** — trees and rocks with HP, hit feel, break, drop items; walk-over pickup; a simple item counter | Punch a tree, wood flies out, pick it up | 2–3 trees, stump, rocks, copper ore rock, item icons |
| W3 | **Inventory** — `ItemData`, stacks, 9-slot hotbar + bag UI, tools as hotbar items, tool power | Hold an axe in the hotbar and chop faster | slot frame, bag panel, tool sprites + icons |
| W4 | **Crafting** — `RecipeData`, place stations, craft near a station, the tier 1–2 recipes, furnace smelting | Build a workbench, craft a stone pickaxe, mine copper, forge a copper sword | workbench, furnace, anvil (in the pack), copper weapon sprites |
| W5 | **Slimes** — generic enemy setup + slime + spawning by area + gel drop | Fight slimes in the forest | slime (idle / hop / hit) |
| W6 | **Death & respawn** — home point, death drops at the death spot, boss reset | Die, wake at home, get your stuff back | campfire (in the pack: Bonfire), drop bag |
| W7 | **Boss progression** — sleeping boss, altar, summon item, boss drop, boss weapons, win screen | **The full v1 loop, start to win** | altar, summon item icon, boss sleep pose, boss weapons |
| W8 | **Game frame** — title, pause, settings, HUD icons for dodge/skill/guard | Feels like a real game | title logo, buttons, ability icons |
| W9 | **Save / load** | Quit and continue later | — |
| W10 | **More enemies** — rocky-area enemy, boss-area guards | Each area feels different | 2 enemy sprites |
| W11 | **Tune pass** — 5–10 full runs with the user; hit the 20–30 min target | v1 done | — |

**Order change (user choice, 2026-10-24):** W6, W8 and W9 are built before W5 (slimes) and W7 (boss progression).

**v1 is done when:** a new player finishes a run in 20–30 minutes without help or F3, the boss fight still
meets the v0 "done when" (lose the first few times, every death explainable, want to retry), and the
island plays differently with a different seed.

## 12. Art the user is drawing / finding

Already in Pixel Crawler (`assets/source/third_party/pixel_crawler/`): Workbench, Furnace, Anvil, Bonfire,
Trees, Rocks, Resources, Tools, Water tiles, Orc/Skeleton mobs. Still needed (by slice): see the table
above. Until art exists, each slice ships with a placeholder that has the **same interface**
(CLAUDE.md §5) — dropping the art in is a swap, never a rewrite.

## 13. Slice log

| Slice | Built by | Judge | Result |
|---|---|---|---|
| W1 big island | Sonnet 5.5 (all 6 tasks) | Opus judge: 0 critical, 1 important (5 of 40 seeds had small land pockets the walk check could not reach), 9 minor. All fixed except the walk time (user call) and max-size rebuild (1776 ms at 300x200, under budget). Fixes re-checked clean. User playtest: pending | Rebuild takes about 600 ms after the fixes (budget 2000). Walk home to boss: 4956 px at 260 px/s = about 19 s straight, about 25 s with the bends. The spec hoped for 1-2 min, so the island is too small or the player too fast. Decide after the playtest. Demo: `docs/demo/w1_island.mp4`. |
| W2 trees and rocks | Sonnet 5.5 (all 6 tasks) | Opus judge: 0 critical, 3 important, all fixed: (1) arrows and boss bolts flew through every tree and rock, (2) all nodes shared one collision circle, (3) pressing 3 twice cancelled swing recovery for free. Re-review found that the fix made 2 shooting tests flaky: 38 tests loaded a random island. Root fix: `run_tests.sh` sets `BOSSFIGHT_TEST_SEED=11` (this was also the old "1 failing" flake). User playtest: pending | Fists punch trees (about 6 hits), rocks and copper (clink, needs a tool). Forest on seed 11: 188 trees, 161 rocks, 36 copper; build 693-840 ms. Tree art Model_01/Size_02, 96x124 px on screen, stump 6x5. Copper is a placeholder circle. The punch deals 1 to the armored dummy (armor floor). `test_island_gen` takes about 30 s. Demo: `docs/demo/w2_gather.mp4`. Decision: [0027](../decision/0027-gathering.md). |
| W3 inventory | Sonnet 5.5 (all tasks, one agent) | Opus judge: 1 critical (closing the bag after a swap could delete an item), 3 important (3rd weapon into the hotbar via shift-click while holding; free weapon swap after stowing the held weapon; slot code rewrote the layout every frame = two owners). All fixed with regression tests, re-review clean (67/67). User playtest: pending | 36 slots (9 hotbar + 27 bag), max stack 64, keys 1-9 + wheel, tools switch instantly, weapon <-> weapon keeps the 0003 swap. Axe: tree in 2 hits (6 punches by hand); pickaxe mines copper, axe clinks on it. Bag panel with click / half / shift, locked while the boss is engaged. Key `3` holster and the item counter are gone. Demo: `docs/demo/w3_inventory.mp4`. Decision: [0029](../decision/0029-inventory.md). |
| W4 crafting | Sonnet 5.5 (all tasks, one agent) | Opus judge, 3 rounds: round 1 found 1 always-failing test, 5 important (panel covered the player, arrow read backwards, anvil looked like a glass table, two owners for the station size, stations could wall off the bridge) + minors; round 2 found tall art hiding stations, natural necks unprotected, a double-rebuild dupe, hidden copper recipes; round 3 pass (74/74). Path flood moved to click only (48 ms). User playtest: pending | Recipes as `.tres`, instant crafting list next to the bag, placed stations (ghost, refusals, pickaxe pickup), timed furnace (3 s per bar, runs while you are away), start kit = wooden sword, copper gear. Demo: `docs/demo/w4_crafting.mp4`. Decision: [0031](../decision/0031-crafting.md). |
| Temp Tiny RPG art (0032) | Sonnet 5.5 (one agent) | Opus judge not run yet (CLAUDE.md 2.4: needs a fresh Opus reviewer) | Soldier + Orc swapped in through BodyRig / BossVisual, no combat code changed apart from forwarding attack phases; 75 tests green; user playtest pending |
| W6 death and respawn | Sonnet 5.5 (one agent) | Opus judge: passed with fixes. A corpse killed mid-dash slid 87 px; F3 "Go to nearest bag" teleported without loading chunks or snapping the camera; a broken guard stayed broken after respawn and the boss kept old cooldowns; the bag was a 10 px dot hidden under the sword. All fixed with tests (dodge cancel, `teleport_player(Vector2)`, guard reset, boss cooldown reset, bigger bag look as exports). User playtest: pending | Die, wake at home after 2 s, half of each material in a bag at the death spot, walk over it to get it back, boss resets. Decision: [0039](../decision/0039-death-respawn.md). |
| W8 game frame | Sonnet 5.5 (one agent) | Opus judge: passed with fixes. Shake had two owners (now only `CameraShake.shake_strength`); tests could read / write the real `settings.cfg` (now blocked under a test run); the guard stayed held after a pause; setting fullscreen off un-maximized the window; menus lacked focus and the title ignored Esc in Settings. All fixed. User playtest: pending | Title (Play / Continue / Settings / Quit), `Esc` pause, shared settings panel (volume, shake, fullscreen) saved to `user://settings.cfg`. Decision: [0040](../decision/0040-game-frame.md). |
| W9 save / load | Sonnet 5.5 (one agent) | Opus judge: OK after fixes. After the boss died, saving never worked again (a dead boss stayed "engaged"; fixed at the root in `Boss._on_died` + `refusal()`); Save & quit gave no hint when refused (now a line on the button before quitting); loading a second weapon started a swap cast (now `Loadout.select_instant`). User playtest: pending | One slot `user://save.json`: seed + changes (gathered nodes, stations, furnaces, bags, inventory, position, HP, deaths, boss defeated). Autosave 60 s, Save & quit, window close; Continue only with a valid save. Decision: [0041](../decision/0041-save-load.md). |
| W6b death drops | Sonnet 5.5 (one agent) | Opus judge: pending | User asked for Minecraft-style drops instead of the bag: items spray out as pickups, `despawn_time` 300 s (death drops only), `drop_gear` / `drop_share` exports, saved with their timers (save version 2). The bag code was deleted. Decision: [0042](../decision/0042-death-drops.md). User playtest: pending |
| W5 slimes | Sonnet 5.5 (3 builders in parallel: enemy core, spawner, demo bot) + pixel-artist (slime art) + Sonnet (Tiny RPG removal) | Opus judges, 4 rounds: shared collision shapes resized every slime; contact radius hardcoded; no test guard so slimes spawned inside other tests; spawns 125 px away headless; sprite path had no timing stretch; visual exports not in F3; v2: residents vanished before you reached them, rate still ~5 slimes/min, biome rates not in F3. All fixed. User (screenshots): slime drawn over trees and the player, sword under the slime, spawns "too many / too often" -> Y-sort fix, sword `weapon_z`, spawner v2 (Minecraft where + Terraria when, 0053). Art review 7/10 -> fixed telegraph, puddle, gel icon. | 5 slime types as data (green, swamp, sand, ice, rock), seeded slime spots, residents, chance per second. Full suite 108 tests, 2 failing (`test_player_animation`, `test_run_dust_shadow`: fail on base too). Tiny RPG art removed (0054), boss is a stand-in circle. Demo: `docs/demo/w5_slimes.mp4` (recorded before spawner v2). Decisions: [0052](../decision/0052-enemies-slime.md), [0053](../decision/0053-natural-enemy-spawning.md). User playtest: pending |
| Food + potion (first design) | Sonnet 5.5 (2 builders: logic, then HUD port of the web mockup) | Opus judge (logic): an item with food + heal gave free food on every refused click; starving floor 0 could leave HP at 0. Fixed with tests. Opus judge (HUD): pass, no bugs. Full suite: map golden test hashed auto node names, which shift when any node is added; now hashes positions only. User: mockup had the old map; asked for HP and food bars of the same length. User playtest: works (2026-11-20) | Food bar drains 10/min, starving stops at 1 HP, eat/drink with the attack click, potion +50 HP / 30 s cooldown shown on the slot. Decision: [0071](../decision/0071-hunger-and-potion.md). |
| Food effects v2 (replaces hunger bar) | Sonnet 5.5 (2 builders: effects logic + v1 removal, then HUD icon port of the web mockup) | Opus judge (logic): pass, no bugs. Opus judge (HUD): pass with fixes: the icon row widened the bottom-left block and would push the boss bar at 3+ effects; icon layout numbers not in F3. Fixed with a test. Full suite: debug-contract name list missed EffectBar. User: wanted buffs like Terraria/Minecraft instead of a hunger bar (slot kept for mana), asked how different regen foods mix. User playtest: regen too fast, halved the rate and doubled the time (same total); then OK to commit | Regen I/II from cooked food, raw pork = small regen + Sick (-20% walk), Minecraft stacking (no add-up, no waste), potion +50 / 30 s. Decision: [0072](../decision/0072-food-effects.md). |
| Chest hold + hold-to-eat | Sonnet 5.5 (4 builders in turn: chest pose, hold-to-eat, gap + sounds, feel data to .tres) | Opus judges, 4 rounds: hand-off ordering (item placed only by main hand, dev-only, kept), a test check that could never fail, crumbs missing from F3, crumbs spawning above the item when facing left; docs stale. All fixed except the dev-only one. User: hands too low with bread (fixed: fixed hand height), items not bag-sized (fixed: scale by icon canvas), asked for Minecraft eating, then a gap + sound, then saved data for clean swaps. User playtest: pending | Non-weapon, non-glowing items held on both hands at the chest, always shown. Hold 1.6 s to eat/drink, walk x0.5, bob + crumbs, 0.5 s gap, procedural chew/sip/gulp placeholders, no body turn on food. Numbers in `data/held_item/chest_hold.tres` + `data/food/eating.tres`. Full suite 129 tests, 0 failing. Decision: [0073](../decision/0073-eating-and-chest-hold-data.md). |
