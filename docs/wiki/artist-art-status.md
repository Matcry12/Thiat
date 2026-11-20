# Artist art - what we have, where it goes

**Status:** Current

Checked 2026-11-17, last pull 2026-11-20 (16 new files: 8 png + 8 `.pxo`), against the game (pixel by pixel). Files are in `assets/source/artist_inbox/`
(pulled by `tools/pull_artist_art.sh`). Update this page after every pull.

## 1. New art for a feature the game HAS - ready to put in

| Her file | Replaces in game | Size | Note |
|---|---|---|---|
| `Weapons/Swords/Wood Sword.png` | `assets/game/ui/items/wooden_sword.png` | 32x32 | **Swapped 2026-11-20** (was 1024 px different). Art points up now: model angle + grip re-set. Wider blade, so the hit area grew 9.5 -> 14 px wide (measured from the picture, 0061) |
| `Weapons/Axe/Axe.png` | `assets/game/ui/items/axe.png` | 32x32 | **Swapped 2026-11-20** (was 213 px different). Model angle + grip re-set |
| `Weapons/Pickaxe/WooodPickaxe.png` | `assets/game/ui/items/pickaxe.png` | 32x32 | **Swapped 2026-11-20** (was 215 px different). Model angle + grip re-set. Name typo; its `.pxo` is `WoodPickaxe.pxo` |
| `Items/Bowpxo.png` | `assets/game/ui/placeholder/bow.png` | 32x32 (old 16x16) | First real bow art. Parked: bows need a string animation |
| `Weapons/Axe/WoodAxe.png` (pull 2026-11-20) | same as `Weapons/Axe/Axe.png` above | 32x32 | Same pixels as her `Axe.png`; only the name is new |
| `Weapons/Hoe/WoodHoe.png` (pull 2026-11-20) | `assets/game/ui/items/hoe.png` | 32x32 | **Swapped 2026-11-20** (was 181 px different). Model angle + grip re-set |
| `Map/Ground/rock.png`, `rock 2.png`, `rock3.png` (pull 2026-11-20) | pebbles in `assets/game/map/temp/rocks_temp.png` | 32x32 each | Small grey pebbles. Temp sheet is a cut-out, so this is a sheet change, not a file swap |
| `Map/Ground/Herbage.png` (pull 2026-11-20) | `assets/game/map/pixel_plains/tufts.png` | 64x32 (game 112x128, per-biome colours) | Grass tufts, one green. Different layout |
| `Map/Ground/High flower_0002.png` (pull 2026-11-20) | `assets/game/map/pixel_plains/flowers.png` | 64x32 (game 80x160) | Yellow + pink tall flowers. Different layout |

Not swapped yet (rocks, tufts, flowers): wait for the user's OK. Hand positions on the 4 swapped tools: fine-tune in the editor (`scenes/weapons/*_model.tscn`, MainHandGrip / OffHandGrip).

## 2. New art for a feature the game does NOT have yet

These 7 are in the game as plain items (icon only, `material`, via `tools/add_items.py`; see Test yard, book tab Items). They have NO effect yet: no food, potion or key system exists. The effect waits until the feature is designed (algorithm first, AGENTS.md §8).

| Her file (now an item) | Needs feature for its effect | Backlog |
|---|---|---|
| `Items/Foods/Bread.png`, `Pork.png`, `cooked pork.png.png`, `soup.png`, `Xucxich.png` (sausage) | Food: eat to heal / fill hunger; cooking pork in a furnace? | not listed yet |
| `Items/Potions/healingpotion.png` | Healing potion (craft + drink) | `backlog.md`: berries / mushrooms / flowers -> healing potion |
| `Items/Key.png` | Key + something locked (chest, door, boss altar?) | not listed yet |

Not in the game at all yet:

| Her file | Needs feature | Note |
|---|---|---|
| `Weapons/Shovel/WoodShovel.png` (pull 2026-11-20) | Digging (shovel tool) | `add_weapon.py` has no `shovel` kind; no dig system |

## 3. Templates we gave her - not new work

Identical to the game files (same pixels). Nothing to do. When she redraws one, keep the size and frame layout.

| Her file | Same as | Size / frames |
|---|---|---|
| `Characters/Template/idle.png`, `run.png`, `death.png` | `assets/game/characters/pixel_plains/idle.png`, `run.png`, `roll_move.png` | 3x 12x17, 4x 12x17, 10x 30x16 |
| `Map/Ground/*.png` (9 sheets: cobble, dirt, grass_dark, grass_light, sand, snow, gravel, water, foam) | `assets/game/map/pixel_plains/ground/` | 192x208; water 256x528; foam 512x64 |
| `Map/Flowers/flowers.png` | `assets/game/map/pixel_plains/flowers.png` | 80x160 |
| `Map/Trees/oaks.png` | `assets/game/map/pixel_plains/oaks_noshadow.png` (game draws per-biome copies) | 288x540 |
| `Map/Trees/hedges.png` | `assets/game/map/pixel_plains/hedges.png` (hedges are off in every biome) | 160x448 |
| `Weapons/Swords/Glide.png` | `assets/game/ui/items/glide.png` | 64x64 |

## Ask the artist

- Names: `snake_case`, no spaces, one extension. `Wood Sword.png` -> `wood_sword.png`, `cooked pork.png.png` -> `cooked_pork.png`, `WooodPickaxe` -> `wood_pickaxe`, `Bowpxo` -> `bow`, `rock 2.png` -> `rock_2.png`, `High flower_0002.png` -> `high_flower.png`.
- Map props: tell us how they fit the game sheets (tufts 112x128 per biome colour, flowers 80x160).
- Do not put Godot `.import` files on Drive (there are 9 in `Map/Ground/`). The pull script skips them now.
