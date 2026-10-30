extends SceneTree
# 0038 step 3: rivers, lakes, shallows. World data on the 512 x 512 island (bare style: no nodes, fast), then the swim slowdown in a real arena.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _params(cols: int, rows: int) -> MapGen.Params:
	var p := MapGen.Params.new()
	p.cols = cols
	p.rows = rows
	p.cell = 32.0
	p.world = Vector2(cols, rows) * 32.0
	p.island_on = true
	p.legacy_tiles = false
	p.player_spawn = Vector2(0.12 * p.world.x, 0.5 * p.world.y)
	p.zone = Rect2(Vector2(0.86 * p.world.x, 0.5 * p.world.y) - Vector2(440, 230), Vector2(880, 460))
	p.spawns = PackedVector2Array([p.player_spawn])
	p.climate_temp_period = 600.0   # the 512 numbers (ArenaMap defaults, v3: biomes 2x)
	p.climate_humid_period = 300.0
	p.climate_rough_period = 200.0
	p.climate_warp_period = 180.0
	p.climate_warp_amp = 28.0
	return p

## Every cell the circle (px) overlaps is dry land (scans the whole bounding box, no sample points).
func _circle_dry(r: MapGen.Result, p: MapGen.Params, pos: Vector2, rad: float) -> bool:
	for cy in range(int(floor((pos.y - rad) / p.cell)), int(floor((pos.y + rad) / p.cell)) + 1):
		for cx in range(int(floor((pos.x - rad) / p.cell)), int(floor((pos.x + rad) / p.cell)) + 1):
			var nx := clampf(pos.x, cx * p.cell, (cx + 1) * p.cell)
			var ny := clampf(pos.y, cy * p.cell, (cy + 1) * p.cell)
			if Vector2(nx, ny).distance_to(pos) <= rad and r.land[cy * p.cols + cx] == 0:
				return false
	return true


func _init() -> void:
	var style: MapStyle = load("res://data/maps/grass.tres")
	var bare: MapStyle = style.duplicate()
	bare.resource_nodes = []
	var p := _params(512, 512)
	var rivers_ok := true
	var rivers_total := 0
	var lakes_total := 0
	var wet_ok := true
	var kinds_ok := true
	var place_ok := true
	var edge_ok := true
	var dry_ok := true
	var conn_ok := true
	var lakes_ok := true
	var small_water := false   # a fresh-water body under water_min_cells
	var ms := 0
	for sd in [11, 7]:
		var t := Time.get_ticks_msec()
		var r := MapGen.generate(bare, p, sd)
		ms = Time.get_ticks_msec() - t
		print("  seed %d: world data %d ms (water %.0f ms)" % [sd, ms, r.timings.get("shape.water", 0.0)])
		var n := p.cols * p.rows
		var seen := PackedByteArray()
		seen.resize(n)
		var stack := PackedInt32Array()
		for i in n:
			if r.fresh[i] == 1:
				rivers_total += 1
			elif r.fresh[i] == 2:
				lakes_total += 1
			# a walkable cell is dry land or shallow; deep ocean is neither
			wet_ok = wet_ok and (r.walk_land[i] == 1) == (r.land[i] == 1 or r.shallow[i] == 1) and not (r.land[i] == 1 and r.shallow[i] == 1)
			var kind := MapGen.water_kind(r, p, Vector2i(i % p.cols, i / p.cols))
			kinds_ok = kinds_ok and (kind == MapGen.WaterKind.NONE) == (r.land[i] == 1) and (kind == MapGen.WaterKind.SHALLOW) == (r.shallow[i] == 1)
		# every body of fresh water (rivers + the lakes on them, 4-neighbour) touches water that is not fresh = the sea or its shallows
		var body := PackedByteArray()
		body.resize(n)
		var big_rivers := 0   # river cells with a wide mouth: widened rivers have a 7+ wide stretch
		for i in n:
			body[i] = 1 if r.fresh[i] > 0 else 0
		for i in n:
			if body[i] == 1 and seen[i] == 0:
				var spans := PackedInt32Array()
				small_water = small_water or MapGen._span_fill(body, seen, p.cols, p.rows, i, 1, spans, stack) < p.water_min_cells
				var touches := false
				var has_river := false
				for k in range(0, spans.size(), 2):
					for c in range(spans[k], spans[k] + spans[k + 1]):
						has_river = has_river or r.fresh[c] == 1
						for o in [-1, 1, -p.cols, p.cols]:
							touches = touches or (r.land[c + o] == 0 and r.fresh[c + o] == 0)
				if has_river and not touches:
					print("  stray fresh body: %d cells at %s" % [spans.size() / 2, Vector2i(i % p.cols, i / p.cols)])
				rivers_ok = rivers_ok and (touches or not has_river)
		# lakes: separate bodies of fresh == 2
		var lseen := PackedByteArray()
		lseen.resize(n)
		var lake_n := 0
		var big_lake := 0
		for i in n:
			if r.fresh[i] == 2 and lseen[i] == 0:
				var spans2 := PackedInt32Array()
				var sz := MapGen._span_fill(r.fresh, lseen, p.cols, p.rows, i, 2, spans2, stack)
				lake_n += 1
				if sz > 150:
					big_lake += 1
				small_water = small_water or sz < p.water_min_cells
		print("  seed %d: %d lake bodies, %d of them over 150 cells" % [sd, lake_n, big_lake])
		lakes_ok = lakes_ok and lake_n >= 2 and lake_n <= 6 and big_lake >= 2   # v3: 2-4 big lakes (a lake on a river may split), no ponds
		# edge: ocean all round, deep (not shallow, not walkable)
		for x in p.cols:
			for y in [0, 1, 2, p.rows - 1]:
				edge_ok = edge_ok and r.walk_land[y * p.cols + x] == 0
		for y in p.rows:
			for x in [0, 1, 2, p.cols - 1]:
				edge_ok = edge_ok and r.walk_land[y * p.cols + x] == 0
		# home and the fight zone are dry land
		var home := Vector2i(p.player_spawn / p.cell)
		dry_ok = dry_ok and r.land[home.y * p.cols + home.x] == 1
		var zc := MapGen.zone_cells(p)
		for y in range(zc.position.y, zc.end.y):
			for x in range(zc.position.x, zc.end.x):
				dry_ok = dry_ok and r.shallow[y * p.cols + x] == 0
		# one island: every walkable cell is reached from home over walkable cells
		var reached := PackedByteArray()
		reached.resize(n)
		MapGen._span_fill(r.walk_land, reached, p.cols, p.rows, home.y * p.cols + home.x, 1, PackedInt32Array(), stack)
		for i in n:
			conn_ok = conn_ok and (r.walk_land[i] == 0 or reached[i] == 1)
		# the walk grid: a sample in the middle of a shallow cell with shallow / land all round is walkable, an ocean one is not
		var free := MapGen._walk_free(p, r.walk_land)
		var nx := int(p.size_px().x / MapGen.FLOW_STEP)
		var wet_free := 0
		var wet_seen := 0
		for i in range(p.cols + 1, n - p.cols - 1):
			if r.shallow[i] == 1 and r.walk_land[i - 1] == 1 and r.walk_land[i + 1] == 1 and r.walk_land[i - p.cols] == 1 and r.walk_land[i + p.cols] == 1:
				wet_seen += 1
				wet_free += free[(2 * (i / p.cols) + 1) * nx + 2 * (i % p.cols) + 1]
		print("  seed %d: %d inner shallow cells, %d walkable samples" % [sd, wet_seen, wet_free])
		kinds_ok = kinds_ok and wet_seen > 500 and wet_free == wet_seen
		var ocean_cell := Vector2i(1, 1)
		kinds_ok = kinds_ok and MapGen.water_kind(r, p, ocean_cell) == MapGen.WaterKind.OCEAN and free[3 * nx + 3] == 0
	_check(rivers_total > 2000 and lakes_total > 1500, "rivers and lakes exist on 512 x 512 (%d river cells, %d lake cells over 2 seeds)" % [rivers_total, lakes_total])
	_check(rivers_ok, "every river body (with the lakes on its path) reaches the sea (touches water that is not fresh)")
	_check(lakes_ok, "water v3: 2-6 lake bodies per seed, 2 big ones (over 150 cells), no ponds")
	_check(not small_water, "no fresh-water body (river or lake) under water_min_cells")
	_check(wet_ok, "walkable = dry land or shallow water; no cell is both")
	_check(kinds_ok, "WaterKind: land = NONE, rivers / lakes / coast shallows = SHALLOW and walkable on the walk grid, deep ocean = OCEAN and blocked")
	_check(edge_ok, "ocean (not walkable) all round the map edge")
	_check(dry_ok, "home is dry land and the fight zone has no water")
	_check(conn_ok, "one connected island: all walkable ground is reached from home")
	_check(ms < 4500, "world data %d ms at 512 x 512 (budget 4500, with nodes + trees the real map is a bit more)" % ms)

	# nothing is placed in water: the full style (trees, rocks, copper, props) at 200 x 120
	var q := _params(200, 120)
	q.obstacle_count = 190
	q.patch_count = 120
	q.legacy_tiles = true
	for sd in [11, 7, 3]:
		var r := MapGen.generate(style, q, sd)
		for o in r.obstacles:
			var rad: float = o["radius"] + MapGen.rock_clearance(q)
			place_ok = place_ok and _circle_dry(r, q, o["pos"], rad)
		if sd == 11:   # the scan can fail: a river cell under a trunk is seen
			var o0: Dictionary = r.obstacles[0]
			var keep := r.land.duplicate()
			r.land[MapGen.cell_index(q, Vector2i(o0["pos"] / q.cell))] = 0
			_check(not _circle_dry(r, q, o0["pos"], o0["radius"]), "control: the cell scan sees a water cell under a trunk")
			r.land = keep
		for d in r.deco:
			var c := Vector2i(d["pos"] / q.cell)
			place_ok = place_ok and r.land[c.y * q.cols + c.x] == 1
		# ground: no tile on water (shore edges come from the dual grid), the shore is dirt / sand around fresh water
		for i in r.land.size():
			if r.land[i] == 0:
				place_ok = place_ok and r.ground[i] == MapGen.Ground.WATER
		place_ok = place_ok and r.obstacles.size() > 50
	_check(place_ok, "no tree, rock, copper or prop on water; no ground tile on water")

	# swim: in shallow water the walk speed is water_speed_scale x
	var arena = load("res://scenes/arena.tscn").instantiate()
	var m: ArenaMap = arena.get_node("ArenaMap")
	m.map_seed = 11
	m.map_cols = 200
	m.map_rows = 120
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player: CharacterBody2D = arena.get_node("Player")
	var sw: Swimmer = player.get_node("Swimmer")
	var res := m.result
	var spot_wet := Vector2.ZERO
	var spot_dry := Vector2.ZERO
	for i in res.land.size():
		var c := Vector2i(i % res.cols, i / res.cols)
		if c.x < 6 or c.y < 6 or c.x > res.cols - 8 or c.y > res.rows - 6:
			continue
		var ok := true   # a strip of 5 cells to the right, all the same kind, and no rock within 160 px
		var want_wet: bool = res.shallow[i] == 1
		for dx in 5:
			var j := i + dx
			ok = ok and res.walk_land[j] == 1 and (res.shallow[j] == 1) == want_wet
		if not ok:
			continue
		var pos := (Vector2(c) + Vector2(0.5, 0.5)) * m.cell_px()
		for o in res.obstacles:
			if pos.distance_to(o["pos"]) < 200.0:
				ok = false
				break
		if ok and want_wet and spot_wet == Vector2.ZERO:
			spot_wet = pos
		if ok and not want_wet and spot_dry == Vector2.ZERO:
			spot_dry = pos
		if spot_wet != Vector2.ZERO and spot_dry != Vector2.ZERO:
			break
	_check(spot_wet != Vector2.ZERO and spot_dry != Vector2.ZERO, "found a clear river / coast shallow spot and a clear dry spot")
	player.aim_override = Vector2.RIGHT
	var speeds := {}
	for name in ["dry", "wet"]:
		player.global_position = spot_dry if name == "dry" else spot_wet
		player.velocity = Vector2.ZERO
		await physics_frame
		await physics_frame
		Input.action_press("move_right")
		await physics_frame
		await physics_frame
		await process_frame
		speeds[name] = player.velocity.length()
		_check(sw.in_water == (name == "wet"), "Swimmer.in_water is %s on the %s spot" % [name == "wet", name])
		var fx0: WaterFx = player.get_node("Visual/WaterFx")
		_check(fx0.in_water == (name == "wet") and player.get_node("Visual/Shadow").visible == (name == "dry"), "WaterFx follows the signal on the %s spot: effect %s, shadow %s" % [name, "on" if name == "wet" else "off", "hidden" if name == "wet" else "shown"])
		Input.action_release("move_right")
		await physics_frame
	print("  speeds: ", speeds)
	_check(absf(speeds["dry"] - player.speed) < 1.0, "dry: full speed (%.0f)" % speeds["dry"])
	_check(absf(speeds["wet"] - player.speed * sw.water_speed_scale) < 1.0, "shallow water: speed x water_speed_scale %.2f (%.0f)" % [sw.water_speed_scale, speeds["wet"]])
	# the effect is a slot node driven by the signal
	var fx: WaterFx = player.get_node("Visual/WaterFx")
	player.global_position = spot_dry
	await physics_frame
	await physics_frame
	await process_frame
	_check(not fx.in_water and player.get_node("Visual/Shadow").visible, "back on land: effect off, shadow back")
	var box := Rect2(spot_wet - Vector2(40, 40), Vector2(80, 80))
	_check(not m.rect_on_land(box) and m.rect_on_land(Rect2(spot_dry - Vector2(10, 10), Vector2(20, 20))), "rect_on_land: a station box over water is refused, over dry land is fine")
	_check(m.water_kind_at(spot_wet) == MapGen.WaterKind.SHALLOW and m.water_kind_at(spot_dry) == MapGen.WaterKind.NONE and m.water_kind_at(Vector2(-50, -50)) == MapGen.WaterKind.OCEAN, "ArenaMap.water_kind_at: shallow, dry, off-map = ocean")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
