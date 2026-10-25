extends SceneTree
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").map_seed = 11
	arena.get_node("ArenaMap").map_cols = 200   # the default island is 512 x 512 since 0038 step 2 (tests/test_chunks.gd); this test keeps the old size
	arena.get_node("ArenaMap").map_rows = 120
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var m: ArenaMap = arena.get_node("ArenaMap")
	var player: CharacterBody2D = arena.get_node("Player")
	var boss: Node2D = arena.get_node("Boss")
	_check(m.map_cols == 200 and m.map_rows == 120 and m.island_on, "the island map at the 200 x 120 test size")
	_check(m.area_at(m.home_point()) == MapGen.Area.FOREST, "home is in the forest")
	_check(m.area_at(boss.global_position) == MapGen.Area.BOSS, "the boss stands in the boss area")
	_check(m.home_point().distance_to(boss.global_position) > 3500.0, "the boss is far from home (%.0f px)" % m.home_point().distance_to(boss.global_position))
	_check(m.area_at(Vector2(5, 5)) == -1, "the map corner is water")
	var water: StaticBody2D = m.get_node("Water")
	_check(water.collision_layer == 1 and water.get_child_count() > 10, "water has collision on the wall layer (%d shapes)" % water.get_child_count())

	# Walk into the coast: find a walkable cell whose east neighbour is deep water, start 2 cells inside, push east.
	var p := m.make_params()
	var coast := Vector2i(-1, -1)
	for y in range(p.rows / 3, p.rows * 2 / 3):
		for x in range(p.cols - 2, p.cols / 2, -1):
			if MapGen.is_walkable(m.result, p, Vector2i(x, y)) and not MapGen.is_walkable(m.result, p, Vector2i(x + 1, y)):   # the deep ocean (shallows are wadeable)
				coast = Vector2i(x, y)
				break
		if coast.x >= 0:
			break
	_check(coast.x >= 0, "found an east coast cell")
	player.set_physics_process(false)
	player.global_position = (Vector2(coast) + Vector2(-1.5, 0.5)) * p.cell
	for i in 90:
		player.velocity = Vector2(400, 60)     # at an angle, as a player would
		player.move_and_slide()
		await physics_frame
	_check(m.water_kind_at(player.global_position) != MapGen.WaterKind.OCEAN, "the player stops at the deep water (shallows can be waded, the ocean never)")

	m.teleport_player("boss")
	_check(m.area_at(player.global_position) == MapGen.Area.BOSS, "Go to boss puts the player in the boss area")
	var tp := player.global_position
	var tp_clear := m._walker_fits(tp)
	_check(tp_clear, "Go to boss lands on free land (no rock, no water)")
	m.teleport_player("home")
	_check(player.global_position.distance_to(m.home_point()) < 1.0, "Go home puts the player at home")
	# M3: a size change before the deferred rebuild must not index past the old arrays
	player.global_position = Vector2(5000, 3600)
	m.map_cols = 300
	var st := m.status_text()
	_check(st.contains("area") and m.area_at(Vector2(9000, 100)) == -1, "area_at/status_text survive a size change before the rebuild")
	await process_frame
	m.map_cols = 200
	await process_frame
	_check(m.land_pct > 20 and m.status_text().contains("land %d%%" % m.land_pct), "land %% cached (%d)" % m.land_pct)
	var bg: ColorRect = arena.get_node("Background")
	_check(bg.color == m.style.water_color, "Background uses MapStyle.water_color")
	_check(m.build_ms > 0, "build time measured (%d ms)" % m.build_ms)
	_check(m.status_text().contains("area"), "F3 status shows the area")

	var hp: Node2D = arena.get_node("HomePoint")
	_check(hp is HomePoint and hp.get_node("Visual") != null, "HomePoint with a Visual slot")
	_check(hp.global_position.distance_to(m.home_point() + Vector2(m.home_offset_x, m.home_offset_y)) < 1.0, "campfire next to the start")
	var clear := true
	for o in m.result.obstacles:
		clear = clear and o["pos"].distance_to(hp.global_position) > m.spawn_clear_radius
	_check(clear, "no rock on the campfire")
	var panel = arena.get_node("TuningPanel")
	_check(panel.settings["Map.map_cols"].get("range", Vector3.ZERO).y >= 300.0, "F3 map_cols slider reaches 300")

	var times: Array[int] = []
	for s in [3, 4, 5]:
		m.generate_seed(s)
		times.append(m.build_ms)
	print("  build ms per seed: %s" % [times])
	_check(times.max() < 2000, "a full island rebuild stays under 2 s headless")

	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
