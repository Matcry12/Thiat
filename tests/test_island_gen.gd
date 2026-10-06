extends SceneTree
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _params() -> MapGen.Params:
	var p := MapGen.Params.new()
	p.cols = 200
	p.rows = 120
	p.cell = 32.0
	p.world = Vector2(200, 120) * 32.0
	p.island_on = true
	p.player_spawn = Vector2(0.12 * p.world.x, 0.5 * p.world.y)
	p.zone = Rect2(Vector2(0.86 * p.world.x, 0.5 * p.world.y) - Vector2(440, 230), Vector2(880, 460))
	p.spawns = PackedVector2Array([p.player_spawn])
	p.obstacle_count = 190
	p.patch_count = 120
	return p

func _connected_land(res: MapGen.Result, p: MapGen.Params) -> bool:
	var start := Vector2i(p.player_spawn / p.cell)
	var seen := PackedByteArray()
	seen.resize(p.cols * p.rows)
	var stack: Array[Vector2i] = [start]
	seen[MapGen.cell_index(p, start)] = 1
	var reached := 1
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + d
			var i := MapGen.cell_index(p, q)
			if i >= 0 and res.land[i] == 1 and seen[i] == 0:
				seen[i] = 1
				reached += 1
				stack.append(q)
	var total := 0
	for v in res.land:
		total += v
	return reached == total

func _init() -> void:
	var style: MapStyle = load("res://data/maps/grass.tres")
	var p := _params()
	var a := MapGen.generate(style, p, 7)
	var b := MapGen.generate(style, p, 7)
	var c := MapGen.generate(style, p, 8)
	_check(a.land == b.land and a.area == b.area, "same seed = same island")
	_check(a.land != c.land, "different seed = different island")
	_check(a.land.size() == 200 * 120 and a.area.size() == 200 * 120, "one land + one area value per cell")

	var edge_water := true
	for x in p.cols:
		for y in [0, p.coast_cells - 1, p.rows - 1]:
			edge_water = edge_water and not MapGen.is_land(a, p, Vector2i(x, y))
	for y in p.rows:
		for x in [0, p.cols - 1]:
			edge_water = edge_water and not MapGen.is_land(a, p, Vector2i(x, y))
	_check(edge_water, "the map edge is water")

	var land_count := 0
	for v in a.land:
		land_count += v
	var share := float(land_count) / a.land.size()
	_check(share > 0.35 and share < 0.85, "island is most of the map but not all of it (%.2f)" % share)

	var home := Vector2i(p.player_spawn / p.cell)
	var zc := Vector2i(p.zone.get_center() / p.cell)
	var all_ok := true
	var reach_ok := true
	var t0 := Time.get_ticks_msec()
	# Seeds 1..40: island shape (no nodes = cheap). Seeds 1..10 (incl. 2, 4, 11-ish repair cases): full walk check.
	var bare: MapStyle = style.duplicate()
	bare.resource_nodes = []
	for s in range(1, 41):
		var full: bool = s <= 10 or s == 11
		var r := MapGen.generate(style if full else bare, p, s)
		var ok: bool = MapGen.is_land(r, p, home) and MapGen.is_land(r, p, zc) and _connected_land(r, p)
		if not ok:
			print("  seed %d: home/zone/connected failed" % s)
		all_ok = all_ok and ok
		var walk := not full or MapGen.floor_reachable(p, r.obstacles, r.land)   # I1: the walk grid reaches every walkable spot
		if not walk:
			print("  seed %d: walk-grid check failed" % s)
		reach_ok = reach_ok and walk
	_check(all_ok, "seeds 1..40: home and zone are land, all land connected to home")
	print("seed loop runtime: %d ms" % (Time.get_ticks_msec() - t0))
	_check(reach_ok, "seeds 1..11 (with nodes): all walkable land reachable from home, rocks and water included (I1)")

	_check(a.area[MapGen.cell_index(p, home)] == MapGen.Area.FOREST, "home is in the forest")
	_check(a.area[MapGen.cell_index(p, zc)] == MapGen.Area.BOSS, "the fight zone is in the boss area")
	var counts := [0, 0, 0]
	for i in a.land.size():
		if a.land[i] == 1:
			counts[a.area[i]] += 1
	_check(counts[0] > 0 and counts[1] > 0 and counts[2] > 0, "all three areas exist %s" % [counts])

	var q := _params()
	q.island_on = false
	var flat := MapGen.generate(style, q, 7)
	var all_land := true
	for v in flat.land:
		all_land = all_land and v == 1
	_check(all_land, "island_on = false: every cell is land (old map)")

	# --- Task 2: everything sits on land ---
	var on_land := true
	for o in a.obstacles:
		var r: float = o["radius"] + MapGen.rock_clearance(p)
		for dy in [-r, 0.0, r]:
			for dx in [-r, 0.0, r]:
				on_land = on_land and MapGen.is_land(a, p, Vector2i((o["pos"] + Vector2(dx, dy)) / p.cell))
	_check(on_land and a.obstacles.size() > 50, "rocks on land, clear of water (%d rocks)" % a.obstacles.size())
	var deco_ok := true
	for d in a.deco:
		deco_ok = deco_ok and MapGen.is_land(a, p, Vector2i(d["pos"] / p.cell))
	_check(deco_ok and a.deco.size() > 100, "deco on land (%d)" % a.deco.size())
	var patches_ok := true
	for r in a.patches:
		for y in range(r.position.y - 1, r.end.y + 1):
			for x in range(r.position.x - 1, r.end.x + 1):
				var i := MapGen.cell_index(p, Vector2i(x, y))
				patches_ok = patches_ok and i >= 0 and a.land[i] == 1 and a.area[i] == MapGen.Area.FOREST
	_check(patches_ok, "dirt patches (and their ring) only in forest land")
	var ground_ok := true
	for i in a.land.size():
		var cell := Vector2i(i % p.cols, i / p.cols)
		if a.land[i] == 0:
			ground_ok = ground_ok and a.kind[i] == MapGen.WATER and not a.dirt.has(cell) and not a.grass.has(cell)
		elif a.area[i] != MapGen.Area.FOREST:
			ground_ok = ground_ok and a.dirt.has(cell) and not a.grass.has(cell)
	_check(ground_ok, "water cells have no ground; rocky and boss cells have no grass")
	_check(a.border.is_empty(), "no wall bushes on the island (the water is the edge)")
	# M1: home inside the coast rim keeps its disc and the zone (no all-water island)
	var rim := _params()
	rim.player_spawn = Vector2(0.01 * rim.world.x, 0.5 * rim.world.y)
	var rr := MapGen.generate(style, rim, 7)
	var rim_land := 0
	for v in rr.land:
		rim_land += v
	_check(rim_land > 1000 and MapGen.is_land(rr, rim, Vector2i(rim.player_spawn / rim.cell)), "home in the coast rim: island is not water (%d land)" % rim_land)

	# M2: corridor_half 0 still connects home and the zone when they are on different rows
	var cor := _params()
	cor.corridor_half = 0
	cor.player_spawn.y = 0.25 * cor.world.y
	cor.island_threshold = 0.7
	var cor_ok := true
	for s in [1, 2, 3]:
		var cr := MapGen.generate(style, cor, s)
		cor_ok = cor_ok and MapGen.is_land(cr, cor, zc) and _connected_land(cr, cor)
	_check(cor_ok, "corridor_half 0: the boss zone is still land and connected")
	_check(a.cols == 200 and a.rows == 120, "result remembers the grid size it was built with")
	_check(not flat.land.is_empty() and MapGen.floor_reachable(q, flat.obstacles), "flat map still reachable (old call)")

	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
