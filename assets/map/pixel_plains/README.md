# Map art — Pixel Plains (official folder)

All map art the game draws comes from this folder. Pack: SnowHex "Pixel Plains" (https://snowhex.itch.io/pixel-plains), credit
required, see `assets/third_party/README.md`. Pack pixels only: new looks are recolours of pack pixels, never new drawing.
**Rule: map art changed → update this README in the same change** (CLAUDE.md).

| File | What it is | In game | Used by | Source |
|---|---|---|---|---|
| `tiles.png` | The pack's ground sheet (grass, dark grass, dirt quarters + fills, decal cells). Sand, snow and flat water are recoloured from it at bake time | yes | `data/maps/ground_pixel_plains.tres` → `scripts/map/pixel_plains_baker.gd` | Byte copy of `assets/third_party/pixel_plains/New Basic Tiles Free.png` (the pack folder has `.gdignore`) |
| `oaks.png` | Oaks, 4 sizes x 2 tones, one row per season (green, autumn orange, yellow, red, snow), with the pack's ground shadow under the trunk | off (`ResourceNodeData.ground_shadow` = false on every oak) | `data/resource_nodes/treepp_oak_*.tres` (`texture`) | Recolour of `Trees and bushes.png`: `tools/art_tests/recolour_game/build.py` |
| `oaks_noshadow.png` | Same sheet and layout, ground shadow pixels cleared | yes | `data/resource_nodes/treepp_oak_*.tres` (`texture_no_shadow`) | `build.py` (same run) |
| `hedges.png` | Hedge pieces per season (long wall, caps, post, frame, block, end), plus logs and the stump | hedge caps off (`PixelPlainsGround.show_hedges` all 0); stump yes (a chopped oak's remains) | caps: `data/maps/prop_pp_hedges.tres`; stump: `treepp_oak_*.tres` (`remains_texture`) | Recolour of `Trees and bushes.png`: `build.py` |
| `flowers.png` | Flower decal cells, one row per colour (pink, blue, yellow, orange, mint) | yes (`PixelPlainsGround.show_flowers` per biome) | `data/maps/prop_pp_flowers.tres` | Recolour of the decal cells of `New Basic Tiles Free.png`: `build.py` |
| `tufts.png` | Grass tuft decal cells, light + dark grass rows per colour (green, yellow, brown, snow) | yes (`PixelPlainsGround.show_tufts` per biome) | `data/maps/prop_pp_tufts.tres` | Recolour of the decal cells: `build.py` |
| `manifest.json` | Every sprite of the 4 prop sheets: region, foot anchor, collision radius, kind, season, biomes | — (data) | read by `tools/art_tests/recolour_game/export_game_data.py`, which writes the `.tres` above | `build.py` |

`manifest.json` stays separate from this table: it lists every sprite (181 regions) for the exporter, this README lists files for people.
`build.py` writes both the sheets and the manifest in one run, so they cannot drift; re-run `export_game_data.py` after it.

## Old art (not in game)

Still in `assets/map/` (not moved, not deleted). Only the old ground look (`MapStyle.pixel_plains` = null) or the switched-off data uses it.

| File | What it was | Why it is off |
|---|---|---|
| `assets/map/Rocks.png` | Old rocks + copper ore (`data/resource_nodes/rock.tres`, `copper_rock.tres`), rock-group pebbles (`data/maps/prop_rocks.tres`) | Not Pixel Plains style: `rock_per_block`, `rock_nodes_per_100`, `copper_per_100` = 0 in every biome, `rock.density_boss` = 0, `copper_near_home_cells` = 0. So no stone / copper source on the map yet |
| `assets/map/Vegetation.png` | Old bushes, stumps, reeds, mushrooms, ferns (`data/maps/prop_veg.tres`) | `PixelPlainsGround.show_other` all 0 |
| `assets/map/Floors_Tiles.png` | Old ground (`data/maps/ground_dirt.tres`, `ground_sand.tres`, `ground_boss.tres`) | The Pixel Plains baker replaces it |
| `assets/map/Water_tiles.png` | Old water edges (`data/maps/grass.tres`) | Flat water shader (`scripts/map/terrain_water_flat.gdshader`) |

Not Pixel Plains but still in game: `assets/map/campfire.png` (the home campfire, `scenes/world/home_point.tscn`).
