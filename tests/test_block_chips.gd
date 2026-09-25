extends SceneTree
# Block: once the parry window runs out while F is still held, a parryable
# hit from the front only chips through block_chip x the unguarded amount.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame

	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	player.set_physics_process(false)

	var guard: Guard = player.get_node("Guard")
	var health: Health = player.get_node("Health")
	# Zero out armor/shield so the hp delta IS the post-guard damage, with no
	# other formula terms muddying the comparison.
	health.armor = 0.0
	health.shield = 0.0
	health.shield_max = 0.0

	guard.aim_direction = Vector2.RIGHT   # dummy sits to the right of the player

	guard.try_guard()
	var window_steps := int(ceil(guard.parry_window * 60.0)) + 2
	for i in window_steps:
		await physics_frame
	var in_block: bool = guard.state == Guard.State.BLOCK
	print("guard reached BLOCK after the window: ", in_block)

	var raw := 50.0
	var hp_before_blocked: float = health.hp
	health.take_damage(raw, dummy, true)
	var blocked_taken: float = hp_before_blocked - health.hp

	# Control: the same hit, no guard in the way.
	var hp_before_control: float = health.hp
	guard.state = Guard.State.READY
	health.take_damage(raw, dummy, true)
	var unguarded_taken: float = hp_before_control - health.hp

	var expected := unguarded_taken * guard.block_chip
	var close_enough: bool = absf(blocked_taken - expected) < 0.01
	print("blocked %.2f, unguarded %.2f, expected %.2f -> match: %s" % [blocked_taken, unguarded_taken, expected, close_enough])

	var ok: bool = in_block and close_enough
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
