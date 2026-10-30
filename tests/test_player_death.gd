extends SceneTree
const StubBrain = preload("res://tests/support/stub_brain.gd")
# Player hp -> 0: input stops (no move, no attack) and NO end screen shows (W6: the Respawner
# handles death, see test_death_respawn.gd). Boss death shows "Boss defeated"; R asks for a retry.

func _init():
	OS.set_environment("BOSSFIGHT_TEST_MAP_CELLS", "192")   # small island: this test does not need the full map
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	var health: Health = player.get_node("Health")
	var end: EndScreen = arena.get_node("EndScreen")
	player.aim_override = Vector2.RIGHT

	# Control: alive, the same input moves the player.
	Input.action_press("move_down")
	await _frames(15)
	Input.action_release("move_down")
	var moved_alive: float = player.global_position.y - 321.0
	print("alive: moved %.1f px down" % moved_alive)
	var shown_before: bool = end.is_showing()

	health.hp = 1.0
	health.take_damage(50.0)
	await _frames(2)
	var y0: float = player.global_position.y
	Input.action_press("move_down")
	Input.action_press("attack")
	await _frames(15)
	Input.action_release("move_down")
	Input.action_release("attack")
	var frozen: bool = absf(player.global_position.y - y0) < 0.01
	var no_swing: bool = player.get_node("WeaponHolder").phase == WeaponHolder.Phase.IDLE
	var was_dead: bool = player.dead
	var label_ok: bool = not end.is_showing()
	print("dead: flag %s, frozen %s, no swing %s, end screen showing %s" % [player.dead, frozen, no_swing, end.is_showing()])

	# R reloads the CURRENT scene. Make this arena the current scene (a headless
	# test adds it straight under root), press R, and expect a fresh live arena.
	current_scene = arena
	var old_id: int = arena.get_instance_id()
	var retried := [false]
	end.retry_requested.connect(func(): retried[0] = true)
	arena.get_node("Boss/Health").take_damage(100000.0)   # the end screen (and R) only exist after the boss dies
	await _frames(2)
	Input.action_press("restart")
	await _frames(4)
	Input.action_release("restart")
	await _until(func(): return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.has_node("Player"), 3.0)
	var fresh = current_scene
	var reloaded: bool = fresh != null and fresh.get_instance_id() != old_id
	var fresh_ok := false
	if reloaded:
		await process_frame
		var fp = fresh.get_node("Player")
		fresh_ok = not fp.dead and fp.get_node("Health").hp == fp.get_node("Health").max_hp and not fresh.get_node("EndScreen").is_showing()
	print("R pressed -> retry requested: %s, fresh arena with a live player: %s" % [retried[0], fresh_ok])

	# Attacks stop when the player dies: a slam in its warning is dropped.
	var arena3 = fresh
	var boss3: Boss = arena3.get_node("Boss")
	# The reloaded boss runs its scripted brain from the first tick and a loaded
	# machine may run several ticks per frame: silence it, wait until it has
	# really stopped (physics ticks, not frames), clear anything it fired.
	boss3.passive = true
	await _until(func(): return boss3.mode == Boss.Mode.IDLE and boss3.current_action == "", 3.0)
	for b in get_nodes_in_group("projectile"):
		b.queue_free()
	await _frames(3)
	boss3.set_brain(StubBrain.new())
	boss3.passive = false
	var p3 = arena3.get_node("Player")
	p3.get_node("Respawner").respawn_delay = 999.0   # this part is about a corpse, not a respawn
	var h3: Health = p3.get_node("Health")
	p3.set_physics_process(false)
	var slam3: BossAttack = boss3.get_attack("slam")
	boss3.force_next("slam")
	await _until(func(): return slam3.phase == BossAttack.Phase.TELEGRAPH, 3.0)
	h3.hp = 1.0
	h3.take_damage(50.0)
	var after := [0]
	h3.damaged.connect(func(_a: float): after[0] += 1)
	await _frames(150)   # far longer than the warning + impact
	var stopped: bool = slam3.phase == BossAttack.Phase.IDLE and boss3.current_action == "" and after[0] == 0
	print("player dead mid-warning: slam dropped %s, hits after death %d" % [slam3.phase == BossAttack.Phase.IDLE, after[0]])

	# Boss death, in another fresh arena.
	arena3.queue_free()
	await process_frame
	var arena2 = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena2)
	arena2.get_node("Boss").passive = true
	await process_frame
	arena2.get_node("Boss/Health").take_damage(100000.0)
	await _frames(2)
	var end2: EndScreen = arena2.get_node("EndScreen")
	var win_ok: bool = end2.is_showing() and end2.label_text().begins_with("Boss defeated")
	print("boss dead: label '%s'" % end2.label_text())

	var ok: bool = moved_alive > 5.0 and not shown_before and was_dead and frozen and no_swing and label_ok and retried[0] and reloaded and fresh_ok and stopped and win_ok
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

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
