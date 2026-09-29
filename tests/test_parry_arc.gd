extends SceneTree
# Regression guard for the signed-angle bug (godot-gotchas.md): a hit from
# directly BEHIND the player must NOT be parryable even with the window open,
# or an absf()-less arc check would silently let it through.
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

	guard.parry_arc_degrees = 90.0
	guard.aim_direction = Vector2.LEFT   # dummy sits to the right -> attack comes from behind

	guard.try_guard()
	var hp_before: float = health.hp
	health.take_damage(50.0, dummy, true)
	var taken: float = hp_before - health.hp
	var took_full: bool = taken >= 49.9

	print("damage taken from behind while parrying: %.2f (want ~50)" % taken)
	print("PASS" if took_full else "FAIL")
	quit(0 if took_full else 1)
