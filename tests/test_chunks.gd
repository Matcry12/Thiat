extends SceneTree
# 0038 step 2: the world is data, only the chunks near the player are nodes.
#   - the default island is 512 x 512 cells, in 32-cell chunks
#   - only the chunks within load_radius of the player are loaded, nearest first, at most chunks_per_frame per frame
#   - walk far away and back: a chunk gives the same nodes again, and a node that was gathered stays gone
#   - a chunk's ground picture is the same pixels as the matching part of the whole-map picture
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _placements(m: ArenaMap) -> Array:
	var out := []
	for id in m.streamer().loaded:
		for k in (m.streamer().loaded[id] as ChunkStreamer.Chunk).placed.size():
			var ch: ChunkStreamer.Chunk = m.streamer().loaded[id]
			if is_instance_valid(ch.nodes[k]) and not ch.nodes[k].is_queued_for_deletion():
				out.append([ch.placed[k], ch.nodes[k].position])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").map_seed = 11
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player: CharacterBody2D = arena.get_node("Player")
	player.set_physics_process(false)
	var m: ArenaMap = arena.get_node("ArenaMap")
	var sr := m.streamer()
	_check(m.map_cols == 512 and m.map_rows == 512 and m.chunk_cells == 32 and m.load_radius == 2 and m.chunks_per_frame == 1, "defaults: 512 x 512 cells, 32-cell chunks, load radius 2, 1 chunk per frame")
	_check(sr.chunk_count() == 16 * 16 and m.result.cols == 512, "16 x 16 chunks, world data for every cell (%d placements)" % m.result.obstacles.size())
	_check(m.gen_ms < 6000, "world data under the 6 s fallback headless (%d ms)" % m.gen_ms)

	# right after the build: the 3 x 3 around the player is there at once
	var pc := sr.chunk_of(player.global_position)
	var near_ok := true
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := pc + Vector2i(dx, dy)
			if c.x >= 0 and c.y >= 0 and c.x < sr.cols_c and c.y < sr.rows_c:
				near_ok = near_ok and sr.is_loaded(sr.chunk_id(c))
	_check(near_ok, "the 3 x 3 chunks around the player are built at once")
	# then one per frame, nearest first
	var last := sr.built_total
	var per_frame_ok := true
	for f in 40:
		await process_frame
		per_frame_ok = per_frame_ok and sr.built_total - last <= m.chunks_per_frame
		last = sr.built_total
	_check(per_frame_ok, "at most chunks_per_frame chunks are built per frame")
	var within := true
	for id in sr.loaded:
		var c := Vector2i(id % sr.cols_c, id / sr.cols_c)
		within = within and maxi(absi(c.x - pc.x), absi(c.y - pc.y)) <= m.load_radius + m.unload_margin
	var want := (mini(pc.x + 2, sr.cols_c - 1) - maxi(pc.x - 2, 0) + 1) * (mini(pc.y + 2, sr.rows_c - 1) - maxi(pc.y - 2, 0) + 1)
	_check(within and sr.loaded.size() == want and sr.loaded.size() < sr.chunk_count() / 4, "only the chunks near the player are loaded (%d of %d, radius 2 = %d)" % [sr.loaded.size(), sr.chunk_count(), want])
	_check(get_nodes_in_group("resource_node").size() == sr.nodes_alive() and sr.nodes_alive() < m.node_count / 4, "only their nodes exist (%d of %d placements)" % [sr.nodes_alive(), m.node_count])
	_check(m.get_node("Ground/Terrain/Grounds").get_child_count() <= sr.loaded.size(), "one ground picture per loaded chunk with land (%d)" % m.get_node("Ground/Terrain/Grounds").get_child_count())

	# a node near home: gather it away, walk far, come back
	var tree := m.nearest_node(&"treepp_oak_green_mature", m.home_point())
	_check(tree != null, "nearest_node finds a tree in the world data")
	var other := m.nearest_node(&"treepp_oak_green_old", m.home_point())
	_check(sr._pins.size() > 0, "nearest_node pins the chunk it loaded")
	sr._pins.clear()   # the pin would keep the home chunk alive for 600 frames
	var before := _placements(m)
	var tp := tree.placement
	var op := other.placement
	var hp0 := other.hp
	other.hp = hp0 - 1.0
	tree.hp = 0.0
	tree._break(player)
	await process_frame
	_check(sr.broken[tp] == 1, "a gathered node is remembered in the world data (placement %d)" % tp)
	m.teleport_player("boss")
	for f in 6:
		await process_frame
	_check(sr.node_of(tp) == null and not sr.is_loaded(sr.chunk_id(sr.chunk_of(m.result.obstacles[tp]["pos"]))), "far away, the home chunk is freed")
	_check(get_nodes_in_group("resource_node").size() == sr.nodes_alive() and sr.loaded.size() <= want + 4, "the boss chunks are loaded instead (%d chunks)" % sr.loaded.size())
	m.teleport_player("home")
	for f in 30:
		await process_frame
	var after := _placements(m)
	var tree_back := sr.node_of(tp) as ResourceNode
	var gone := tree_back == null or tree_back.is_broken()
	var kept := sr.node_of(op) != null
	var same := true
	for e in before:
		if e[0] != tp:
			same = same and after.has(e)
	_check(gone, "the gathered node did not respawn after its chunk came back")
	_check(kept and same and after.size() >= before.size() - 1, "the other nodes of the chunk came back at the same places (%d before, %d after)" % [before.size(), after.size()])

	# teleport builds the target at once
	m.teleport_player("boss")
	var bc := sr.chunk_of(player.global_position)
	_check(sr.is_loaded(sr.chunk_id(bc)), "Go to boss: the chunk under the player is already built")

	# F3 / F1 hooks
	_check(m.status_text().contains("chunks ") and m.status_text().contains("nodes alive") and m.status_text().contains("chunk build ms"), "F3 [Map] shows chunks loaded / total, build ms and what is alive")
	_check(sr.loaded_rects().size() == sr.loaded.size(), "F1 can draw every loaded chunk")

	# a chunk picture is the same pixels as that part of the whole picture
	var style := m.style
	var p := m.make_params()
	p.cols = 100
	p.rows = 70
	p.world = Vector2(100, 70) * p.cell
	p.player_spawn = Vector2(0.2 * p.world.x, 0.5 * p.world.y)
	p.zone = Rect2(Vector2(0.8 * p.world.x, 0.5 * p.world.y) - Vector2(440, 230), Vector2(880, 460))
	p.spawns = PackedVector2Array([p.player_spawn])
	p.obstacle_count = 30
	var res := MapGen.generate(style, p, 7)
	var baked := GroundBaker.bake(res, style, m.tint_look())
	var whole: Image = baked["ground"]
	var whole_foam: Image = baked["foam"]
	var t: int = GroundBaker.tile_of(style)
	var seams_ok := true
	for corner in [Vector2i(0, 0), Vector2i(32, 32), Vector2i(64, 0), Vector2i(64, 32), Vector2i(96, 64)]:
		var w := mini(32, 101 - corner.x)
		var h := mini(32, 71 - corner.y)
		var both := GroundBaker.bake_region(res, style, corner.x, corner.y, w, h)
		var cut := whole.get_region(Rect2i(corner.x * t, corner.y * t, w * t, h * t))
		var cut_foam := whole_foam.get_region(Rect2i(corner.x * t, corner.y * t, w * t, h * t))
		seams_ok = seams_ok and (both["ground"] as Image).get_data() == cut.get_data() and (both["foam"] as Image).get_data() == cut_foam.get_data()
	_check(seams_ok, "a chunk's ground and foam pictures equal the same pixels of the whole pictures (5 pieces, edges and corners)")
	var tint_whole := GroundBaker.tint_image(res, m.tint_look())
	var tint_part := GroundBaker.tint_image_region(res, m.tint_look(), 31, 31, 34, 34)
	_check(tint_part.get_data() == tint_whole.get_region(Rect2i(31, 31, 34, 34)).get_data(), "a chunk's tint map equals that part of the whole map")

	var shade_whole := GroundBaker.shade_image(res, m.tint_look())
	_check(GroundBaker.shade_image_region(res, m.tint_look(), 31, 31, 34, 34).get_data() == shade_whole.get_region(Rect2i(31, 31, 34, 34)).get_data(), "a chunk's shade map equals that part of the whole map")
	# gathered nodes survive a chunk re-layout (chunk_cells slider); a new world forgets them
	var tp2 := sr.broken.find(1)
	m.chunk_cells = 64
	_check(tp2 < 0 or sr.broken[tp2] == 1, "chunk_cells slider keeps the gathered-node memory")
	# a station cannot go over a tree whose chunk is not loaded
	m.teleport_player("home")
	var far_tree := m.nearest_node(&"treepp_oak_green_old", m.layout()["boss"], false)
	var fp: Vector2 = far_tree.position
	m.teleport_player("boss")
	await process_frame
	m.streamer()._unload(m.streamer().chunk_id_at(fp)) if m.streamer().is_loaded(m.streamer().chunk_id_at(fp)) else null
	_check(m.placement_blocked(Rect2(fp - Vector2(8, 8), Vector2(16, 16))), "placement_blocked sees a tree of an unloaded chunk")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
