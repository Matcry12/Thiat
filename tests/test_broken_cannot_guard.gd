extends SceneTree
# Broken punish: while BROKEN, try_guard() fails and a hit goes through at
# full damage (no shield left to raise).
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

	guard.state = Guard.State.BROKEN
	guard.tank = 0.0

	var opened: bool = guard.try_guard()
	print("try_guard() during BROKEN: ", opened, " (want false)")

	var hp_before: float = health.hp
	health.take_damage(30.0, dummy, true)
	var taken: float = hp_before - health.hp
	var took_full: bool = taken >= 29.9
	print("damage taken while BROKEN: %.2f (want ~30)" % taken)

	var ok: bool = not opened and took_full
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
