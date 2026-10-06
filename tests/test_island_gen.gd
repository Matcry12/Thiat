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
	for s in range(1, 41):
		var r := MapGen.generate(style, p, s)
		var ok: bool = MapGen.is_land(r, p, home) and MapGen.is_land(r, p, zc) and _connected_land(r, p)
		if not ok:
			print("  seed %d: home/zone/connected failed" % s)
		all_ok = all_ok and ok
	_check(all_ok, "seeds 1..40: home and zone are land, all land connected to home")

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

	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
