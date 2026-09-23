extends SceneTree
# End-to-end: stand next to the dummy, aim at it, swing -> hp must drop exactly once.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	var holder = arena.get_node("Player/WeaponHolder")
	var hitbox = arena.get_node("Player/Hitbox")
	var health = dummy.get_node("Health")

	player.global_position = dummy.global_position - Vector2(50, 0)  # 50px away, within 76 reach
	player.set_physics_process(false)  # stop it re-aiming at the (0,0) headless mouse
	hitbox.aim_direction = Vector2.RIGHT                              # facing the dummy
	await physics_frame
	var hp_before: float = health.hp

	holder.try_attack()
	for i in 40:                                                      # ~0.66s covers all phases
		await physics_frame

	var dealt: float = hp_before - health.hp
	var expected := 20.0                                              # 30 dmg - 20 armor*0.5
	print("hp %.0f -> %.0f  (dealt %.1f, expected %.1f once)" % [hp_before, health.hp, dealt, expected])
	print("phase back to idle: ", holder.phase == 0)
	var ok: bool = is_equal_approx(dealt, expected) and holder.phase == 0
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
