# Map art — Pixel Plains (official folder)

All map art the game draws comes from this folder. Pack: SnowHex "Pixel Plains" (https://snowhex.itch.io/pixel-plains), credit
required, see `assets/source/third_party/README.md`. Pack pixels only: new looks are recolours of pack pixels, never new drawing (ground sheets: baked once from the pack, then yours to redraw).
**Rule: map art changed → update this README in the same change** (CLAUDE.md).

| File | What it is | In game | Used by | Source |
|---|---|---|---|---|
| `tiles.png` | The pack's ground sheet (grass, dark grass, dirt quarters + fills, decal cells). Still loaded: the pack's own edge pairs, quarters and the edge shapes (the role map) come from it. Pixels never change; copy kept in `assets/source/map/pixel_plains_original/tiles.png` | yes | `data/maps/ground_pixel_plains.tres` (`texture`) → `scripts/map/pixel_plains_baker.gd` | Byte copy of `assets/source/third_party/pixel_plains/New Basic Tiles Free.png` (`assets/source/` has `.gdignore`) |
| `ground/*.png` (7) | One sheet per ground, same size + cell layout as `tiles.png`: `dirt`, `grass_light`, `grass_dark`, `sand`, `snow`, `cobble`, `gravel` (table below). Cobble starts as a copy of dirt, gravel of sand. The first five also hold the edge tiles (cells 0..3 of rows 1..4) | yes | `data/maps/ground_pixel_plains.tres` (`sheet_*`) → `PixelPlainsBaker` (`_fill`, `_slot`, `palette`) | `tools/bake_ground_art.gd` (`timeout 300 godot --headless --script tools/bake_ground_art.gd`; re-running overwrites hand-drawn changes) writes the sheets; `-- tiles` writes only the edge tiles + `foam.png` + `water.png`. The test checks the sheets exist, load, are the right size; not that they equal the tool |
| `ground/foam.png` (512x64) | Beach foam: 8 frames left to right, each 4x4 slots of 16 px; slot = the sand's corner mask 1..14. Foam colour where lit, transparent else | yes | `ground_pixel_plains.tres` (`foam_texture`) → `PixelPlainsBaker` (animation mask) → `terrain_anim.gdshader` | `bake_ground_art.gd -- tiles`, then redraw |
| `ground/water.png` (256 wide) | Water: cell (0,0), all 16x16 px = flat water, tiled by the open-water shader and the shore tiles (open water with no mark, and under mixed corners); below it one row of 8 frames of 32x32 per wave mark variant (16 rows, add a row = one more variant) | yes | `ground_pixel_plains.tres` (`water_texture`) → `PixelPlainsBaker.water_colour`, `terrain_water_flat.gdshader` | `bake_ground_art.gd -- tiles`, then redraw |
| `oaks_noshadow.png` | Oaks, 4 sizes x 2 tones, one row per season (green, autumn orange, yellow, red, snow), no ground shadow. The ORIGINAL: only the fallback now (the game draws `biomes/<biome>/oaks.png`) | fallback | `data/resource_nodes/treepp_oak_*.tres` (`texture`) | Recolour of `Trees and bushes.png`: `tools/art_tests/recolour_game/build.py`. The old shadow version `oaks.png` (never drawn) is in `assets/retired/map/pixel_plains/` |
| `biomes/<biome>/oaks.png`, `hedges.png` | One oaks + one hedges sheet per biome (`plains forest autumn taiga snowy rocky swamp beach_sand beach_gravel`), same size + layout as the originals, so redraw one biome without touching the others. Start as byte copies. A tree or hedge in biome X draws from X's sheet with the same region; a missing file falls back to the original sheet | yes | `scripts/map/biome_art.gd` (`BiomeArt.sheet`, data `data/maps/biome_art.tres`: `enabled`, `folder`) from `ResourceNodeVisual`, `ChunkDeco` | `tools/bake_biome_art.gd` (`timeout 120 godot --headless --script tools/bake_biome_art.gd`; writes only missing files, `-- --force` overwrites). After adding files run `godot --headless --import`. F3 `[Map]` ground text shows loaded / missing sheets |
| `hedges.png` | Hedge pieces per season (long wall, caps, post, frame, block, end), plus logs and the stump | hedge caps off (`PixelPlainsGround.show_hedges` all 0); stump yes (a chopped oak's remains) | caps: `data/maps/prop_pp_hedges.tres`; stump: `treepp_oak_*.tres` (`remains_texture`) | Recolour of `Trees and bushes.png`: `build.py` |
| `flowers.png` | Flower decal cells, one row per colour (pink, blue, yellow, orange, mint) | yes (`PixelPlainsGround.show_flowers` per biome) | `data/maps/prop_pp_flowers.tres` | Recolour of the decal cells of `New Basic Tiles Free.png`: `build.py` |
| `tufts.png` | Grass tuft decal cells, light + dark grass rows per colour (green, yellow, brown, snow) | yes (`PixelPlainsGround.show_tufts` per biome) | `data/maps/prop_pp_tufts.tres` | Recolour of the decal cells: `build.py` |
| `assets/source/map/pixel_plains/manifest.json` | Every sprite of the 4 prop sheets: region, foot anchor, collision radius, kind, season, biomes | — (data) | read by `tools/art_tests/recolour_game/export_game_data.py`, which writes the `.tres` above | `build.py` |

### Ground pictures: which cells the game reads, what a redraw changes

Slot s (1..15) = cell (s % 4, 1 + s / 4) of a ground's sheet; s = corner mask NW 1, NE 2, SW 4, SE 8, a bit set when that cell is this ground or a higher one (priority water < sand < dirt < light < dark < snow).
Alpha 0 in a slot = the lower ground shows. Slot 15 = the base of that ground (when it is the lowest in a mixed corner). A redraw is read after F3 > Pixel Plains > "Reload ground pictures" (no editor re-import needed); re-running `bake_ground_art.gd -- tiles` overwrites it.

| File | Cells the game reads | What a redraw changes |
|---|---|---|
| `dirt`, `grass_light`, `grass_dark` | fill tiles (`plain_*` / `variants_*` cells); slots 1..14 (edge over the ground below), slot 15 (flat base) | the plain look; the border where this ground lies over another; this ground as the base of a mixed corner |
| `sand`, `snow` | same | same. Sand's edge over water has no shadow pixels: the water base shows |
| `cobble`, `gravel` | fill tiles only (cells that are cobble / gravel on all 4 corners); borders and mixed corners use `dirt` / `sand` | the plain look of pure cobble / gravel cells |
| `foam.png` | slot = sand mask, frame f at x + f * 64 | where the beach foam is lit, in which frame, its colour |
| `water.png` | cell (0,0): flat water; rows below: wave marks | the water colour everywhere, the wave marks of open water |
| swatch (cell 0,12 of the five sheets) | NOT read by the game any more: only by `bake_ground_art.gd -- tiles` as its colour input | nothing in the game |

Boss ground is dirt on the map. A missing `sheet_*` falls back to the dirt sheet with a warning. Per-biome ground: `biomes/<biome>/ground/<file>.png` (the 7 sheets + `foam.png` + `water.png`, same layout; byte copies today, written by `bake_ground_art.gd -- biomes`, missing files only, `--force` overwrites, then `godot --headless --import`). Each layer of a corner reads the files of the biome of the first cell (NW NE SW SE) holding that ground, fills the NW cell; a missing file falls back to the base `ground/` file. The open-water sprite (`terrain_water_flat.gdshader`) always uses the base `water.png`; only mixed corners read a biome's water cell. Redrawing a base `ground/` file does not change biome cells while their own copy exists.

`manifest.json` lives in `assets/source/map/pixel_plains/` (only tools read it, not the game) and stays separate from this table: it lists every sprite (181 regions) for the exporter, this README lists files for people.
`build.py` writes both the sheets and the manifest in one run, so they cannot drift; re-run `export_game_data.py` after it.

## Old art (retired)

Moved (not deleted): `Floors_Tiles.png` (old ground) and `Water_tiles.png` (old water edges) to `assets/retired/map/`; the original `Rocks.png` to `assets/source/map/`. The old ground path is gone with them (`MapStyle.grounds`, `GroundData`, the old `GroundBaker` bake; their data is in `assets/retired/data/maps/`: `ground_*.tres`). The flat test map (`island_on = false`) draws no ground tiles any more.

Rocks, copper ore and pebbles still draw from `assets/game/map/temp/rocks_temp.png`: a temporary cut-out of the original `Rocks.png` (see `temp/README.md`), replace with new art. Used by `data/resource_nodes/rock.tres`, `copper_rock.tres`, `data/maps/prop_rocks.tres`, and the pebble / obstacle sets in `data/maps/grass.tres`. `rock_per_block`, `rock_nodes_per_100`, `copper_per_100` = 0 in every biome, `rock.density_boss` = 0, `copper_near_home_cells` = 0, so there is no stone / copper source on the island yet (Test yard has them).

Retired (moved, not deleted, to `assets/retired/`): `map/Vegetation.png`, `characters/player/player_character_template.png` (old player body), `world/trees.png`, `world/trees/*` (old bushes, stumps and tree sheets), with the old tree nodes (`data/resource_nodes/tree.tres`, `tree_*.tres`), `data/maps/prop_veg.tres`, `prop_stump_*.tres` (under `assets/retired/data/`) and the old bush border. The Pixel Plains oaks (`treepp_*`) and `pp_*` sets are the only vegetation now.

Not Pixel Plains but still in game: `assets/game/map/campfire.png` (the home campfire, `scenes/world/home_point.tscn`).
