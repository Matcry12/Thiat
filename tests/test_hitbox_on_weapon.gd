extends SceneTree
# The hit area must be CARRIED BY THE WEAPON (decision 0011) and must travel with
# the blade's swing, not sit still covering the whole cone.
func _init():
	var player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	# Headless mouse reads as (0,0); the player would re-aim every frame and
	# fight the assertions (see .claude/memory/godot-gotchas.md).
	player.set_physics_process(false)
	var wv_early = player.get_node("WeaponVisual")
	wv_early.set_process(false)

	var hitboxes = root.get_tree().get_nodes_in_group("hitbox")
	var hitbox = null
	for hb in hitboxes:
		if player.is_ancestor_of(hb):
			hitbox = hb
	var found = hitbox != null
	print("player hitbox found via group: ", found)
	if not found:
		print("FAIL"); quit(1); return

	# carried by the weapon, not bolted to the player body
	var under_weapon = false
	var n = hitbox.get_parent()
	while n != null:
		if n.name == "WeaponVisual":
			under_weapon = true
		n = n.get_parent()
	print("hitbox is under WeaponVisual: ", under_weapon)

	var wv = player.get_node("WeaponVisual")
	var pivot = player.get_node("WeaponVisual/SwingPivot")

	# The hitbox NODE sits on the pivot, so its POSITION never moves. What moves is
	# the orientation of the shape it carries — check that directly.
	var shape: CollisionPolygon2D = hitbox.get_child(0)

	wv.set_aim_angle(0.0); pivot.rotation = 0.0
	await physics_frame
	var r0: float = shape.global_transform.get_rotation()

	wv.set_aim_angle(PI * 0.5)
	await physics_frame
	var r_aim: float = shape.global_transform.get_rotation()
	var aim_moves: bool = absf(r_aim - r0) > 0.1
	print("hit area follows aim: %s (%.2f -> %.2f rad)" % [aim_moves, r0, r_aim])

	# the SWING turns it too — this is what "it is how we swing" means
	wv.set_aim_angle(0.0); pivot.rotation = 0.0
	await physics_frame
	var r1: float = shape.global_transform.get_rotation()
	pivot.rotation = deg_to_rad(60)
	await physics_frame
	var r_swing: float = shape.global_transform.get_rotation()
	var swing_moves: bool = absf(r_swing - r1) > 0.1
	print("hit area travels with the swing: %s (%.2f -> %.2f rad)" % [swing_moves, r1, r_swing])

	var ok = under_weapon and aim_moves and swing_moves
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
