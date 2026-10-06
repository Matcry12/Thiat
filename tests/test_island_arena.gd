extends SceneTree
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").map_seed = 11
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var m: ArenaMap = arena.get_node("ArenaMap")
	var player: CharacterBody2D = arena.get_node("Player")
	var boss: Node2D = arena.get_node("Boss")
	_check(m.map_cols == 200 and m.map_rows == 120 and m.island_on, "default map is the 200 x 120 island")
	_check(m.area_at(m.home_point()) == MapGen.Area.FOREST, "home is in the forest")
	_check(m.area_at(boss.global_position) == MapGen.Area.BOSS, "the boss stands in the boss area")
	_check(m.home_point().distance_to(boss.global_position) > 3500.0, "the boss is far from home (%.0f px)" % m.home_point().distance_to(boss.global_position))
	_check(m.area_at(Vector2(5, 5)) == -1, "the map corner is water")
	var water: StaticBody2D = m.get_node("Water")
	_check(water.collision_layer == 1 and water.get_child_count() > 10, "water has collision on the wall layer (%d shapes)" % water.get_child_count())

	# Walk into the coast: find a land cell whose east neighbour is water, start 2 cells inside, push east.
	var p := m.make_params()
	var coast := Vector2i(-1, -1)
	for y in range(p.rows / 3, p.rows * 2 / 3):
		for x in range(p.cols - 2, p.cols / 2, -1):
			if MapGen.is_land(m.result, p, Vector2i(x, y)) and not MapGen.is_land(m.result, p, Vector2i(x + 1, y)):
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
	_check(m.area_at(player.global_position) != -1, "the player stops at the shore (never on water)")

	m.teleport_player("boss")
	_check(m.area_at(player.global_position) == MapGen.Area.BOSS, "Go to boss puts the player in the boss area")
	m.teleport_player("home")
	_check(player.global_position.distance_to(m.home_point()) < 1.0, "Go home puts the player at home")
	_check(m.build_ms > 0, "build time measured (%d ms)" % m.build_ms)
	_check(m.status_text().contains("area"), "F3 status shows the area")

	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
