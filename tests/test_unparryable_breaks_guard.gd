extends SceneTree
# An unparryable (purple) attack does full damage AND breaks the guard, whether
# it lands in the tap (PARRY) window or while holding (BLOCK). Purple = dodge;
# any F is wrong, and neither timing may be safer than the other.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame

	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	player.set_physics_process(false)
	dummy.get_node("Attacker").set_physics_process(false)   # no stray hits

	var guard: Guard = player.get_node("Guard")
	var health: Health = player.get_node("Health")
	health.armor = 0.0
	health.shield = 0.0
	health.shield_max = 0.0
	guard.aim_direction = Vector2.RIGHT   # dummy sits to the right of the player

	# --- tap window (PARRY), purple ---
	guard.try_guard()
	var hp0: float = health.hp
	health.take_damage(40.0, dummy, false)
	var parry_full: bool = hp0 - health.hp >= 39.9
	var parry_broke: bool = guard.tank == 0.0 and guard.state == Guard.State.BROKEN
	print("PARRY vs purple: damage %.2f (want ~40), guard broken: %s" % [hp0 - health.hp, parry_broke])
	guard.release()

	# Recover, then refill the bar so BLOCK starts fresh. Wait for the STATE,
	# never a wall-clock timer: the guard counts physics steps, which can lag
	# behind the clock on a busy machine. A timer here made this test flaky
	# (1 in ~4 runs the guard was still BROKEN and the F press was refused).
	var recovered: bool = await _until(func(): return guard.state == Guard.State.READY, guard.break_recovery + 2.0)
	guard.tank = guard.tank_max
	health.hp = health.max_hp

	# --- held (BLOCK), purple ---
	var pressed: bool = guard.try_guard()
	var in_block: bool = await _until(func(): return guard.state == Guard.State.BLOCK, guard.parry_window + 2.0)
	print("recovered: %s, F accepted: %s" % [recovered, pressed])
	print("reached BLOCK: ", in_block)
	var hp1: float = health.hp
	health.take_damage(40.0, dummy, false)
	var block_full: bool = hp1 - health.hp >= 39.9
	var block_broke: bool = guard.tank == 0.0 and guard.state == Guard.State.BROKEN
	print("BLOCK vs purple: damage %.2f (want ~40), guard broken: %s" % [hp1 - health.hp, block_broke])

	var ok: bool = parry_full and parry_broke and recovered and pressed and in_block and block_full and block_broke
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

## Steps physics until `cond` is true or `timeout` seconds of GAME time pass.
func _until(cond: Callable, timeout: float) -> bool:
	var left := timeout
	while not cond.call():
		await physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second
		if left <= 0.0:
			return false
	return true
