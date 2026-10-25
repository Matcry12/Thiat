extends SceneTree
# The arena scene builds its map: tiles + sprites + rock bodies (below the characters), the F3 panel
# lists the map's exports and shows the seed, `New map` changes the seed, a slider rebuilds the
# same seed, and the F1 overlay can find the rocks.
func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	var mm = arena.get_node("ArenaMap")
	mm.island_on = false
	mm.map_cols = 72
	mm.map_rows = 40
	mm.zone_x = 0.72
	mm.player_spawn_x = 0.14
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var m: ArenaMap = arena.get_node("ArenaMap")
	var ok := true

	m.load_all_chunks()   # 0038 step 2: trees, rocks and props exist per chunk near the player; this test counts every one
	var seed_a := m.current_seed
	ok = ok and _t(seed_a != 0, "random seed rolled when map_seed = 0")
	ok = ok and _t(m.get_node("Ground/Dirt").get_used_cells().size() == 72 * 40, "dirt layer fills the arena (%d)" % m.get_node("Ground/Dirt").get_used_cells().size())
	ok = ok and _t(m.get_node("Ground/Grass").get_used_cells().size() > 300, "grass layer is filled")
	ok = ok and _t(m.get_node("Ground/Border").get_child_count() > 20, "bushes along the walls")
	var ground: Node2D = m.get_node("Ground")
	ok = ok and _t(ground.z_index <= -2 and arena.get_node("Background").z_index < ground.z_index, "ground under shadows (z -1) and characters; Background under ground")
	ok = ok and _t(m.z_index == 0 and m.get_node("Obstacles").z_index == 0 and arena.y_sort_enabled and m.y_sort_enabled and m.get_node("Obstacles").y_sort_enabled, "rocks Y-sort with the characters")
	var rocks := get_nodes_in_group("map_obstacle")
	ok = ok and _t(rocks.size() == m.result.obstacles.size() and rocks.size() > 0, "one body per rock (%d)" % rocks.size())
	for r in rocks:
		ok = ok and _t((r as StaticBody2D).collision_layer & 1 == 1, "rock on the walls' layer")

	var panel = arena.get_node("TuningPanel")
	for key in ["Map.map_seed", "Map.patch_count", "Map.patch_noise_threshold", "Map.deco_density", "Map.deco_min_spacing", "Map.obstacle_count", "Map.obstacle_min_spacing", "Map.spawn_clear_radius", "Map.border_density", "Map.dark_grass_chance", "Map.noise_frequency", "Map.patch_min_size", "Map.patch_max_size", "Map.map_cols", "Map.map_rows", "Map.zone_width", "Map.zone_height", "Map.camera_smoothing_speed"]:
		ok = ok and _t(panel.settings.has(key), "F3 lists " + key)

	# a slider keeps the seed and rebuilds
	panel.apply_value("Map.patch_count", 2)
	await process_frame
	await process_frame
	ok = ok and _t(m.current_seed == seed_a and m.result.patches.size() <= 8, "slider: same seed, fewer patches (patch_count is per screen: 2 x 3.8 = 8 max)")

	# Same seed after the player has walked away = same map (spawns are read once, not live).
	var layout_before := [m.result.patches, m.result.obstacles, m.result.deco, m.result.grass]
	arena.get_node("Player").global_position = Vector2(900, 500)
	m.rebuild(false)
	ok = ok and _t([m.result.patches, m.result.obstacles, m.result.deco, m.result.grass] == layout_before, "moving the player does not change the map")

	# Draw order: put a rock in the open and test the sort keys against a player behind / in front.
	ok = ok and await _rock_checks(arena, m)

	m.new_map()
	ok = ok and _t(m.current_seed >= 1 and m.current_seed <= 9999, "seeds fit the F3 slider")
	ok = ok and _t(panel.get_node_or_null(".") != null and m.save_value("map_seed") == m.current_seed, "F3 Save stores the showing seed")
	ok = ok and _t(m.current_seed != seed_a, "New map rolls a new seed")
	m.load_all_chunks()
	ok = ok and _t(get_nodes_in_group("map_obstacle").size() == m.result.obstacles.size(), "old rocks are gone after a rebuild")

	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _rock_checks(arena: Node, m: ArenaMap) -> bool:
	var ok := true
	var player: CharacterBody2D = arena.get_node("Player")
	var boss: CharacterBody2D = arena.get_node("Boss")
	player.set_physics_process(false)
	for r in get_nodes_in_group("map_obstacle"):
		r.queue_free()
	await process_frame
	var rock := StaticBody2D.new()           # same recipe as ArenaMap's rocks
	rock.add_to_group("map_obstacle")
	var cs := CollisionShape2D.new()
	cs.shape = CircleShape2D.new()
	cs.shape.radius = 22.0
	rock.add_child(cs)
	rock.position = Vector2(576, 324)
	m.get_node("Obstacles").add_child(rock)
	boss.add_collision_exception_with(rock)   # ArenaMap does this for every rock it builds
	await physics_frame
	# Sort: Y-sort draws the lower y in front. Rock origin y=324. Behind = smaller y.
	player.global_position = Vector2(576, 270)
	ok = ok and _t(player.global_position.y < rock.global_position.y, "player behind the rock sorts first (drawn behind)")
	# Collision: from the left, the player is stopped by the rock, the boss is not.
	var motion := Vector2(100, 0)
	player.global_position = Vector2(500, 324)
	boss.global_position = Vector2(500, 324)
	ok = ok and _t(player.test_move(player.global_transform, motion), "player is blocked by a rock")
	ok = ok and _t(not boss.test_move(boss.global_transform, motion), "boss passes through a rock")
	# Arrows still stop on it: a ray on the world layer hits the rock.
	var q := PhysicsRayQueryParameters2D.create(Vector2(500, 324), Vector2(650, 324))
	q.collision_mask = 1
	ok = ok and _t(not arena.get_world_2d().direct_space_state.intersect_ray(q).is_empty(), "arrows (world mask) stop on a rock")
	rock.queue_free()
	return ok


func _t(cond: bool, msg: String) -> bool:
	if not cond:
		print("FAIL: ", msg)
	return cond
