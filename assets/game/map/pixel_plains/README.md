# Map art — Pixel Plains (official folder)

All map art the game draws comes from this folder. Pack: SnowHex "Pixel Plains" (https://snowhex.itch.io/pixel-plains), credit
required, see `assets/source/third_party/README.md`. Pack pixels only: new looks are recolours of pack pixels, never new drawing (ground sheets: baked once from the pack, then yours to redraw).
**Rule: map art changed → update this README in the same change** (CLAUDE.md).

| File | What it is | In game | Used by | Source |
|---|---|---|---|---|
| `tiles.png` | The pack's ground sheet (grass, dark grass, dirt quarters + fills, decal cells). Still loaded: the pack's own edge pairs, quarters and the edge shapes (the role map) come from it. Pixels never change; copy kept in `assets/source/map/pixel_plains_original/tiles.png` | yes | `data/maps/ground_pixel_plains.tres` (`texture`) → `scripts/map/pixel_plains_baker.gd` | Byte copy of `assets/source/third_party/pixel_plains/New Basic Tiles Free.png` (`assets/source/` has `.gdignore`) |
| `ground/*.png` (7) | One sheet per ground, same size + cell layout as `tiles.png`: `dirt`, `grass_light`, `grass_dark`, `sand`, `snow`, `cobble`, `gravel` (table below). Cobble starts as a copy of dirt, gravel of sand | yes | `data/maps/ground_pixel_plains.tres` (`sheet_*`) → `PixelPlainsBaker` (`_fill`, `palette`) | `tools/bake_ground_art.gd` (`timeout 300 godot --headless --script tools/bake_ground_art.gd`; re-running overwrites hand-drawn changes). The test only checks the sheets exist, load and are readable; it does not compare them with the tool |
| `oaks.png` | Oaks, 4 sizes x 2 tones, one row per season (green, autumn orange, yellow, red, snow), with the pack's ground shadow under the trunk | off (`ResourceNodeData.ground_shadow` = false on every oak) | `data/resource_nodes/treepp_oak_*.tres` (`texture`) | Recolour of `Trees and bushes.png`: `tools/art_tests/recolour_game/build.py` |
| `oaks_noshadow.png` | Same sheet and layout, ground shadow pixels cleared | yes | `data/resource_nodes/treepp_oak_*.tres` (`texture_no_shadow`) | `build.py` (same run) |
| `hedges.png` | Hedge pieces per season (long wall, caps, post, frame, block, end), plus logs and the stump | hedge caps off (`PixelPlainsGround.show_hedges` all 0); stump yes (a chopped oak's remains) | caps: `data/maps/prop_pp_hedges.tres`; stump: `treepp_oak_*.tres` (`remains_texture`) | Recolour of `Trees and bushes.png`: `build.py` |
| `flowers.png` | Flower decal cells, one row per colour (pink, blue, yellow, orange, mint) | yes (`PixelPlainsGround.show_flowers` per biome) | `data/maps/prop_pp_flowers.tres` | Recolour of the decal cells of `New Basic Tiles Free.png`: `build.py` |
| `tufts.png` | Grass tuft decal cells, light + dark grass rows per colour (green, yellow, brown, snow) | yes (`PixelPlainsGround.show_tufts` per biome) | `data/maps/prop_pp_tufts.tres` | Recolour of the decal cells: `build.py` |
| `assets/source/map/pixel_plains/manifest.json` | Every sprite of the 4 prop sheets: region, foot anchor, collision radius, kind, season, biomes | — (data) | read by `tools/art_tests/recolour_game/export_game_data.py`, which writes the `.tres` above | `build.py` |

### Ground sheets: what the game reads

| Sheet | Fill tiles (cells of `plain_*` / `variants_*`) | Swatch (4 squares of 4 px, left to right: fill, highlight, outline, shade, from the top-left of cell 0,12) | Redraw changes |
|---|---|---|---|
| `dirt`, `grass_light`, `grass_dark` | the pack's tiles | read for borders: the fill colour of flat edges, highlight + outline of step edges, shade = shadow cast onto this ground | the plain look of that ground; its border colours |
| `sand`, `snow` | dirt tiles recoloured | same | the plain look; its border colours |
| `cobble`, `gravel` | only for cells that are cobble / beach gravel on all 4 corners | NOT read: borders and mixed corners use the `dirt` / `sand` sheet | the plain look of pure cobble / gravel cells only |

Water has no sheet (flat shader colour). Boss ground is dirt on the map. A missing `sheet_*` falls back to the dirt sheet with a warning.

`manifest.json` lives in `assets/source/map/pixel_plains/` (only tools read it, not the game) and stays separate from this table: it lists every sprite (181 regions) for the exporter, this README lists files for people.
`build.py` writes both the sheets and the manifest in one run, so they cannot drift; re-run `export_game_data.py` after it.

## Old art (retired)

Moved (not deleted): `Floors_Tiles.png` (old ground) and `Water_tiles.png` (old water edges) to `assets/retired/map/`; the original `Rocks.png` to `assets/source/map/`. The old ground path is gone with them (`MapStyle.grounds`, `GroundData`, the old `GroundBaker` bake; their data is in `assets/retired/data/maps/`: `ground_*.tres`). The flat test map (`island_on = false`) draws no ground tiles any more.

Rocks, copper ore and pebbles still draw from `assets/game/map/temp/rocks_temp.png`: a temporary cut-out of the original `Rocks.png` (see `temp/README.md`), replace with new art. Used by `data/resource_nodes/rock.tres`, `copper_rock.tres`, `data/maps/prop_rocks.tres`, and the pebble / obstacle sets in `data/maps/grass.tres`. `rock_per_block`, `rock_nodes_per_100`, `copper_per_100` = 0 in every biome, `rock.density_boss` = 0, `copper_near_home_cells` = 0, so there is no stone / copper source on the island yet (Test yard has them).

Retired (moved, not deleted, to `assets/retired/`): `map/Vegetation.png`, `characters/player/player_character_template.png` (old player body), `world/trees.png`, `world/trees/*` (old bushes, stumps and tree sheets), with the old tree nodes (`data/resource_nodes/tree.tres`, `tree_*.tres`), `data/maps/prop_veg.tres`, `prop_stump_*.tres` (under `assets/retired/data/`) and the old bush border. The Pixel Plains oaks (`treepp_*`) and `pp_*` sets are the only vegetation now.

Not Pixel Plains but still in game: `assets/game/map/campfire.png` (the home campfire, `scenes/world/home_point.tscn`).
