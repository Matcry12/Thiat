extends SceneTree
# The map is 72x40 cells (2x the screen) and ArenaMap owns its size: the 4 walls, the player's
# camera limits and the layout (player far left outside the zone, dummy near the player, boss in the
# zone) all come from map_cols / map_rows. Changing the size moves all of them.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _walls_rect(m: ArenaMap) -> Rect2:
	var r := Rect2()
	var first := true
	for w in m.get_node("Walls").get_children():
		var size: Vector2 = (w.get_node("CollisionShape2D").shape as RectangleShape2D).size
		var wr := Rect2(w.position - size * 0.5, size)
		r = wr if first else r.merge(wr)
		first = false
		_check(w.collision_layer == 1 and w.collision_mask == 0, "wall %s on layer 1, mask 0" % w.name)
	return r

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
	var player: CharacterBody2D = arena.get_node("Player")
	var cam: Camera2D = player.get_node("Camera")

	_check(m.get_node("Walls").get_child_count() == 4, "4 generated walls")
	_check(arena.get_node_or_null("Walls") == null, "no hand-placed Walls left in the scene")
	_check(_walls_rect(m) == Rect2(0, 0, 2304, 1280), "default walls frame 2304x1280 (%s)" % _walls_rect(m))
	_check(cam.is_current() and cam.get_parent() == player, "a Camera2D follows the player")
	_check(cam.limit_left == 0 and cam.limit_top == 0 and cam.limit_right == 2304 and cam.limit_bottom == 1280, "camera limits = the map")
	_check(cam.position_smoothing_enabled, "camera smoothing on by default")
	_check(arena.get_node("Background").size == Vector2(2304, 1280), "background covers the map")
	_check(arena.get_node("ArenaMap/Ground/Border").get_child_count() > 40, "bush border follows the bigger edges")
	var far_bush := false
	for b in arena.get_node("ArenaMap/Ground/Border").get_children():
		far_bush = far_bush or b.position.x > 2200
	_check(far_bush, "bushes reach the new right edge")
	# density: patches and rocks scale with the area (4 and 6 per screen -> about 15 and 23)
	_check(m.result.patches.size() > 8, "patch count scaled with the area (%d)" % m.result.patches.size())

	# layout
	var zone: Area2D = arena.get_node("FightZone")
	var zr := Rect2(zone.global_position - Vector2(440, 230), Vector2(880, 460))
	var boss: Boss = arena.get_node("Boss")
	var dummy: Node2D = arena.get_node("Dummy")
	_check(Rect2(0, 0, 2304, 1280).encloses(zr), "zone sits inside the map")
	_check(zone.global_position.x > 1152, "zone is in the right half")
	_check(zr.has_point(boss.global_position) and boss.home == boss.global_position, "boss spawns inside the zone and knows its home")
	_check(not zr.has_point(player.global_position) and zr.position.x - player.global_position.x > 500, "player spawns well outside the zone, to its left")
	_check(not zr.has_point(dummy.global_position) and dummy.global_position.distance_to(player.global_position) < 450, "dummy near the player, outside the zone")
	for r in get_nodes_in_group("map_obstacle"):
		_check(not zr.grow(r.get_child(0).shape.radius).has_point(r.global_position), "rock outside the zone")
		break

	# a different size: walls and camera limits follow, the layout moves with it
	m.map_cols = 50
	m.map_rows = 30
	await process_frame
	await process_frame
	_check(_walls_rect(m) == Rect2(0, 0, 1600, 960), "50x30 cells -> walls frame 1600x960 (%s)" % _walls_rect(m))
	_check(cam.limit_right == 1600 and cam.limit_bottom == 960, "camera limits follow (%d, %d)" % [cam.limit_right, cam.limit_bottom])
	_check(arena.get_node("Background").size == Vector2(1600, 960), "background follows")
	_check(Rect2(0, 0, 1600, 960).encloses(Rect2(zone.global_position - Vector2(440, 230), Vector2(880, 460))), "zone still inside the smaller map")
	_check(Rect2(0, 0, 1600, 960).has_point(player.global_position) and boss.home == boss.global_position, "player and boss re-placed inside it")
	_check(m.result.dirt.size() == 50 * 30, "ground rebuilt at the new size")

	# F1 draws in world coordinates: its layer must carry the camera transform
	m.camera_smoothing = false
	player.global_position = Vector2(1000, 500)
	await process_frame
	await process_frame
	var overlay_layer: Node2D = arena.get_node("DebugOverlay/DrawLayer")
	_check(root.canvas_transform.origin != Vector2.ZERO and overlay_layer.transform == root.canvas_transform, "F1 shapes follow the camera (%s)" % overlay_layer.transform.origin)

	# the walls really block
	player.set_physics_process(false)
	player.global_position = Vector2(60, 480)
	await physics_frame
	_check(player.test_move(player.global_transform, Vector2(-100, 0)), "the left wall stops the player")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
