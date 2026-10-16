class_name TerrainVisual
extends Node2D
## The look of the island ground, in one node: the water (a shader), the baked ground picture and the shore foam.
## ArenaMap hands it pictures (GroundBaker) and numbers; nothing else reaches inside. Swap this for a TileMap,
## a mesh or a different art style and ArenaMap's combat-facing code does not change (CLAUDE.md section 5).
## Children are created once; show_island() only replaces textures.

const WATER_SHADER := preload("res://scripts/map/terrain_water.gdshader")
const GROUND_SHADER := preload("res://scripts/map/terrain_ground.gdshader")
const FOAM_SHADER := preload("res://scripts/map/terrain_foam.gdshader")

var _water: Sprite2D
var _ground: Sprite2D
var _foam: Sprite2D


func _ready() -> void:
	name = "Terrain"
	_water = _make_sprite("Water", WATER_SHADER)
	_ground = _make_sprite("Ground", GROUND_SHADER)
	_foam = _make_sprite("Foam", FOAM_SHADER)
	_water.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_water.region_enabled = true
	visible = false


func _make_sprite(n: String, shader: Shader) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = n
	sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := ShaderMaterial.new()
	m.shader = shader
	sp.material = m
	add_child(sp)
	return sp


## images: GroundBaker.bake() result; water: its repeating water picture; art_scale: screen px per art px.
func show_island(images: Dictionary, water: Image, art_scale: float) -> void:
	var g: Image = images["ground"]
	_water.texture = ImageTexture.create_from_image(water)
	_water.region_rect = Rect2(0, 0, g.get_width(), g.get_height())
	_ground.texture = ImageTexture.create_from_image(g)
	_foam.texture = ImageTexture.create_from_image(images["foam"])
	set_tint(images["tint"], images["shade"])
	for sp in [_water, _ground, _foam]:
		sp.scale = Vector2.ONE * art_scale
	# dual grid: the picture is one tile bigger than the map and starts half a tile up and left
	var half := float(images["tile"]) * 0.5
	for sp in [_ground, _foam]:
		sp.position = -Vector2(half, half) * art_scale
	var gm := _ground.material as ShaderMaterial
	gm.set_shader_parameter("tex_size", Vector2(g.get_width(), g.get_height()))
	gm.set_shader_parameter("half_tile", half)
	visible = true


func set_tint(tint: Image, shade: Image) -> void:
	var m := _ground.material as ShaderMaterial
	m.set_shader_parameter("tint_map", ImageTexture.create_from_image(tint))
	m.set_shader_parameter("shade_map", ImageTexture.create_from_image(shade))


func hide_island() -> void:
	visible = false
	for sp in [_water, _ground, _foam]:
		sp.texture = null


## Live numbers (no rebuild): {shimmer_speed, shimmer_strength, shimmer_scale, shimmer_amount, wave_strength,
## foam_alpha, foam_pulse, foam_speed}.
func set_look(look: Dictionary) -> void:
	for k in ["shimmer_speed", "shimmer_strength", "shimmer_scale", "shimmer_amount", "wave_strength", "drift_scale", "drift_speed", "shimmer_color"]:
		(_water.material as ShaderMaterial).set_shader_parameter(k, look[k])
	for k in ["ground_brightness", "ground_saturation"]:
		(_ground.material as ShaderMaterial).set_shader_parameter(k, look[k])
	for k in ["foam_alpha", "foam_pulse", "foam_speed", "foam_color"]:
		(_foam.material as ShaderMaterial).set_shader_parameter(k, look[k])
