# BossFight v1 — design

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
| 2 | **Furnace** (stone + wood) | copper ore → copper bar (instant, Terraria-style) |
| 2 | **Anvil** (copper bars) | copper sword, copper axe, copper pickaxe |
| — | Workbench | healing potion (gel) — or a later alchemy station |
| 3 | Anvil | summon item (copper + gel + rare item); 1–2 boss weapons from the boss drop |

- **Stations are placed in the world** by the player (one simple "place this here" action on a grid;
  this is *not* a building system). You craft when standing near a station.
- **Inventory:** the hotbar becomes ~9 slots; a bag opens with `Tab`/`I`. Old rule stays
  ([0003](../decision/0003-loadout-and-swapping.md)): max 2 weapons in the hotbar, swap cast + cooldown;
  tools, potions and materials fill the rest. Bag is locked during the boss fight.
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

Respawn at home after a short delay. Keep weapons and tools. Drop **50%** (tune) of each
material stack in a bag at the death spot; walking over it gives it back. The boss resets.

## 9. Game frame

Title (Play / Continue / Settings / Quit), pause on `Esc` (Resume / Settings / Save & quit), settings
(volume, shake strength, fullscreen), win screen. **Save and load:** the world seed + what changed
(broken nodes, placed stations, dropped bags), the inventory, the player position, boss defeated.

## 10. Not in v1

Armor and accessories, boss 2, building / placing blocks, hunger, day/night, farming, NPCs, minimap,
Minecraft-style timed smelting. (Armor + boss 2 = v2.)

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
| W6 | **Death & respawn** — home point, drop bag at death spot, boss reset | Die, wake at home, get your stuff back | campfire (in the pack: Bonfire), drop bag |
| W7 | **Boss progression** — sleeping boss, altar, summon item, boss drop, boss weapons, win screen | **The full v1 loop, start to win** | altar, summon item icon, boss sleep pose, boss weapons |
| W8 | **Game frame** — title, pause, settings, HUD icons for dodge/skill/guard | Feels like a real game | title logo, buttons, ability icons |
| W9 | **Save / load** | Quit and continue later | — |
| W10 | **More enemies** — rocky-area enemy, boss-area guards | Each area feels different | 2 enemy sprites |
| W11 | **Tune pass** — 5–10 full runs with the user; hit the 20–30 min target | v1 done | — |

**v1 is done when:** a new player finishes a run in 20–30 minutes without help or F3, the boss fight still
meets the v0 "done when" (lose the first few times, every death explainable, want to retry), and the
island plays differently with a different seed.

## 12. Art the user is drawing / finding

Already in Pixel Crawler (`assets/third_party/pixel_crawler/`): Workbench, Furnace, Anvil, Bonfire,
Trees, Rocks, Resources, Tools, Water tiles, Orc/Skeleton mobs. Still needed (by slice): see the table
above. Until art exists, each slice ships with a placeholder that has the **same interface**
(CLAUDE.md §5) — dropping the art in is a swap, never a rewrite.

## 13. Slice log

| Slice | Built by | Judge | Result |
|---|---|---|---|
| W1 big island | Sonnet 5.5 (all 6 tasks) | Opus judge: 0 critical, 1 important (5 of 40 seeds had small land pockets the walk check could not reach), 9 minor. All fixed except the walk time (user call) and max-size rebuild (1776 ms at 300x200, under budget). Fixes re-checked clean. User playtest: pending | Rebuild takes about 600 ms after the fixes (budget 2000). Walk home to boss: 4956 px at 260 px/s = about 19 s straight, about 25 s with the bends. The spec hoped for 1-2 min, so the island is too small or the player too fast. Decide after the playtest. Demo: `docs/demo/w1_island.mp4`. |
| W2 trees and rocks | Sonnet 5.5 (all 6 tasks) | Opus judge: 0 critical, 3 important, all fixed: (1) arrows and boss bolts flew through every tree and rock, (2) all nodes shared one collision circle, (3) pressing 3 twice cancelled swing recovery for free. Re-review found that the fix made 2 shooting tests flaky: 38 tests loaded a random island. Root fix: `run_tests.sh` sets `BOSSFIGHT_TEST_SEED=11` (this was also the old "1 failing" flake). User playtest: pending | Fists punch trees (about 6 hits), rocks and copper (clink, needs a tool). Forest on seed 11: 188 trees, 161 rocks, 36 copper; build 693-840 ms. Tree art Model_01/Size_02, 96x124 px on screen, stump 6x5. Copper is a placeholder circle. The punch deals 1 to the armored dummy (armor floor). `test_island_gen` takes about 30 s. Demo: `docs/demo/w2_gather.mp4`. Decision: [0027](../decision/0027-gathering.md). |
