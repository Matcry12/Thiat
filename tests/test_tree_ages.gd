extends SceneTree
# 0036 / 0037 step 3: an old tree takes more hits than a sapling, drops more, and leaves a stump (the size-2 sheet has no stump art).
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _hits(path: String, arena: Node, at: Vector2, player: Node2D) -> Array:
	var n: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	n.setup(load(path), 0)
	n.position = at
	arena.add_child(n)
	var axe: WeaponData = load("res://data/weapons/stone_axe.tres")
	var hits := 0
	while not n.is_broken() and hits < 50:
		n.take_gather_hit(axe, player)
		hits += 1
	return [hits, n]

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player: Node2D = arena.get_node("Player")
	var sap: ResourceNodeData = load("res://data/resource_nodes/tree_oak_sapling.tres")
	var old: ResourceNodeData = load("res://data/resource_nodes/tree_oak_old.tres")
	_check(old.max_hp > sap.max_hp and old.drop_max > sap.drop_max, "old tree: more HP and wood than a sapling (%.0f/%d vs %.0f/%d)" % [old.max_hp, old.drop_max, sap.max_hp, sap.drop_max])
	var a := _hits("res://data/resource_nodes/tree_oak_sapling.tres", arena, player.global_position + Vector2(300, 300), player)
	var b := _hits("res://data/resource_nodes/tree_oak_old.tres", arena, player.global_position + Vector2(400, 300), player)
	_check(b[0] > a[0], "old tree needs more axe hits (%d) than a sapling (%d)" % [b[0], a[0]])
	_check(old.remains_region.has_area() and is_instance_valid(b[1]) and not b[1].is_queued_for_deletion(), "old tree leaves a stump")
	var all_stump := true
	for f in DirAccess.get_files_at("res://data/resource_nodes"):
		if f.begins_with("tree_") and f.ends_with(".tres"):
			var d: ResourceNodeData = load("res://data/resource_nodes/" + f)
			if d.regions.size() > 0 and d.texture.resource_path.contains("_s") and not d.texture.resource_path.contains("_s2") and not d.remains_region.has_area():
				all_stump = false
				print("no stump: ", f)
	_check(all_stump, "every small / mature / old tree kind has a stump")
	quit(0 if _ok else 1)
