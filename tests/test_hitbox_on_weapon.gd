extends SceneTree
# Headless: proves decision 0011 — the Hitbox is parented under the blade and
# inherits its transform, and it does nothing while the weapon is idle.
func _init():
	var player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	# Player's own _physics_process recomputes aim from the headless (0,0)
	# mouse every tick and would stomp the rotation we set by hand below.
	player.set_physics_process(false)

	var weapon_visual: Node2D = player.get_node("WeaponVisual")
	var blade: Node = player.get_node("WeaponVisual/Blade")
	var hitbox: Node2D = player.get_node("WeaponVisual/Blade/Hitbox")

	# 1. Parent chain includes Blade.
	var parented_under_blade: bool = hitbox.get_parent() == blade
	print("hitbox parent is Blade: ", parented_under_blade)

	# 2. Rotating WeaponVisual moves the hitbox's global_position (proves it
	# inherits the transform instead of being computed independently).
	weapon_visual.rotation = 0.0
	await physics_frame
	var pos_a: Vector2 = hitbox.global_position
	weapon_visual.rotation = deg_to_rad(90.0)
	await physics_frame
	var pos_b: Vector2 = hitbox.global_position
	var moved_with_rotation: bool = not pos_a.is_equal_approx(pos_b)
	print("hitbox moves when WeaponVisual rotates: ", moved_with_rotation, " (", pos_a, " -> ", pos_b, ")")

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

	var ok: bool = parented_under_blade and moved_with_rotation and no_damage_while_idle
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
