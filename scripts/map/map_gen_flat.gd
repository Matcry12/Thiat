class_name MapGenFlat
extends RefCounted
## MapGen stage "flat": moved out of map_gen.gd unchanged (static helpers; MapGen keeps the public API and the shared consts / Params / Result).


static func _place_patches(res: MapGen.Result, p: MapGen.Params, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var lo := maxi(p.patch_min_size, MapGen.PATCH_MIN)
	var hi := maxi(p.patch_max_size, lo)
	for _attempt in p.patch_count * 40:
		if res.patches.size() >= p.patch_count:
			break
		var w := rng.randi_range(lo, hi)
		var h := rng.randi_range(lo, hi)
		# x0 >= 1 and x1 <= cols-2: the ring around the hole stays on the grid.
		if p.cols - 1 - w < 1 or p.rows - 1 - h < 1:
			continue
		var r := Rect2i(rng.randi_range(1, p.cols - 1 - w), rng.randi_range(1, p.rows - 1 - h), w, h)
		if MapGen._n01(noise, r.position.x + w * 0.5, r.position.y + h * 0.5) < p.patch_noise_threshold:
			continue
		if not _all_forest_land(res, p, r.grow(1)):
			continue
		var clear := true
		for other in res.patches:
			if r.grow(MapGen.MIN_GAP).intersects(other):
				clear = false
				break
		if clear:
			res.patches.append(r)


static func _all_forest_land(res: MapGen.Result, p: MapGen.Params, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := MapGen.cell_index(p, Vector2i(x, y))
			if i < 0 or res.land[i] == 0 or res.area[i] != MapGen.Area.FOREST:
				return false
	return true


## Fills res.kind, res.grass and res.dirt (and res.water).
static func _assign_ground(res: MapGen.Result, style: MapStyle, p: MapGen.Params, rng: RandomNumberGenerator) -> void:
	res.kind.resize(p.cols * p.rows)
	res.kind.fill(MapGen.FILL)
	for i in res.land.size():
		if res.land[i] == 0:
			res.kind[i] = MapGen.WATER
	var special: Dictionary = {}   # cell -> atlas coord, or null for "no grass tile"
	for r in res.patches:
		var v := rng.randi() % style.variant_count()
		var x0 := r.position.x
		var y0 := r.position.y
		var x1 := r.end.x - 1
		var y1 := r.end.y - 1
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				special[Vector2i(x, y)] = null
				res.kind[y * p.cols + x] = MapGen.HOLE
		special[Vector2i(x0, y0)] = style.edge("nw", v)
		special[Vector2i(x1, y0)] = style.edge("ne", v)
		special[Vector2i(x0, y1)] = style.edge("sw", v)
		special[Vector2i(x1, y1)] = style.edge("se", v)
		for x in range(x0, x1 + 1):
			var col := "l" if x == x0 else ("r" if x == x1 else "m")
			_ring(res, p, special, Vector2i(x, y0 - 1), style.edge("n_" + col, v))
			_ring(res, p, special, Vector2i(x, y1 + 1), style.edge("s_" + col, v))
		for y in range(y0, y1 + 1):
			var row := "t" if y == y0 else ("b" if y == y1 else "m")
			_ring(res, p, special, Vector2i(x0 - 1, y), style.edge("w_" + row, v))
			_ring(res, p, special, Vector2i(x1 + 1, y), style.edge("e_" + row, v))

	# Dark grass follows smooth noise (a dark meadow, not salt and pepper): the darkest
	# `dark_grass_chance` share of the full-grass cells.
	var dark_noise := MapGen._noise(res.seed + 1, p.noise_frequency * 1.5)
	var fills: Array[Vector2i] = []
	for y in p.rows:
		for x in p.cols:
			if not special.has(Vector2i(x, y)) and res.kind[y * p.cols + x] == MapGen.FILL and res.area[y * p.cols + x] == MapGen.Area.FOREST:
				fills.append(Vector2i(x, y))
	var values: Array[float] = []
	for c in fills:
		values.append(MapGen._n01(dark_noise, c.x, c.y))
	var sorted := values.duplicate()
	sorted.sort()
	var cut := 2.0
	if p.dark_grass_chance > 0.0 and not sorted.is_empty():
		cut = sorted[clampi(int((1.0 - p.dark_grass_chance) * sorted.size()), 0, sorted.size() - 1)]

	for i in fills.size():
		var pool: Array[Vector2i] = style.grass_fills
		if values[i] >= cut and not style.grass_dark_fills.is_empty():
			pool = style.grass_dark_fills
		res.grass[fills[i]] = pool[rng.randi() % pool.size()]
	for cell in special:
		if special[cell] != null:
			res.grass[cell] = special[cell]
	for y in p.rows:
		for x in p.cols:
			var i := y * p.cols + x
			if res.land[i] == 0:
				if not style.water_fills.is_empty():
					res.water[Vector2i(x, y)] = style.water_fills[rng.randi() % style.water_fills.size()]
				continue
			var pool: Array[Vector2i] = style.dirt_fills
			if res.area[i] == MapGen.Area.ROCKY and not style.rocky_fills.is_empty():
				pool = style.rocky_fills
			elif res.area[i] == MapGen.Area.BOSS and not style.boss_fills.is_empty():
				pool = style.boss_fills
			res.dirt[Vector2i(x, y)] = pool[rng.randi() % pool.size()]


static func _ring(res: MapGen.Result, p: MapGen.Params, special: Dictionary, c: Vector2i, coord: Vector2i) -> void:
	special[c] = coord
	res.kind[c.y * p.cols + c.x] = MapGen.RING


# ---------------------------------------------------------------- obstacles ---

static func _place_obstacles(res: MapGen.Result, style: MapStyle, p: MapGen.Params, rng: RandomNumberGenerator) -> void:
	var set := style.obstacles
	if set == null or set.regions.is_empty() or set.radii.size() < set.regions.size():
		return
	var size := p.size_px()
	var spacing := maxf(p.obstacle_min_spacing, MapGenWalk.rock_clearance(p))
	var pad := p.cell + MapGenWalk.rock_clearance(p)
	res.obstacle_bucket = 2.0 * float(Array(set.radii).max()) + spacing
	for _attempt in p.obstacle_count * 60:
		if res.obstacles.size() >= p.obstacle_count:
			break
		var idx := rng.randi() % set.regions.size()
		var r := set.radii[idx]
		var pos := Vector2(
			rng.randf_range(pad + r, size.x - pad - r),
			rng.randf_range(pad + r, size.y - pad - r))
		var sprite := set.regions[idx].size * float(style.pixel_scale)
		if not MapGenWalk._obstacle_legal(res, p, pos, r, sprite, spacing):
			continue
		MapGenWalk._add_obstacle(res, {"region": idx, "pos": pos, "radius": r, "node": -1})


# ------------------------------------------------------------------- biomes ---
