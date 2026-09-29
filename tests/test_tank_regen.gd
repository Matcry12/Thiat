extends SceneTree
# Tank regen: after draining the tank and letting go of guard, waiting past
# tank_regen_delay grows it back and fires tank_changed.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame

	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	player.set_physics_process(false)

	var guard: Guard = player.get_node("Guard")
	var health: Health = player.get_node("Health")
	health.armor = 0.0
	health.shield = 0.0
	health.shield_max = 0.0

	guard.tank_regen_delay = 0.2   # keep the test short
	guard.tank_regen_rate = 20.0

	guard.aim_direction = Vector2.RIGHT
	guard.try_guard()
	var window_steps := int(ceil(guard.parry_window * 60.0)) + 2
	for i in window_steps:
		await physics_frame

	health.take_damage(20.0, dummy, true)
	var tank_after_drain: float = guard.tank
	print("tank drained: ", tank_after_drain, " < ", guard.tank_max)

	guard.release()   # stop guarding so regen can run

	# Array, not a bare int: GDScript lambdas capture outer locals BY VALUE,
	# so a plain counter mutated inside the lambda wouldn't be seen out here.
	var changed_events := [0]
	guard.tank_changed.connect(func(_c: float, _m: float): changed_events[0] += 1)

	var wait_steps := int((guard.tank_regen_delay + 0.5) * 60.0)
	for i in wait_steps:
		await physics_frame

	var grew: bool = guard.tank > tank_after_drain
	var fired: bool = changed_events[0] > 0
	print("tank grew back: ", grew, " before=", tank_after_drain, " after=", guard.tank)
	print("tank_changed fired during regen: ", fired, " count=", changed_events[0])

	var ok: bool = grew and fired
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
