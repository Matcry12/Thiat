extends SceneTree
# Real path: WeaponHolder fires the bow, the Projectile hits the dummy, SoundBoard plays bow.hit.
func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	player.get_node("Inventory").give_dev_kit()
	var loadout: Loadout = player.get_node("Loadout")
	var holder: WeaponHolder = player.get_node("WeaponHolder")
	var dummy = arena.get_node("Dummy")
	for i in 5:
		await physics_frame
	for n in get_nodes_in_group("map_obstacle"):
		if n.global_position.distance_to(dummy.global_position) < 500.0:
			n.free()
	loadout.select(loadout.weapon_slot(1))
	player.aim_override = dummy.global_position - player.global_position
	var board: SoundBoard = (arena.get_node("HitFx") as HitFx).sound
	var hp: float = dummy.get_node("Health").hp
	holder.try_attack()
	var left := 4.0
	while left > 0.0 and dummy.get_node("Health").hp >= hp:
		await physics_frame
		left -= 1.0 / 60.0
	var ok: bool = dummy.get_node("Health").hp < hp and board.last_event == &"bow.hit"
	print(("ok   " if ok else "FAIL ") + "real bow shot: last sound %s" % board.last_event)
	quit(0 if ok else 1)
