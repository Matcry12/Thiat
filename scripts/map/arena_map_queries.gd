class_name ArenaMapQueries
extends RefCounted
## ArenaMap helper: questions about the built world (area, water, corridor, walk check, free spot, nearest node). Moved out of arena_map.gd unchanged; ArenaMap keeps the public methods and calls these with itself.


static func _cell_i(m: ArenaMap, pos: Vector2) -> int:   ## index into result.land / f / biome, -1 off the grid
	var c := Vector2i((pos / m.cell_px()).floor())
	return -1 if c.x < 0 or c.y < 0 or c.x >= m.result.cols or c.y >= m.result.rows else c.y * m.result.cols + c.x


## MapGen.Biome under a world position, -1 off the grid / no biome map (flat test map).
static func biome_id_at(m: ArenaMap, pos: Vector2) -> int:
	var i := m._cell_i(pos)
	return -1 if i < 0 or m.result.biome.is_empty() else m.result.biome[i]


## Placed things (stations) must not stand on a tree or rock of a chunk that is not loaded: asks the world data.
static func placement_blocked(m: ArenaMap, rect: Rect2) -> bool:
	if m.result == null:
		return false
	var b0 := Vector2i(rect.position / m.result.obstacle_bucket) - Vector2i.ONE
	var b1 := Vector2i(rect.end / m.result.obstacle_bucket) + Vector2i.ONE
	for by in range(b0.y, b1.y + 1):
		for bx in range(b0.x, b1.x + 1):
			for o: Dictionary in m.result.obstacle_grid.get(Vector2i(bx, by), []):
				var c: Vector2 = o["pos"]
				if m._streamer.is_loaded(m._streamer.chunk_id_at(c)):
					continue   # a loaded chunk: its live nodes are checked by the caller (and a gathered one no longer counts)
				var q := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
				if q.distance_to(c) <= o["radius"]:
					return true
	return false


## MapGen.Area at a world position, or -1 on water / off the map.
static func area_at(m: ArenaMap, pos: Vector2) -> int:
	if m.result == null:
		return -1
	var c := Vector2i((pos / m.cell_px()).floor())
	if c.x < 0 or c.y < 0 or c.x >= m.result.cols or c.y >= m.result.rows:   # the size the m.result was built with
		return -1
	var i := c.y * m.result.cols + c.x
	return -1 if m.result.land[i] == 0 else m.result.area[i]


## True when every cell `rect` (px) overlaps is dry land (a station box over a thin river is refused).
static func rect_on_land(m: ArenaMap, rect: Rect2) -> bool:
	if m.result == null:
		return true
	var c0 := Vector2i((rect.position / m.cell_px()).floor())
	var c1 := Vector2i((rect.end / m.cell_px()).floor())
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			if cx < 0 or cy < 0 or cx >= m.result.cols or cy >= m.result.rows or m.result.land[cy * m.result.cols + cx] == 0:
				return false
	return true


## MapGen.WaterKind at a world position: NONE on dry land, SHALLOW in a river / lake / coast shallows (walkable), OCEAN beyond (blocks).
## Follows the drawn ground: the shore's sand is drawn a few pixels into its water cells, and a point on that sand is dry.
static func water_kind_at(m: ArenaMap, pos: Vector2) -> int:
	if m.result == null or m.result.shallow.is_empty():
		return MapGen.WaterKind.NONE
	var c := Vector2i((pos / m.cell_px()).floor())
	if c.x < 0 or c.y < 0 or c.x >= m.result.cols or c.y >= m.result.rows:
		return MapGen.WaterKind.OCEAN
	var i := c.y * m.result.cols + c.x
	if m.result.land[i] == 1:
		return MapGen.WaterKind.NONE
	if m.style != null and m.style.pixel_plains != null and not m.result.ground.is_empty() \
			and PixelPlainsBaker.drawn_land_at(m.result, m.style.pixel_plains, Vector2i((pos / float(m.style.pixel_scale)).floor())):
		return MapGen.WaterKind.NONE
	return MapGen.WaterKind.SHALLOW if m.result.shallow[i] == 1 else MapGen.WaterKind.OCEAN


## True in the boss's land (area BOSS) or inside the fight zone: no placing stations there.
static func in_boss_area(m: ArenaMap, pos: Vector2) -> bool:
	return m._zone.has_point(pos) or m.area_at(pos) == MapGen.Area.BOSS


## True on a cell of the land bridge carved to reach the boss (only when the island needed one).
static func in_corridor(m: ArenaMap, pos: Vector2) -> bool:
	return m.result != null and m.result.bridge.has(Vector2i((pos / m.cell_px()).floor()))


## True if `rect` touches any bridge cell (a rect can straddle a bridge without a corner inside it).
static func in_corridor_rect(m: ArenaMap, rect: Rect2) -> bool:
	if m.result == null or m.result.bridge.is_empty():
		return false
	var c0 := Vector2i((rect.position / m.cell_px()).floor())
	var c1 := Vector2i((rect.end / m.cell_px()).floor())
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			if m.result.bridge.has(Vector2i(x, y)):
				return true
	return false


## Would solid boxes at `rects` (px) cut the walk from home to the boss zone? Reuses MapGen's walk grid and
## flood. The base grid is built once per island (cached); one check is one flood (`last_walk_check_ms`).
## False when there was no walk to protect to begin with.
static func blocks_boss_path(m: ArenaMap, rects: Array[Rect2]) -> bool:
	if m.result == null or m.yard != null:
		return false
	var p := m.make_params()
	m._warm_walk_grid(p)
	if not m._walk_base_ok:
		return false
	var t0 := Time.get_ticks_usec()
	var ok := MapGen.blockers_keep_local_walk(p, m._walk_grid, rects, m._zone.get_center()) or MapGen.goal_reachable_with(p, m._walk_grid, rects, m._zone.get_center())
	m.last_walk_check_ms = (Time.get_ticks_usec() - t0) / 1000.0
	return not ok


## The base walk grid of this island (kept from generate, only the rocks are cleared) and whether home reaches the boss at all. Built right after
## generate, so the first station placement is one flood, not a 0.4 s grid build.
static func _warm_walk_grid(m: ArenaMap, p: MapGen.Params) -> void:
	if m._walk_for == m.result or m.result == null or m.yard != null:   # the m.yard has no m.boss path to protect
		return
	m._walk_for = m.result
	m._walk_grid = MapGen.walk_grid(p, m.result.obstacles, m.result.walk_land, m.result.walk_base)
	m._walk_base_ok = MapGen.goal_reachable_with(p, m._walk_grid, [] as Array[Rect2], m._zone.get_center())


## The live ResourceNode of kind `id` (or, with `prefix`, any kind whose id starts with it: "tree" = every tree) nearest to `to` that has
## not been gathered, found in the WORLD DATA (so it works for a node whose chunk is not loaded) and loaded on demand. Null if there is none.
static func nearest_node(m: ArenaMap, id: StringName, to: Vector2, prefix := false) -> ResourceNode:
	if m.result == null:
		return null
	var best := -1
	var best_d := INF
	for i in m.result.obstacles.size():
		var o := m.result.obstacles[i]
		if o["node"] < 0 or m._streamer.broken[i] == 1:
			continue
		var kind_id := m.style.resource_nodes[o["node"]].id
		if kind_id != id and not (prefix and String(kind_id).begins_with(String(id))):
			continue
		var d: float = to.distance_squared_to(o["pos"])
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return null
	m._streamer.build_around(m.result.obstacles[best]["pos"], 0)
	m._streamer.pin(m._streamer.chunk_id_at(m.result.obstacles[best]["pos"]))
	return m._streamer.node_of(best) as ResourceNode


## Nearest spot to `target` (rings of 16 px, up to 480 px out) where a walker stands on land, clear of every rock.
static func _free_spot(m: ArenaMap, target: Vector2) -> Vector2:
	if m.result == null:
		return target
	for ring in 31:
		for k in maxi(ring * 8, 1):
			var a := TAU * k / maxi(ring * 8, 1)
			var pos := target + Vector2.from_angle(a) * ring * 16.0
			if m._walker_fits(pos):
				return pos
	return target


static func _walker_fits(m: ArenaMap, pos: Vector2) -> bool:
	for off in [Vector2.ZERO, Vector2(m.agent_radius, 0), Vector2(-m.agent_radius, 0), Vector2(0, m.agent_radius), Vector2(0, -m.agent_radius)]:
		var c := Vector2i(((pos + off) / m.cell_px()).floor())
		if c.x < 0 or c.y < 0 or c.x >= m.result.cols or c.y >= m.result.rows or m.result.land[c.y * m.result.cols + c.x] == 0:
			return false
	var b := Vector2i(pos / m.result.obstacle_bucket)   # only the rocks in the buckets around it (bucket >= 2 x the widest rock + spacing)
	for by in range(b.y - 1, b.y + 2):
		for bx in range(b.x - 1, b.x + 2):
			for o: Dictionary in m.result.obstacle_grid.get(Vector2i(bx, by), []):
				if pos.distance_to(o["pos"]) <= o["radius"] + m.agent_radius:
					return false
	return true


## The training dummy stays where the layout puts it when a walker fits there; on some seeds that is water or a rock, so it moves to the nearest
## spot where one does (searched in rings around the layout spot).
static func _fit_dummy(m: ArenaMap) -> void:
	var dummy := m.get_node_or_null(m.dummy_path) as Node2D
	if dummy == null or m.result == null or m._walker_fits(dummy.global_position):
		return
	var from := dummy.global_position
	var step := m.cell_px() * 0.5
	for ring in range(1, 80):
		for k in ring * 8:
			var a := TAU * k / (ring * 8)
			var q := from + Vector2.from_angle(a) * ring * step
			if m._walker_fits(q):
				dummy.global_position = q
				if "home" in dummy:
					dummy.home = q
				if dummy.has_meta("spot"):
					dummy.set_meta("spot", q)
				return
