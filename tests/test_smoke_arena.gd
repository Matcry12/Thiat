extends SceneTree
# Smoke: the REAL scenes/arena.tscn at the REAL island size (no map_cols override, no tests/support scenes).
# Hand-built test arenas once hid a bug the real arena had. Boot, move, swing, bag, die, respawn.
# run_tests.sh also fails this test if its output has a SCRIPT ERROR.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _until(cond: Callable, timeout: float) -> bool:
	var left := timeout
	while not cond.call():
		await physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second
		if left <= 0.0:
			return false
	return true

func _init() -> void:
	OS.set_environment("BOSSFIGHT_TEST_MAP_CELLS", "")   # real island size, whatever the runner exports
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	var boss: Boss = arena.get_node("Boss")
	boss.passive = true   # quiet arena: this is not a boss test
	await process_frame
	var m: ArenaMap = arena.get_node("ArenaMap")
	var player = arena.get_node("Player")
	var health: Health = player.get_node("Health")
	var dummy = arena.get_node("Dummy")

	_check(m.map_cols == 512 and m.map_rows == 512, "real default island size (%d x %d)" % [m.map_cols, m.map_rows])
	var sr := m.streamer()
	_check(sr.is_loaded(sr.chunk_id(sr.chunk_of(player.global_position))) and boss != null, "the chunk under the player is built and the boss exists")
	_check(m._walker_fits(player.global_position), "player stands on free land")
	_check(m.water_kind_at(player.global_position) == MapGen.WaterKind.NONE, "player is on dry land")
	_check(player.global_position.distance_to(m.home_point()) < 400.0, "player starts at home")

	# Real input: hold move_down (aim fixed: headless mouse is (0,0)).
	player.aim_override = Vector2.RIGHT
	var y0: float = player.global_position.y
	Input.action_press("move_down")
	await _frames(15)
	Input.action_release("move_down")
	_check(player.global_position.y - y0 > 5.0, "move_down moves the player (%.1f px)" % (player.global_position.y - y0))
	await _frames(20)   # let a possible dodge/slide settle

	# Swing the start weapon at the dummy through the real attack action.
	player.set_physics_process(false)   # park the player at the dummy; we drive the swing input below
	player.global_position = dummy.global_position - Vector2(45, 0)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	player.aim_override = Vector2.RIGHT
	var dh: Health = dummy.get_node("Health")
	await _frames(2)
	var hp0: float = dh.hp
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	var w = player.get_node("Loadout").active_weapon()
	await _frames(ceili((w.windup + w.active + w.recovery) * 60.0) + 6)
	_check(dh.hp < hp0, "swing hits the dummy (hp %.0f -> %.0f)" % [hp0, dh.hp])

	# Bag through its real input action.
	var bag = get_first_node_in_group("bag_panel")
	_check(bag != null and not bag.is_open(), "bag starts closed")
	Input.action_press("bag")
	await _frames(3)
	Input.action_release("bag")
	await _frames(2)
	_check(bag.is_open(), "bag key opens the bag")
	Input.action_press("bag")
	await _frames(3)
	Input.action_release("bag")
	await _frames(2)
	_check(not bag.is_open(), "bag key closes the bag")

	# Death and respawn at home.
	var resp: Respawner = player.get_node("Respawner")
	resp.respawn_delay = 0.3
	player.set_physics_process(false)   # park the corpse far from home, so "respawn at home" can really fail
	player.global_position = m.home_point() + Vector2(0, 1500)
	await _frames(2)
	_check(player.global_position.distance_to(m.home_point()) > 1000.0, "parked far from home before dying (%.0f px)" % player.global_position.distance_to(m.home_point()))
	player.set_physics_process(true)
	health.hp = 1.0
	health.take_damage(50.0)
	await _frames(2)
	_check(player.dead, "player dies at 0 hp")
	var back: bool = await _until(func(): return not player.dead, 3.0)
	_check(back and health.hp > 0.0, "player respawns with hp (%.0f)" % health.hp)
	_check(player.global_position.distance_to(m.home_point()) < 400.0, "respawn is at home")

	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
