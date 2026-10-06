extends SceneTree
const ClassicArena = preload("res://tests/support/classic_arena.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var arena = ClassicArena.make()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var inv: Inventory = player.get_node("Inventory")
	var col: Collector = player.get_node("Collector")
	var wood: ItemData = load("res://data/items/wood.tres")
	var far := Pickup.spawn(arena, wood, 1, player.global_position + Vector2(300, 0), player.global_position + Vector2(300, 0))
	var near := Pickup.spawn(arena, wood, 1, player.global_position + Vector2(col.magnet_radius - 10, 0), player.global_position + Vector2(col.magnet_radius - 10, 0))
	for i in 90:
		await physics_frame
	_check(inv.count(&"wood") == 1, "the near pickup flew in, the far one stayed (%d)" % inv.count(&"wood"))
	_check(is_instance_valid(far) and not is_instance_valid(near), "far still on the ground")

	# Break a tree: its drops land on the ground and end up in the inventory when you walk over.
	var tree: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	tree.setup(load("res://data/resource_nodes/tree.tres"), 0)
	tree.position = player.global_position + Vector2(40, 0)
	arena.add_child(tree)
	await physics_frame
	var fists: WeaponData = load("res://data/weapons/fists.tres")
	while not tree.is_broken():
		tree.take_gather_hit(fists, player)
	await physics_frame
	var dropped := get_nodes_in_group_count(arena) - 1   # minus the far pickup
	_check(dropped >= 2 and dropped <= 4, "tree dropped 2-4 wood pickups (%d)" % dropped)
	for i in 120:
		await physics_frame
	_check(inv.count(&"wood") >= 3, "walking next to the drops collects them (%d)" % inv.count(&"wood"))

	var hud = arena.get_node("HUD")
	_check(hud.get_node_or_null("%ItemCounter") != null or _find_counter(hud) != null, "HUD has an item counter")
	await _water_edge()
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)

func get_nodes_in_group_count(_a) -> int:
	return root.get_tree().root.get_tree().get_nodes_in_group("pickup").size()

func _find_counter(n: Node) -> Node:
	if n is ItemCounter:
		return n
	for c in n.get_children():
		var f := _find_counter(c)
		if f:
			return f
	return null

func _water_edge() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").map_seed = 11
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var m: ArenaMap = arena.get_node("ArenaMap")
	var p := m.make_params()
	var coast := Vector2i(-1, -1)
	for y in range(p.rows / 3, p.rows * 2 / 3):
		for x in range(p.cols - 2, p.cols / 2, -1):
			if MapGen.is_land(m.result, p, Vector2i(x, y)) and not MapGen.is_land(m.result, p, Vector2i(x + 1, y)):
				coast = Vector2i(x, y)
				break
		if coast.x >= 0:
			break
	_check(coast.x >= 0, "found an east coast cell")
	var pos := (Vector2(coast) + Vector2(0.5, 0.5)) * p.cell
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	player.global_position = pos + Vector2(-2000, 0)
	for k in 5:
		var tree: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
		tree.setup(load("res://data/resource_nodes/tree.tres"), 0)
		tree.position = pos
		arena.add_child(tree)
		await physics_frame
		while not tree.is_broken():
			tree.take_gather_hit(load("res://data/weapons/fists.tres"), player)
		tree.queue_free()
	for i in 40:
		await physics_frame
	var bad := 0
	var n := 0
	for pk in root.get_tree().get_nodes_in_group("pickup"):
		if not arena.is_ancestor_of(pk):
			continue
		n += 1
		if m.area_at(pk.global_position) == -1:
			bad += 1
	_check(n >= 10 and bad == 0, "no drop lands in water (%d drops, %d in water)" % [n, bad])
