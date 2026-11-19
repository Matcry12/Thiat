class_name MapGenGround
extends RefCounted
## MapGen stage "ground": moved out of map_gen.gd unchanged (static helpers; MapGen keeps the public API and the shared consts / Params / Result).


# ------------------------------------------------------------------- ground ---
## The island's ground (looks only). Area -> ground, smoothed so no 1-cell spikes or holes reach the tiles, plus a
## beach. Dirt (patches, the camp, paths) is NOT in the ground array: it is a list of round stamps in pixels
## (`res.dirt_stamps`) that GroundBaker paints smoothly over the tiles, so a path at 45 degrees has no stair teeth.
## All from its own random stream (seed + 101): the gameplay stream is untouched, so seeds keep their trees, rocks and deco.
static func _build_ground(res: MapGen.Result, style: MapStyle, p: MapGen.Params) -> void:
	var n := p.cols * p.rows
	var rng := RandomNumberGenerator.new()
	rng.seed = res.seed + 101
	var noise := MapGen._noise(res.seed + 5, 0.13)
	var t := Time.get_ticks_usec()
	var g := PackedByteArray()
	var dist: PackedByteArray
	# The expensive base (biome ground, border jitter, smoothing, small patches, water distance) only depends on these numbers: a look
	# slider for paths / camp / patches re-uses it and only redoes the stamps and the beach (0038 step 2).
	var key := [p.border_jitter, p.min_island_cells, p.smooth_passes, p.camp_radius + p.beach_cells + 3, int(style.pixel_plains != null)]
	if res.ground_key == key and not res.ground_base.is_empty():
		g = res.ground_base.duplicate()
		dist = res.ground_dist
	else:
		g.resize(n)
		var mix: Array = []   # per biome: the noise that mixes its second ground in (BiomeData.ground_alt), null = none
		for bd in res.biomes:
			mix.append(MapGen._noise(res.seed + MapGen.SEED_VEG_NOISE + 1, 1.0 / maxf(bd.ground_alt_period, 1.0)) if bd.ground_alt > 0 else null)
		for i in n:
			if res.land[i] == 1:
				if res.area[i] == MapGen.Area.BOSS:
					g[i] = MapGen.AREA_GROUND[MapGen.Area.BOSS]
					continue
				var bi: int = res.biome[i]
				var bd := res.biomes[bi]
				g[i] = bd.ground
				if mix[bi] != null and MapGen._n01(mix[bi], i % p.cols, i / p.cols) >= bd.ground_alt_share:
					g[i] = bd.ground_alt   # rocky: stone with dirt in clumps
		t = MapGen._lap(res, "ground.init", t)
		_jitter_borders(g, p, res.seed + 9)   # twice, so a border wanders by up to two cells
		_jitter_borders(g, p, res.seed + 10)
		t = MapGen._lap(res, "ground.jitter", t)
		_smooth_ground(g, p.cols, p.rows, p.smooth_passes)
		t = MapGen._lap(res, "ground.smooth", t)
		_drop_small(g, p)
		t = MapGen._lap(res, "ground.dropsmall", t)
		if not res.shore.is_empty():   # the land around a river / lake: the biome's own shore ground (dirt, sand ...); beaches and the boss land keep theirs
			for i in n:
				if res.shore[i] == 1 and g[i] != 0 and res.area[i] != MapGen.Area.BOSS and res.biome[i] < MapGen.Biome.BEACH_SAND:
					g[i] = res.biomes[res.biome[i]].shore_ground
		t = MapGen._lap(res, "ground.shore", t)
		dist = _water_dist(res, p, p.camp_radius + p.beach_cells + 3)
		t = MapGen._lap(res, "ground.waterdist", t)
		res.ground_base = g.duplicate()
		res.ground_dist = dist
		res.ground_key = key
	res.cell = p.cell
	res.dirt_stamps = PackedVector3Array()
	res.dirt_cells = {}
	_dirt_patches(res, p, g, dist, rng)
	var camp: Vector2 = p.spawns[3] if p.spawns.size() > 3 else p.player_spawn
	var camp_cell := Vector2i(camp / p.cell)
	# the clearing shrinks where home is near the coast (never into the beach), but it is never dropped unless camp_radius is 0
	if p.camp_radius > 0:
		var camp_r := clampf(float(dist[camp_cell.y * p.cols + camp_cell.x]) - p.beach_cells - 1.2, 1.2, p.camp_radius + 0.5)
		_add_blob(res, p, camp, camp_r * p.cell, rng)
	if p.path_on:
		_carve_paths(res, p, g, dist, rng, noise)
	t = MapGen._lap(res, "ground.camp+paths", t)
	var wobble := MapGen._noise(res.seed + 6, 0.21)
	for i in n:   # the beach is `beach_cells` wide, plus a ragged extra cell where the noise says so
		if g[i] != MapGen.Ground.WATER and (dist[i] <= p.beach_cells or (dist[i] == p.beach_cells + 1 and p.beach_cells > 0 and MapGen._n01(wobble, i % p.cols, i / p.cols) > 0.62)):
			g[i] = MapGen.Ground.DIRT
	t = MapGen._lap(res, "ground.beach", t)
	_smooth_ground(g, p.cols, p.rows, 1)
	res.ground = g
	t = MapGen._lap(res, "ground.smooth2", t)


## Ground only, again, after a look setting changed: nodes, rocks and the walk grid are not touched. Deco that now
## stands on dirt or cobble (and is not a pebble-like set) is dropped; a set with `any_ground` (the biome passes) only when a path or the camp covers it.
static func rebuild_ground(res: MapGen.Result, style: MapStyle, p: MapGen.Params) -> void:
	_build_ground(res, style, p)
	var kept: Array[Dictionary] = []
	for d in res.deco:
		var set: PropSet = style.deco[d["set"]]
		var c := Vector2i(d["pos"] / p.cell)
		var gd := res.ground[c.y * p.cols + c.x]
		if not set.on_dirt and ((not set.any_ground and (gd == MapGen.Ground.DIRT or gd == MapGen.Ground.COBBLE or gd == MapGen.Ground.SAND or gd == MapGen.Ground.SNOW)) or res.dirt_cells.has(c)):
			continue
		kept.append(d)
	res.deco = kept


## Border cells (land cells touching a different land ground) swap to that neighbour's ground with chance `border_jitter`,
## so a border is not one cell column for a long run. Smoothing runs after and removes what is too thin.
static func _jitter_borders(g: PackedByteArray, p: MapGen.Params, jitter_seed: int) -> void:
	if p.border_jitter <= 0.0:
		return
	var src := g.duplicate()
	var cols := p.cols
	var offs := PackedInt32Array([-cols, cols, -1, 1])
	for y in range(1, p.rows - 1):
		for i in range(y * cols + 1, y * cols + cols - 1):
			var c := src[i]
			if c == 0:
				continue
			for o in offs:
				var v := src[i + o]
				if v != 0 and v != c:
					if float(_hash_int(i - y * cols, y, jitter_seed) % 100) / 100.0 < p.border_jitter:
						g[i] = v
					break


static func _hash_int(x: int, y: int, s: int) -> int:
	return ((x * 73856093) ^ (y * 19349663) ^ (s * 83492791)) & 0x7fffffff


## Connected patches of one ground (4-neighbour) smaller than `min_island_cells` take the ground most of their
## border cells have. Water is never touched.
static func _drop_small(g: PackedByteArray, p: MapGen.Params) -> void:
	if p.min_island_cells <= 1:
		return
	var cols := p.cols
	var rows := p.rows
	var n := g.size()
	var seen := PackedByteArray()
	seen.resize(n)
	var cells := PackedInt32Array()   # flood queue, reused
	cells.resize(n)
	for start in n:
		if g[start] == 0 or seen[start] == 1:
			continue
		var kind := g[start]
		var tail := 1
		var head := 0
		cells[0] = start
		seen[start] = 1
		var votes := {}
		while head < tail:
			var i := cells[head]
			head += 1
			var x := i % cols
			for dir in 4:
				var j := i + 1 if dir == 0 else (i - 1 if dir == 1 else (i + cols if dir == 2 else i - cols))
				if (dir == 0 and x == cols - 1) or (dir == 1 and x == 0) or j < 0 or j >= n:
					continue
				var gj := g[j]
				if gj == kind:
					if seen[j] == 0:
						seen[j] = 1
						cells[tail] = j
						tail += 1
				elif gj != 0:
					votes[gj] = votes.get(gj, 0) + 1
		if tail < p.min_island_cells and not votes.is_empty():
			var best := 0
			var bn := -1
			for v in votes:
				if votes[v] > bn:
					bn = votes[v]
					best = v
			for k in tail:
				g[cells[k]] = best


## Majority passes: a land cell turns into its neighbours' ground when it is a 1-wide strip (same ground on
## both opposite sides), a spike (3 of 4 neighbours agree) or one half of a checkerboard. Water never votes.
## Cells on the map edge are left alone.
static func _smooth_ground(g: PackedByteArray, cols: int, rows: int, passes: int) -> void:
	for _pass in passes:
		var src := g.duplicate()
		for y in range(1, rows - 1):
			var row := y * cols
			for x in range(1, cols - 1):
				var i := row + x
				var c := src[i]
				if c == 0:
					continue
				var n := src[i - cols]
				var s := src[i + cols]
				var w := src[i - 1]
				var e := src[i + 1]
				if n == c and s == c and w == c and e == c and g[i - 1] == c and g[i - cols] == c:
					continue   # nothing around it differs, so none of the rules below can fire
				if n == s and n != c and n != 0:
					g[i] = n
				elif w == e and w != c and w != 0:
					g[i] = w
				else:
					for v in [n, s, w, e]:
						if v != c and v != 0 and int(n == v) + int(s == v) + int(w == v) + int(e == v) >= 3:
							g[i] = v
							break
					if g[i] == c:
						# checkerboard: two touching sides agree and the diagonal between them is our own ground.
						# Reads the live array (not src): two cells of one checkerboard must not both flip at once.
						n = g[i - cols]
						s = g[i + cols]
						w = g[i - 1]
						e = g[i + 1]
						if e == s and e != c and e != 0 and g[i + cols + 1] == c:
							g[i] = e
						elif e == n and e != c and e != 0 and g[i - cols + 1] == c:
							g[i] = e
						elif w == s and w != c and w != 0 and g[i + cols - 1] == c:
							g[i] = w
						elif w == n and w != c and w != 0 and g[i - cols - 1] == c:
							g[i] = w


## Cells to the nearest water (8-neighbour steps): water 0, a coast cell 1 ... `cap`; further land = cap + 1.
static func _water_dist(res: MapGen.Result, p: MapGen.Params, cap: int) -> PackedByteArray:
	var cols := p.cols
	var rows := p.rows
	var n := cols * rows
	var land := res.land
	var d := PackedByteArray()
	d.resize(n)
	d.fill(cap + 1)
	var frontier := PackedInt32Array()
	for i in n:
		if land[i] == 0:
			d[i] = 0
			frontier.append(i)
	var offs := PackedInt32Array([-cols - 1, -cols, -cols + 1, -1, 1, cols - 1, cols, cols + 1])
	for step in cap:
		var next := PackedInt32Array()
		var nd := step + 1
		for i in frontier:
			var x := i % cols
			var y := i / cols
			if x < 1 or y < 1 or x >= cols - 1 or y >= rows - 1:
				continue
			for o in offs:
				var j := i + o
				if d[j] > nd:
					d[j] = nd
					next.append(j)
		frontier = next
	return d


## A round dirt stamp (world px) and the cells it covers (deco keeps off them).
static func _add_stamp(res: MapGen.Result, p: MapGen.Params, center: Vector2, r: float) -> void:
	res.dirt_stamps.append(Vector3(center.x, center.y, r))
	var c0 := Vector2i(((center - Vector2(r, r)) / p.cell).floor())
	var c1 := Vector2i(((center + Vector2(r, r)) / p.cell).floor())
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			if (Vector2(x + 0.5, y + 0.5) * p.cell).distance_to(center) < r + p.cell * 0.4:
				res.dirt_cells[Vector2i(x, y)] = true


## An organic blob: one big disc plus three smaller ones around it.
static func _add_blob(res: MapGen.Result, p: MapGen.Params, center: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	_add_stamp(res, p, center, r)
	var a0 := rng.randf() * TAU
	for k in 3:
		_add_stamp(res, p, center + Vector2.from_angle(a0 + k * TAU / 3.0 + rng.randf_range(-0.4, 0.4)) * r * 0.75, r * rng.randf_range(0.5, 0.7))


## A few small, ragged dirt patches in the forest, away from the coast.
static func _dirt_patches(res: MapGen.Result, p: MapGen.Params, g: PackedByteArray, dist: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var spots := PackedInt32Array()
	for i in g.size():
		if g[i] == MapGen.Ground.GRASS and dist[i] > p.beach_cells + 3:
			spots.append(i)
	if spots.is_empty():
		return
	for _k in roundi(p.dirt_patches * spots.size() / 100.0):
		var i := spots[rng.randi() % spots.size()]
		var c := (Vector2(i % p.cols, i / p.cols) + Vector2(0.5, 0.5)) * p.cell
		_add_blob(res, p, c, rng.randf_range(0.8, maxf(p.dirt_patch_size * 0.7, 0.9)) * p.cell, rng)


## Home -> boss path over the walkable land, and a few branches towards the rocky ground. A* on the cell grid
## (AStarGrid2D, C++): water and the beach are solid, trees and rocks are expensive, noise makes it wander. The cell
## path is smoothed (Chaikin) and turned into stamps spaced along it, only where the ground is forest grass (a path ends
## where the rocky ground begins). The walk grid is not read or changed.
static func _carve_paths(res: MapGen.Result, p: MapGen.Params, g: PackedByteArray, dist: PackedByteArray, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, p.cols, p.rows)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	astar.fill_solid_region(astar.region, true)
	var keep := p.beach_cells + 2
	for i in g.size():
		if g[i] != MapGen.Ground.WATER and dist[i] > keep:
			var c := Vector2i(i % p.cols, i / p.cols)
			astar.set_point_solid(c, false)
			astar.set_point_weight_scale(c, 1.0 + p.path_wobble * 3.0 * MapGen._n01(noise, c.x, c.y))
	for o in res.obstacles:   # go round trees and rocks
		var oc := Vector2i(o["pos"] / p.cell)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var q := oc + Vector2i(dx, dy)
				if astar.is_in_boundsv(q):
					astar.set_point_weight_scale(q, 8.0)
	var start := Vector2i(p.player_spawn / p.cell)
	var goal := Vector2i(p.zone.get_center() / p.cell)
	for e in [start, goal]:
		astar.set_point_solid(e, false)
	var main := astar.get_id_path(start, goal)
	var forest: Array[Vector2i] = []
	for c in main:
		if g[c.y * p.cols + c.x] == MapGen.Ground.GRASS:
			forest.append(c)
	_stamp_path(res, p, g, main, maxi(p.path_width, 2))
	# branches: from points along the forest part of the main path to rocky cells that touch the forest
	var borders: Array[Vector2i] = []
	for y in range(1, p.rows - 1):
		for x in range(1, p.cols - 1):
			var i := y * p.cols + x
			if g[i] == MapGen.Ground.COBBLE and (g[i - 1] == MapGen.Ground.GRASS or g[i + 1] == MapGen.Ground.GRASS or g[i - p.cols] == MapGen.Ground.GRASS or g[i + p.cols] == MapGen.Ground.GRASS) and dist[i] > keep:
				borders.append(Vector2i(x, y))
	if forest.is_empty() or borders.is_empty():
		return
	for b in p.path_branches:
		var origin := forest[int(forest.size() * lerpf(0.15, 0.85, float(b + 1) / (p.path_branches + 1)))]
		var far: Array[Vector2i] = []
		for c in borders:
			if absi(c.y - origin.y) > 10:
				far.append(c)
		if far.is_empty():
			continue
		var target := far[rng.randi() % far.size()]
		astar.set_point_solid(target, false)
		_stamp_path(res, p, g, astar.get_id_path(origin, target), maxi(p.path_width - 1, 2))


## Smooths a cell path (Chaikin, 3 rounds) and drops round stamps of diameter `width` cells along it, spaced a third
## of the radius apart, on forest grass only.
static func _stamp_path(res: MapGen.Result, p: MapGen.Params, g: PackedByteArray, cells: Array[Vector2i], width: int) -> void:
	if cells.size() < 2:
		return
	var pts := PackedVector2Array()
	for c in cells:
		pts.append((Vector2(c) + Vector2(0.5, 0.5)) * p.cell)
	for _round in 3:
		var nxt := PackedVector2Array([pts[0]])
		for k in pts.size() - 1:
			nxt.append(pts[k].lerp(pts[k + 1], 0.25))
			nxt.append(pts[k].lerp(pts[k + 1], 0.75))
		nxt.append(pts[pts.size() - 1])
		pts = nxt
	var r := width * p.cell * 0.5
	var step := r / 3.0
	var carry := 0.0
	var taper_len := 5.0 * p.cell     # past the forest the path fades out over this far onto the cobble
	var walked := -1.0                # < 0: not in the forest yet
	for k in pts.size() - 1:
		var seg := pts[k + 1] - pts[k]
		var seg_len := seg.length()
		var t := carry
		while t < seg_len:
			var at := pts[k] + seg * (t / maxf(seg_len, 0.001))
			var c := Vector2i(at / p.cell)
			if c.x >= 1 and c.y >= 1 and c.x < p.cols - 1 and c.y < p.rows - 1:
				var gd := g[c.y * p.cols + c.x]
				if gd == MapGen.Ground.GRASS:
					walked = 0.0
					_add_stamp(res, p, at, r)
				elif gd == MapGen.Ground.COBBLE and walked >= 0.0 and walked < taper_len:
					var f := walked / taper_len   # narrow plus dither: a worn trail that thins out
					if float(_hash_int(int(at.x), int(at.y), res.seed) % 100) / 100.0 >= f * 0.7:
						_add_stamp(res, p, at, r * lerpf(1.0, 0.3, f))
					walked += step
			t += step
		carry = t - seg_len
