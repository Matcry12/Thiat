class_name TerrainVisual
extends Node2D
## The look of the island ground, in one node: the water (a shader), the baked ground pictures and the shore foam.
## ArenaMap hands it pictures (GroundBaker) and numbers; nothing else reaches inside. Swap this for a TileMap,
## a mesh or a different art style and ArenaMap's combat-facing code does not change (CLAUDE.md section 5).
## The water is one big sprite under the whole island. The ground and the foam come in pieces, one pair per map chunk
## (0038 step 2): set_chunk() adds one, remove_chunk() frees it, so only the chunks near the player cost memory.

const WATER_SHADER := preload("res://scripts/map/terrain_water.gdshader")
const GROUND_SHADER := preload("res://scripts/map/terrain_ground.gdshader")
const FOAM_SHADER := preload("res://scripts/map/terrain_foam.gdshader")
const FLAT_WATER_SHADER := preload("res://scripts/map/terrain_water_flat.gdshader")   ## Pixel Plains water (0046): replaces WATER_SHADER
const ANIM_SHADER := preload("res://scripts/map/terrain_anim.gdshader")               ## Pixel Plains animated foam: replaces FOAM_SHADER

var _water: Sprite2D
var _grounds: Node2D   ## parent of every chunk's ground sprite (drawn above the water)
var _foams: Node2D     ## parent of every chunk's foam sprite (drawn above the ground)
var _foam_material: ShaderMaterial   ## one for all foam sprites
var _anim_material: ShaderMaterial   ## the same for Pixel Plains' animation masks
var _flat_params := {}               ## PixelPlainsGround.shader_params(); empty = the old water + foam
var _look := {}
var _chunks := {}      ## key -> {ground: Sprite2D, foam: Sprite2D}


func _ready() -> void:
	name = "Terrain"
	_water = Sprite2D.new()
	_water.name = "Water"
	_water.centered = false
	_water.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var wm := ShaderMaterial.new()
	wm.shader = WATER_SHADER
	_water.material = wm
	_water.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_water.region_enabled = true
	add_child(_water)
	_grounds = Node2D.new()
	_grounds.name = "Grounds"
	add_child(_grounds)
	_foams = Node2D.new()
	_foams.name = "Foams"
	add_child(_foams)
	_foam_material = ShaderMaterial.new()
	_foam_material.shader = FOAM_SHADER
	_anim_material = ShaderMaterial.new()
	_anim_material.shader = ANIM_SHADER
	visible = false


## The water under the whole map. water: its repeating picture; map_art_px: the map's size in art pixels; art_scale: screen px per art px.
## flat: PixelPlainsGround.shader_params() = the Pixel Plains water (one flat colour + marks) and animated foam instead of the old shader water.
func begin_island(water: Image, map_art_px: Vector2, art_scale: float, shallow: Image = null, tile := 16.0, flat := {}) -> void:
	clear_chunks()
	_flat_params = flat
	if not flat.is_empty():
		var one := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
		one.fill(Color.WHITE)
		_water.texture = ImageTexture.create_from_image(one)
		var fm := ShaderMaterial.new()
		fm.shader = FLAT_WATER_SHADER
		for k in flat:
			fm.set_shader_parameter(k, flat[k])
			_anim_material.set_shader_parameter(k, flat[k])
		_water.material = fm
		_set_water_rect(map_art_px, art_scale, tile)
		visible = true
		return
	if _water.material.shader != WATER_SHADER:   # back from the Pixel Plains water
		var wm0 := ShaderMaterial.new()
		wm0.shader = WATER_SHADER
		_water.material = wm0
	_water.texture = ImageTexture.create_from_image(water)
	var wm := _water.material as ShaderMaterial
	if shallow == null:
		wm.set_shader_parameter("shallow_mask", null)   # no shallows on this map: drop the old map's mask
	else:   # which cells are shallow water (one pixel per cell, 255 = shallow)
		wm.set_shader_parameter("shallow_mask", ImageTexture.create_from_image(shallow))
		wm.set_shader_parameter("map_cells", Vector2(shallow.get_width(), shallow.get_height()))
		wm.set_shader_parameter("tile", tile)
	_set_water_rect(map_art_px, art_scale, tile)
	visible = true


## The water reaches as far as the ground pictures: they start half a tile before the first cell, so the water starts there and is one tile bigger.
func _set_water_rect(map_art_px: Vector2, art_scale: float, tile: float) -> void:
	_water.position = Vector2(-tile * 0.5, -tile * 0.5) * art_scale
	_water.region_rect = Rect2(Vector2.ZERO, map_art_px + Vector2(tile, tile))
	_water.scale = Vector2.ONE * art_scale


## One chunk's ground and foam. images: GroundBaker.bake_region() result plus tint / shade maps that cover cells
## [first_cell - 1, first_cell - 1 + tint.size) (one cell more than the picture on every side). first_corner: its first corner tile.
## Replaces the chunk if it is already there.
func set_chunk(key: int, first_corner: Vector2i, images: Dictionary, art_scale: float) -> void:
	remove_chunk(key)
	var g: Image = images["ground"]
	var half := float(images["tile"]) * 0.5
	var tile := float(images["tile"])
	var pos := (Vector2(first_corner) * tile - Vector2(half, half)) * art_scale
	var ground := Sprite2D.new()
	ground.centered = false
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.texture = ImageTexture.create_from_image(g)
	ground.position = pos
	ground.scale = Vector2.ONE * art_scale
	var gm := ShaderMaterial.new()
	gm.shader = GROUND_SHADER
	gm.set_shader_parameter("tex_size", Vector2(g.get_width(), g.get_height()))
	gm.set_shader_parameter("half_tile", half)
	gm.set_shader_parameter("tile", tile)
	ground.material = gm
	_grounds.add_child(ground)
	var foam := Sprite2D.new()
	foam.centered = false
	foam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	foam.texture = ImageTexture.create_from_image(images["foam"])
	foam.position = pos
	foam.scale = Vector2.ONE * art_scale
	foam.material = _anim_material if images.get("anim", false) else _foam_material
	_foams.add_child(foam)
	_chunks[key] = {"ground": ground, "foam": foam}
	_apply_ground_look(gm)
	set_chunk_tint(key, images["tint"], images["shade"])


func set_chunk_tint(key: int, tint: Image, shade: Image) -> void:
	if not _chunks.has(key):
		return
	var m := (_chunks[key]["ground"] as Sprite2D).material as ShaderMaterial
	m.set_shader_parameter("tint_map", ImageTexture.create_from_image(tint))
	m.set_shader_parameter("shade_map", ImageTexture.create_from_image(shade))
	m.set_shader_parameter("map_cells", Vector2(tint.get_width(), tint.get_height()))
	m.set_shader_parameter("map_margin", Vector2.ONE)


func remove_chunk(key: int) -> void:
	if _chunks.has(key):
		for sp: Sprite2D in [_chunks[key]["ground"], _chunks[key]["foam"]]:
			sp.get_parent().remove_child(sp)
			sp.queue_free()
		_chunks.erase(key)


func clear_chunks() -> void:
	for key in _chunks.keys():
		remove_chunk(key)


func chunk_count() -> int:
	return _chunks.size()


func has_chunk(key: int) -> bool:
	return _chunks.has(key)


func hide_island() -> void:
	clear_chunks()
	visible = false
	_water.texture = null


## Live numbers (no rebuild): {shimmer_speed, shimmer_strength, shimmer_scale, shimmer_amount, wave_strength,
## foam_alpha, foam_pulse, foam_speed, shallow_lighten, shallow_color}.
func set_look(look: Dictionary) -> void:
	_look = look
	if _flat_params.is_empty():   # the Pixel Plains water has its own numbers (begin_island)
		for k in ["shimmer_speed", "shimmer_strength", "shimmer_scale", "shimmer_amount", "wave_strength", "drift_scale", "drift_speed", "shimmer_color", "shallow_lighten", "shallow_color"]:
			(_water.material as ShaderMaterial).set_shader_parameter(k, look[k])
		for k in ["foam_alpha", "foam_pulse", "foam_speed", "foam_color"]:
			_foam_material.set_shader_parameter(k, look[k])
	for key in _chunks:
		_apply_ground_look(((_chunks[key]["ground"] as Sprite2D).material) as ShaderMaterial)


func _apply_ground_look(m: ShaderMaterial) -> void:
	if _look.is_empty():
		return
	for k in ["ground_brightness", "ground_saturation"]:
		m.set_shader_parameter(k, _look[k])
	m.set_shader_parameter("neutral", _look.get("ground_neutral", false))
