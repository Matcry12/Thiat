class_name PixelPlainsGround
extends Resource
## The Pixel Plains ground (SnowHex pack), as DATA: which 8x8 quarter of which 16 px tile of the sheet draws what. GroundBaker
## builds the picture from it (dual grid, quarter by quarter) with the pack's own pixels, no tint, no mirror, no rotation.
## Generated from tools/asset_viewer/pixel_plains_tiles.py by tools/asset_viewer/pixel_plains_export_tres.py: edit the .tres in F3,
## or change the python table and export again. MapStyle.pixel_plains = null brings the old ground look back.
## Materials: DIRT 0, LIGHT grass 1, DARK grass 2 (the pack's own art), SAND 3, SNOW 4 (dirt art recoloured), WATER 5 (flat colour, drawn by
## PixelPlainsBaker). NONE (-1) = water in a map cell array.

enum Mat { NONE = -1, DIRT, LIGHT, DARK, SAND, SNOW, WATER }
## Which sheet a cell is drawn from. The first 5 equal Mat; cobble and beach gravel share the material of dirt / sand.
enum Sheet { DIRT, LIGHT, DARK, SAND, SNOW, COBBLE, GRAVEL }
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


# ---- Ground pictures (decision 0069, docs/wiki/ground-tileset-algorithm.md) -------------------------------------------------
## Every border, the beach foam and the water are pixels of the pictures below (`sheet_*`, foam, water). Nothing here is a colour.


@export_group("Borders")

## All flat (the default): every border of two grounds is drawn from the ground sheets' edge slots (flat, quiet outline), sand meets water with foam.
## Off: grass / dirt and dark / light grass use the pack's own raised-edge pairs (tiles.png). Kept for the python reference test only.
@export var all_flat := true:
	set(v):
		all_flat = v
		_touch()

@export_group("Ground sheets")

## One picture per ground, same size and cell layout as `texture` (tiles.png). Made by tools/bake_ground_art.gd, then redrawn by hand if wanted.
## The game reads from a sheet: its fill tiles (plain_* / variants_* cells) and its edge block (cells 0..3 of rows 1..4, slot s = cell (s % 4, 1 + s / 4)).
## The 4-colour swatch (PixelPlainsBaker.SWATCH_CELL) is only the input of `tools/bake_ground_art.gd -- tiles`.
@export var sheet_dirt: Texture2D:
	set(v):
		sheet_dirt = v
		_touch()
@export var sheet_grass_light: Texture2D:
	set(v):
		sheet_grass_light = v
		_touch()
@export var sheet_grass_dark: Texture2D:
	set(v):
		sheet_grass_dark = v
		_touch()
@export var sheet_sand: Texture2D:
	set(v):
		sheet_sand = v
		_touch()
@export var sheet_snow: Texture2D:
	set(v):
		sheet_snow = v
		_touch()
## Cobble and beach gravel: their own sheet, for the cells that are only that ground (a mixed corner and every border use the sheet of its material, dirt / sand).
@export var sheet_cobble: Texture2D:
	set(v):
		sheet_cobble = v
		_touch()
@export var sheet_gravel: Texture2D:
	set(v):
		sheet_gravel = v
		_touch()
## Beach foam: 8 frames of 4x4 slots (slot = sand mask), foam colour where lit. Water: cell (0,0) = flat water, then rows of wave mark variants.
## Both made by `tools/bake_ground_art.gd -- tiles`, redraw them to change the look (README of the folder).
@export var foam_texture: Texture2D:
	set(v):
		foam_texture = v
		_touch()
@export var water_texture: Texture2D:
	set(v):
		water_texture = v
		_touch()

@export_group("Fills")
## Sand / snow fills: plain tile only (true = clean fill) or its rare variants too.
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

## Who lies over whom where grounds meet: the higher number is drawn over the lower. Order: water 1, sand 2, dirt 3, light 4, dark 5, snow 6.
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

## Chance that a 32 px block of open water has a wave mark (the marks are the rows of water.png).
@export_range(0.0, 1.0, 0.01) var mark_chance := 0.85:
	set(v):
		mark_chance = v
		_touch()
## Index of a material in the per-material tables (water in a cell array is NONE).
static func mi(m: int) -> int:
	return int(Mat.WATER) if m < 0 else m


## Fill / highlight / outline / shade of a ground (dirt .. snow): the swatch of its sheet. Water: its colour is pixel (0, 0) of water.png (fill_of only).
func fill_of(m: int) -> Color:
	return PixelPlainsBaker.water_colour(self) if mi(m) == Mat.WATER else PixelPlainsBaker.palette(self, mi(m))[0]


func hl_of(m: int) -> Color:
	return PixelPlainsBaker.palette(self, mi(m))[1]


func outline_of(m: int) -> Color:
	return PixelPlainsBaker.palette(self, mi(m))[2]


func shade_of(m: int) -> Color:
	return PixelPlainsBaker.palette(self, mi(m))[3]


func sheet_of(skin: int) -> Texture2D:
	return [sheet_dirt, sheet_grass_light, sheet_grass_dark, sheet_sand, sheet_snow, sheet_cobble, sheet_gravel][skin]


## Skin of a map ground that is NOT the default of its material (cobble, gravel), else -1.
static func special_skin(ground: int, biome: int) -> int:
	if ground == MapGen.Ground.COBBLE:
		return Sheet.COBBLE
	if ground == MapGen.Ground.SAND and biome == MapGen.Biome.BEACH_GRAVEL:
		return Sheet.GRAVEL
	return -1


func prio_of(m: int) -> int:
	return [prio_dirt, prio_light, prio_dark, prio_sand, prio_snow, prio_water][mi(m)]


func name_of(m: int) -> String:
	return ["dirt", "light grass", "dark grass", "sand", "snow", "water"][mi(m)]


## Uniforms of the two water shaders (flat water + animated foam), see TerrainVisual.begin_island: the two pictures, the frame rate, the mark density.
func shader_params() -> Dictionary:
	var out := PixelPlainsBaker.shader_pictures(self)
	out["fps"] = anim_fps
	out["chance"] = mark_chance
	return out


## F3 > Pixel Plains: read the ground pictures from disk again and rebuild the map.
func debug_actions() -> Array:
	return [{"label": "Reload ground pictures", "run": func():
		PixelPlainsBaker.reload_pictures()
		emit_changed()}]
