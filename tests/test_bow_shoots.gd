extends SceneTree
# Swap to the bow, aim at the dummy, attack: an arrow spawns at the Muzzle,
# travels, the dummy takes exactly the bow's damage, and the arrow is gone
# after the hit. An arrow fired at a wall frees without damage.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame
	var player = arena.get_node("Player")
	player.get_node("Inventory").give_dev_kit()   # W4: the start kit is only a wooden sword (decision 0031)
	player.aim_override = Vector2.RIGHT
	var loadout: Loadout = player.get_node("Loadout")
	var weapon_holder: WeaponHolder = player.get_node("WeaponHolder")
	var dummy = arena.get_node("Dummy")
	var dummy_health: Health = dummy.get_node("Health")

	await _frames(5)   # let one-off startup delta spikes settle (test_guard_pose.gd does the same)

	loadout.swap_cast = 0.05   # shorten so the test does not sit waiting
	loadout.try_swap(1)
	await _wait_until(func(): return not loadout.is_casting(), 2.0)
	var bow: WeaponData = loadout.active_weapon()
	var equipped: bool = weapon_holder.weapon == bow
	print("bow equipped: %s" % equipped)

	# Aim the player at the dummy, close enough that a 700 px/s arrow with
	# 520 range travelling for a handful of physics frames will reach it.
	var to_dummy: Vector2 = dummy.global_position - player.global_position
	player.aim_override = to_dummy

	var before: float = dummy_health.hp
	weapon_holder.try_attack()
	await _wait_seconds(bow.windup + bow.active + 0.02)   # attack fires mid-ACTIVE

	var arrows := get_tree_arrows()
	print("arrows in flight right after fire: %d" % arrows.size())

	var hit := false
	var left := 3.0
	while left > 0.0:
		await physics_frame
		left -= (1.0 / Engine.physics_ticks_per_second)
		if dummy_health.hp < before:
			hit = true
			break
	await _frames(3)   # let the arrow queue_free actually leave the tree

	var dealt: float = before - dummy_health.hp
	var expected: float = maxf(1.0, bow.damage - dummy_health.armor * 0.5)
	var damage_ok: bool = hit and is_equal_approx(dealt, expected)
	print("dummy hp before %.1f -> after %.1f (dealt %.1f, want %.1f): %s" % [before, dummy_health.hp, dealt, expected, damage_ok])

	var arrow_gone: bool = get_tree_arrows().is_empty()
	print("arrow gone after the hit: %s" % arrow_gone)

	# A second arrow, aimed straight up at the arena's top wall (world layer 1,
	# no dummy in that direction), must free itself with no damage anywhere.
	player.aim_override = Vector2.UP
	weapon_holder.cancel()
	await _frames(2)
	var before2: float = dummy_health.hp
	weapon_holder.try_attack()
	await _wait_seconds(bow.windup + bow.active + 0.02)
	var left2 := 3.0
	while not get_tree_arrows().is_empty() and left2 > 0.0:
		await physics_frame
		left2 -= (1.0 / Engine.physics_ticks_per_second)
	var no_damage: bool = is_equal_approx(dummy_health.hp, before2)
	print("shot at empty space: dummy untouched %s, arrow gone %s" % [no_damage, get_tree_arrows().is_empty()])

	# Point-blank: bodies touching. The player's CENTRE stays outside the hurtbox
	# (radius 13), but the MUZZLE (28px out) ends up inside it, so the
	# Muzzle spawns the arrow already past it. This is exactly the bug fixed
	# in projectile.gd (the first raycast segment must start at the shooter,
	# not the spawn point) — must fail before that fix, pass after.
	player.global_position = dummy.global_position - Vector2(20, 0)
	player.aim_override = Vector2.RIGHT
	weapon_holder.cancel()
	await _frames(2)
	dummy_health.hp = dummy_health.max_hp
	var before3: float = dummy_health.hp
	weapon_holder.try_attack()
	await _wait_seconds(bow.windup + bow.active + 0.02)
	var hit3 := false
	var left3 := 1.0   # point-blank lands almost immediately if it lands at all
	while left3 > 0.0:
		await physics_frame
		left3 -= (1.0 / Engine.physics_ticks_per_second)
		if dummy_health.hp < before3:
			hit3 = true
			break
	print("point-blank shot (20px away): dummy hit: %s" % hit3)

	# Aim-left (mirrored): dummy to the LEFT of the player, aiming left. The
	# mirrored Muzzle/arm must still fire correctly and land.
	player.global_position = dummy.global_position + Vector2(200, 0)
	player.aim_override = Vector2.LEFT
	weapon_holder.cancel()
	await _frames(2)
	dummy_health.hp = dummy_health.max_hp
	var before4: float = dummy_health.hp
	weapon_holder.try_attack()
	await _wait_seconds(bow.windup + bow.active + 0.02)
	var hit4 := false
	var left4 := 3.0
	while left4 > 0.0:
		await physics_frame
		left4 -= (1.0 / Engine.physics_ticks_per_second)
		if dummy_health.hp < before4:
			hit4 = true
			break
	print("aim-left mirrored shot: dummy hit: %s" % hit4)

	var ok := equipped and arrows.size() >= 1 and damage_ok and arrow_gone and no_damage and hit3 and hit4
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func get_tree_arrows() -> Array:
	return get_nodes_in_group("projectile")   # self IS the SceneTree here

func _frames(n: int) -> void:
	for i in n:
		await process_frame

## Deterministic real-time wait, in PHYSICS ticks rather than create_timer():
## a timer fires on idle frames, whose first delta can spike right after
## script startup and skip straight past a short window (bit us here — the
## loadout's swap-cast finished a whole physics tick before a 0.10s timer
## ever fired). physics_frame does not have that problem.
func _wait_seconds(s: float) -> void:
	var ticks: int = ceili(s * Engine.physics_ticks_per_second) + 1
	for i in ticks:
		await physics_frame

func _wait_until(cond: Callable, timeout: float) -> void:
	var left := timeout
	while not cond.call() and left > 0.0:
		await physics_frame
		left -= (1.0 / Engine.physics_ticks_per_second)
