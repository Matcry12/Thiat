extends SceneTree
# W6 (decisions 0039 + 0042): die -> everything drops as loose pickups around the corpse, boss resets, nothing is
# grabbed while dead, respawn at home with full hp after the delay, walking back to the drops returns everything
# (the hotbar weapon rule still applies), drops despawn after despawn_time, drop_gear / drop_share / despawn 0 work.
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

func _wipe(inv: Inventory) -> void:
	for i in Inventory.SIZE:
		inv.remove_from_slot(i, 99999)

func _drops() -> Array:
	return get_nodes_in_group("pickup").filter(func(p): return p.death_drop)

func _sum(drops: Array, id: StringName) -> int:
	var n := 0
	for p in drops:
		if p.item.id == id:
			n += p.amount
	return n

func _init() -> void:
	var arena = await World.make(self)
	var player: Node2D = arena.get_node("Player")
	var map: ArenaMap = arena.get_node("ArenaMap")
	var inv: Inventory = player.get_node("Inventory")
	var health: Health = player.get_node("Health")
	var rs: Respawner = player.get_node("Respawner")
	var boss: Boss = arena.get_node("Boss")
	rs.respawn_delay = 1.5
	rs.despawn_time = 300.0
	var home := map.home_point()
	inv.give_dev_kit()
	player.get_node("Loadout").rearm()
	inv.add(World.item("wood"), 25)
	inv.add(World.item("stone"), 1)
	inv.add(World.item("copper_bar"), 10)

	# Boss mid-fight: engaged, phase 2, hurt, away from home.
	boss.passive = true
	boss.aggro = Boss.Aggro.ENGAGED
	boss.health.hp = boss.health.max_hp * 0.3
	boss.phase = 2
	boss.global_position = boss.home + Vector2(150, 0)

	# --- death A: everything drops ---
	player.global_position = home + Vector2(300, 0)
	var spot: Vector2 = player.global_position
	rs.kill()
	await physics_frame
	_check(player.dead and rs.deaths == 1 and rs.is_waiting(), "died: dead flag, deaths = 1, respawn timer running")
	var drops := _drops()
	_check(_sum(drops, &"wood") == 25 and _sum(drops, &"stone") == 1 and _sum(drops, &"copper_bar") == 10, "all materials dropped (drop_share 1)")
	_check(_sum(drops, &"wooden_sword") + _sum(drops, &"bow") + _sum(drops, &"stone_axe") + _sum(drops, &"stone_pickaxe") == 4, "tools and weapons dropped too")
	var inv_empty := true
	for i in Inventory.SIZE:
		inv_empty = inv_empty and inv.slot_item(i) == null
	_check(inv_empty, "inventory is empty")
	_check(drops.size() > 5 and drops.all(func(p): return p.amount <= rs.max_per_pickup and p.despawn_left > 290.0), "a spray of pickups (big stacks split), each with a despawn timer")
	await _until(func(): return drops.all(func(p): return p.settled), 2.0)
	_check(drops.all(func(p): var d: float = p.global_position.distance_to(spot); return d >= rs.spray_min - 1.0 and d <= rs.spray_max + 1.0), "drops landed around the corpse (%d px band)" % rs.spray_max)
	_check(boss.health.hp == boss.health.max_hp and boss.phase == 1 and boss.aggro == Boss.Aggro.RETURNING, "boss reset: full hp, phase 1, walking home")
	await _until(func(): return boss.aggro == Boss.Aggro.IDLE, 3.0)
	_check(boss.aggro == Boss.Aggro.IDLE and boss.global_position.distance_to(boss.home) < 3.0 and boss.outside_time == 0.0 and not boss.health.invulnerable, "boss back at home, idle, vulnerable")
	_check(player.dead and inv.used_slots() == 0 and _drops().size() == drops.size(), "nothing grabbed while dead (the corpse is on top of the drops)")

	# --- respawn ---
	await _until(func(): return not player.dead, 3.0)
	_check(not player.dead and player.global_position.distance_to(home) < 1.0 and health.hp == health.max_hp, "woke up at home with full hp")

	# --- walk back: magnet + pickup bring everything home ---
	for off in [Vector2.ZERO, Vector2(60, 0), Vector2(-60, 0), Vector2(0, 60), Vector2(0, -60)]:   # the spray is wider than the magnet: walk through the pile
		player.global_position = spot + off
		await _until(func(): return _drops().is_empty(), 0.6)
	_check(inv.count(&"wood") == 25 and inv.count(&"stone") == 1 and inv.count(&"copper_bar") == 10, "walking back returned every material")
	_check(inv.count(&"wooden_sword") == 1 and inv.count(&"bow") == 1 and inv.count(&"stone_axe") == 1 and inv.count(&"stone_pickaxe") == 1, "and the gear")

	# --- the weapon in hand comes back in hand: no fists, no swap cast ---
	var lo: Loadout = player.get_node("Loadout")
	_check(not lo.is_holstered() and not lo.is_casting() and lo.active_weapon() != null, "after the walk back a weapon is in hand (no fists, no cast)")

	# --- hotbar weapon rule on pickup: a 3rd weapon goes to the bag ---
	_check(inv.hotbar_weapon_count() == 2, "two weapons in the hotbar")
	var third := Pickup.spawn(arena, World.item("copper_sword"), 1, player.global_position, player.global_position)
	var third_id := third.get_instance_id()
	await _until(func(): return not is_instance_valid(instance_from_id(third_id)), 2.0)
	var in_bag := false
	for i in range(Inventory.HOTBAR, Inventory.SIZE):
		in_bag = in_bag or (inv.slot_item(i) != null and inv.slot_item(i).id == &"copper_sword")
	_check(inv.hotbar_weapon_count() == 2 and in_bag, "3rd weapon picked up into the bag, not the hotbar")

	# --- drop_gear off, drop_share 0.5 ---
	rs.drop_gear = false
	rs.drop_share = 0.5
	rs.respawn_delay = 0.3
	inv.clear()   # materials only: the gear stays
	inv.add(World.item("wood"), 7)
	player.global_position = home + Vector2(400, 0)
	rs.kill()
	await physics_frame
	drops = _drops()
	_check(_sum(drops, &"wood") == 3 and _sum(drops, &"wooden_sword") == 0 and inv.count(&"wooden_sword") == 1 and inv.count(&"wood") == 4, "drop_gear off keeps gear; drop_share 0.5 halves materials (floor)")
	await _until(func(): return not player.dead, 3.0)
	for p in _drops():
		p.free()
	_wipe(inv)

	# --- despawn ---
	rs.drop_gear = true
	rs.drop_share = 1.0
	rs.despawn_time = 1.0
	inv.add(World.item("wood"), 3)
	player.global_position = home + Vector2(500, 0)
	rs.kill()
	await physics_frame
	_check(_drops().size() == 1, "one drop")
	await _until(func(): return _drops().is_empty(), 3.0)
	_check(_drops().is_empty(), "the drop despawned after despawn_time")
	await _until(func(): return not player.dead, 3.0)

	# --- a cursor stack that does not fit spills as a death drop too ---
	inv.add(World.item("wood"), 99999)
	inv.hold(World.item("copper_bar"), 5)
	player.global_position = home + Vector2(600, 0)
	rs.kill()
	await physics_frame
	_check(_sum(_drops(), &"copper_bar") == 5 and _drops().all(func(p): return p.despawn_left > 0.0 and p.scale.x == rs.drop_scale), "cursor stack that did not fit: a flagged death drop with a timer and the drop size")
	await _until(func(): return not player.dead, 3.0)
	for p in _drops():
		p.free()
	_wipe(inv)

	# --- despawn_time 0 = never; nothing to drop = no pickups ---
	rs.despawn_time = 0.0
	inv.add(World.item("wood"), 3)
	player.global_position = home + Vector2(500, 0)
	rs.kill()
	await physics_frame
	var d0 := _drops()
	_check(d0.size() == 1 and d0[0].despawn_left < 0.0, "despawn_time 0: the drop never despawns")
	await _until(func(): return not player.dead, 3.0)
	for p in _drops():
		p.free()
	_wipe(inv)
	rs.kill()
	await physics_frame
	_check(rs.deaths == 6 and _drops().is_empty(), "nothing carried: nothing drops")
	_check(rs.status_text().contains("drops on ground: 0"), "F3 status reads the drops")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
