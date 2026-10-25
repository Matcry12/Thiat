extends SceneTree
# W6 (decision 0039): die -> boss resets, materials halve into a DeathBag at the death spot (weapons stay),
# the bag is not self-collected while dead, respawn at home with full hp after the delay, walking over
# the bag gives it back (what does not fit stays), a death with no materials leaves no bag.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _until(cond: Callable, timeout: float) -> bool:
	var left := timeout
	while not cond.call():
		await physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second
		if left <= 0.0:
			return false
	return true

func _init() -> void:
	var arena = await World.make(self)
	var player: Node2D = arena.get_node("Player")
	var map: ArenaMap = arena.get_node("ArenaMap")
	var inv: Inventory = player.get_node("Inventory")
	var health: Health = player.get_node("Health")
	var rs: Respawner = player.get_node("Respawner")
	var boss: Boss = arena.get_node("Boss")
	rs.respawn_delay = 0.5
	var home := map.home_point()
	inv.give_dev_kit()
	inv.add(World.item("wood"), 25)
	inv.add(World.item("stone"), 1)
	inv.add(World.item("copper_bar"), 10)
	var weapons_before := inv.count(&"sword") + inv.count(&"bow") + inv.count(&"stone_axe") + inv.count(&"stone_pickaxe")

	# Boss mid-fight: engaged, phase 2, hurt, away from home.
	boss.passive = true
	boss.aggro = Boss.Aggro.ENGAGED
	boss.health.hp = boss.health.max_hp * 0.3
	boss.phase = 2
	boss.global_position = boss.home + Vector2(150, 0)

	# --- death A ---
	player.global_position = home + Vector2(300, 0)
	var spot: Vector2 = player.global_position
	rs.kill()
	await physics_frame
	_check(player.dead and rs.deaths == 1 and rs.is_waiting(), "died: dead flag, deaths = 1, respawn timer running")
	var bags := get_nodes_in_group("death_bag")
	_check(bags.size() == 1 and bags[0].global_position.distance_to(spot) < 1.0, "one bag at the death spot")
	var bag: DeathBag = bags[0]
	_check(inv.count(&"wood") == 13 and inv.count(&"stone") == 1 and inv.count(&"copper_bar") == 5, "wood 25 -> 13 kept, stone 1 -> 1 (floor), bar 10 -> 5 kept")
	_check(bag.total() == 12 + 0 + 5, "bag holds 12 wood + 5 bar (%d)" % bag.total())
	_check(inv.count(&"sword") + inv.count(&"bow") + inv.count(&"stone_axe") + inv.count(&"stone_pickaxe") == weapons_before, "weapons and tools kept")
	_check(boss.health.hp == boss.health.max_hp and boss.phase == 1 and boss.aggro == Boss.Aggro.RETURNING, "boss reset: full hp, phase 1, walking home")
	await _until(func(): return boss.aggro == Boss.Aggro.IDLE, 3.0)
	_check(boss.aggro == Boss.Aggro.IDLE and boss.global_position.distance_to(boss.home) < 3.0 and boss.outside_time == 0.0 and not boss.health.invulnerable, "boss back at home, idle, vulnerable")
	_check(is_instance_valid(bag) and bag.total() == 17, "bag not self-collected while dead")

	# --- respawn ---
	await _until(func(): return not player.dead, 3.0)
	_check(not player.dead and not rs.is_waiting(), "woke up after the delay")
	_check(player.global_position.distance_to(home) < 1.0, "at the home point")
	_check(health.hp == health.max_hp, "full hp")

	# --- death mid-dash: no sliding corpse; broken guard cleared on wake ---
	# (checked on death B below)
	# --- walk over the bag ---
	player.global_position = spot
	await physics_frame
	await physics_frame
	await process_frame
	_check(inv.count(&"wood") == 25 and inv.count(&"copper_bar") == 10 and inv.count(&"stone") == 1, "walking over the bag returned everything")
	_check(get_nodes_in_group("death_bag").is_empty(), "empty bag is gone")

	# --- death B: no materials -> no bag; weapons never drop ---
	inv.clear()
	var dodge: Dodge = player.get_node("Dodge")
	var guard: Guard = player.get_node("Guard")
	player.set_physics_process(true)
	player.aim_override = Vector2.RIGHT
	dodge.try_dodge(Vector2.RIGHT, Vector2.RIGHT)
	await physics_frame
	var x0: float = player.global_position.x
	guard._break_tank()
	rs.kill()
	await physics_frame
	await physics_frame
	await physics_frame
	_check(not dodge.is_dashing() and absf(player.global_position.x - x0) < 40.0 and player.velocity == Vector2.ZERO, "killed mid-dash: the body stops (%.1f px)" % (player.global_position.x - x0))
	player.set_physics_process(false)
	_check(rs.deaths == 2 and get_nodes_in_group("death_bag").is_empty(), "nothing to drop: deaths = 2, no bag")
	await _until(func(): return not player.dead, 3.0)
	_check(guard.state == Guard.State.READY and guard.tank == guard.tank_max, "respawn clears a broken guard")

	# --- bag bigger than the inventory: the rest stays inside ---
	var wood := World.item("wood")
	var big := DeathBag.spawn(arena, home + Vector2(200, 0), {wood.id: {"item": wood, "count": 100000}})
	player.global_position = big.global_position
	await physics_frame
	await physics_frame
	await process_frame
	var got := inv.count(&"wood")
	_check(got > 0 and is_instance_valid(big) and big.total() == 100000 - got, "full inventory: %d wood taken, %d stay in the bag" % [got, big.total()])

	# --- two bags at once ---
	DeathBag.spawn(arena, home + Vector2(500, 0), {wood.id: {"item": wood, "count": 3}})
	_check(get_nodes_in_group("death_bag").size() == 2, "several bags can exist")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
