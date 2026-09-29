extends SceneTree
# Real E press through player.gd with the sword equipped:
#   1. a lunge into open space moves the player ~distance
#   2. a lunge through the dummy damages it EXACTLY once, with the skill's damage
#   3. the sword's skill cooldown starts; a second E during it does nothing
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame
	var player = arena.get_node("Player")
	player.aim_override = Vector2.LEFT
	var loadout: Loadout = player.get_node("Loadout")
	var slot: SkillSlot = player.get_node("SkillSlot")
	var dummy = arena.get_node("Dummy")
	var dh: Health = dummy.get_node("Health")
	var sword: WeaponData = loadout.active_weapon()
	var lunge: LungeSlash = slot.skill_for(sword)
	await _frames(5)

	var ok := true
	# 1. Open space to the left (wall is far): moves about `distance`.
	var start: Vector2 = player.global_position
	await _tap("skill")
	var started: bool = slot.is_active() and slot.moves_body()
	await _wait_until(func(): return not slot.is_active(), 2.0)
	await _frames(3)
	var moved: float = start.distance_to(player.global_position)
	var dist_ok: bool = started and absf(moved - lunge.distance) < 12.0
	print("lunge started: %s | moved %.1f px (want ~%.0f): %s" % [started, moved, lunge.distance, dist_ok])
	ok = ok and dist_ok
	slot.reset_cooldowns()

	# 2. Through the dummy: exactly one hit of the skill's damage.
	player.global_position = dummy.global_position - Vector2(100, 0)
	player.aim_override = Vector2.RIGHT
	await _frames(3)
	var hp_before: float = dh.hp
	await _tap("skill")
	await _wait_until(func(): return not slot.is_active(), 2.0)
	await _frames(10)   # a double hit would show up in the frames after
	var dealt: float = hp_before - dh.hp
	var want: float = maxf(1.0, lunge.damage - dh.armor * 0.5)
	var dmg_ok: bool = is_equal_approx(dealt, want)
	print("lunge dealt %.1f (want exactly %.1f, one hit): %s" % [dealt, want, dmg_ok])
	ok = ok and dmg_ok

	# 3. Cooldown started; a second E does nothing.
	var cd: float = slot.cooldown_left(sword)
	var cd_ok: bool = cd > 0.0 and cd <= sword.skill_cooldown
	var pos_before: Vector2 = player.global_position
	player.global_position = dummy.global_position - Vector2(100, 0)
	await _tap("skill")
	await _frames(3)
	var second_ignored: bool = not slot.is_active()
	print("cooldown left %.2fs: %s | second E ignored: %s" % [cd, cd_ok, second_ignored])
	ok = ok and cd_ok and second_ignored

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
