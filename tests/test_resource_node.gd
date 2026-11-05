extends SceneTree
const ClassicArena = preload("res://tests/support/classic_arena.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _node(arena: Node, path: String, at: Vector2) -> ResourceNode:
	var n: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	n.setup(load(path), 0)
	n.position = at
	arena.add_child(n)
	return n

func _swing(wh: WeaponHolder) -> void:
	wh.aim_direction = Vector2.RIGHT
	wh.try_attack()
	for i in 50:
		await physics_frame

func _init() -> void:
	var arena = ClassicArena.make()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	var lo: Loadout = player.get_node("Loadout")
	var wh: WeaponHolder = player.get_node("WeaponHolder")
	player.set_physics_process(false)
	player.get_node("WeaponVisual").set_aim_angle(0.0)
	var spot: Vector2 = player.global_position + Vector2(0, 160)
	player.global_position = spot
	var tree := _node(arena, "res://data/resource_nodes/tree.tres", spot + Vector2(40, 0))
	await physics_frame
	var fx_seen: Array[StringName] = []
	arena.get_node("HitFx").hit_fx.connect(func(t): fx_seen.append(t))

	# Sword: the swing passes through (sword hitbox does not see layer 32).
	await _swing(wh)
	_check(tree.hp == tree.data.max_hp, "sword does not chop (hp %.0f)" % tree.hp)

	lo.select(1)   # the start-kit stone axe (bare fists gather nothing, decision 0048)
	await physics_frame
	var axe_hit: float = lo.active_weapon().gather_damage * (tree.data.tool_bonus if lo.active_weapon().tool_kind == tree.data.preferred_tool else 1.0)
	await _swing(wh)
	_check(is_equal_approx(tree.hp, tree.data.max_hp - axe_hit), "one swing = one gather hit, not one per polled frame")
	_check(fx_seen.has(&"chop"), "chop hit feel fired")
	var hits := 1
	while not tree.is_broken() and hits < 20:
		await _swing(wh)
		hits += 1
	_check(tree.is_broken() and hits == ceili(tree.data.max_hp / axe_hit), "tree breaks after max_hp / axe hit swings (%d)" % hits)
	_check(fx_seen.has(&"node_break"), "break hit feel fired")
	await physics_frame
	_check(not is_instance_valid(tree) or tree.get_node("CollisionShape2D").disabled, "a broken tree no longer blocks")

	var ore := _node(arena, "res://data/resource_nodes/copper_rock.tres", spot + Vector2(40, 0))
	await physics_frame
	await _swing(wh)
	_check(ore.hp == ore.data.max_hp and fx_seen.has(&"clink"), "copper: clink, no damage with hands")

	# An arrow at a node: no crash, no damage (layer 32 is not in the arrow mask; the body stops it).
	var proj: Projectile = load("res://scenes/projectiles/arrow.tscn").instantiate()
	arena.add_child(proj)
	proj.global_position = ore.global_position - Vector2(120, 0)
	proj.setup(Vector2.RIGHT, 700.0, 520.0, 18.0, true, player)
	for i in 30:
		await physics_frame
	_check(ore.hp == ore.data.max_hp, "an arrow does not mine")
	_check(not is_instance_valid(proj) or proj.global_position.x < ore.global_position.x, "the node stops the arrow (x %.0f)" % (proj.global_position.x if is_instance_valid(proj) else -1.0))
	# A boss bolt (mask world + player) is stopped by the node too.
	var bolt: Projectile = load("res://scenes/projectiles/arrow.tscn").instantiate()
	arena.add_child(bolt)
	bolt.global_position = ore.global_position - Vector2(120, 0)
	bolt.setup(Vector2.RIGHT, 700.0, 520.0, 18.0, true, null, false, 1 | 2)
	for i in 30:
		await physics_frame
	_check(not is_instance_valid(bolt) or bolt.global_position.x < ore.global_position.x, "the node stops a boss bolt")

	# 0036: reset after a pause; rocks drop only to a pickaxe; trees drop by hand.
	var hand := WeaponData.new()
	hand.gather_damage = 1.0
	var pick := WeaponData.new()
	pick.gather_damage = 1.0
	pick.tool_kind = &"pickaxe"
	var reset_tree := _node(arena, "res://data/resource_nodes/tree.tres", spot + Vector2(-300, 0))
	reset_tree.data = reset_tree.data.duplicate()
	reset_tree.data.reset_delay = 0.05
	reset_tree.take_gather_hit(hand, player)
	reset_tree.take_gather_hit(hand, player)
	_check(reset_tree.hp == reset_tree.data.max_hp - 2.0, "quick hits add up (hp %.0f)" % reset_tree.hp)
	for i in 12:
		await physics_frame   # 0.05 s of game time = 3 ticks; 12 is plenty
	_check(reset_tree.status_text().contains("%.0f/" % reset_tree.data.max_hp), "status shows full hp after the delay")
	reset_tree.take_gather_hit(hand, player)
	_check(reset_tree.hp == reset_tree.data.max_hp - 1.0, "after the delay the node restarts from full hp (hp %.0f)" % reset_tree.hp)
	var before := get_nodes_in_group("pickup").size()
	var hand_tree := _node(arena, "res://data/resource_nodes/tree.tres", spot + Vector2(-300, 60))
	hand_tree.data = hand_tree.data.duplicate()
	hand_tree.data.max_hp = 1.0
	hand_tree.hp = 1.0
	hand_tree.take_gather_hit(hand, player)
	_check(get_nodes_in_group("pickup").size() > before, "tree broken by hands drops")
	before = get_nodes_in_group("pickup").size()
	var hand_rock := _node(arena, "res://data/resource_nodes/rock.tres", spot + Vector2(-300, 120))
	hand_rock.data = hand_rock.data.duplicate()
	hand_rock.data.max_hp = 1.0
	hand_rock.hp = 1.0
	hand_rock.take_gather_hit(hand, player)
	_check(hand_rock.is_broken() and get_nodes_in_group("pickup").size() == before, "rock broken by hands drops nothing")
	_check(hand_rock.status_text().contains("no drop"), "status says no drop")
	var pick_rock := _node(arena, "res://data/resource_nodes/rock.tres", spot + Vector2(-300, 180))
	pick_rock.data = pick_rock.data.duplicate()
	pick_rock.data.max_hp = 1.0
	pick_rock.hp = 1.0
	pick_rock.take_gather_hit(pick, player)
	_check(pick_rock.is_broken() and get_nodes_in_group("pickup").size() > before, "rock broken by pickaxe drops")

	# I2: each node keeps its own radius (shape is per instance).
	var big_data: ResourceNodeData = load("res://data/resource_nodes/rock.tres").duplicate()
	big_data.radius = 40.0
	var big: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	big.setup(big_data, 0)
	arena.add_child(big)
	var small := _node(arena, "res://data/resource_nodes/tree.tres", spot + Vector2(400, 0))
	_check((big.get_node("CollisionShape2D").shape as CircleShape2D).radius == 40.0 and (small.get_node("CollisionShape2D").shape as CircleShape2D).radius == 14.0, "two nodes keep their own radius")

	# I3: switching mid-swing is refused (no free recovery cancel).
	lo.select(lo.weapon_slot(0))   # back to the sword
	await physics_frame
	var held_slot := lo.selected_slot
	wh.aim_direction = Vector2.RIGHT
	wh.try_attack()
	await physics_frame
	_check(wh.phase != WeaponHolder.Phase.IDLE and not lo.select(1 if held_slot != 1 else 2) and lo.selected_slot == held_slot and wh.phase != WeaponHolder.Phase.IDLE, "select refused mid-swing, state unchanged")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
