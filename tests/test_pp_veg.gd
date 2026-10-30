extends SceneTree
## Pixel Plains trees + plants (slice 3): oaks are gatherable nodes (treepp_*), flowers / tufts / hedge caps come from the pp_* PropSets,
## everything is gated per biome by PixelPlainsGround.show_*, and a seed gives the same result twice.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false


func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	var m0: ArenaMap = arena.get_node("ArenaMap")
	m0.map_seed = 3
	m0.map_cols = 200
	m0.map_rows = 120
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var m: ArenaMap = arena.get_node("ArenaMap")
	var style := m.style
	var pp := style.pixel_plains
	_check(pp != null and pp.shows(&"trees", 0), "grass.tres has Pixel Plains with trees shown in plains")
	var p := m.make_params()
	var r := MapGen.generate(style, p, 3)
	var trees := {}   # biome -> count
	var old := 0
	for o in r.obstacles:
		if o["node"] < 0:
			continue
		var id := String(style.resource_nodes[o["node"]].id)
		if id.begins_with("treepp_oak_"):
			var ci := MapGen.cell_index(p, Vector2i(o["pos"] / p.cell))
			trees[r.biome[ci]] = trees.get(r.biome[ci], 0) + 1
		elif id.begins_with("tree"):
			old += 1
	print("  pp oaks per biome: %s" % [trees])
	var n := 0
	for b in trees:
		n += trees[b]
		# the tree's jitter (tree_jitter) can push a trunk of a neighbouring biome across the border: a couple of strays are fine
		_check(pp.shows(&"trees", b) or trees[b] <= 2, "oaks only in biomes with art (biome %d: %d)" % [b, trees[b]])
	var snowy := -1
	for k in style.biomes.size():
		if style.biomes[k].label == "snowy":
			snowy = k
	var wrong := 0   # a non-snow oak in the snowy biome (the dead / teal fallback must use the snow oak)
	for o in r.obstacles:
		if o["node"] >= 0 and String(style.resource_nodes[o["node"]].id).begins_with("treepp_oak_") and not String(style.resource_nodes[o["node"]].id).begins_with("treepp_oak_snow_"):
			var ci2 := MapGen.cell_index(p, Vector2i(o["pos"] / p.cell))
			wrong += 1 if r.biome[ci2] == snowy else 0
	_check(trees.get(snowy, 0) > 0 and wrong == 0, "snowy: only snow oaks (%d trees, %d other colour)" % [trees.get(snowy, 0), wrong])
	_check(n > 100, "oaks exist (%d)" % n)
	_check(old == 0, "no old trees in Pixel Plains mode (%d)" % old)
	var kinds := {}
	for d in r.deco:
		var id: StringName = style.deco[d["set"]].id
		kinds[id] = kinds.get(id, 0) + 1
	print("  deco per set: %s" % [kinds])
	for id in kinds:
		_check(String(id).begins_with("pp_"), "deco only from pp_ sets (%s)" % id)
	_check(kinds.has(&"pp_flowers") and kinds.has(&"pp_tufts") and kinds.has(&"pp_hedges"), "flowers, tufts and hedge caps are placed")
	# same seed, same trees and deco
	var r2 := MapGen.generate(style, p, 3)
	_check(r2.obstacles.size() == r.obstacles.size() and r2.deco.size() == r.deco.size(), "deterministic (%d obstacles, %d deco)" % [r.obstacles.size(), r.deco.size()])
	# the per-biome switch: everything off -> no oaks, no plants, rocks and copper stay
	var saved := [pp.show_trees, pp.show_flowers, pp.show_tufts, pp.show_hedges]
	var zeros := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
	pp.show_trees = zeros
	pp.show_flowers = zeros
	pp.show_tufts = zeros
	pp.show_hedges = zeros
	var r3 := MapGen.generate(style, p, 3)
	var t3 := 0
	var rocks := 0
	for o in r3.obstacles:
		var id := String(style.resource_nodes[o["node"]].id) if o["node"] >= 0 else ""
		t3 += 1 if id.begins_with("tree") else 0
		rocks += 1 if id == "rock" or id == "copper_rock" else 0
	_check(t3 == 0 and r3.deco.is_empty() and rocks > 30, "all switches off: no trees (%d), no plants (%d), rocks stay (%d)" % [t3, r3.deco.size(), rocks])
	pp.show_trees = saved[0]
	pp.show_flowers = saved[1]
	pp.show_tufts = saved[2]
	pp.show_hedges = saved[3]
	# master switch
	pp.hide_trees = true
	var r4 := MapGen.generate(style, m.make_params(), 3)
	pp.hide_trees = false
	var t4 := 0
	for o in r4.obstacles:
		t4 += 1 if o["node"] >= 0 and String(style.resource_nodes[o["node"]].id).begins_with("tree") else 0
	_check(t4 == 0, "hide_trees master switch (%d trees)" % t4)
	# a chopped oak leaves the pack's stump (manifest kind stump, on hedges.png)
	var oak: ResourceNodeData = load("res://data/resource_nodes/treepp_oak_green_old.tres")
	_check(oak.remains_region.has_area() and oak.remains_texture != null and oak.remains_texture.resource_path.ends_with("hedges.png"), "oak has a stump from the pack")
	var rn: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	rn.setup(oak, 0)
	root.add_child(rn)
	await process_frame
	rn.get_node("Visual").show_remains(oak)
	var body: Sprite2D = rn.get_node("Visual/Body")
	_check(body.texture == oak.remains_texture and body.region_rect == oak.remains_region, "chopped oak shows the stump region on the stump sheet")
	quit(0 if _ok else 1)
