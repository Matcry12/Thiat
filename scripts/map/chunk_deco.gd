class_name ChunkDeco
extends RefCounted
## The small floor props (plants, flowers, pebbles ...) of ONE map chunk as a few MultiMeshInstance2D: one per prop sheet,
## so a chunk with 150 props is a handful of draw calls and a handful of nodes, not 150 Sprite2D. Props have no collision
## and need no Y-sorting (they live on the ground layer). Swap this for Sprite2D or a TileMap and ArenaMap does not change.

const SHADER := preload("res://scripts/map/chunk_deco.gdshader")

static var _quad: QuadMesh
static var _materials := {}   ## PropSet instance id -> ShaderMaterial


## deco: the Result.deco dictionaries to show ({set, region, pos = bottom centre of the picture, px}); sets: MapStyle.deco.
## Returns a Node2D (named "Deco") holding the instances. Positions are world px; the node sits at the origin.
## ysort_min_px: props whose picture is taller than this (art px) are left out here: see build_tall.
static func build(deco: Array[Dictionary], sets: Array[PropSet], art_scale: float, ysort_min_px := 1000000) -> Node2D:
	var root := Node2D.new()
	root.name = "Deco"
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	var by_set := {}   # set index -> Array of deco dictionaries
	for d in deco:
		if sets[d["set"]].regions[d["region"]].size.y > ysort_min_px:
			continue
		if not by_set.has(d["set"]):
			by_set[d["set"]] = []
		by_set[d["set"]].append(d)
	for si in by_set:
		var set: PropSet = sets[si]
		var list: Array = by_set[si]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_custom_data = true
		mm.mesh = _quad
		mm.instance_count = list.size()
		# drawn in instance order: lowest on screen last, so a bush hides the flower behind it (one sheet = one set = one y order)
		var order: Array[Vector2] = []
		for k in list.size():
			order.append(Vector2(list[k]["pos"].y, k))
		order.sort()
		for n in order.size():
			var item: Dictionary = list[int(order[n].y)]
			var k := n
			var r: Rect2 = set.regions[item["region"]]
			var size := r.size * art_scale
			# a sprite stands with its bottom centre on `pos`; the quad is centred, so lift it by half its height
			mm.set_instance_transform_2d(k, Transform2D(Vector2(size.x, 0.0), Vector2(0.0, size.y), item["pos"] - Vector2(0.0, size.y * 0.5)))
			mm.set_instance_custom_data(k, Color(r.position.x, r.position.y, r.size.x, r.size.y))
		var inst := MultiMeshInstance2D.new()
		inst.name = "Set%d" % si
		inst.multimesh = mm
		inst.texture = set.texture
		inst.material = _material(set)
		root.add_child(inst)
	return root


## The tall props (picture taller than ysort_min_px art px) as Y-sorted Sprite2D, to be added under the same Y-sorted parent as the trees and
## characters: the player walks behind a bush. Foot (bottom centre) on `pos`.
static func build_tall(deco: Array[Dictionary], sets: Array[PropSet], art_scale: float, ysort_min_px: int) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for d in deco:
		var set: PropSet = sets[d["set"]]
		var r: Rect2 = set.regions[d["region"]]
		if r.size.y <= ysort_min_px:
			continue
		var sp := Sprite2D.new()
		sp.name = "Prop"
		sp.texture = set.texture
		sp.region_enabled = true
		sp.region_rect = r
		sp.offset = Vector2(0.0, -r.size.y * 0.5)
		sp.scale = Vector2.ONE * art_scale
		sp.position = d["pos"]
		out.append(sp)
	return out


## Forget cached materials (a new map or a changed sheet).
static func clear_cache() -> void:
	_materials.clear()


static func _material(set: PropSet) -> ShaderMaterial:
	var key := set.get_instance_id()
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("sheet_size", Vector2(set.texture.get_size()))
		_materials[key] = m
	return _materials[key]
