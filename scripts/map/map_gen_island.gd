class_name MapGenIsland
extends RefCounted
## MapGen stage "island": moved out of map_gen.gd unchanged (static helpers; MapGen keeps the public API and the shared consts / Params / Result).


## Fills res.land and res.area. Shape = the continent (see _make_continent); then only the land connected to home is kept, a bridge
## is carved if the boss zone is cut off, the climate biomes are made, then the water (rivers, lakes, shallows) is cut out of the land
## and what a walker cannot reach is dropped (_make_water, _prune_unwalkable).
static func _shape_island(res: MapGen.Result, p: MapGen.Params) -> void:
	var n := p.cols * p.rows
	res.cols = p.cols
	res.rows = p.rows
	res.land.resize(n)
	res.area.resize(n)
	res.area.fill(MapGen.Area.FOREST)
	if p.yard:
		res.land.fill(1)
		res.walk_land = res.land
		res.biome.resize(n)
		res.biome.fill(MapGen.Biome.PLAINS)
		res.f.resize(n)
		res.temp.resize(n)
		res.humid.resize(n)
		res.rough.resize(n)
		return
	if not p.island_on:
		res.land.fill(1)
		res.walk_land = res.land
		return
	res.land.fill(0)
	var home := Vector2i(p.player_spawn / p.cell)
	var zc := MapGen.zone_cells(p)
	var t := Time.get_ticks_usec()
	_make_continent(res, p, home, zc)
	t = MapGen._lap(res, "shape.continent", t)
	_open_land(res, p, home, zc)
	t = MapGen._lap(res, "shape.open", t)
	var zi := MapGen.cell_index(p, zc.get_center())
	var reached := _flood_land(res, p, home)
	if zi < 0 or reached[zi] == 0:
		_carve(res, p, home, zc.get_center())
		reached = PackedByteArray()
	t = MapGen._lap(res, "shape.flood+carve", t)
	_drop_cut_off(res, p, home, reached)
	t = MapGen._lap(res, "shape.dropcut", t)
	MapGenBiomes._make_biomes(res, p, home)
	t = MapGen._lap(res, "shape.biomes", t)
	MapGenWater._make_water(res, p, home, zc)
	t = MapGen._lap(res, "shape.water", t)
	_prune_unwalkable(res, p)
	t = MapGen._lap(res, "shape.prune", t)
	_assign_areas(res, MapGen.boss_cells(p))


## Length scale for a map smaller than the 512 x 512 island: the water numbers are meant for 512 and shrink with the map.
static func _world_scale(p: MapGen.Params) -> float:
	return minf(1.0, minf(p.cols, p.rows) / 512.0)


## The land mass (0038 step 3): "continentalness" = noise (domain-warped like the climate) mixed with one big round blob, faded to
## ocean towards the map edge, plus a ridge along the home -> boss line so the island always reaches both. Sea level is the quantile that
## gives `land_share` of land. Bays and peninsulas come from the noise; home and the zone stay land.
static func _make_continent(res: MapGen.Result, p: MapGen.Params, home: Vector2i, zc: Rect2i) -> void:
	var cols := p.cols
	var rows := p.rows
	var n := cols * rows
	var ws := _world_scale(p)
	var amp := p.climate_warp_amp
	var wnx := MapGenBiomes._climate_noise(res.seed + MapGen.SEED_CLIMATE + 3, p.climate_warp_period, p.climate_warp_octaves)
	var wny := MapGenBiomes._climate_noise(res.seed + MapGen.SEED_CLIMATE + 4, p.climate_warp_period, p.climate_warp_octaves)
	var cn := MapGenBiomes._climate_noise(res.seed + MapGen.SEED_WATER, p.cont_period * ws, p.cont_octaves)
	var warp_x := PackedFloat32Array()
	var warp_y := PackedFloat32Array()
	warp_x.resize(n)
	warp_y.resize(n)
	var vals := PackedFloat32Array()
	vals.resize(n)
	var edge_cells := maxf(p.cont_edge_cells * ws, 1.0)
	var a := Vector2(home) + Vector2(0.5, 0.5)
	var seg := Vector2(zc.get_center()) - a
	var seg_len2 := maxf(seg.length_squared(), 1.0)
	var neck := maxf(p.neck_cells * ws, 1.0)
	var hx := cols * 0.5
	var hy := rows * 0.5
	for y in rows:
		var ey := mini(y, rows - 1 - y)
		for x in cols:
			var i := y * cols + x
			var wx := wnx.get_noise_2d(x + 0.5, y + 0.5) * amp
			var wy := wny.get_noise_2d(x + 0.5, y + 0.5) * amp
			warp_x[i] = wx
			warp_y[i] = wy
			var e := mini(ey, mini(x, cols - 1 - x))
			var sx := x + 0.5 + wx
			var sy := y + 0.5 + wy
			var v := 0.0
			if e >= 1:
				var b := clampf(0.5 + cn.get_noise_2d(sx, sy) * p.cont_gain, 0.0, 1.0)
				var r := Vector2((x + 0.5 - hx) / hx, (y + 0.5 - hy) / hy).length()
				v = (1.0 - p.cont_radial) * b + p.cont_radial * clampf(1.0 - pow(r, 1.8), 0.0, 1.0)
				if e < edge_cells:
					v *= pow(e / edge_cells, 0.7)
			var q := Vector2(sx, sy) - a
			var d := (q - seg * clampf(q.dot(seg) / seg_len2, 0.0, 1.0)).length()
			vals[i] = v + p.neck_boost * (1.0 - smoothstep(0.0, neck, d))
	res.warp_x = warp_x
	res.warp_y = warp_y
	var sorted := vals.duplicate()
	sorted.sort()
	var sea: float = sorted[clampi(int(n * (1.0 - p.land_share)), 0, n - 1)]
	var land := res.land
	var hr2 := p.home_clear_cells * p.home_clear_cells
	var rim := p.coast_cells
	for y in rows:
		var dy2 := (y - home.y) * (y - home.y)
		var zone_y := y >= zc.position.y and y < zc.end.y
		for x in cols:
			var i := y * cols + x
			var forced := (x - home.x) * (x - home.x) + dy2 <= hr2 or (zone_y and x >= zc.position.x and x < zc.end.x)
			# the home disc and the zone stay land even inside the coast rim (else home in the rim = no island)
			if forced or (vals[i] > sea and x >= rim and y >= rim and x < cols - rim and y < rows - rim):
				land[i] = 1
	res.land = land


static func _drop_cut_off(res: MapGen.Result, p: MapGen.Params, home: Vector2i, known := PackedByteArray()) -> PackedInt32Array:
	var keep := known if not known.is_empty() else _flood_land(res, p, home)   # `known`: the flood the caller already made of this very land
	var dropped := PackedInt32Array()
	for i in res.land.size():
		if res.land[i] == 1 and keep[i] == 0:
			res.land[i] = 0      # islands cut off from home: drop them
			dropped.append(i)
	return dropped


## Ground a walker cannot reach from home (a 1-cell neck behind a lobe, a shallow nook) must not exist: drop the cell under every walk-grid
## sample that floor_reachable would call cut off, from the land or the shallow water. Repeats until none is left (each pass only removes
## walkable cells, so it ends). Done once per generate, after the water, on `walk_land`; leaves the final walk grid in walk_base.
static func _prune_unwalkable(res: MapGen.Result, p: MapGen.Params) -> void:
	var nx := int(p.size_px().x / MapGen.FLOW_STEP)
	var ny := int(p.size_px().y / MapGen.FLOW_STEP)
	var start := Vector2i(clampi(int(p.player_spawn.x / MapGen.FLOW_STEP), 0, nx - 1), clampi(int(p.player_spawn.y / MapGen.FLOW_STEP), 0, ny - 1))
	var walk := res.walk_land
	var cnt := PackedInt32Array([0])
	var free := MapGenWalk._walk_free(p, walk, cnt)
	var free_n := cnt[0]
	var home_i := MapGen.cell_index(p, Vector2i(p.player_spawn / p.cell))
	var cell_seen := PackedByteArray()
	var stack := PackedInt32Array()
	while true:
		if free[start.y * nx + start.x] == 0:
			break
		var dropped := PackedInt32Array()
		var seen := MapGenWalk._walk_flood(free, nx, ny, start, cnt)
		if cnt[0] != free_n:   # a walker can stand somewhere it cannot reach: drop the cell under it
			for i in free.size():
				if free[i] == 1 and seen[i] == 0:
					var c := Vector2i(Vector2((i % nx + 0.5) * MapGen.FLOW_STEP, (i / nx + 0.5) * MapGen.FLOW_STEP) / p.cell)
					dropped.append(c.y * p.cols + c.x)
		else:   # and walkable cells (4-neighbour) that home cannot reach, e.g. two cells that only touch at a corner
			cell_seen.clear()
			cell_seen.resize(walk.size())
			MapGenWalk._span_fill(walk, cell_seen, p.cols, p.rows, home_i, 1, PackedInt32Array(), stack)
			for i in walk.size():
				if walk[i] == 1 and cell_seen[i] == 0:
					dropped.append(i)
		if dropped.is_empty():   # everything is reached: this grid is the final one
			break
		for ci in dropped:
			walk[ci] = 0
			res.land[ci] = 0
			if not res.shallow.is_empty():
				res.shallow[ci] = 0
				res.fresh[ci] = 0
		free_n += MapGenWalk._walk_free_patch(p, walk, free, dropped)
	res.walk_land = walk
	res.walk_base = free
	res.walk_base_n = free_n


## Morphological opening (erode then dilate, 4-neighbour): removes land strips 1 cell wide. A walker
## cannot stand on them, and they would make "all land is walkable" false. Home disc and zone stay.
static func _open_land(res: MapGen.Result, p: MapGen.Params, home: Vector2i, zc: Rect2i) -> void:
	var cols := p.cols
	var rows := p.rows
	var land := res.land
	var opened := PackedByteArray()
	opened.resize(cols * rows)
	for y in range(1, rows - 1):   # a core cell has all four neighbours on the grid; opening marks it and them
		for i in range(y * cols + 1, y * cols + cols - 1):
			if land[i] == 1 and land[i - 1] == 1 and land[i + 1] == 1 and land[i - cols] == 1 and land[i + cols] == 1:
				opened[i] = 1
				opened[i - 1] = 1
				opened[i + 1] = 1
				opened[i - cols] = 1
				opened[i + cols] = 1
	# home disc and zone keep their land
	var r := p.home_clear_cells
	for y in range(maxi(home.y - r, 0), mini(home.y + r + 1, rows)):
		for x in range(maxi(home.x - r, 0), mini(home.x + r + 1, cols)):
			if (x - home.x) * (x - home.x) + (y - home.y) * (y - home.y) <= r * r:
				opened[y * cols + x] = land[y * cols + x]
	for y in range(maxi(zc.position.y, 0), mini(zc.end.y, rows)):
		for x in range(maxi(zc.position.x, 0), mini(zc.end.x, cols)):
			opened[y * cols + x] = land[y * cols + x]
	res.land = opened


## Land cells reachable from `from` (4-neighbour) as a mask over the grid (1 = reached). All zero if `from` is not land.
static func _flood_land(res: MapGen.Result, p: MapGen.Params, from: Vector2i) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(p.cols * p.rows)
	if MapGen.is_land(res, p, from):
		MapGenWalk._span_fill(res.land, seen, p.cols, p.rows, from.y * p.cols + from.x)
	return seen


## A straight land bridge, (2 * max(corridor_half, 1) + 1) cells wide. Never touches the coast_cells rim.
static func _carve(res: MapGen.Result, p: MapGen.Params, a: Vector2i, b: Vector2i) -> void:
	var half := maxi(p.corridor_half, 1)   # 0 would be an 8-connected line: the 4-neighbour flood cuts it
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for s in steps + 1:
		var c := Vector2i(Vector2(a).lerp(Vector2(b), float(s) / maxf(steps, 1)).round())
		for dy in range(-half, half + 1):
			for dx in range(-half, half + 1):
				var q := c + Vector2i(dx, dy)
				if q.x >= p.coast_cells and q.y >= p.coast_cells and q.x < p.cols - p.coast_cells and q.y < p.rows - p.coast_cells:
					res.land[q.y * p.cols + q.x] = 1
					res.bridge[q] = true


## Boss land (the fight zone grown by boss_land_cells) is BOSS; every other land cell is FOREST (its look comes from its biome).
static func _assign_areas(res: MapGen.Result, zc: Rect2i) -> void:
	var cols := res.cols
	for i in res.land.size():
		if res.land[i] == 0:
			continue
		res.area[i] = MapGen.Area.BOSS if zc.has_point(Vector2i(i % cols, i / cols)) else MapGen.Area.FOREST


# ------------------------------------------------------------------ patches ---
