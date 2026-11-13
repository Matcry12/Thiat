class_name ChunkStreamer
extends Node
## Decision 0038, step 2: the world is data, only the part near the player is nodes.
##   WORLD DATA (MapGen.Result, global, built once per map): land, biome, ground ids, every tree / rock / prop placement.
##   VISUALS + NODES are made per chunk (chunk_cells x chunk_cells cells): the ground picture + foam (GroundBaker.bake_region ->
##   TerrainVisual), the ResourceNodes (rocks, trees), the floor props (ChunkDeco). Chunks inside `load_radius` of the player are
##   loaded, at most `chunks_per_frame` per frame, nearest first; chunks beyond `load_radius + unload_margin` are freed.
##   Gathered nodes are remembered by placement index (`broken`), so a chunk that comes back does not respawn them.
## ArenaMap owns this node and is the only one that talks to it.

const RESOURCE_NODE := preload("res://scenes/world/resource_node.tscn")


class Chunk:
	var id := 0
	var nodes: Array[Node2D] = []        ## ResourceNodes and cover rocks, parallel to `placed`
	var placed := PackedInt32Array()     ## obstacle index (placement index) of each node
	var deco: Node2D                     ## the ChunkDeco root, null if the chunk has no props
	var tall: Array[Sprite2D] = []       ## the Y-sorted big props (bushes ...), under the obstacles root
	var has_ground := false


var map: ArenaMap
var loaded := {}                  ## chunk id -> Chunk
var cols_c := 0                   ## chunk grid size
var rows_c := 0
var chunk_cells := 32
var broken := PackedByteArray()   ## per placement index: 1 = gathered / broken (world data)
var last_ms := 0.0                ## build time of the latest chunk, the average and the worst, for F3
var avg_ms := 0.0
var max_ms := 0.0
var built_total := 0
var queued := 0                   ## chunks wanted and not loaded yet
var hold_all := false             ## true after load_all(): nothing is unloaded and nothing is planned until the next reset() (tools, tests)
var part_ms := {"ground": 0.0, "deco": 0.0, "nodes": 0.0}   ## average build ms of the three parts of a chunk, for F3

var _obs: Array[PackedInt32Array] = []    ## per chunk id: placement indices of its obstacles
var _deco: Array[PackedInt32Array] = []   ## per chunk id: indices into Result.deco
var _wanted: Array[int] = []              ## missing chunk ids, nearest first
var _focus := Vector2i(-99999, -99999)    ## the chunk the player was in when `_wanted` was made
var _dirty := true
var _sum_ms := 0.0
var _pins := {}                           ## chunk id -> frames left: kept loaded though far (nearest_node)


func _process(_delta: float) -> void:
	if map == null or map.result == null or cols_c == 0 or hold_all:
		return
	for id in _pins.keys():
		_pins[id] -= 1
		if _pins[id] <= 0:
			_pins.erase(id)
			_dirty = true
	var pos := map.stream_focus()
	var fc := chunk_of(pos)
	if fc != _focus or _dirty:
		if _focus.x > -99999 and maxi(absi(fc.x - _focus.x), absi(fc.y - _focus.y)) > 1:
			build_around(pos, 1)   # a jump (teleport, a tool placing the player): do not show an empty map for the next few frames
		_focus = fc
		_dirty = false
		_unload_far(fc)
		_wanted = _missing_within(fc, map.load_radius)
	var made := 0
	while made < map.chunks_per_frame and not _wanted.is_empty():
		var id: int = _wanted.pop_front()
		if not loaded.has(id):
			_build(id)
			made += 1
	queued = _wanted.size()


## Throw everything away and index the current MapGen.Result (a new map, a new size). Gathered nodes are forgotten: it is a new world.
func reset(keep_broken := false) -> void:
	var old_broken := broken
	_free_all()
	hold_all = false
	_pins.clear()
	chunk_cells = maxi(map.chunk_cells, 4)
	var res := map.result
	cols_c = ceili(float(res.cols) / chunk_cells)
	rows_c = ceili(float(res.rows) / chunk_cells)
	broken = PackedByteArray()
	broken.resize(res.obstacles.size())
	if keep_broken and old_broken.size() == broken.size():
		broken = old_broken   # same world, only the chunk layout changed: gathered nodes stay gone
	_obs.clear()
	_obs.resize(cols_c * rows_c)
	_deco.clear()
	_deco.resize(cols_c * rows_c)
	for k in _obs.size():
		_obs[k] = PackedInt32Array()
		_deco[k] = PackedInt32Array()
	var px := map.cell_px() * chunk_cells
	for i in res.obstacles.size():
		_obs[_id_at(res.obstacles[i]["pos"], px)].append(i)
	_index_deco()
	last_ms = 0.0
	avg_ms = 0.0
	max_ms = 0.0
	built_total = 0
	_sum_ms = 0.0
	part_ms = {"ground": 0.0, "deco": 0.0, "nodes": 0.0}
	_wanted.clear()
	queued = 0
	_focus = Vector2i(-99999, -99999)
	_dirty = true


## Result.deco changed (the ground was rebuilt and some props dropped): index it again and redo the loaded chunks' ground and props.
func reload_visuals() -> void:
	_index_deco()
	for id in loaded.keys():
		var ch: Chunk = loaded[id]
		_drop_visuals(ch)
		_build_visuals(ch)


func retint() -> void:
	var terrain := map.terrain()
	for id in loaded:
		if (loaded[id] as Chunk).has_ground:
			var c := _cells_of(id)
			terrain.set_chunk_tint(id, GroundBaker.tint_image_region(map.result, map.tint_look(), c.position.x - 1, c.position.y - 1, _tiles_of(id).x + 1, _tiles_of(id).y + 1),
				GroundBaker.shade_image_region(map.result, map.tint_look(), c.position.x - 1, c.position.y - 1, _tiles_of(id).x + 1, _tiles_of(id).y + 1))


## Build every missing chunk within `radius` chunks (Chebyshev) of the world position now, nearest first. For spawn, teleport, a new map.
func build_around(pos: Vector2, radius: int) -> void:
	if map == null or map.result == null or cols_c == 0:
		return
	for id in _missing_within(chunk_of(pos), radius):
		if not loaded.has(id):
			_build(id)
	_dirty = true


func load_all() -> void:
	for id in cols_c * rows_c:
		if not loaded.has(id):
			_build(id)
	hold_all = true


## The wanted set may have changed (a radius): plan again next frame.
func refresh() -> void:
	_dirty = true


## Keep a chunk loaded for `frames` frames even when it is far from the player (a caller got a node of it and has not moved there yet).
func pin(id: int, frames := 600) -> void:
	_pins[id] = frames


func chunk_id_at(pos: Vector2) -> int:
	return chunk_id(chunk_of(pos))


func is_loaded(id: int) -> bool:
	return loaded.has(id)


func chunk_count() -> int:
	return cols_c * rows_c


func chunk_of(pos: Vector2) -> Vector2i:
	var px := map.cell_px() * chunk_cells
	return Vector2i(clampi(int(floorf(pos.x / px)), 0, cols_c - 1), clampi(int(floorf(pos.y / px)), 0, rows_c - 1))


func chunk_id(c: Vector2i) -> int:
	return c.y * cols_c + c.x


## The chunk's cells as a Rect2i (the last row / column may be smaller).
func _cells_of(id: int) -> Rect2i:
	var x0 := (id % cols_c) * chunk_cells
	var y0 := (id / cols_c) * chunk_cells
	return Rect2i(x0, y0, mini(chunk_cells, map.result.cols - x0), mini(chunk_cells, map.result.rows - y0))


## The chunk's corner tiles (dual grid): its cells, and one more row / column at the far edge of the map.
func _tiles_of(id: int) -> Vector2i:
	var c := _cells_of(id)
	return Vector2i(c.size.x + (1 if c.end.x == map.result.cols else 0), c.size.y + (1 if c.end.y == map.result.rows else 0))


## The world rectangle (px) of every loaded chunk, for the F1 overlay.
func loaded_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var cp := map.cell_px()
	for id in loaded:
		out.append(Rect2(Vector2(_cells_of(id).position) * cp, Vector2(_cells_of(id).size) * cp))
	return out


## The live node of a placement (null while its chunk is not loaded, or after it was gathered).
func node_of(placement: int) -> Node2D:
	var id := _id_at(map.result.obstacles[placement]["pos"], map.cell_px() * chunk_cells)
	if not loaded.has(id):
		return null
	var ch: Chunk = loaded[id]
	var k := ch.placed.find(placement)
	return ch.nodes[k] if k >= 0 and is_instance_valid(ch.nodes[k]) else null


func nodes_alive() -> int:
	var n := 0
	for id in loaded:
		for node in (loaded[id] as Chunk).nodes:
			n += 1 if is_instance_valid(node) and not node.is_queued_for_deletion() else 0
	return n


func deco_alive() -> int:
	var n := 0
	for id in loaded:
		var ch: Chunk = loaded[id]
		if ch.deco != null:
			for mmi in ch.deco.get_children():
				n += (mmi as MultiMeshInstance2D).multimesh.instance_count
		n += ch.tall.size()
	return n


func status_text() -> String:
	return "chunks %d/%d loaded (%d queued), %d cells, load radius %d\nchunk build ms last %.1f avg %.1f max %.1f (%d built; avg ground %.1f, props %.1f, nodes %.1f)\nnodes alive %d  deco alive %d" % [
		loaded.size(), cols_c * rows_c, queued, chunk_cells, map.load_radius, last_ms, avg_ms, max_ms, built_total, part_ms["ground"], part_ms["deco"], part_ms["nodes"], nodes_alive(), deco_alive()]


func _id_at(pos: Vector2, chunk_px: float) -> int:
	return clampi(int(pos.y / chunk_px), 0, rows_c - 1) * cols_c + clampi(int(pos.x / chunk_px), 0, cols_c - 1)


func _index_deco() -> void:
	for k in _deco.size():
		_deco[k] = PackedInt32Array()
	var px := map.cell_px() * chunk_cells
	var deco := map.result.deco
	for i in deco.size():
		_deco[_id_at(deco[i]["pos"], px)].append(i)


## Ids of the chunks within `radius` of chunk `fc` that are not loaded, nearest first (ties: by id).
func _missing_within(fc: Vector2i, radius: int) -> Array[int]:
	var found: Array[Vector3i] = []   # (squared distance, id, 0)
	for cy in range(maxi(fc.y - radius, 0), mini(fc.y + radius, rows_c - 1) + 1):
		for cx in range(maxi(fc.x - radius, 0), mini(fc.x + radius, cols_c - 1) + 1):
			var id := cy * cols_c + cx
			if not loaded.has(id):
				found.append(Vector3i((cx - fc.x) * (cx - fc.x) + (cy - fc.y) * (cy - fc.y), id, 0))
	found.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var out: Array[int] = []
	for f in found:
		out.append(f.y)
	return out


func _unload_far(fc: Vector2i) -> void:
	var limit := map.load_radius + map.unload_margin
	for id in loaded.keys():
		if _pins.has(id):
			continue
		var c := Vector2i(id % cols_c, id / cols_c)
		if maxi(absi(c.x - fc.x), absi(c.y - fc.y)) > limit:
			_unload(id)


func _free_all() -> void:
	for id in loaded.keys():
		_unload(id)
	loaded.clear()


func _unload(id: int) -> void:
	var ch: Chunk = loaded[id]
	loaded.erase(id)
	var boss := map.boss()
	for n in ch.nodes:
		if is_instance_valid(n):
			if boss != null and n is PhysicsBody2D:
				boss.remove_collision_exception_with(n)
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.queue_free()
	_drop_visuals(ch)


func _drop_visuals(ch: Chunk) -> void:
	if ch.has_ground:
		map.terrain().remove_chunk(ch.id)
		ch.has_ground = false
	for sp in ch.tall:
		if is_instance_valid(sp):
			if sp.get_parent() != null:
				sp.get_parent().remove_child(sp)
			sp.queue_free()
	ch.tall.clear()
	if ch.deco != null:
		if ch.deco.get_parent() != null:
			ch.deco.get_parent().remove_child(ch.deco)
		ch.deco.queue_free()
		ch.deco = null


func _build(id: int) -> void:
	var t0 := Time.get_ticks_usec()
	var ch := Chunk.new()
	ch.id = id
	loaded[id] = ch
	_build_visuals(ch)
	var t1 := Time.get_ticks_usec()
	_build_nodes(ch)
	var t2 := Time.get_ticks_usec()
	last_ms = (t2 - t0) / 1000.0
	built_total += 1
	part_ms["nodes"] += ((t2 - t1) / 1000.0 - part_ms["nodes"]) / built_total
	_sum_ms += last_ms
	avg_ms = _sum_ms / built_total
	max_ms = maxf(max_ms, last_ms)


func _build_visuals(ch: Chunk) -> void:
	var res := map.result
	var cells := _cells_of(ch.id)
	var t0 := Time.get_ticks_usec()
	if not res.ground.is_empty() and _has_ground(cells):
		var tiles := _tiles_of(ch.id)
		var images := GroundBaker.bake_region(res, map.style, cells.position.x, cells.position.y, tiles.x, tiles.y)
		images["tint"] = GroundBaker.tint_image_region(res, map.tint_look(), cells.position.x - 1, cells.position.y - 1, tiles.x + 1, tiles.y + 1)
		images["shade"] = GroundBaker.shade_image_region(res, map.tint_look(), cells.position.x - 1, cells.position.y - 1, tiles.x + 1, tiles.y + 1)
		map.terrain().set_chunk(ch.id, cells.position, images, float(map.style.pixel_scale))
		ch.has_ground = true
	var t1 := Time.get_ticks_usec()
	part_ms["ground"] += ((t1 - t0) / 1000.0 - part_ms["ground"]) / (built_total + 1)
	var list: Array[Dictionary] = []
	for i in _deco[ch.id]:
		list.append(res.deco[i])
	if not list.is_empty():
		ch.deco = ChunkDeco.build(list, map.style.deco, float(map.style.pixel_scale), map.ysort_min_px, map.biome_id_at)
		ch.deco.name = "Deco%d" % ch.id
		map.deco_root().add_child(ch.deco)
		ch.tall = ChunkDeco.build_tall(list, map.style.deco, float(map.style.pixel_scale), map.ysort_min_px, map.biome_id_at)
		for sp in ch.tall:
			map.obstacles_root().add_child(sp)
	part_ms["deco"] += ((Time.get_ticks_usec() - t1) / 1000.0 - part_ms["deco"]) / (built_total + 1)


## Any ground under the cells the chunk's corner tiles look at (water-only chunks need no picture).
func _has_ground(cells: Rect2i) -> bool:
	var res := map.result
	for y in range(maxi(cells.position.y - 1, 0), mini(cells.end.y + 1, res.rows)):
		for x in range(maxi(cells.position.x - 1, 0), mini(cells.end.x + 1, res.cols)):
			if res.ground[y * res.cols + x] != MapGen.Ground.WATER:
				return true
	return false


func _build_nodes(ch: Chunk) -> void:
	var res := map.result
	var style := map.style
	var boss := map.boss()
	for idx in _obs[ch.id]:
		var o := res.obstacles[idx]
		var n: Node2D
		if o["node"] >= 0:
			var data := style.resource_nodes[o["node"]]
			if broken[idx] == 1 and not data.remains_region.has_area():
				continue   # gathered and nothing is left to see
			var rn: ResourceNode = RESOURCE_NODE.instantiate()
			rn.setup(data, o["region"])
			rn.biome = map.biome_id_at(o["pos"])
			rn.placement = idx
			rn.position = o["pos"]
			rn.broken.connect(_on_node_broken)
			map.obstacles_root().add_child(rn)
			if broken[idx] == 1:
				rn.restore_broken()
			n = rn
		else:
			n = map.make_cover_rock(o)
			map.obstacles_root().add_child(n)
		if boss != null and n is PhysicsBody2D:
			boss.add_collision_exception_with(n)   # the boss walks through rocks and trees: cover against the player, never a hiding place from its charge
		ch.nodes.append(n)
		ch.placed.append(idx)


## A save says this placement was gathered: remember it, and show it that way if its chunk is loaded now.
func mark_broken(idx: int) -> void:
	if idx < 0 or idx >= broken.size() or broken[idx] == 1:
		return
	broken[idx] = 1
	var n := node_of(idx) as ResourceNode
	if n == null:
		return
	if n.data.remains_region.has_area():
		n.restore_broken()
	else:
		n.queue_free()

func broken_list() -> Array:
	var a := []
	for i in broken.size():
		if broken[i] == 1:
			a.append(i)
	return a

func _on_node_broken(n: ResourceNode) -> void:
	if n.placement >= 0 and n.placement < broken.size():
		broken[n.placement] = 1
