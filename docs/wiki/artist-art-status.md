# Artist art - what we have, where it goes

**Status:** Current

Checked 2026-11-17 against the game (pixel by pixel). Files are in `assets/source/artist_inbox/`
(pulled by `tools/pull_artist_art.sh`). Update this page after every pull.

## 1. New art for a feature the game HAS - ready to put in

| Her file | Replaces in game | Size | Note |
|---|---|---|---|
| `Weapons/Swords/Wood Sword.png` | `assets/game/ui/items/wooden_sword.png` | 32x32 | Redraw (1024 px differ) |
| `Weapons/Axe/Axe.png` | `assets/game/ui/items/axe.png` | 32x32 | Redraw (213 px differ) |
| `Weapons/Pickaxe/WooodPickaxe.png` | `assets/game/ui/items/pickaxe.png` | 32x32 | Redraw (215 px differ). Name typo; its `.pxo` is `WoodPickaxe.pxo` |
| `Items/Bowpxo.png` | `assets/game/ui/placeholder/bow.png` | 32x32 (old 16x16) | First real bow art. Weapons go in via `tools/add_weapon.py` |

## 2. New art for a feature the game does NOT have yet

No food, potion or key system exists. This art waits until the feature is designed (algorithm first, AGENTS.md §8).

| Her file | Needs feature | Backlog |
|---|---|---|
| `Items/Foods/Bread.png`, `Pork.png`, `cooked pork.png.png`, `soup.png`, `Xucxich.png` (sausage) | Food: eat to heal / fill hunger; cooking pork in a furnace? | not listed yet |
| `Items/Potions/healingpotion.png` | Healing potion (craft + drink) | `backlog.md`: berries / mushrooms / flowers -> healing potion |
| `Items/Key.png` | Key + something locked (chest, door, boss altar?) | not listed yet |

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

- Names: `snake_case`, no spaces, one extension. `Wood Sword.png` -> `wood_sword.png`, `cooked pork.png.png` -> `cooked_pork.png`, `WooodPickaxe` -> `wood_pickaxe`, `Bowpxo` -> `bow`.
- Do not put Godot `.import` files on Drive (there are 9 in `Map/Ground/`). The pull script skips them now.
