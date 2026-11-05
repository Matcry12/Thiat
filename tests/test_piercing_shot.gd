extends SceneTree
# Bow equipped, real E press: after the charge one arrow flies through the
# first dummy and the SECOND one behind it. Each is damaged exactly once by the
# skill's damage.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame
	var player = arena.get_node("Player")
	player.get_node("Inventory").give_dev_kit()   # W4: the start kit is only a wooden sword (decision 0031)
	player.aim_override = Vector2.RIGHT
	var loadout: Loadout = player.get_node("Loadout")
	var slot: SkillSlot = player.get_node("SkillSlot")
	var dummy1 = arena.get_node("Dummy")
	var dummy2 = load("res://scenes/dummy.tscn").instantiate()
	arena.add_child(dummy2)
	dummy2.global_position = dummy1.global_position + Vector2(110, 0)
	var h1: Health = dummy1.get_node("Health")
	var h2: Health = dummy2.get_node("Health")
	await _frames(5)

	loadout.select(loadout.weapon_slot(1))
	var bow: WeaponData = loadout.active_weapon()
	var shot: PiercingShot = slot.skill_for(bow)

	player.global_position = dummy1.global_position - Vector2(200, 0)
	player.aim_override = dummy1.global_position - player.global_position
	await _frames(3)
	var b1: float = h1.hp
	var b2: float = h2.hp
	await _tap("skill")
	var charging: bool = slot.is_active()
	# Charging: slower and cannot attack.
	var scale_ok: bool = is_equal_approx(slot.move_scale(), shot.charge_move_scale)
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	var attack_refused: bool = player.get_node("WeaponHolder").phase == WeaponHolder.Phase.IDLE
	await _wait_until(func(): return h2.hp < b2 and h1.hp < b1, 4.0)
	await _frames(20)   # a double hit would land in these frames

	var want: float = maxf(1.0, shot.damage - h1.armor * 0.5)
	var d1: float = b1 - h1.hp
	var d2: float = b2 - h2.hp
	var both: bool = is_equal_approx(d1, want) and is_equal_approx(d2, want)
	print("charging: %s, slowed: %s | dummy1 took %.1f, dummy2 took %.1f (want %.1f each, once): %s" % [charging, scale_ok, d1, d2, want, both])
	await _wait_until(func(): return get_nodes_in_group("projectile").is_empty(), 3.0)
	var arrow_gone: bool = get_nodes_in_group("projectile").is_empty()
	print("arrow gone after its range/wall: %s" % arrow_gone)
	print("attack input refused while charging: %s" % attack_refused)
	var ok := charging and scale_ok and attack_refused and arrow_gone and both
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)

func _wait_until(cond: Callable, timeout: float) -> void:
	var left := timeout
	while not cond.call() and left > 0.0:
		await physics_frame
		left -= (1.0 / Engine.physics_ticks_per_second)
