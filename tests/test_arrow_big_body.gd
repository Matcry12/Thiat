extends SceneTree
# A target whose BODY is bigger than its hurtbox: the ray meets the body first.
# It must still count as a hit on that target (not a wall) for a normal arrow,
# and the piercing shot must hit it AND the one behind it.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame
	var player = arena.get_node("Player")
	var loadout: Loadout = player.get_node("Loadout")
	var slot: SkillSlot = player.get_node("SkillSlot")
	var holder: WeaponHolder = player.get_node("WeaponHolder")
	var d1 = arena.get_node("Dummy")
	var d2 = load("res://scenes/dummy.tscn").instantiate()
	arena.add_child(d2)
	d2.global_position = d1.global_position + Vector2(110, 0)
	d1.set_physics_process(false)   # no home return: the test places the dummies itself
	d2.set_physics_process(false)
	# Body radius 20 > hurtbox radius 13 (the shape resource is shared by both).
	(d1.get_node("CollisionShape2D").shape as CircleShape2D).radius = 20.0
	var h1: Health = d1.get_node("Health")
	var h2: Health = d2.get_node("Health")
	await _frames(5)
	loadout.swap_cast = 0.05
	loadout.try_swap(1)
	await _wait_until(func(): return not loadout.is_casting(), 2.0)
	var bow: WeaponData = loadout.active_weapon()
	player.global_position = d1.global_position - Vector2(200, 0)
	player.aim_override = d1.global_position - player.global_position
	await _frames(3)

	var b1: float = h1.hp
	holder.try_attack()
	await _wait_until(func(): return h1.hp < b1, 3.0)
	var normal_ok: bool = is_equal_approx(b1 - h1.hp, maxf(1.0, bow.damage - h1.armor * 0.5))
	print("normal arrow hit the big-bodied dummy: %s" % normal_ok)
	await _wait_until(func(): return get_nodes_in_group("projectile").is_empty(), 3.0)

	await _wait_until(func(): return holder.phase == WeaponHolder.Phase.IDLE, 3.0)   # E is refused mid-swing
	b1 = h1.hp
	var b2: float = h2.hp
	var shot: PiercingShot = slot.skill_for(bow)
	Input.action_press("skill")
	await physics_frame
	await physics_frame
	Input.action_release("skill")
	await _wait_until(func(): return h2.hp < b2 and h1.hp < b1, 4.0)
	await _frames(15)
	var want: float = maxf(1.0, shot.damage - h1.armor * 0.5)
	var pierce_ok: bool = is_equal_approx(b1 - h1.hp, want) and is_equal_approx(b2 - h2.hp, want)
	print("piercing shot hit both, once each: %s" % pierce_ok)
	var ok := normal_ok and pierce_ok
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _wait_until(cond: Callable, timeout: float) -> void:
	var left := timeout
	while not cond.call() and left > 0.0:
		await physics_frame
		left -= (1.0 / Engine.physics_ticks_per_second)
