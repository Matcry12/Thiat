class_name PixelPlainsGround
extends Resource
## The Pixel Plains ground (SnowHex pack), as DATA: which 8x8 quarter of which 16 px tile of the sheet draws what. GroundBaker
## builds the picture from it (dual grid, quarter by quarter) with the pack's own pixels, no tint, no mirror, no rotation.
## Generated from tools/asset_viewer/pixel_plains_tiles.py by tools/asset_viewer/pixel_plains_export_tres.py: edit the .tres in F3,
## or change the python table and export again. MapStyle.pixel_plains = null brings the old ground look back.
## Materials: DIRT 0, LIGHT grass 1, DARK grass 2 (the pack's own art), SAND 3, SNOW 4 (dirt art recoloured), WATER 5 (flat colour, drawn by
## PixelPlainsBaker). NONE (-1) = water in a map cell array. Slice 2: every cell also has a LEVEL (see Levels below, decision 0046).

enum Mat { NONE = -1, DIRT, LIGHT, DARK, SAND, SNOW, WATER }
## An entry of a case table that is not a pack quarter: the plain quarter of the upper / lower material.
const UPPER := -1
const LOWER := -2

@export var texture: Texture2D:
	set(v):
		texture = v
		_touch()
@export var tile_size := 16:
	set(v):
		tile_size = v
		_touch()
## Per MapGen.Ground (WATER DIRT COBBLE GRASS BOSS SAND SNOW): its material. GRASS is light or dark by biome (`dark_biomes`).
@export var ground_material := PackedInt32Array([-1, 0, 0, 1, 0, 3, 4]):
	set(v):
		ground_material = v
		_touch()
## Per MapStyle.biomes index: 1 = grass of this biome is DARK grass (forest, taiga, swamp).
@export var dark_biomes := PackedInt32Array([0, 1, 0, 1, 0, 0, 1, 0, 0]):
	set(v):
		dark_biomes = v
		_touch()
## Map rule: a dark cell with dirt within this many cells (8 neighbours) becomes light grass (the pack has no dark-on-dirt edge). 0 = off.
@export_range(0, 3) var dark_dirt_gap := 1:
	set(v):
		dark_dirt_gap = v
		_touch()
## Who lies on top where two materials touch: dirt, light, dark (higher wins).
@export var layer_dirt := 1:
	set(v):
		layer_dirt = v
		_touch()
@export var layer_light := 5:
	set(v):
		layer_light = v
		_touch()
@export var layer_dark := 6:
	set(v):
		layer_dark = v
		_touch()
## Whole 16 px tiles (col, row) per material. Plain ones most of the time (`plain_weight`), the rare variants otherwise.
@export var plain_dirt: Array[Vector2i] = []:
	set(v):
		plain_dirt = v
		_touch()
@export var plain_light: Array[Vector2i] = []:
	set(v):
		plain_light = v
		_touch()
@export var plain_dark: Array[Vector2i] = []:
	set(v):
		plain_dark = v
		_touch()
@export var variants_dirt: Array[Vector2i] = []:
	set(v):
		variants_dirt = v
		_touch()
@export var variants_light: Array[Vector2i] = []:
	set(v):
		variants_light = v
		_touch()
@export var variants_dark: Array[Vector2i] = []:
	set(v):
		variants_dark = v
		_touch()
@export_range(0.0, 1.0, 0.01) var plain_weight := 0.85:
	set(v):
		plain_weight = v
		_touch()
## The plain 8x8 quarter of each material: (col, row, slot) slot 0 TL 1 TR 2 BL 3 BR.
@export var quarter_dirt := Vector3i(9, 8, 0):
	set(v):
		quarter_dirt = v
		_touch()
@export var quarter_light := Vector3i(10, 7, 0):
	set(v):
		quarter_light = v
		_touch()
@export var quarter_dark := Vector3i(10, 11, 0):
	set(v):
		quarter_dark = v
		_touch()
## The 16 dual-grid cases per pair, 64 entries: mask * 4 + quadrant (NW NE SW SE). Mask bits NW 1, NE 2, SW 4, SE 8, set = UPPER material.
## Entry (col, row, slot) = a pack quarter; (-1, 0, 0) = upper plain quarter; (-2, 0, 0) = lower plain quarter.
@export var table_light_on_dirt: Array[Vector3i] = []:
	set(v):
		table_light_on_dirt = v
		_touch()
@export var table_dark_on_light: Array[Vector3i] = []:
	set(v):
		table_dark_on_light = v
		_touch()
## Trees and floor plants (slice 3): the recoloured pack art, per biome (MapStyle.biomes index). 1 = drawn there, 0 = hidden (the pack has no art
## for it, or none that fits). Filled from the manifest by tools/art_tests/recolour_game/export_game_data.py; the old art stays in the code.
## trees = oaks (gatherable; other models / dead colours: nothing), hedges = the one-cell hedge pieces standing in for bushes,
## other = everything else (fir / pine, rock stones, bushes, mushrooms, foxglove, reeds, stumps). A change rebuilds the map.
@export var show_trees := PackedInt32Array([1, 1, 1, 0, 1, 1, 1, 0, 0]):
	set(v):
		show_trees = v
		_touch()
## Oak colour (BiomeData.SEASONS index) that stands where the biome's tree table asks for one the pack lacks (dead, teal). -1 = nothing stands there.
## Filled from the manifest (the oak variant made for that biome) by export_game_data.py.
@export var tree_fallback_season := PackedInt32Array([0, 0, 1, -1, 6, 0, 0, -1, -1]):
	set(v):
		tree_fallback_season = v
		_touch()
@export var show_flowers := PackedInt32Array([1, 1, 1, 1, 0, 0, 1, 0, 0]):
	set(v):
		show_flowers = v
		_touch()
@export var show_tufts := PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 0, 0]):
	set(v):
		show_tufts = v
		_touch()
@export var show_hedges := PackedInt32Array([1, 1, 1, 0, 0, 0, 0, 0, 0]):
	set(v):
		show_hedges = v
		_touch()
@export var show_other := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0]):
	set(v):
		show_other = v
		_touch()
## Master switches on top of the per-biome ones: true = no trees at all / no biome plants at all.
@export var hide_trees := false:
	set(v):
		hide_trees = v
		_touch()
@export var hide_veg := false:
	set(v):
		hide_veg = v
		_touch()


## Is `kind` (trees flowers tufts hedges other) drawn in biome `b`? Master switches included.
func shows(kind: StringName, b: int) -> bool:
	if hide_trees and kind == &"trees" or hide_veg and kind != &"trees":
		return false
	var a: PackedInt32Array = get("show_" + String(kind))
	return b >= 0 and b < a.size() and a[b] == 1


## A table / switch changed (F3): forget the built pieces and tell the map.
func _touch() -> void:
	PixelPlainsBaker.clear_cache()
	emit_changed()


func layer_of(m: int) -> int:
	return [layer_dirt, layer_light, layer_dark][m]


func quarter_of(m: int) -> Vector3i:
	return [quarter_dirt, quarter_light, quarter_dark][m]


func plain_of(m: int) -> Array[Vector2i]:
	return [plain_dirt, plain_light, plain_dark][m]


func variants_of(m: int) -> Array[Vector2i]:
	return [variants_dirt, variants_light, variants_dark][m]


## Material of a cell before the map rule.
func material_of(ground: int, biome: int) -> int:
	var m := ground_material[ground] if ground < ground_material.size() else int(Mat.NONE)
	if m == Mat.LIGHT and ground == MapGen.Ground.GRASS and biome >= 0 and biome < dark_biomes.size() and dark_biomes[biome] == 1:
		return Mat.DARK
	return m


# ---- Slice 2 (0046): levels, step / flat borders, new grounds, flat water ----------------------------------------------------
## Everything below is a first pick, tune by eye (F3). Colours are the ones of tools/art_tests/recolour/borders.py (the approved demo).
## Level of a cell: who stands higher. A different level = STEP border (outline, highlight, shadow down-right in the LOWER ground's shade);
## the same level = FLAT border (same shapes, no shadow, outline = upper fill a bit darker). Material priority only breaks ties.


@export_group("Levels")

## All flat: every cell is on one level, so every border is flat (no step shadows, also dark / light grass and grass / dirt) and sand meets water with foam.
## Off = the per-ground levels below (steps). User pick after playtest: levels looked chaotic.
@export var all_flat := true:
	set(v):
		all_flat = v
		_touch()

## Water.
@export_range(0, 9) var level_water := 0:
	set(v):
		level_water = v
		_touch()

## Beach sand (biome beach): level with the water = flat beach with animated foam.
@export_range(0, 9) var level_beach_sand := 0:
	set(v):
		level_beach_sand = v
		_touch()

## Sand on the shore of a river / lake: above the water = a step (sand bank).
@export_range(0, 9) var level_bank_sand := 1:
	set(v):
		level_bank_sand = v
		_touch()

## Sand anywhere else (desert): level with grass = flat edge.
@export_range(0, 9) var level_inland_sand := 2:
	set(v):
		level_inland_sand = v
		_touch()

## Dirt, cobble, boss ground: below grass.
@export_range(0, 9) var level_dirt := 1:
	set(v):
		level_dirt = v
		_touch()

## Light and dark grass.
@export_range(0, 9) var level_grass := 2:
	set(v):
		level_grass = v
		_touch()

## Snow inside a snowy biome: level with grass = flat.
@export_range(0, 9) var level_snow := 2:
	set(v):
		level_snow = v
		_touch()

## Snow with a land cell of another biome next to it (8 neighbours): above grass = step.
@export_range(0, 9) var level_snow_edge := 3:
	set(v):
		level_snow_edge = v
		_touch()

## Flat border: the outline pixels are the upper fill this much darker.
@export_range(0.0, 0.5, 0.01) var quiet_darken := 0.08:
	set(v):
		quiet_darken = v
		_touch()

@export_group("Material colours")

## dirt: fill, highlight and outline of its edge when it is the UPPER ground, shade = shadow cast ONTO it.
@export var dirt_fill := Color8(240, 181, 65):
	set(v):
		dirt_fill = v
		_touch()

@export var dirt_hl := Color8(250, 208, 112):
	set(v):
		dirt_hl = v
		_touch()

@export var dirt_outline := Color8(150, 100, 60):
	set(v):
		dirt_outline = v
		_touch()

@export var dirt_shade := Color8(189, 106, 98):
	set(v):
		dirt_shade = v
		_touch()

## light: fill, highlight and outline of its edge when it is the UPPER ground, shade = shadow cast ONTO it.
@export var light_fill := Color8(99, 171, 63):
	set(v):
		light_fill = v
		_touch()

@export var light_hl := Color8(164, 196, 67):
	set(v):
		light_hl = v
		_touch()

@export var light_outline := Color8(42, 89, 79):
	set(v):
		light_outline = v
		_touch()

@export var light_shade := Color8(59, 125, 79):
	set(v):
		light_shade = v
		_touch()

## dark: fill, highlight and outline of its edge when it is the UPPER ground, shade = shadow cast ONTO it.
@export var dark_fill := Color8(59, 125, 79):
	set(v):
		dark_fill = v
		_touch()

@export var dark_hl := Color8(99, 171, 63):
	set(v):
		dark_hl = v
		_touch()

@export var dark_outline := Color8(42, 89, 79):
	set(v):
		dark_outline = v
		_touch()

@export var dark_shade := Color8(42, 89, 79):
	set(v):
		dark_shade = v
		_touch()

## sand: fill, highlight and outline of its edge when it is the UPPER ground, shade = shadow cast ONTO it.
@export var sand_fill := Color8(236, 214, 150):
	set(v):
		sand_fill = v
		_touch()

@export var sand_hl := Color8(248, 232, 182):
	set(v):
		sand_hl = v
		_touch()

@export var sand_outline := Color8(150, 112, 84):
	set(v):
		sand_outline = v
		_touch()

@export var sand_shade := Color8(170, 134, 100):
	set(v):
		sand_shade = v
		_touch()

## snow: fill, highlight and outline of its edge when it is the UPPER ground, shade = shadow cast ONTO it.
@export var snow_fill := Color8(240, 246, 252):
	set(v):
		snow_fill = v
		_touch()

@export var snow_hl := Color8(255, 255, 255):
	set(v):
		snow_hl = v
		_touch()

@export var snow_outline := Color8(150, 170, 204):
	set(v):
		snow_outline = v
		_touch()

@export var snow_shade := Color8(214, 228, 242):
	set(v):
		snow_shade = v
		_touch()

## water: fill, highlight and outline of its edge when it is the UPPER ground, shade = shadow cast ONTO it.
@export var water_fill := Color8(112, 210, 228):
	set(v):
		water_fill = v
		_touch()

@export var water_hl := Color8(112, 210, 228):
	set(v):
		water_hl = v
		_touch()

@export var water_outline := Color8(112, 210, 228):
	set(v):
		water_outline = v
		_touch()

@export var water_shade := Color8(30, 88, 140):
	set(v):
		water_shade = v
		_touch()

@export_group("Recolour (sand, snow = dirt art)")
## Sand fills: plain dirt-art tile only (true = clean fill, no patch squares) or its rare variants too.

## The pack's dirt colours that sand / snow replace: fill, darker patch, shadow.
@export var src_dirt_fill := Color8(240, 181, 65):
	set(v):
		src_dirt_fill = v
		_touch()

@export var src_dirt_patch := Color8(235, 150, 61):
	set(v):
		src_dirt_patch = v
		_touch()

@export var src_dirt_shadow := Color8(189, 106, 98):
	set(v):
		src_dirt_shadow = v
		_touch()

## Sand: fill = `sand_fill`; patch; shadow = `sand_shade`.
@export var sand_patch := Color8(222, 192, 125):
	set(v):
		sand_patch = v
		_touch()

## Snow: fill = `snow_fill`; patch; shadow = `snow_shade`.
@export var snow_patch := Color8(214, 228, 242):
	set(v):
		snow_patch = v
		_touch()

@export var sand_plain_only := true:
	set(v):
		sand_plain_only = v
		_touch()
## Snow fills: plain dirt-art tile only (true) or its rare variants too.
@export var snow_plain_only := true:
	set(v):
		snow_plain_only = v
		_touch()
@export_group("Priority (ties only)")

## Who takes the upper shape when two grounds are on the same level.
@export_range(0, 15) var prio_dirt := 3:
	set(v):
		prio_dirt = v
		_touch()

## 
@export_range(0, 15) var prio_light := 4:
	set(v):
		prio_light = v
		_touch()

## 
@export_range(0, 15) var prio_dark := 5:
	set(v):
		prio_dark = v
		_touch()

## 
@export_range(0, 15) var prio_sand := 2:
	set(v):
		prio_sand = v
		_touch()

## 
@export_range(0, 15) var prio_snow := 6:
	set(v):
		prio_snow = v
		_touch()

## 
@export_range(0, 15) var prio_water := 1:
	set(v):
		prio_water = v
		_touch()

@export_group("Water")

## Water + foam animation: frames per second (8 frames per loop).
@export_range(1.0, 30.0, 0.5) var anim_fps := 8.0:
	set(v):
		anim_fps = v
		_touch()

## Foam (beach outline, dashes).
@export var foam_colour := Color8(218, 246, 252):
	set(v):
		foam_colour = v
		_touch()

## Bank band: water just below / right of land.
@export var band_colour := Color8(40, 112, 166):
	set(v):
		band_colour = v
		_touch()

## Band thickness under land (px).
@export_range(0, 6) var band_up := 3:
	set(v):
		band_up = v
		_touch()

## Band thickness right of land (px).
@export_range(0, 6) var band_left := 2:
	set(v):
		band_left = v
		_touch()

## Beach foam: lit px of every 8 along the shore (the lit part moves 1 px per frame).
@export_range(1, 8) var beach_foam_lit := 6:
	set(v):
		beach_foam_lit = v
		_touch()

## Foam dashes: chance that a shore tile gets one.
@export_range(0.0, 1.0, 0.01) var dash_keep := 0.55:
	set(v):
		dash_keep = v
		_touch()

## Foam dash length (px).
@export_range(1, 5) var dash_len_min := 4:
	set(v):
		dash_len_min = v
		_touch()

## 
@export_range(1, 5) var dash_len_max := 5:
	set(v):
		dash_len_max = v
		_touch()

## A dash sits this many px (or more) off the bank, ...
@export_range(1, 8) var dash_near := 2:
	set(v):
		dash_near = v
		_touch()

## ... anchored at most this far, ...
@export_range(1, 8) var dash_far := 4:
	set(v):
		dash_far = v
		_touch()

## ... and may run out to this far.
@export_range(1, 8) var dash_reach := 8:
	set(v):
		dash_reach = v
		_touch()

## Wave marks (light dashes on open water): one per block of this many px.
@export_range(8, 128) var mark_block := 32:
	set(v):
		mark_block = v
		_touch()

## Chance of a mark in a block.
@export_range(0.0, 1.0, 0.01) var mark_chance := 0.85:
	set(v):
		mark_chance = v
		_touch()

## Mark length (px).
@export_range(1, 8) var mark_len_min := 3:
	set(v):
		mark_len_min = v
		_touch()

## 
@export_range(1, 8) var mark_len_max := 5:
	set(v):
		mark_len_max = v
		_touch()

## Mark lightness (0..255 added) in the first / second half of its 8 frame loop.
@export_range(0, 120) var mark_light_a := 34:
	set(v):
		mark_light_a = v
		_touch()

## 
@export_range(0, 120) var mark_light_b := 14:
	set(v):
		mark_light_b = v
		_touch()


## Index of a material in the per-material tables (water in a cell array is NONE).
static func mi(m: int) -> int:
	return int(Mat.WATER) if m < 0 else m


func fill_of(m: int) -> Color:
	return [dirt_fill, light_fill, dark_fill, sand_fill, snow_fill, water_fill][mi(m)]


func hl_of(m: int) -> Color:
	return [dirt_hl, light_hl, dark_hl, sand_hl, snow_hl, water_hl][mi(m)]


func outline_of(m: int) -> Color:
	return [dirt_outline, light_outline, dark_outline, sand_outline, snow_outline, water_outline][mi(m)]


func shade_of(m: int) -> Color:
	return [dirt_shade, light_shade, dark_shade, sand_shade, snow_shade, water_shade][mi(m)]


func prio_of(m: int) -> int:
	return [prio_dirt, prio_light, prio_dark, prio_sand, prio_snow, prio_water][mi(m)]


func name_of(m: int) -> String:
	return ["dirt", "light grass", "dark grass", "sand", "snow", "water"][mi(m)]


## Uniforms of the two water shaders (flat water + animated foam), see TerrainVisual.begin_island.
func shader_params() -> Dictionary:
	return {"shallow": water_fill, "foam_colour": foam_colour, "fps": anim_fps, "beach_lit": beach_foam_lit, "block": float(mark_block), "chance": mark_chance,
		"len_min": mark_len_min, "len_max": mark_len_max, "light_a": mark_light_a / 255.0, "light_b": mark_light_b / 255.0}
