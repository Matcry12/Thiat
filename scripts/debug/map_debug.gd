class_name MapDebug
extends Node
## The F3 side of ArenaMap: the biome map picture and the extra F3 rows / buttons. ArenaMap keeps the
## values (biome_map_on, biome_map_alpha, style); this node only reads them and draws. Child of ArenaMap.

const ROCK_NODES: Array[String] = ["rock", "copper_rock", "treepp_oak_green_sapling", "treepp_oak_green_young", "treepp_oak_green_mature", "treepp_oak_green_old"]

var _map: ArenaMap
var _overlay: Sprite2D   ## the F3 biome map layer, one pixel per cell
var _overlay_for: MapGen.Result   ## the result its picture shows

func _ready() -> void:
	_map = get_parent() as ArenaMap
	_overlay = Sprite2D.new()   # a slot for the F3 biome map: a see-through picture over everything, never part of the ground
	_overlay.name = "BiomeOverlay"
	_overlay.centered = false
	_overlay.z_index = 60
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.visible = false
	var layer := CanvasLayer.new()   # own canvas that follows the camera: the night tint does not darken the F3 biome picture
	layer.layer = 1
	layer.follow_viewport_enabled = true
	add_child(layer)
	layer.add_child(_overlay)
	_map.biome_map_changed.connect(refresh)
	refresh(true)

## F3 biome map: shown only on an island with biomes; the picture is made once per map (force = make it again).
func refresh(force := false) -> void:
	if force:
		_overlay_for = null
	var result := _map.result
	var show := _map.biome_map_on and result != null and not result.biome.is_empty()
	_overlay.visible = show
	if not show:
		return
	if _overlay_for != result:
		_overlay.texture = ImageTexture.create_from_image(GroundBaker.biome_image(result))
		_overlay_for = result
	_overlay.scale = Vector2.ONE * _map.cell_px()
	_overlay.modulate.a = _map.biome_map_alpha

func children() -> Array:
	var out: Array = []
	var style := _map.style
	if style:
		for bd in style.biomes:   # climate point, ground, trees, rocks, deco, tint of every biome (0038)
			out.append({"name": "Biome " + bd.label, "object": bd})
	if style and style.pixel_plains != null:
		out.append({"name": "Pixel Plains", "object": style.pixel_plains})
	for k in ROCK_NODES:
		out.append({"name": "Node " + k.replace("_rock", ""), "object": load("res://data/resource_nodes/%s.tres" % k), "cat": "Items & Crafting"})
	return out

func actions() -> Array:
	var m := _map
	return [
		{"label": "New map", "run": m.new_map},
		{"label": "Go home", "run": func(): m.teleport_player("home")},
		{"label": "Go to boss", "run": func(): m.teleport_player("boss")},
		{"label": "Biome map", "toggle": func(): return m.biome_map_on, "run": func(): m.biome_map_on = not m.biome_map_on},
		{"label": "Generate", "arg": "int", "hint": "seed", "run": func(v): m.generate_seed(clampi(int(v), 1, 9999))},   # seed 1-9999
	]
