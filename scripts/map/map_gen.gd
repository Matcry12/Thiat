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
	var obstacles: Array[Dictionary] = []    ## {region, pos (collision circle centre), radius}
	var border: Array[Dictionary] = []       ## {region, pos (bottom-centre), flip}
	var land := PackedByteArray()            ## 1 land, 0 water, per cell
	var area := PackedByteArray()            ## Area per cell (ignore on water)


static func generate(style: MapStyle, p: Params, rng_seed: int) -> Result:
	var res := Result.new()
	res.seed = rng_seed
	_shape_island(res, p)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var noise := _noise(rng_seed, p.noise_frequency)
	_place_patches(res, p, rng, noise)
	_assign_ground(res, style, p, rng)
	_place_obstacles(res, style, p, rng)
	_place_deco(res, style, p, rng, _noise(rng_seed + 2, p.noise_frequency))
	_place_border(res, style, p, rng)
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
			if x < p.coast_cells or y < p.coast_cells or x >= p.cols - p.coast_cells or y >= p.rows - p.coast_cells:
				continue
			var c := Vector2i(x, y)
			var d := Vector2(float(x) / (p.cols - 1) * 2.0 - 1.0, float(y) / (p.rows - 1) * 2.0 - 1.0).length()
			var v := 1.0 - pow(d, p.island_falloff) + (_n01(noise, x, y) - 0.5) * 2.0 * p.island_noise
			if v > p.island_threshold or Vector2(c).distance_to(Vector2(home)) <= p.home_clear_cells or zc.has_point(c):
				res.land[y * p.cols + x] = 1
	if not _flood_land(res, p, home).has(zc.get_center()):
		_carve(res, p, home, zc.get_center())
	var keep := _flood_land(res, p, home)
	for i in n:
		if res.land[i] == 1 and not keep.has(Vector2i(i % p.cols, i / p.cols)):
			res.land[i] = 0      # islands cut off from home: drop them
	_assign_areas(res, p, home, zc)


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


## A straight land bridge, (2 * corridor_half + 1) cells wide. Never touches the coast_cells rim.
static func _carve(res: Result, p: Params, a: Vector2i, b: Vector2i) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for s in steps + 1:
		var c := Vector2i(Vector2(a).lerp(Vector2(b), float(s) / maxf(steps, 1)).round())
		for dy in range(-p.corridor_half, p.corridor_half + 1):
			for dx in range(-p.corridor_half, p.corridor_half + 1):
				var q := c + Vector2i(dx, dy)
				if q.x >= p.coast_cells and q.y >= p.coast_cells and q.x < p.cols - p.coast_cells and q.y < p.rows - p.coast_cells:
					res.land[q.y * p.cols + q.x] = 1


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
		var clear := true
		for other in res.patches:
			if r.grow(MIN_GAP).intersects(other):
				clear = false
				break
		if clear:
			res.patches.append(r)


## Fills res.kind, res.grass and res.dirt.
static func _assign_ground(res: Result, style: MapStyle, p: Params, rng: RandomNumberGenerator) -> void:
	res.kind.resize(p.cols * p.rows)
	res.kind.fill(FILL)
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
			if not special.has(Vector2i(x, y)):
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
			res.dirt[Vector2i(x, y)] = style.dirt_fills[rng.randi() % style.dirt_fills.size()]


static func _ring(res: Result, p: Params, special: Dictionary, c: Vector2i, coord: Vector2i) -> void:
	special[c] = coord
	res.kind[c.y * p.cols + c.x] = RING


# ---------------------------------------------------------------- obstacles ---

static func _place_obstacles(res: Result, style: MapStyle, p: Params, rng: RandomNumberGenerator) -> void:
	var set := style.obstacles
	if set == null or set.regions.is_empty() or set.radii.size() < set.regions.size():
		return
	var size := p.size_px()
	for _attempt in p.obstacle_count * 60:
		if res.obstacles.size() >= p.obstacle_count:
			break
		var idx := rng.randi() % set.regions.size()
		var r := set.radii[idx]
		var pos := Vector2(
			rng.randf_range(p.cell + r, size.x - p.cell - r),
			rng.randf_range(p.cell + r, size.y - p.cell - r))
		var sprite := set.regions[idx].size * float(style.pixel_scale)
		if not _obstacle_legal(res, p, pos, r, sprite):
			continue
		res.obstacles.append({"region": idx, "pos": pos, "radius": r})
		if not floor_reachable(p, res.obstacles):
			res.obstacles.pop_back()   # it walled something off: drop it


static func _obstacle_legal(res: Result, p: Params, pos: Vector2, r: float, sprite: Vector2) -> bool:
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
	for o in res.obstacles:
		if pos.distance_to(o["pos"]) < r + o["radius"] + p.obstacle_min_spacing:
			return false
	return true


## Flood fill on a coarse grid from the player's spawn: every cell a walker of agent_radius can stand
## on (inside the walls, clear of every rock) must be reachable. Public: the tests call it too.
static func floor_reachable(p: Params, obstacles: Array[Dictionary]) -> bool:
	var size := p.size_px()
	var nx := int(size.x / FLOW_STEP)
	var ny := int(size.y / FLOW_STEP)
	var free := PackedByteArray()
	free.resize(nx * ny)
	var total := 0
	for y in ny:
		for x in nx:
			var c := Vector2((x + 0.5) * FLOW_STEP, (y + 0.5) * FLOW_STEP)
			var ok := c.x >= p.cell + p.agent_radius and c.x <= size.x - p.cell - p.agent_radius \
				and c.y >= p.cell + p.agent_radius and c.y <= size.y - p.cell - p.agent_radius
			if ok:
				for o in obstacles:
					if c.distance_to(o["pos"]) <= o["radius"] + p.agent_radius:
						ok = false
						break
			if ok:
				free[y * nx + x] = 1
				total += 1
	var start := Vector2i(clampi(int(p.player_spawn.x / FLOW_STEP), 0, nx - 1), clampi(int(p.player_spawn.y / FLOW_STEP), 0, ny - 1))
	if free[start.y * nx + start.x] == 0:
		return false
	var seen := PackedByteArray()
	seen.resize(nx * ny)
	var stack: Array[Vector2i] = [start]
	seen[start.y * nx + start.x] = 1
	var reached := 1
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + d
			if q.x < 0 or q.y < 0 or q.x >= nx or q.y >= ny:
				continue
			var i := q.y * nx + q.x
			if free[i] == 1 and seen[i] == 0:
				seen[i] = 1
				reached += 1
				stack.append(q)
	return reached == total


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
		if res.kind[cell.y * p.cols + cell.x] != FILL and not set.on_dirt:
			continue                      # plants only on full grass
		if rng.randf() > _n01(noise, pos.x / p.cell, pos.y / p.cell):
			continue                      # likelier where the noise is high
		var ok := true
		for d in res.deco:
			if pos.distance_to(d["pos"]) < p.deco_min_spacing:
				ok = false
				break
		if ok:
			for o in res.obstacles:
				if pos.distance_to(o["pos"]) < o["radius"] + 8.0:
					ok = false
					break
		if ok:
			res.deco.append({"set": si, "region": rng.randi() % set.regions.size(), "pos": pos})


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
