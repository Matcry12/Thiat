class_name MapGen
extends RefCounted
## Pure logic of the procedural arena: no nodes, no textures. Same seed + same Params + same style
## = exactly the same map. ArenaMap turns the Result into tiles and sprites; tests read it directly.
##
## Ground model (see MapStyle): dirt everywhere below, grass above with rectangular HOLES (the dirt
## patches). The tile set has no concave corners and no 1-wide strips, so patches are rectangles of
## at least 2x2 cells with at least MIN_GAP grass cells between any two (diagonals too).

const MIN_GAP := 2
const PATCH_MIN := 2
const FILL := 0   ## cell kinds: full grass, hole (dirt shows), ring (grass with a bumpy edge)
const HOLE := 1
const RING := 2
const FLOW_STEP := 16.0   ## cell size of the walkability grid, in px
const WATER := 3          ## fourth cell kind: no ground tile, water shows
enum Area { FOREST, ROCKY, BOSS }


class Params:
	var cols := 36
	var rows := 21
	var cell := 32.0
	var world := Vector2(1152, 648)   ## the screen; the grid may overhang it by a part cell
	var patch_count := 4
	var patch_min_size := 3
	var patch_max_size := 7
	var noise_frequency := 0.1
	var patch_noise_threshold := 0.5
	var deco_density := 0.1
	var deco_min_spacing := 30.0
	var obstacle_count := 6
	var obstacle_min_spacing := 40.0
	var spawn_clear_radius := 110.0
	var border_density := 0.9
	var dark_grass_chance := 0.0
	var agent_radius := 14.0      ## the widest walker that must still reach all floor
	var zone := Rect2()           ## FightZone: obstacles never touch it
	var spawns := PackedVector2Array()
	var player_spawn := Vector2.ZERO
	var island_on := false            ## false = the old flat map (every cell land, one area)
	var island_noise_frequency := 0.035
	var island_noise := 0.3           ## how ragged the coast is
	var island_falloff := 2.0         ## higher = land reaches further to the edges
	var island_threshold := 0.15      ## higher = smaller island
	var coast_cells := 3              ## this many cells at the map edge are always water
	var home_clear_cells := 6         ## land disc around home, always
	var corridor_half := 2            ## half width of the land bridge carved when home and boss are cut apart
	var forest_end := 0.45            ## area by distance home -> boss (0 = home, 1 = boss)
	var rocky_end := 0.8
	var area_wobble := 0.12           ## noise on the area borders, so they are not circles

	func size_px() -> Vector2:
		return world


class Result:
	var seed := 0
	var patches: Array[Rect2i] = []          ## the holes, in cells
	var kind := PackedByteArray()            ## FILL / HOLE / RING per cell (index y * cols + x)
	var grass: Dictionary = {}               ## Vector2i cell -> Vector2i atlas coord (no entry = no grass tile)
	var dirt: Dictionary = {}                ## Vector2i cell -> Vector2i atlas coord (every cell)
	var deco: Array[Dictionary] = []         ## {set, region, pos}  pos = bottom-centre of the sprite
	var obstacles: Array[Dictionary] = []    ## {region, pos (collision circle centre), radius, node}  node = index into style.resource_nodes, -1 = plain cover rock
	var border: Array[Dictionary] = []       ## {region, pos (bottom-centre), flip}
	var water: Dictionary = {}               ## Vector2i cell -> atlas coord on style.water_texture (empty = no water art)
	var land := PackedByteArray()            ## 1 land, 0 water, per cell
	var bridge := {}                         ## Vector2i cell -> true for every cell of the carved land bridge (stations may not stand there)
	var area := PackedByteArray()            ## Area per cell (ignore on water)
	var cols := 0                            ## grid size land/area were built with (Params may change later)
	var rows := 0
	var obstacle_grid := {}                  ## Vector2i bucket -> Array of obstacle dicts (spacing lookups)
	var obstacle_bucket := 1.0               ## bucket size: at least 2 * the largest radius + spacing


static func generate(style: MapStyle, p: Params, rng_seed: int) -> Result:
	var res := Result.new()
	res.seed = rng_seed
	_shape_island(res, p)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var noise := _noise(rng_seed, p.noise_frequency)
	_place_patches(res, p, rng, noise)
	_assign_ground(res, style, p, rng)
	if p.island_on and not style.resource_nodes.is_empty():
		_place_nodes(res, style, p, rng)   # on the island every rock is a resource node
	else:
		_place_obstacles(res, style, p, rng)
	_place_deco(res, style, p, rng, _noise(rng_seed + 2, p.noise_frequency))
	if not p.island_on:
		_place_border(res, style, p, rng)   # on the island the water is the edge
	return res


static func _noise(noise_seed: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = noise_seed
	n.frequency = freq
	return n


static func _n01(n: FastNoiseLite, x: float, y: float) -> float:
	return n.get_noise_2d(x, y) * 0.5 + 0.5


# ------------------------------------------------------------------- island ---

static func cell_index(p: Params, c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= p.cols or c.y >= p.rows:
		return -1
	return c.y * p.cols + c.x


static func is_land(res: Result, p: Params, c: Vector2i) -> bool:
	var i := cell_index(p, c)
	return i >= 0 and res.land[i] == 1


static func zone_cells(p: Params) -> Rect2i:
	var a := Vector2i((p.zone.position / p.cell).floor())
	var b := Vector2i((p.zone.end / p.cell).ceil())
	return Rect2i(a, b - a).grow(3)


## Fills res.land and res.area. Shape = radial falloff + noise; then only the land connected to home
## is kept, and a bridge is carved if the boss zone is cut off.
static func _shape_island(res: Result, p: Params) -> void:
	var n := p.cols * p.rows
	res.cols = p.cols
	res.rows = p.rows
	res.land.resize(n)
	res.area.resize(n)
	res.area.fill(Area.FOREST)
	if not p.island_on:
		res.land.fill(1)
		return
	res.land.fill(0)
	var noise := _noise(res.seed + 3, p.island_noise_frequency)
	var home := Vector2i(p.player_spawn / p.cell)
	var zc := zone_cells(p)
	for y in p.rows:
		for x in p.cols:
			var c := Vector2i(x, y)
			var forced := Vector2(c).distance_to(Vector2(home)) <= p.home_clear_cells or zc.has_point(c)
			# the home disc and the zone stay land even inside the coast rim (else home in the rim = no island)
			if not forced and (x < p.coast_cells or y < p.coast_cells or x >= p.cols - p.coast_cells or y >= p.rows - p.coast_cells):
				continue
			var d := Vector2(float(x) / (p.cols - 1) * 2.0 - 1.0, float(y) / (p.rows - 1) * 2.0 - 1.0).length()
			var v := 1.0 - pow(d, p.island_falloff) + (_n01(noise, x, y) - 0.5) * 2.0 * p.island_noise
			if forced or v > p.island_threshold:
				res.land[y * p.cols + x] = 1
	_open_land(res, p, home, zc)
	if not _flood_land(res, p, home).has(zc.get_center()):
		_carve(res, p, home, zc.get_center())
	_drop_cut_off(res, p, home)
	_prune_unwalkable(res, p)
	_drop_cut_off(res, p, home)
	_assign_areas(res, p, home, zc)


static func _drop_cut_off(res: Result, p: Params, home: Vector2i) -> void:
	var keep := _flood_land(res, p, home)
	for i in res.land.size():
		if res.land[i] == 1 and not keep.has(Vector2i(i % p.cols, i / p.cols)):
			res.land[i] = 0      # islands cut off from home: drop them


## Land a walker cannot reach from home (a 1-cell neck behind a lobe) must not exist: drop the cell under
## every walk-grid sample that floor_reachable would call cut off. Repeats until none is left (each pass
## only removes land, so it ends). Done once per generate, before rocks.
static func _prune_unwalkable(res: Result, p: Params) -> void:
	var nx := int(p.size_px().x / FLOW_STEP)
	var ny := int(p.size_px().y / FLOW_STEP)
	var start := Vector2i(clampi(int(p.player_spawn.x / FLOW_STEP), 0, nx - 1), clampi(int(p.player_spawn.y / FLOW_STEP), 0, ny - 1))
	while true:
		var free := _walk_free(p, res.land)
		if free[start.y * nx + start.x] == 0:
			return
		var seen := _walk_flood(free, nx, ny, start)
		var dropped := false
		for i in free.size():
			if free[i] == 1 and seen[i] == 0:
				var c := Vector2i(Vector2((i % nx + 0.5) * FLOW_STEP, (i / nx + 0.5) * FLOW_STEP) / p.cell)
				res.land[c.y * p.cols + c.x] = 0
				dropped = true
		if not dropped:
			return


## Morphological opening (erode then dilate, 4-neighbour): removes land strips 1 cell wide. A walker
## cannot stand on them, and they would make "all land is walkable" false. Home disc and zone stay.
static func _open_land(res: Result, p: Params, home: Vector2i, zc: Rect2i) -> void:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var core := PackedByteArray()
	core.resize(res.land.size())
	for y in p.rows:
		for x in p.cols:
			var c := Vector2i(x, y)
			var ok := is_land(res, p, c)
			for d in dirs:
				ok = ok and is_land(res, p, c + d)
			core[y * p.cols + x] = 1 if ok else 0
	var opened := core.duplicate()
	for y in p.rows:
		for x in p.cols:
			if core[y * p.cols + x] == 1:
				for d in dirs:
					var i := cell_index(p, Vector2i(x, y) + d)
					if i >= 0:
						opened[i] = 1
	for y in p.rows:
		for x in p.cols:
			var c := Vector2i(x, y)
			var i := y * p.cols + x
			if Vector2(c).distance_to(Vector2(home)) <= p.home_clear_cells or zc.has_point(c):
				continue
			res.land[i] = opened[i]


## Land cells reachable from `from` (4-neighbour). Returns a set (Dictionary cell -> true).
static func _flood_land(res: Result, p: Params, from: Vector2i) -> Dictionary:
	var seen := {}
	if not is_land(res, p, from):
		return seen
	var stack: Array[Vector2i] = [from]
	seen[from] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + d
			if is_land(res, p, q) and not seen.has(q):
				seen[q] = true
				stack.append(q)
	return seen


## A straight land bridge, (2 * max(corridor_half, 1) + 1) cells wide. Never touches the coast_cells rim.
static func _carve(res: Result, p: Params, a: Vector2i, b: Vector2i) -> void:
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


static func _assign_areas(res: Result, p: Params, home: Vector2i, zc: Rect2i) -> void:
	var noise := _noise(res.seed + 4, p.island_noise_frequency * 2.0)
	var span := maxf(Vector2(home).distance_to(Vector2(zc.get_center())), 1.0)
	for y in p.rows:
		for x in p.cols:
			var i := y * p.cols + x
			if res.land[i] == 0:
				continue
			var t := Vector2(home).distance_to(Vector2(x, y)) / span + (_n01(noise, x, y) - 0.5) * 2.0 * p.area_wobble
			var a := Area.FOREST if t < p.forest_end else (Area.ROCKY if t < p.rocky_end else Area.BOSS)
			if zc.has_point(Vector2i(x, y)):
				a = Area.BOSS
			res.area[i] = a


# ------------------------------------------------------------------ patches ---

static func _place_patches(res: Result, p: Params, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var lo := maxi(p.patch_min_size, PATCH_MIN)
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
		if _n01(noise, r.position.x + w * 0.5, r.position.y + h * 0.5) < p.patch_noise_threshold:
			continue
		if not _all_forest_land(res, p, r.grow(1)):
			continue
		var clear := true
		for other in res.patches:
			if r.grow(MIN_GAP).intersects(other):
				clear = false
				break
		if clear:
			res.patches.append(r)


static func _all_forest_land(res: Result, p: Params, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := cell_index(p, Vector2i(x, y))
			if i < 0 or res.land[i] == 0 or res.area[i] != Area.FOREST:
				return false
	return true


## Fills res.kind, res.grass and res.dirt (and res.water).
static func _assign_ground(res: Result, style: MapStyle, p: Params, rng: RandomNumberGenerator) -> void:
	res.kind.resize(p.cols * p.rows)
	res.kind.fill(FILL)
	for i in res.land.size():
		if res.land[i] == 0:
			res.kind[i] = WATER
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
				res.kind[y * p.cols + x] = HOLE
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
	var dark_noise := _noise(res.seed + 1, p.noise_frequency * 1.5)
	var fills: Array[Vector2i] = []
	for y in p.rows:
		for x in p.cols:
			if not special.has(Vector2i(x, y)) and res.kind[y * p.cols + x] == FILL and res.area[y * p.cols + x] == Area.FOREST:
				fills.append(Vector2i(x, y))
	var values: Array[float] = []
	for c in fills:
		values.append(_n01(dark_noise, c.x, c.y))
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
			if res.area[i] == Area.ROCKY and not style.rocky_fills.is_empty():
				pool = style.rocky_fills
			elif res.area[i] == Area.BOSS and not style.boss_fills.is_empty():
				pool = style.boss_fills
			res.dirt[Vector2i(x, y)] = pool[rng.randi() % pool.size()]


static func _ring(res: Result, p: Params, special: Dictionary, c: Vector2i, coord: Vector2i) -> void:
	special[c] = coord
	res.kind[c.y * p.cols + c.x] = RING


# ---------------------------------------------------------------- obstacles ---

static func _place_obstacles(res: Result, style: MapStyle, p: Params, rng: RandomNumberGenerator) -> void:
	var set := style.obstacles
	if set == null or set.regions.is_empty() or set.radii.size() < set.regions.size():
		return
	var size := p.size_px()
	var spacing := maxf(p.obstacle_min_spacing, rock_clearance(p))
	var pad := p.cell + rock_clearance(p)
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
		if not _obstacle_legal(res, p, pos, r, sprite, spacing):
			continue
		_add_obstacle(res, {"region": idx, "pos": pos, "radius": r, "node": -1})


## Trees, rocks and copper by area: per kind and area, round(density * land cells / 100) nodes, each at a
## random spot of a random land cell of that area. Same legality rules as the plain rocks.
static func _place_nodes(res: Result, style: MapStyle, p: Params, rng: RandomNumberGenerator) -> void:
	var cells: Array = [[], [], []]   # per Area: land cells
	for i in res.land.size():
		if res.land[i] == 1:
			cells[res.area[i]].append(Vector2i(i % p.cols, i / p.cols))
	var spacing := maxf(p.obstacle_min_spacing, rock_clearance(p))
	var widest := 0.0
	for k in style.resource_nodes:
		widest = maxf(widest, k.radius)
	res.obstacle_bucket = 2.0 * widest + spacing
	for ki in style.resource_nodes.size():
		var kind: ResourceNodeData = style.resource_nodes[ki]
		for a in 3:
			var list: Array = cells[a]
			var density := [kind.density_forest, kind.density_rocky, kind.density_boss][a] as float
			var target := roundi(density * list.size() / 100.0)
			var made := 0
			for _attempt in target * 60:
				if made >= target:
					break
				var c: Vector2i = list[rng.randi() % list.size()]
				var pos := (Vector2(c) + Vector2(rng.randf(), rng.randf())) * p.cell
				var v := rng.randi() % maxi(kind.regions.size(), 1)
				var sprite := kind.regions[v].size * float(kind.pixel_scale) if v < kind.regions.size() else Vector2.ZERO
				if _obstacle_legal(res, p, pos, kind.radius, sprite, spacing):
					_add_obstacle(res, {"region": v, "pos": pos, "radius": kind.radius, "node": ki})
					made += 1
	_repair_reach(res, p)


static func _add_obstacle(res: Result, o: Dictionary) -> void:
	res.obstacles.append(o)
	res.obstacle_grid.get_or_add(Vector2i(o["pos"] / res.obstacle_bucket), []).append(o)


## True if any obstacle is closer than r + its radius + spacing. Bucket lookup; needs that sum <= obstacle_bucket.
static func _obstacle_near(res: Result, pos: Vector2, r: float, spacing: float) -> bool:
	var b := Vector2i(pos / res.obstacle_bucket)
	for by in range(b.y - 1, b.y + 2):
		for bx in range(b.x - 1, b.x + 2):
			for o: Dictionary in res.obstacle_grid.get(Vector2i(bx, by), []):
				if pos.distance_to(o["pos"]) < r + o["radius"] + spacing:
					return true
	return false


## A walker's width plus one FLOW_STEP: rocks keep this far from water, walls and each other, so every
## gap is wide enough for the 16 px walkability grid of floor_reachable to see a path through it.
static func rock_clearance(p: Params) -> float:
	return p.agent_radius * 2.0 + FLOW_STEP


static func _obstacle_legal(res: Result, p: Params, pos: Vector2, r: float, sprite: Vector2, spacing: float) -> bool:
	var reach := r + rock_clearance(p)
	for dy in [-reach, 0.0, reach]:
		for dx in [-reach, 0.0, reach]:
			# ponytail: 9 samples can miss a 1-cell water notch between them; full cell scan if a rock ever touches water
			if not is_land(res, p, Vector2i((pos + Vector2(dx, dy)) / p.cell)):
				return false
	# Never touching the fight zone: the boss has no pathfinding.
	var closest := Vector2(clampf(pos.x, p.zone.position.x, p.zone.end.x), clampf(pos.y, p.zone.position.y, p.zone.end.y))
	if pos.distance_to(closest) < r + 4.0:
		return false
	# The picture too: the sprite stands on the circle, so a tall rock must not lean into the zone
	# (you would walk through what you can see).
	if Rect2(pos.x - sprite.x * 0.5, pos.y + r - sprite.y, sprite.x, sprite.y).intersects(p.zone):
		return false
	for s in p.spawns:
		if pos.distance_to(s) < p.spawn_clear_radius + r:
			return false
	return not _obstacle_near(res, pos, r, spacing)


## Walk grid (FLOW_STEP px): 1 where a walker of agent_radius can stand, ignoring rocks. Inside the walls,
## and (if `land` is given) with all four sides and the centre on land.
static func _walk_free(p: Params, land := PackedByteArray()) -> PackedByteArray:
	var size := p.size_px()
	var nx := int(size.x / FLOW_STEP)
	var ny := int(size.y / FLOW_STEP)
	var free := PackedByteArray()
	free.resize(nx * ny)
	var r := p.agent_radius
	var lo := p.cell + r   # inside the walls: every sample below is >= 1 cell from the grid edge, so no bounds checks
	for y in ny:
		var cy := (y + 0.5) * FLOW_STEP
		if cy < lo or cy > size.y - lo:
			continue
		var row := int(cy / p.cell) * p.cols
		var row_up := int((cy - r) / p.cell) * p.cols
		var row_dn := int((cy + r) / p.cell) * p.cols
		for x in nx:
			var cx := (x + 0.5) * FLOW_STEP
			if cx < lo or cx > size.x - lo:
				continue
			if land.is_empty():
				free[y * nx + x] = 1
				continue
			var col := int(cx / p.cell)
			if land[row + col] == 1 and land[row + int((cx - r) / p.cell)] == 1 and land[row + int((cx + r) / p.cell)] == 1 \
					and land[row_up + col] == 1 and land[row_dn + col] == 1:
				free[y * nx + x] = 1
	return free


## 4-neighbour flood over a walk grid; returns the seen mask.
static func _walk_flood(free: PackedByteArray, nx: int, ny: int, start: Vector2i) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(nx * ny)
	if free[start.y * nx + start.x] == 0:
		return seen
	var stack: Array[Vector2i] = [start]
	seen[start.y * nx + start.x] = 1
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + d
			if q.x < 0 or q.y < 0 or q.x >= nx or q.y >= ny:
				continue
			var i := q.y * nx + q.x
			if free[i] == 1 and seen[i] == 0:
				seen[i] = 1
				stack.append(q)
	return seen


## Flood fill on a coarse grid from the player's spawn: every cell a walker of agent_radius can stand
## on (inside the walls, clear of every rock) must be reachable. Public: the tests call it too.
static func floor_reachable(p: Params, obstacles: Array[Dictionary], land := PackedByteArray()) -> bool:
	return _unreached(p, obstacles, land).is_empty()


## Centres of the walk-grid samples a walker could stand on but cannot reach from home (see floor_reachable).
## If home itself is blocked, returns [Vector2.INF].
static func _unreached(p: Params, obstacles: Array[Dictionary], land: PackedByteArray) -> PackedVector2Array:
	var nx := int(p.size_px().x / FLOW_STEP)
	var ny := int(p.size_px().y / FLOW_STEP)
	var free := walk_grid(p, obstacles, land)
	var start := Vector2i(clampi(int(p.player_spawn.x / FLOW_STEP), 0, nx - 1), clampi(int(p.player_spawn.y / FLOW_STEP), 0, ny - 1))
	if free[start.y * nx + start.x] == 0:
		return PackedVector2Array([Vector2.INF])
	var seen := _walk_flood(free, nx, ny, start)
	var out := PackedVector2Array()
	for i in free.size():
		if free[i] == 1 and seen[i] == 0:
			out.append(Vector2((i % nx + 0.5) * FLOW_STEP, (i / nx + 0.5) * FLOW_STEP))
	return out


## The walk grid with every rock cleared out of it: 1 where a walker can stand.
static func walk_grid(p: Params, obstacles: Array[Dictionary], land: PackedByteArray) -> PackedByteArray:
	var nx := int(p.size_px().x / FLOW_STEP)
	var ny := int(p.size_px().y / FLOW_STEP)
	var free := _walk_free(p, land)
	for o in obstacles:   # each rock clears only the samples in its own box
		var reach: float = o["radius"] + p.agent_radius
		var pos: Vector2 = o["pos"]
		for y in range(maxi(int((pos.y - reach) / FLOW_STEP), 0), mini(int((pos.y + reach) / FLOW_STEP) + 1, ny)):
			for x in range(maxi(int((pos.x - reach) / FLOW_STEP), 0), mini(int((pos.x + reach) / FLOW_STEP) + 1, nx)):
				if Vector2((x + 0.5) * FLOW_STEP, (y + 0.5) * FLOW_STEP).distance_to(pos) <= reach:
					free[y * nx + x] = 0
	return free


## Can a walker still get from the player's spawn to `goal` (px) on `free` once the rects in `blockers`
## (solid boxes, px) are added? Reuses the same flood as floor_reachable. `free` is not changed.
## One flood; call it with no blockers first to know whether there is a path to protect at all.
static func goal_reachable_with(p: Params, free: PackedByteArray, blockers: Array[Rect2], goal: Vector2) -> bool:
	var nx := int(p.size_px().x / FLOW_STEP)
	var ny := int(p.size_px().y / FLOW_STEP)
	var start := Vector2i(clampi(int(p.player_spawn.x / FLOW_STEP), 0, nx - 1), clampi(int(p.player_spawn.y / FLOW_STEP), 0, ny - 1))
	var g := Vector2i(clampi(int(goal.x / FLOW_STEP), 0, nx - 1), clampi(int(goal.y / FLOW_STEP), 0, ny - 1))
	var f := free.duplicate()
	for r in blockers:
		var b := r.grow(p.agent_radius)
		for y in range(maxi(int(b.position.y / FLOW_STEP), 0), mini(int(b.end.y / FLOW_STEP) + 1, ny)):
			for x in range(maxi(int(b.position.x / FLOW_STEP), 0), mini(int(b.end.x / FLOW_STEP) + 1, nx)):
				if b.has_point(Vector2((x + 0.5) * FLOW_STEP, (y + 0.5) * FLOW_STEP)):
					f[y * nx + x] = 0
	if f[start.y * nx + start.x] == 0:
		return false
	return _walk_flood(f, nx, ny, start)[g.y * nx + g.x] == 1


## Many nodes can close a pocket between them and the coast. Drop the nodes around any walkable spot
## the walker cannot reach, until none is left (each pass only removes, so it ends).
static func _repair_reach(res: Result, p: Params) -> void:
	while true:
		var lost := _unreached(p, res.obstacles, res.land)
		if lost.is_empty() or lost[0] == Vector2.INF:
			return
		var kept: Array[Dictionary] = []
		for o in res.obstacles:
			var reach: float = o["radius"] + p.agent_radius + 2.0 * FLOW_STEP
			var near := false
			for q in lost:
				if q.distance_to(o["pos"]) <= reach:
					near = true
					break
			if not near:
				kept.append(o)
		if kept.size() == res.obstacles.size():
			return   # nothing removable: do not loop forever
		res.obstacles = kept
		res.obstacle_grid.clear()
		for o in kept:
			res.obstacle_grid.get_or_add(Vector2i(o["pos"] / res.obstacle_bucket), []).append(o)


# --------------------------------------------------------------------- deco ---

static func _place_deco(res: Result, style: MapStyle, p: Params, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var sets := style.deco
	var total_w := 0.0
	for s in sets:
		total_w += s.weight if not s.regions.is_empty() else 0.0
	if total_w <= 0.0:
		return
	var size := p.size_px()
	var target := int(p.deco_density * p.cols * p.rows)
	var grid := {}   # Vector2i bucket -> Array of positions; bucket size = deco_min_spacing
	var bucket := maxf(p.deco_min_spacing, 1.0)
	for _attempt in target * 25:
		if res.deco.size() >= target:
			break
		var pos := Vector2(rng.randf_range(p.cell * 1.5, size.x - p.cell * 1.5), rng.randf_range(p.cell * 1.5, size.y - p.cell))
		var pick := rng.randf() * total_w
		var si := 0
		for i in sets.size():
			var w: float = sets[i].weight if not sets[i].regions.is_empty() else 0.0
			if pick < w:
				si = i
				break
			pick -= w
		var set: PropSet = sets[si]
		var cell := Vector2i(pos / p.cell)
		if res.land[cell.y * p.cols + cell.x] == 0:
			continue
		if res.kind[cell.y * p.cols + cell.x] != FILL and not set.on_dirt:
			continue                      # plants only on full grass
		if rng.randf() > _n01(noise, pos.x / p.cell, pos.y / p.cell):
			continue                      # likelier where the noise is high
		var ok := true
		var b := Vector2i(pos / bucket)
		for by in range(b.y - 1, b.y + 2):
			for bx in range(b.x - 1, b.x + 2):
				for other: Vector2 in grid.get(Vector2i(bx, by), []):
					if pos.distance_to(other) < p.deco_min_spacing:
						ok = false
		if ok:
			for o in res.obstacles:
				if pos.distance_to(o["pos"]) < o["radius"] + 8.0:
					ok = false
					break
		if ok:
			res.deco.append({"set": si, "region": rng.randi() % set.regions.size(), "pos": pos})
			grid.get_or_add(b, []).append(pos)


# ------------------------------------------------------------------- border ---

## Bushes laid along the four walls, each overlapping the one before. Sorted by y so lower ones
## cover upper ones.
static func _place_border(res: Result, style: MapStyle, p: Params, rng: RandomNumberGenerator) -> void:
	var set := style.border
	if set == null or set.regions.is_empty():
		return
	var s := float(style.pixel_scale)
	var size := p.size_px()
	var inner := p.cell - 6.0         # how far a bush reaches in from the screen edge
	var dens := maxf(p.border_density, 0.05)
	for edge in 4:                    # 0 top, 1 bottom, 2 left, 3 right
		var t := -16.0
		var limit := size.x if edge < 2 else size.y
		while t < limit:
			var idx := rng.randi() % set.regions.size()
			var sz: Vector2 = set.regions[idx].size * s
			var pos := Vector2.ZERO
			var along := sz.x if edge < 2 else sz.y
			match edge:
				0: pos = Vector2(t + sz.x * 0.5, inner + rng.randf_range(-4.0, 8.0))
				1: pos = Vector2(t + sz.x * 0.5, size.y - inner + sz.y + rng.randf_range(-8.0, 4.0))
				2: pos = Vector2(inner - sz.x * 0.5 + rng.randf_range(-4.0, 8.0), t + sz.y)
				3: pos = Vector2(size.x - inner + sz.x * 0.5 + rng.randf_range(-8.0, 4.0), t + sz.y)
			res.border.append({"region": idx, "pos": pos, "flip": rng.randf() < 0.5})
			t += along * rng.randf_range(0.5, 0.75) / dens
	res.border.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
