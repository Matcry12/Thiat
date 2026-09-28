extends SceneTree
# Block overflow: a hit bigger than the remaining tank drains it to 0, sends
# only the leftover through to the player, fires `broke`, and moves the
# state to BROKEN.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame

	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	player.set_physics_process(false)

	var guard: Guard = player.get_node("Guard")
	var health: Health = player.get_node("Health")
	health.armor = 0.0
	health.shield = 0.0
	health.shield_max = 0.0

	guard.aim_direction = Vector2.RIGHT   # dummy sits to the right of the player

	guard.try_guard()
	var window_steps := int(ceil(guard.parry_window * 60.0)) + 2
	for i in window_steps:
		await physics_frame

	guard.tank = 10.0   # less than the incoming hit
	# Array, not a bare bool: GDScript lambdas capture outer locals BY VALUE,
	# so a plain `var broke_fired := false` mutated inside the lambda would
	# never be seen out here. The array reference is what's captured.
	var broke_fired := [false]
	guard.broke.connect(func(): broke_fired[0] = true)

	var raw := 35.0
	var hp_before: float = health.hp
	health.take_damage(raw, dummy, true)
	var taken: float = hp_before - health.hp

	var leftover_matches: bool = absf(taken - 25.0) < 0.01
	var tank_zeroed: bool = guard.tank == 0.0
	var became_broken: bool = guard.state == Guard.State.BROKEN
	print("leftover damage taken: %.2f (want 25.0), match: %s" % [taken, leftover_matches])
	print("tank ended at 0: ", tank_zeroed, " tank=", guard.tank)
	print("broke signal fired: ", broke_fired[0])
	print("state is BROKEN: ", became_broken)

	var ok: bool = leftover_matches and tank_zeroed and broke_fired[0] and became_broken
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
