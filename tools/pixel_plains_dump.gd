extends SceneTree
## $0 preview data for the Pixel Plains pack: one window of the generated map as JSON (ground, biome, water flags, trees, rocks, deco).
##   godot --headless --script tools/pixel_plains_dump.gd -- <out.json> [seed] [cx cy] [w h]   (centre defaults to home, 60 x 34)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var seed_v := int(a[1]) if a.size() > 1 else 11
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	var m: ArenaMap = arena.get_node("ArenaMap")
	m.map_seed = seed_v
	m._rebuild_queued = false
	m._place_actors()
	var r := MapGen.generate(m.style, m.make_params(), seed_v)
	var cell := m.cell_px()
	var home := Vector2i(m.home_point() / cell)
	var cx := int(a[2]) if a.size() > 3 else home.x
	var cy := int(a[3]) if a.size() > 3 else home.y
	var w := int(a[4]) if a.size() > 5 else 60
	var h := int(a[5]) if a.size() > 5 else 34
	var x0 := cx - w / 2
	var y0 := cy - h / 2
	var cells: Array = []
	for y in range(y0, y0 + h):
		var row: Array = []
		for x in range(x0, x0 + w):
			var i: int = y * r.cols + x
			row.append([r.ground[i] if not r.ground.is_empty() else 0, r.biome[i] if not r.biome.is_empty() else 0, r.land[i],
				r.shallow[i] if not r.shallow.is_empty() else 0, r.fresh[i] if not r.fresh.is_empty() else 0,
				1 if r.dirt_cells.has(Vector2i(x, y)) else 0])
		cells.append(row)
	var win := Rect2(Vector2(x0, y0) * cell, Vector2(w, h) * cell).grow(cell * 3)
	var trees: Array = []
	var rocks: Array = []
	for o in r.obstacles:
		if not win.has_point(o["pos"]):
			continue
		var n: int = o["node"]
		if n < 0:
			rocks.append({"pos": [o["pos"].x, o["pos"].y], "radius": o["radius"], "id": "cover_rock"})
			continue
		var d: ResourceNodeData = m.style.resource_nodes[n]
		var e := {"pos": [o["pos"].x, o["pos"].y], "radius": o["radius"], "id": str(d.id)}
		if String(d.id).begins_with("treepp_"):
			trees.append(e)
		else:
			rocks.append(e)
	var deco: Array = []
	for d in r.deco:
		if not win.has_point(d["pos"]):
			continue
		var ps: PropSet = m.style.deco[d["set"]]
		var g := ""
		for k in ps.groups:
			if (ps.groups[k] as PackedInt32Array).has(d["region"]):
				g = str(k)
		deco.append({"pos": [d["pos"].x, d["pos"].y], "set": str(ps.id), "group": g})
	var f := FileAccess.open(a[0], FileAccess.WRITE)
	f.store_string(JSON.stringify({"seed": seed_v, "cell": cell, "x0": x0, "y0": y0, "w": w, "h": h, "home": [home.x, home.y],
		"cells": cells, "trees": trees, "rocks": rocks, "deco": deco}))
	print("home ", home, " trees ", trees.size(), " rocks ", rocks.size(), " deco ", deco.size())
	quit(0)
