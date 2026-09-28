extends SceneTree
# An unparryable (purple) attack goes through full damage whether the player
# is PARRYing or BLOCKing -- it breaks guard entirely, by design.
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

	# --- PARRY open, unparryable attack ---
	guard.try_guard()
	var hp_before_parry: float = health.hp
	health.take_damage(40.0, dummy, false)
	var taken_parry: float = hp_before_parry - health.hp
	var full_during_parry: bool = taken_parry >= 39.9
	print("damage during PARRY vs unparryable: %.2f (want ~40)" % taken_parry)

	health.hp = health.max_hp   # reset for a clean second measurement

	# --- keep holding F until it becomes BLOCK, unparryable attack again ---
	var window_steps := int(ceil(guard.parry_window * 60.0)) + 2
	for i in window_steps:
		await physics_frame
	var in_block: bool = guard.state == Guard.State.BLOCK
	print("reached BLOCK: ", in_block)

	var hp_before_block: float = health.hp
	var tank_before_block: float = guard.tank
	health.take_damage(40.0, dummy, false)
	var taken_block: float = hp_before_block - health.hp
	var full_during_block: bool = taken_block >= 39.9
	print("damage during BLOCK vs unparryable: %.2f (want ~40)" % taken_block)

	var shield_broke: bool = guard.tank == 0.0 and guard.state == Guard.State.BROKEN
	print("shield broke: ", shield_broke, " tank before=", tank_before_block, " after=", guard.tank, " state=", Guard.State.keys()[guard.state])

	var ok: bool = full_during_parry and in_block and full_during_block and shield_broke
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
