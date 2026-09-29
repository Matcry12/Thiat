extends SceneTree
# Block: a full tank absorbs a parryable hit from the front entirely. Player
# takes 0, tank drops by exactly the damage.
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

	guard.aim_direction = Vector2.RIGHT   # dummy sits to the right of the player

	guard.try_guard()
	var window_steps := int(ceil(guard.parry_window * 60.0)) + 2
	for i in window_steps:
		await physics_frame
	var in_block: bool = guard.state == Guard.State.BLOCK
	print("guard reached BLOCK after the window: ", in_block)

	var raw := 20.0
	var tank_before: float = guard.tank
	var hp_before: float = health.hp
	health.take_damage(raw, dummy, true)

	var player_took_zero: bool = health.hp == hp_before
	var tank_dropped_exactly: bool = absf((tank_before - guard.tank) - raw) < 0.01
	print("player hp unchanged: ", player_took_zero, " hp=", health.hp)
	print("tank dropped by raw damage: ", tank_dropped_exactly, " before=", tank_before, " after=", guard.tank)

	var ok: bool = in_block and player_took_zero and tank_dropped_exactly
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
