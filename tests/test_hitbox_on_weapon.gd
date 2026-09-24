extends SceneTree
# Headless: proves decision 0011 (amended) — the Hitbox is parented under
# WeaponVisual (the hand pivot, not the Blade's own swing animation) and
# inherits WeaponVisual's transform, and it does nothing while the weapon is
# idle.
func _init():
	var player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	# Player's own _physics_process recomputes aim from the headless (0,0)
	# mouse every tick and would stomp the rotation we set by hand below.
	player.set_physics_process(false)

	var weapon_visual: Node2D = player.get_node("WeaponVisual")
	var hitbox: Node2D = player.get_node("WeaponVisual/Hitbox")

	# 1. Parent chain includes WeaponVisual (the hand pivot), per the amendment.
	var parented_under_weapon_visual: bool = hitbox.get_parent() == weapon_visual
	print("hitbox parent is WeaponVisual: ", parented_under_weapon_visual)

	# 2. Rotating WeaponVisual moves the sector's world-space extent (proves it
	# inherits the transform instead of being computed independently). The
	# Hitbox node itself sits AT the hand pivot (WeaponVisual's origin), so its
	# own global_position does not move on a pure rotation — what has to move
	# is the generated shape, so check a point on the actual sector polygon.
	var sector: CollisionPolygon2D = hitbox.get_node("SectorShape")
	weapon_visual.rotation = 0.0
	await physics_frame
	var tip_a: Vector2 = sector.global_transform * sector.polygon[sector.polygon.size() / 2]
	weapon_visual.rotation = deg_to_rad(90.0)
	await physics_frame
	var tip_b: Vector2 = sector.global_transform * sector.polygon[sector.polygon.size() / 2]
	var moved_with_rotation: bool = not tip_a.is_equal_approx(tip_b)
	print("hitbox shape moves when WeaponVisual rotates: ", moved_with_rotation, " (", tip_a, " -> ", tip_b, ")")

	# 3. No damage while idle: the shape may still geometrically overlap a
	# target, but Hitbox only checks overlaps while `start_swing()` was called.
	var holder: WeaponHolder = player.get_node("WeaponHolder")
	print("weapon idle at start: ", holder.phase == 0)
	var health: Health = load("res://scenes/dummy.tscn").instantiate().get_node("Health")
	root.add_child(health.get_parent())
	health.get_parent().global_position = hitbox.global_position
	var hp_before: float = health.hp
	for i in 10:
		await physics_frame
	var no_damage_while_idle: bool = health.hp == hp_before
	print("no damage dealt while idle: ", no_damage_while_idle)

	var ok: bool = parented_under_weapon_visual and moved_with_rotation and no_damage_while_idle
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
