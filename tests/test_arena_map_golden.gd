extends SceneTree
# Golden hashes of ArenaMap (make_params, build stats, queries, teleport spot, chunk nodes) for a fixed seed on the small map,
# taken before arena_map.gd was split into arena_map_*.gd helpers. A real change re-pins them on purpose (run it, copy the printed lines).
func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").map_seed = 11
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var m: ArenaMap = arena.get_node("ArenaMap")
	m.load_all_chunks()
	var got := {}
	var p := m.make_params()
	var h := 0
	for prop in p.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var v: Variant = p.get(prop["name"])
			if v is Resource:   # var_to_bytes would write the object id, which changes with every loaded script
				v = (v as Resource).resource_path
			h = hash([h, prop["name"], hash(var_to_bytes(v))])
	got["params"] = h
	got["stats"] = hash(var_to_bytes([m.node_count, m.stone_count, m.copper_count, m.tree_counts, m.tree_colours, m.deco_counts, m.biome_pct, m.land_pct, m.water_text]))
	var q := []
	var step := m.map_size() / 40.0
	for iy in range(-2, 42):
		for ix in range(-2, 42):
			var pos := Vector2(ix, iy) * step + Vector2(5, 7)
			var r := Rect2(pos, Vector2(40, 30))
			q.append([m.area_at(pos), m.water_kind_at(pos), m.rect_on_land(r), m.in_corridor(pos), m.in_corridor_rect(r), m.in_boss_area(pos), m.biome_id_at(pos), m.placement_blocked(r)])
	got["queries"] = hash(var_to_bytes(q))
	var rects: Array[Rect2] = [Rect2(m.home_point() + Vector2(60, 0), Vector2(300, 300)), Rect2(m.boss_point() - Vector2(400, 40), Vector2(200, 80))]
	m.teleport_player("boss")
	var pl := arena.get_node("Player") as Node2D
	var near := m.nearest_node(&"tree", m.home_point(), true)
	got["spots"] = hash(var_to_bytes([m.blocks_boss_path(rects), pl.global_position, near.global_position if near else null, m.layout()]))
	var nodes := []
	for n in get_nodes_in_group("resource_node"):
		nodes.append([(n as Node2D).global_position, String(n.name)])
	nodes.sort()
	got["chunks"] = hash(var_to_bytes([nodes, get_nodes_in_group("map_obstacle").size(), m.get_node("Ground/Terrain/Grounds").get_child_count()]))
	var pins := {"params": 1819046139, "stats": 3318182244, "queries": 671949035, "spots": 4147318138, "chunks": 2817986983}
	var ok := true
	for k in got:
		print("golden %s = %d" % [k, got[k]])
		var good: bool = got[k] == pins[k]
		print(("ok   " if good else "FAIL ") + "arena map %s unchanged" % k)
		ok = ok and good
	quit(0 if ok else 1)
