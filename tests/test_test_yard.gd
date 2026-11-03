extends SceneTree
# Test yard (decision 0056): the title button's arena. Small flat map, every tree kind + rocks + copper, 3 stations, dummy, slime.
#   - loads fast, nothing is saved, no random enemy packs
#   - every listed node exists, chopping/mining it breaks it and drops; Reset yard regrows everything
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	ArenaMap.yard_mode = true
	var t0 := Time.get_ticks_msec()
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var ms := Time.get_ticks_msec() - t0
	var m: ArenaMap = arena.get_node("ArenaMap")
	var y: TestYard = arena.get_node("TestYard")
	_check(ms < 1500, "yard loads fast (%d ms, budget 1500 under load)" % ms)
	_check(m.map_cols == y.cells and m.result.cols == y.cells, "map is %d x %d cells" % [y.cells, y.cells])
	_check(m.water_text == "none" and m.result.land.count(0) == 0, "all land, no water")
	_check(m.result.deco.is_empty(), "no random deco")
	_check(not SaveGame.io_enabled() and not arena.get_node("EnemySpawner").enabled, "saving and natural spawning are off")
	_check(arena.get_node("SaveGame").refusal() == "test run", "SaveGame refuses to save in the yard")

	var want := y.node_list(m.home_point())
	var trees := 0
	for n in want:
		trees += int(String(n["id"]).begins_with("treepp_oak_"))
	_check(trees >= 5 * 4 and want.size() == trees + 3, "layout lists %d trees + rocks + copper (%d nodes)" % [trees, want.size()])
	_check(m.result.obstacles.size() == want.size(), "every listed node was placed (%d)" % m.result.obstacles.size())
	var missing := 0
	for n in want:
		missing += int(m.nearest_node(n["id"], n["pos"]) == null)
	_check(missing == 0, "every listed id is found as a real node")
	_check(get_nodes_in_group("station").size() == 3, "3 stations placed")
	_check(get_nodes_in_group("enemy").size() == 1, "one slime")
	_check(arena.get_node("Dummy").global_position.distance_to(m.home_point() + y.dummy_offset) < 1.0, "dummy at the yard spot")
	var inv: Inventory = arena.get_node("Player/Inventory")
	_check(inv.count(&"wooden_sword") + inv.count(&"stone_axe") + inv.count(&"stone_pickaxe") == 3, "start kit: sword, axe, pickaxe")

	# chop one of each kind with the real axe / pickaxe data
	var axe: WeaponData = load("res://data/weapons/stone_axe.tres")
	var pick: WeaponData = load("res://data/weapons/stone_pickaxe.tres")
	var player: Node2D = arena.get_node("Player")
	var ids: Array[StringName] = [&"treepp_oak_green_old", &"treepp_oak_snow_sapling", &"rock", &"copper_rock"]
	var broke_all := true
	for id in ids:
		var node := m.nearest_node(id, m.home_point())
		var tool := axe if String(id).begins_with("tree") else pick
		var guard := 0
		var rc: int = arena.get_node("HitFx").layer_counts["reaction"]
		while not node.is_broken() and guard < 200:
			node.take_gather_hit(tool, player)
			guard += 1
		broke_all = broke_all and node.is_broken()
		_check(node.is_broken(), "%s breaks in %d hits" % [id, guard])
		_check(arena.get_node("HitFx").layer_counts["reaction"] > rc, "%s: sway / pop reaction played" % id)
	await process_frame
	# map nodes are built before HitFx joins its group: a chop must still reach it (sound + tree reaction)
	var fx: HitFx = arena.get_node("HitFx")
	_check(fx.layer_counts["sound"] > 0 and fx.layer_counts["reaction"] > 0, "chops in the yard fire hit FX")
	_check(get_nodes_in_group("pickup").size() > 0, "breaking drops pickups")
	_check(y.nodes_alive() == want.size() - ids.size(), "status counts %d alive" % y.nodes_alive())

	# F3 map rebuild: yard stations are re-made, not refunded to the bag (3)
	m.rebuild(false)
	_check(inv.count(&"workbench") + inv.count(&"furnace") + inv.count(&"anvil") == 0, "map rebuild does not refund yard stations")
	_check(get_nodes_in_group("station").size() == 3, "rebuild: the 3 yard stations are back")

	# player-placed station (3) and the real Delete save (5)
	var mine: Station = load("res://data/items/workbench.tres").placeable.instantiate()
	mine.item = load("res://data/items/workbench.tres")
	arena.add_child(mine)
	mine.global_position = m.home_point() + Vector2(0, 600)
	var tmp := "user://yard_test_save.json"
	var keep := SaveGame.path
	SaveGame.path = tmp
	FileAccess.open(tmp, FileAccess.WRITE).store_string("{}")
	arena.get_node("SaveGame").debug_actions()[2]["run"].call()
	_check(FileAccess.file_exists(tmp), "Delete save is refused in the yard")
	DirAccess.remove_absolute(tmp)
	SaveGame.path = keep

	# cells slider (1)
	y.cells = 48
	y.reset()
	await process_frame
	_check(m.map_cols == 48 and m.result.cols == 48 and y.status_text().contains("48x48"), "Reset yard applies cells (real size shown)")
	_check(inv.count(&"workbench") == 1 and inv.count(&"furnace") + inv.count(&"anvil") == 0, "reset: the player's own station goes back to the bag (not deleted), no yard station does")
	y.cells = 64
	y.reset()
	await process_frame
	_check(y.nodes_alive() == want.size(), "Reset yard regrows every node")
	_check(m.nearest_node(&"rock", m.home_point()) != null and not m.nearest_node(&"rock", m.home_point()).is_broken(), "a reset rock is whole")
	_check(get_nodes_in_group("station").size() == 3 and get_nodes_in_group("enemy").size() == 1, "reset: 3 yard stations, 1 slime (none doubled)")
	_check(inv.count(&"workbench") == 1, "repeated resets add no more station items to the bag")
	_check(y.status_text().begins_with("on"), "F3 status line")
	ArenaMap.yard_mode = false
	quit(0 if _ok else 1)
