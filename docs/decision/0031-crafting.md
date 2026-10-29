# 0031 - Crafting: instant recipes, placed stations, a timed furnace

**Date:** 2026-10-10 - **Slice:** W4 - **Supersedes** the "copper ore -> copper bar (instant, Terraria-style)" line in [v1-design](../wiki/v1-design.md) section 5 and the "Minecraft-style timed smelting" line in section 10.

## Context
v1-design section 5 planned recipes, placed stations and an instant furnace. The user decided in the W4 brief: crafting is **instant** (a Terraria-style list), but **smelting takes time**: the furnace is a small machine. The W3 start kit (sword, bow, axe, pickaxe) also had to go, so the loop (punch trees -> tools -> copper -> copper sword) is real.

## Decision
- **Data, zero code per recipe.** `RecipeData` (`result`, `result_count`, `ingredients: Array[IngredientData]`, `station`, `order`) in `data/recipes/*.tres`. `SmeltRecipeData` (`input`, `output`, `output_count`, `smelt_time` = 3.0 s) in `data/smelting/*.tres`. `RecipeBook.load_dir()` finds the files; a new file is a new recipe.
- **Crafter** (child of the Player) holds the rules. A recipe shows when it is "by hand" (`station = &""`) or its station is within `craft_radius` (150 px) of the player. `craft(recipe)` takes the ingredients and gives the result at once. If the inventory is full the result drops at the player (`Inventory.give_or_drop`): never lost. Refused while a boss is engaged (same lock as the bag).
- **Stations are items you place.** Workbench, Furnace, Anvil are `ItemData` (category `placeable`) with a `placeable: PackedScene`. Selecting one in the hotbar (it counts as bare hands) shows a **ghost** (the real station scene with `ghost = true`) on a 32 px grid cell 70 px along the aim; the attack click places it and takes the item. White = free, red = refused. `Placer.check_at()` is the one rule: refused on water (also half over the shore), on resource nodes / rocks (a broken stump is free), on other stations, on pickups, in the boss area (`ArenaMap.in_boss_area`: boss land or the fight zone), on the land bridge to the boss (`MapGen.Result.bridge`, `ArenaMap.in_corridor`: a station must never wall off the only path) and on the player; also refused while a boss is engaged. The ghost is tinted green / red with a 1 px outline (exports on the `Placer`).
- **Station** = `StaticBody2D` + `CraftStation` (`station_id`, `craft_radius`) + `Visual` (`Art` from a rect on the Pixel Crawler sheet, `Placeholder` box). The body size is `footprint`, never the picture.
- **Picking a station back up: a hit with a pickaxe.** Not hands (a punch at a tree next to your base must not undo it), not axes. The item comes back, and a furnace's contents too (to the inventory, or the ground if full). **One swing takes one station:** the nearest to you among those hit in the same frame, and `pickup_lockout` (0.5 s, an @export on the station) refuses the next pickup, because a swing keeps polling for several frames and a cluster of stations would vanish at once (found in the demo).
- **Furnace** (`Furnace` node on the station) owns an input slot, an output slot and a timer. One item per `smelt_time`, while input remains and the output has room, **also when the player is far away** (it ticks in physics time; `advance(dt)` carries the remainder, so tests can run N * smelt_time at once). The state lives on the furnace node (ready for W9 save). Fuel is not in v1 (ponytail: add it if the playtest asks).
- **UI:** see the section "UI: Minecraft-style window, select instead of place" below (it replaced the first side-column version).
- **In the world** a `ProgressCue` above the furnace shows a small bar and a glow on the art while it smelts. No text.
- **Skin.** All looks are new `InventorySkin` fields (group "Crafting panel"). Station art = `art` + `art_region` on the station scene. See [replacing-art](../wiki/replacing-art.md).
- **Start kit** = `wooden_sword` only (`Inventory.start_items`, an @export, in `player.tscn`). `Inventory.give_dev_kit()` (F3 `Give W3 kit`) restores sword, bow, axe, pickaxe and re-arms the sword. Tests that fought with the old kit call it.
- **Copper gear = copies with stronger numbers, same models, tinted** (`WeaponData.model_tint`, applied by `WeaponVisual`).

## The tables
Recipes (`data/recipes/`, `order` = list position):

| Result | Station | Ingredients |
|---|---|---|
| Workbench | by hand | 10 wood |
| Stone pickaxe | workbench | 4 wood, 6 stone |
| Stone axe | workbench | 4 wood, 4 stone |
| Bow (the "wooden bow") | workbench | 8 wood |
| Furnace | workbench | 10 stone, 4 wood |
| Anvil | workbench | 5 copper bars |
| Copper sword | anvil | 6 copper bars, 3 wood |
| Copper axe | anvil | 5 copper bars, 3 wood |
| Copper pickaxe | anvil | 5 copper bars, 3 wood |

Smelting (`data/smelting/`): copper ore -> copper bar, 1 : 1, 3.0 s each. Arrows are not made: the bow has no ammo.

Tools and weapons:

| Item | damage | gather_damage | tool_power | Notes |
|---|---|---|---|---|
| Wooden sword (start) | 20 | - | - | copy of the sword, same lunge skill, brown tint |
| Sword (W3 kit only now) | 30 | - | - | unchanged |
| Copper sword | 40 | - | - | orange tint |
| Stone axe | 8 | 1 | 0 | unchanged; 2 hits on a tree |
| Copper axe | 10 | 2 | 1 | 1 hit on a tree (x3 axe bonus); can mine copper |
| Stone pickaxe | 8 | 1 | 2 | unchanged |
| Copper pickaxe | 10 | 2 | 3 | mines copper twice as fast |

Everything above is data: the F3 panel has a section per recipe (`Recipe <id>`), per smelt recipe (`Smelt <id>`), `Crafter`, `Placer` and each tool.

## UI: one grid of icons, click, put it down (superseded by [0045](0045-ui-port-craft-book.md): click chooses, `Craft` makes)
First version: a side column of rows. Second: a Minecraft-style window with ingredient grid and result slot. The user found that too complex ("a icon of item could craftable and uncraftable, when we click it it shows that item, we just drag it to inventory and that's was craft"). Final version:
- `Tab` / `I` opens **one centred window** (`CraftWindow`): the crafting area on top, the bag (3 x 9, the existing `BagPanel`) and a **copy of the hotbar** below. The HUD hotbar at the top-left hides while it is open (it would show the same slots twice). The boss lock closes it like the bag; a lock icon shows when it cannot open.
- **The crafting area is one grid of result icons, nothing else** (no ingredient grid, arrow or result slot). An icon is **lit** when you can craft it, **dimmed** when you hold at least one of its ingredients ("you are on the way"). Recipes you have nothing for are **hidden** (`Crafter.listed_recipes`). Order: the nearest station's recipes, then the craftable ones, then the rest (each by `order`).
- **Click a lit icon:** the ingredients are taken at that moment and the item lands on the **cursor**, the same held stack as when you pick a stack up in the bag (`Crafter.craft_to_cursor`, `Inventory.hold`). Click again while holding the same item and it stacks one more, up to its max stack. Then **click any bag or hotbar slot** to put it down (the bag's normal click rules). A different held item, or a full stack, refuses. A dimmed icon does nothing but flash red (`craft_flash_color`). Lit = light backdrop, dim = dark backdrop + 45% alpha, so it never depends on the art's colours (the dark anvil). A recipe whose station is out of range is listed dim too (when you hold an ingredient) and its tooltip ends with the missing station's icon in red. The held stack is drawn offset (+8,+8), 1.1x, with a drop shadow (skin `cursor_*`), in the bag too.
- **Click-to-cursor, not drag.** Drag would need a second input path next to the bag's click-to-pick-up. Click then click-slot is the same as moving any bag stack, so it feels the same and adds no code.
- **Shift click a lit icon:** crafts one straight into the inventory (it drops at the player if full: never lost). `craft_many` is removed.
- **Closing the window (or the boss lock closing it) while holding** puts the stack back with the bag's `return_held`: into the inventory, else on the ground at the player. Never lost.
- **Ingredients show only in the hover tooltip**, under the name: small ingredient icons with the need count, red when short (`HudTooltip.watch(..., extra)`, `Crafter.ingredient_status`). The tooltip is a later sibling of the window, so it draws above it.
- **Furnace tab** (a furnace in range, icon tabs, opens on the nearest station's tab, remembers your last choice near the same stations): `[input slot] > [progress arrow that fills] > [output slot]`, the tab pulses while the furnace works. The station marker (icon) shows hand / workbench / anvil when there are no tabs.
- The UI only sends requests (`craft_requested(recipe, straight)`, `furnace_*_clicked`); `Crafter`, `Furnace` and `Inventory` decide.
- Skin: group "Crafting window" in `InventorySkin`. Everything uses the `ItemSlot` scene.
- Cost: the window covers the screen centre while open (the game keeps running behind it).

## Why
- Instant crafting keeps the loop short; the time cost lives in gathering and in the furnace, where it gives the player something to do while it runs (mine more copper).
- One rule for placing (`check_at`) is shared by the ghost, the click and the F3 buttons.
- Reusing `ItemSlot`, the cursor stack and `Inventory.click_slot` rules means the furnace behaves like the bag.

## Consequences
- v1-design section 5 / 10 now read "timed furnace, instant crafting" (edited).
- Any map rebuild (F3 `New map`, sliders) takes every placed station back first: the item and a furnace's contents go to the inventory (else the ground at the player), so nothing is left in water.
- Station size has one owner: the scene's `CollisionShape2D` (`Station.footprint()`); `Station.item` is code-owned. Per-tree meta (not static vars) holds the pickup bookkeeping.
- The anvil art is a drawn placeholder (the Pixel Crawler anvil sheets show no plain anvil).
- Placing is a click on `attack`: with a station selected you cannot swing. Select a weapon to fight.
- A station in the hotbar counts as bare hands (fists out). Maybe odd in the playtest; a hand-holding-a-hammer visual is a later swap.
- Unsure for the playtest: amounts, `craft_radius` 150, `place_distance` 70, smelt time 3 s, list of 5 visible rows (9 recipes in total, it scrolls with the wheel), pickaxe-only pickup.
