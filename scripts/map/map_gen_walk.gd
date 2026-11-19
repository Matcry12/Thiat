class_name MapGenWalk
extends RefCounted
## MapGen stage "walk": moved out of map_gen.gd unchanged (static helpers; MapGen keeps the public API and the shared consts / Params / Result).


static func _add_obstacle(res: MapGen.Result, o: Dictionary) -> void:
	res.obstacles.append(o)
	res.obstacle_grid.get_or_add(Vector2i(o["pos"] / res.obstacle_bucket), []).append(o)


## True if any obstacle is closer than r + its radius + spacing. Bucket lookup; needs that sum <= obstacle_bucket.
static func _obstacle_near(res: MapGen.Result, pos: Vector2, r: float, spacing: float) -> bool:
	var b := Vector2i(pos / res.obstacle_bucket)
	for by in range(b.y - 1, b.y + 2):
		for bx in range(b.x - 1, b.x + 2):
			for o: Dictionary in res.obstacle_grid.get(Vector2i(bx, by), []):
				if pos.distance_to(o["pos"]) < r + o["radius"] + spacing:
					return true
	return false


## A walker's width plus one FLOW_STEP: rocks keep this far from water, walls and each other, so every
## gap is wide enough for the 16 px walkability grid of floor_reachable to see a path through it.
static func rock_clearance(p: MapGen.Params) -> float:
	return p.agent_radius * 2.0 + MapGen.FLOW_STEP


static func _obstacle_legal(res: MapGen.Result, p: MapGen.Params, pos: Vector2, r: float, sprite: Vector2, spacing: float) -> bool:
	if not MapGen.circle_on_land(res, p, pos, r + rock_clearance(p)):
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
	return spacing < 0.0 or not _obstacle_near(res, pos, r, spacing)   # spacing < 0: no min distance (aged trees: only trunk cells exclude)


## Walk grid (FLOW_STEP px): 1 where a walker of agent_radius can stand, ignoring rocks. Inside the walls,
## and (if `land` is given) with all four sides and the centre on land.
static func _walk_free(p: MapGen.Params, land := PackedByteArray(), count := PackedInt32Array()) -> PackedByteArray:
	var size := p.size_px()
	var nx := int(size.x / MapGen.FLOW_STEP)
	var ny := int(size.y / MapGen.FLOW_STEP)
	var free := PackedByteArray()
	free.resize(nx * ny)
	var r := p.agent_radius
	var lo := p.cell + r   # inside the walls: every sample below is >= 1 cell from the grid edge, so no bounds checks
	var ones := 0
	var x_lo := nx
	var x_hi := -1
	var colc := PackedInt32Array()   # per sample column: the cell under it, and under its left / right feeler
	var coll := PackedInt32Array()
	var colr := PackedInt32Array()
	colc.resize(nx)
	coll.resize(nx)
	colr.resize(nx)
	for x in nx:
		var cx := (x + 0.5) * MapGen.FLOW_STEP
		if cx < lo or cx > size.x - lo:
			continue
		x_lo = mini(x_lo, x)
		x_hi = x
		colc[x] = int(cx / p.cell)
		coll[x] = int((cx - r) / p.cell)
		colr[x] = int((cx + r) / p.cell)
	for y in ny:
		var cy := (y + 0.5) * MapGen.FLOW_STEP
		if cy < lo or cy > size.y - lo:
			continue
		if land.is_empty():
			for x in range(x_lo, x_hi + 1):
				free[y * nx + x] = 1
			ones += maxi(x_hi - x_lo + 1, 0)
			continue
		var row := int(cy / p.cell) * p.cols
		var row_up := int((cy - r) / p.cell) * p.cols
		var row_dn := int((cy + r) / p.cell) * p.cols
		for x in range(x_lo, x_hi + 1):
			var col := colc[x]
			if land[row + col] == 1 and land[row + coll[x]] == 1 and land[row + colr[x]] == 1 \
					and land[row_up + col] == 1 and land[row_dn + col] == 1:
				free[y * nx + x] = 1
				ones += 1
	if not count.is_empty():
		count[0] = ones
	return free


## After the land under the cells in `changed` (flat cell indices) went to water: redo only the walk-grid samples that look at
## those cells, in place. Returns the change in the number of free samples. Same rule as _walk_free.
static func _walk_free_patch(p: MapGen.Params, land: PackedByteArray, free: PackedByteArray, changed: PackedInt32Array) -> int:
	var size := p.size_px()
	var nx := int(size.x / MapGen.FLOW_STEP)
	var ny := int(size.y / MapGen.FLOW_STEP)
	var r := p.agent_radius
	var lo := p.cell + r
	var delta := 0
	var span := int(ceilf((p.cell + r) / MapGen.FLOW_STEP)) + 1   # samples around a cell that can look at it
	for ci in changed:
		var cx := ci % p.cols
		var cy := ci / p.cols
		var x0 := maxi(int(cx * p.cell / MapGen.FLOW_STEP) - span, 0)
		var x1 := mini(int((cx + 1) * p.cell / MapGen.FLOW_STEP) + span, nx - 1)
		var y0 := maxi(int(cy * p.cell / MapGen.FLOW_STEP) - span, 0)
		var y1 := mini(int((cy + 1) * p.cell / MapGen.FLOW_STEP) + span, ny - 1)
		for y in range(y0, y1 + 1):
			var sy := (y + 0.5) * MapGen.FLOW_STEP
			for x in range(x0, x1 + 1):
				var i := y * nx + x
				if free[i] == 0:
					continue
				var sx := (x + 0.5) * MapGen.FLOW_STEP
				var row := int(sy / p.cell) * p.cols
				var col := int(sx / p.cell)
				if not (land[row + col] == 1 and land[row + int((sx - r) / p.cell)] == 1 and land[row + int((sx + r) / p.cell)] == 1 \
						and land[int((sy - r) / p.cell) * p.cols + col] == 1 and land[int((sy + r) / p.cell) * p.cols + col] == 1):
					free[i] = 0   # land only ever goes away here, so a sample can only turn from free to blocked
					delta -= 1
	return delta


## 4-neighbour flood over a walk grid; returns the seen mask.
static func _walk_flood(free: PackedByteArray, nx: int, ny: int, start: Vector2i, count := PackedInt32Array()) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(nx * ny)
	if not count.is_empty():
		count[0] = 0
	if free[start.y * nx + start.x] == 0:
		return seen
	var reached := _span_fill(free, seen, nx, ny, start.y * nx + start.x)
	if not count.is_empty():
		count[0] = reached
	return seen


## 4-neighbour flood by spans: fills a whole run of a row, then looks at the rows above and below it. `seen` gets 1 on every
## cell reached from `start` over cells where `open` is 1. Returns how many. A run costs a few operations per cell, not per neighbour.
static func _span_fill(open: PackedByteArray, seen: PackedByteArray, w: int, h: int, start: int, want := 1, spans := PackedInt32Array(), stack := PackedInt32Array()) -> int:
	if stack.size() < 2 * w * h + 4:   # spans never overlap, so at most 2 pushes per cell
		stack.resize(2 * w * h + 4)
	var sp := 1
	stack[0] = start
	var reached := 0
	while sp > 0:
		sp -= 1
		var i := stack[sp]
		if seen[i] == 1:
			continue
		var y := i / w
		var row := y * w
		var xl := i - row
		var xr := xl
		while xl > 0 and open[row + xl - 1] == want and seen[row + xl - 1] == 0:
			xl -= 1
		while xr < w - 1 and open[row + xr + 1] == want and seen[row + xr + 1] == 0:
			xr += 1
		for k in range(row + xl, row + xr + 1):
			seen[k] = 1
		reached += xr - xl + 1
		spans.append(row + xl)
		spans.append(xr - xl + 1)
		for r2 in [row - w, row + w]:
			if r2 < 0 or r2 >= w * h:
				continue
			var run := false
			for k in range(r2 + xl, r2 + xr + 1):
				if open[k] == want and seen[k] == 0:
					if not run:
						stack[sp] = k
						sp += 1
						run = true
				else:
					run = false
	return reached


## Flood fill on a coarse grid from the player's spawn: every cell a walker of agent_radius can stand
## on (inside the walls, clear of every rock) must be reachable. Public: the tests call it too.
static func floor_reachable(p: MapGen.Params, obstacles: Array[Dictionary], land := PackedByteArray()) -> bool:
	return _unreached(p, obstacles, land).is_empty()


## Centres of the walk-grid samples a walker could stand on but cannot reach from home (see floor_reachable).
## If home itself is blocked, returns [Vector2.INF].
static func _unreached(p: MapGen.Params, obstacles: Array[Dictionary], land: PackedByteArray, base := PackedByteArray(), base_n := -1) -> PackedVector2Array:
	var nx := int(p.size_px().x / MapGen.FLOW_STEP)
	var ny := int(p.size_px().y / MapGen.FLOW_STEP)
	var cnt := PackedInt32Array([0])
	var free := base.duplicate() if not base.is_empty() else _walk_free(p, land, cnt)
	var free_n := base_n if not base.is_empty() and base_n >= 0 else cnt[0]
	free_n -= _clear_rocks(p, free, obstacles, nx, ny)
	var start := Vector2i(clampi(int(p.player_spawn.x / MapGen.FLOW_STEP), 0, nx - 1), clampi(int(p.player_spawn.y / MapGen.FLOW_STEP), 0, ny - 1))
	if free[start.y * nx + start.x] == 0:
		return PackedVector2Array([Vector2.INF])
	var seen := _walk_flood(free, nx, ny, start, cnt)
	var out := PackedVector2Array()
	if cnt[0] == free_n:   # the flood reached every free sample: nothing is lost (the common case)
		return out
	for i in free.size():
		if free[i] == 1 and seen[i] == 0:
			out.append(Vector2((i % nx + 0.5) * MapGen.FLOW_STEP, (i / nx + 0.5) * MapGen.FLOW_STEP))
	return out


## Clears every rock out of a walk grid (each clears only the samples in its own box). Returns how many samples it cleared.
static func _clear_rocks(p: MapGen.Params, free: PackedByteArray, obstacles: Array[Dictionary], nx: int, ny: int) -> int:
	var cleared := 0
	var agent := p.agent_radius
	for o in obstacles:
		var reach: float = o["radius"] + agent
		var pos: Vector2 = o["pos"]
		for y in range(maxi(int((pos.y - reach) / MapGen.FLOW_STEP), 0), mini(int((pos.y + reach) / MapGen.FLOW_STEP) + 1, ny)):
			var cy := (y + 0.5) * MapGen.FLOW_STEP
			for x in range(maxi(int((pos.x - reach) / MapGen.FLOW_STEP), 0), mini(int((pos.x + reach) / MapGen.FLOW_STEP) + 1, nx)):
				if free[y * nx + x] == 1 and Vector2((x + 0.5) * MapGen.FLOW_STEP, cy).distance_to(pos) <= reach:
					free[y * nx + x] = 0
					cleared += 1
	return cleared


## The walk grid with every rock cleared out of it: 1 where a walker can stand.
## `base` = a ready _walk_free(p, land) to copy instead of computing it again (land does not change between calls).
static func walk_grid(p: MapGen.Params, obstacles: Array[Dictionary], land: PackedByteArray, base := PackedByteArray()) -> PackedByteArray:
	var nx := int(p.size_px().x / MapGen.FLOW_STEP)
	var ny := int(p.size_px().y / MapGen.FLOW_STEP)
	var free := base.duplicate() if not base.is_empty() else _walk_free(p, land)
	_clear_rocks(p, free, obstacles, nx, ny)
	return free


## Can a walker still get from the player's spawn to `goal` (px) on `free` once the rects in `blockers`
## (solid boxes, px) are added? Reuses the same flood as floor_reachable. `free` is not changed.
## One flood; call it with no blockers first to know whether there is a path to protect at all.
static func goal_reachable_with(p: MapGen.Params, free: PackedByteArray, blockers: Array[Rect2], goal: Vector2) -> bool:
	var nx := int(p.size_px().x / MapGen.FLOW_STEP)
	var ny := int(p.size_px().y / MapGen.FLOW_STEP)
	var start := Vector2i(clampi(int(p.player_spawn.x / MapGen.FLOW_STEP), 0, nx - 1), clampi(int(p.player_spawn.y / MapGen.FLOW_STEP), 0, ny - 1))
	var g := Vector2i(clampi(int(goal.x / MapGen.FLOW_STEP), 0, nx - 1), clampi(int(goal.y / MapGen.FLOW_STEP), 0, ny - 1))
	var f := free.duplicate()
	for r in blockers:
		var b := r.grow(p.agent_radius)
		for y in range(maxi(int(b.position.y / MapGen.FLOW_STEP), 0), mini(int(b.end.y / MapGen.FLOW_STEP) + 1, ny)):
			for x in range(maxi(int(b.position.x / MapGen.FLOW_STEP), 0), mini(int(b.end.x / MapGen.FLOW_STEP) + 1, nx)):
				if b.has_point(Vector2((x + 0.5) * MapGen.FLOW_STEP, (y + 0.5) * MapGen.FLOW_STEP)):
					f[y * nx + x] = 0
	if f[start.y * nx + start.x] == 0:
		return false
	return _walk_flood(f, nx, ny, start)[g.y * nx + g.x] == 1


## Fast yes for goal_reachable_with: crop a window around the blockers and check that every walkable cell touching them stays connected
## to the others inside the window. If it does, the blockers cannot cut the walk (a path through the blocked spot detours inside the window).
## false = unknown (a ring cell is cut off inside the window, or the spawn / goal is under a blocker): run the full flood.
static func blockers_keep_local_walk(p: MapGen.Params, free: PackedByteArray, blockers: Array[Rect2], goal: Vector2, margin := 12) -> bool:
	var nx := int(p.size_px().x / MapGen.FLOW_STEP)
	var ny := int(p.size_px().y / MapGen.FLOW_STEP)
	var all := Rect2()
	for i in blockers.size():
		var b := blockers[i].grow(p.agent_radius)
		all = b if i == 0 else all.merge(b)
		for pt in [p.player_spawn, goal]:
			if b.has_point(pt):
				return false
	if blockers.is_empty():
		return true
	var x0 := maxi(int(all.position.x / MapGen.FLOW_STEP) - margin, 0)
	var y0 := maxi(int(all.position.y / MapGen.FLOW_STEP) - margin, 0)
	var x1 := mini(int(all.end.x / MapGen.FLOW_STEP) + margin + 1, nx)
	var y1 := mini(int(all.end.y / MapGen.FLOW_STEP) + margin + 1, ny)
	var w := x1 - x0
	var h := y1 - y0
	if w <= 0 or h <= 0:
		return false
	var open := PackedByteArray()
	open.resize(w * h)
	for y in h:
		for x in w:
			open[y * w + x] = free[(y0 + y) * nx + x0 + x]
	var blocked := PackedByteArray()
	blocked.resize(w * h)
	for r in blockers:
		var b := r.grow(p.agent_radius)
		for y in range(maxi(int(b.position.y / MapGen.FLOW_STEP) - y0, 0), mini(int(b.end.y / MapGen.FLOW_STEP) + 1 - y0, h)):
			for x in range(maxi(int(b.position.x / MapGen.FLOW_STEP) - x0, 0), mini(int(b.end.x / MapGen.FLOW_STEP) + 1 - x0, w)):
				if b.has_point(Vector2((x0 + x + 0.5) * MapGen.FLOW_STEP, (y0 + y + 0.5) * MapGen.FLOW_STEP)):
					blocked[y * w + x] = 1
	var ring := PackedInt32Array()
	for y in h:
		for x in w:
			var i := y * w + x
			if open[i] == 1 and blocked[i] == 0 and (
					(x > 0 and blocked[i - 1] == 1) or (x < w - 1 and blocked[i + 1] == 1) or (y > 0 and blocked[i - w] == 1) or (y < h - 1 and blocked[i + w] == 1)):
				ring.append(i)
	for i in w * h:
		if blocked[i] == 1:
			open[i] = 0
	if ring.is_empty():
		return true
	var seen := PackedByteArray()
	seen.resize(w * h)
	_span_fill(open, seen, w, h, ring[0])
	for i in ring:
		if seen[i] == 0:
			return false
	return true


## Many nodes can close a pocket between them and the coast. Drop the nodes around any walkable spot
## the walker cannot reach, until none is left (each pass only removes, so it ends).
static func _repair_reach(res: MapGen.Result, p: MapGen.Params, only_nodes: Array = []) -> void:
	if res.walk_base.is_empty():
		var cnt0 := PackedInt32Array([0])
		res.walk_base = _walk_free(p, res.walk_land, cnt0)
		res.walk_base_n = cnt0[0]
	var nx := int(p.size_px().x / MapGen.FLOW_STEP)
	var ny := int(p.size_px().y / MapGen.FLOW_STEP)
	var start := Vector2i(clampi(int(p.player_spawn.x / MapGen.FLOW_STEP), 0, nx - 1), clampi(int(p.player_spawn.y / MapGen.FLOW_STEP), 0, ny - 1))
	var free := res.walk_base.duplicate()
	var free_n := res.walk_base_n - _clear_rocks(p, free, res.obstacles, nx, ny)
	if free[start.y * nx + start.x] == 0:
		return   # home itself is blocked: nothing to repair
	var cnt := PackedInt32Array([0])
	var seen := _walk_flood(free, nx, ny, start, cnt)
	var seen_n := cnt[0]
	var stack := PackedInt32Array()   # shared flood stack
	var cand := PackedInt32Array()    # samples that may be unreached (empty = look at all of them, the first round)
	var first := true
	while seen_n < free_n:
		# the samples a walker can stand on but cannot reach
		var lost_mask := PackedByteArray()   # an obstacle looks only at the samples in its own box
		lost_mask.resize(nx * ny)
		var still := PackedInt32Array()
		if first:
			for i in free.size():
				if free[i] == 1 and seen[i] == 0:
					lost_mask[i] = 1
					still.append(i)
		else:
			for i in cand:
				if free[i] == 1 and seen[i] == 0 and lost_mask[i] == 0:
					lost_mask[i] = 1
					still.append(i)
		first = false
		var kept: Array[Dictionary] = []
		var removed: Array[Dictionary] = []
		for o in res.obstacles:
			var reach: float = o["radius"] + p.agent_radius + 2.0 * MapGen.FLOW_STEP
			var near := false
			if not only_nodes.is_empty() and not only_nodes.has(o["node"]):
				kept.append(o)
				continue
			var pos: Vector2 = o["pos"]
			for y in range(maxi(int((pos.y - reach) / MapGen.FLOW_STEP), 0), mini(int((pos.y + reach) / MapGen.FLOW_STEP) + 1, ny)):
				for x in range(maxi(int((pos.x - reach) / MapGen.FLOW_STEP), 0), mini(int((pos.x + reach) / MapGen.FLOW_STEP) + 1, nx)):
					if lost_mask[y * nx + x] == 1 and Vector2((x + 0.5) * MapGen.FLOW_STEP, (y + 0.5) * MapGen.FLOW_STEP).distance_to(pos) <= reach:
						near = true
						break
				if near:
					break
			if near:
				removed.append(o)
			else:
				kept.append(o)
		if removed.is_empty():
			return   # nothing removable: do not loop forever
		res.obstacles = kept
		res.obstacle_grid.clear()
		for o in kept:
			res.obstacle_grid.get_or_add(Vector2i(o["pos"] / res.obstacle_bucket), []).append(o)
		# the walk grid again with the remaining rocks; the samples that just became free are inside the removed rocks' boxes
		var free_new := res.walk_base.duplicate()
		free_n = res.walk_base_n - _clear_rocks(p, free_new, kept, nx, ny)
		var fresh := PackedInt32Array()
		for o in removed:
			var reach: float = o["radius"] + p.agent_radius
			var pos: Vector2 = o["pos"]
			for y in range(maxi(int((pos.y - reach) / MapGen.FLOW_STEP), 0), mini(int((pos.y + reach) / MapGen.FLOW_STEP) + 1, ny)):
				for x in range(maxi(int((pos.x - reach) / MapGen.FLOW_STEP), 0), mini(int((pos.x + reach) / MapGen.FLOW_STEP) + 1, nx)):
					var i := y * nx + x
					if free_new[i] == 1 and free[i] == 0:
						free[i] = 1   # marks it handled; `free` ends up equal to free_new
						fresh.append(i)
		free = free_new
		# reachability only grows: flood from every fresh sample that touches a reached one
		for i in fresh:
			if seen[i] == 0:
				var x := i % nx
				if (x > 0 and seen[i - 1] == 1) or (x < nx - 1 and seen[i + 1] == 1) or (i >= nx and seen[i - nx] == 1) or (i + nx < nx * ny and seen[i + nx] == 1):
					seen_n += _span_fill(free, seen, nx, ny, i, 1, PackedInt32Array(), stack)
		still.append_array(fresh)
		cand = still


# --------------------------------------------------------------------- deco ---
