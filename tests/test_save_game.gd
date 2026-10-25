extends SceneTree
# W9 (decision 0041): change a world -> save -> fresh arena -> Continue-style load -> same state (inventory, selected slot,
# furnace, bag, a gathered node in a chunk that is NOT loaded, hp, deaths, position, a map export); refusals; corrupt files;
# Continue disabled without a save. Everything goes to a temp path, never the real user://save.json.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _write(text: String) -> void:
	var f := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _init() -> void:
	SaveGame.path = "user://test_save.json"
	SaveGame.force_io = true
	SaveGame.delete_save()

	# --- no save / corrupt / old version: nothing valid, no crash ---
	_check(not SaveGame.has_valid_save(), "no file: no valid save")
	_write("{ this is not json")
	_check(not SaveGame.has_valid_save(), "corrupt file: no valid save")
	_write(JSON.stringify({"version": 999, "world": {"seed": 5}, "player": {}, "inventory": []}))
	_check(not SaveGame.has_valid_save(), "other version: no valid save")
	_write(JSON.stringify({"version": 1, "world": {"seed": 5}}))
	_check(not SaveGame.has_valid_save(), "missing parts: no valid save")
	var title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	_check(title.button("Continue").disabled, "title: Continue greyed with a bad file")
	title.queue_free()
	SaveGame.delete_save()

	# --- build a world A and change it ---
	var arena = await World.make(self)
	var player: CharacterBody2D = arena.get_node("Player")
	var m: ArenaMap = arena.get_node("ArenaMap")
	var inv: Inventory = player.get_node("Inventory")
	var lo: Loadout = player.get_node("Loadout")
	var rs: Respawner = player.get_node("Respawner")
	var sg: SaveGame = arena.get_node("SaveGame")
	var seed_a := m.current_seed
	inv.give_dev_kit()
	inv.add(World.item("wood"), 7)
	inv.add(World.item("copper_ore"), 5)
	lo.select(2)   # the axe
	var home := m.home_point()
	var furnace_st := World.station(arena, "furnace", home + Vector2(150, 80))
	var f := furnace_st.furnace()
	f.in_item = World.item("copper_ore")
	f.in_count = 3
	f.progress = 1.5
	f.out_item = World.item("copper_bar")
	f.out_count = 2
	DeathBag.spawn(arena, home + Vector2(-200, 60), {&"stone": {"item": World.item("stone"), "count": 9}})
	var far := -1
	var near := -1
	for i in m.result.obstacles.size():
		var o: Dictionary = m.result.obstacles[i]
		if o["node"] < 0:
			continue
		if far < 0 and not m._streamer.is_loaded(m._streamer.chunk_id_at(o["pos"])):
			far = i
		if near < 0 and m._streamer.node_of(i) != null:
			near = i
		if far >= 0 and near >= 0:
			break
	_check(far >= 0, "found a gatherable node in a chunk that is not loaded (%d)" % far)
	m.mark_broken(far)
	if near >= 0:
		m.mark_broken(near)
	rs.deaths = 2
	player.global_position = home + Vector2(60, 40)
	player.get_node("Health").hp = 40.0
	m.chunks_per_frame = 3
	sg.play_time = 123.0
	var inv_before: Array = inv.to_array()

	# --- refusals ---
	player.set("dead", true)
	_check(sg.save() == "dead" and not FileAccess.file_exists(SaveGame.path), "no save while dead")
	player.set("dead", false)
	var boss: Boss = arena.get_node("Boss")
	boss.aggro = Boss.Aggro.ENGAGED
	_check(sg.save() == "boss engaged" and not FileAccess.file_exists(SaveGame.path), "no save while the boss is engaged")
	boss.aggro = Boss.Aggro.IDLE
	SaveGame.force_io = false
	OS.set_environment("BOSSFIGHT_TEST_SEED", "11")
	_check(sg.save() == "test run" and not FileAccess.file_exists(SaveGame.path), "no save under a test run")
	SaveGame.force_io = true

	# --- save ---
	_check(sg.save() == "" and SaveGame.has_valid_save(), "saved a valid file")
	var raw = JSON.parse_string(FileAccess.get_file_as_string(SaveGame.path))
	_check(int(raw["version"]) == 1 and int(raw["world"]["seed"]) == seed_a, "file has a version and the seed")
	arena.queue_free()
	await process_frame
	await process_frame

	# --- Continue: a fresh arena from the file ---
	var title2 = load("res://scenes/title.tscn").instantiate()
	root.add_child(title2)
	await process_frame
	_check(not title2.button("Continue").disabled, "title: Continue enabled with a valid save")
	title2.queue_free()
	SaveGame.begin_load(SaveGame.read_save())
	var arena2 = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena2)
	arena2.get_node("Boss").passive = true
	await process_frame
	await process_frame
	var p2: CharacterBody2D = arena2.get_node("Player")
	var m2: ArenaMap = arena2.get_node("ArenaMap")
	var inv2: Inventory = p2.get_node("Inventory")
	_check(m2.current_seed == seed_a, "same island seed")
	_check(inv2.to_array() == inv_before, "inventory slot for slot")
	_check(p2.get_node("Loadout").selected_slot == 2, "selected slot")
	_check(p2.global_position.distance_to(home + Vector2(60, 40)) < 1.0 and is_equal_approx(p2.get_node("Health").hp, 40.0), "position and hp")
	_check(p2.get_node("Respawner").deaths == 2 and arena2.get_node("SaveGame").play_time >= 123.0, "deaths and play time")
	_check(m2.chunks_per_frame == 3, "a changed map export came back")
	_check(m2._streamer.broken[far] == 1 and (near < 0 or m2._streamer.broken[near] == 1), "gathered nodes stay gathered (including the unloaded chunk)")
	var sts := get_nodes_in_group("station")
	var f2: Furnace = sts[0].furnace() if sts.size() == 1 else null
	_check(f2 != null and f2.in_count + f2.out_count == 5 and f2.out_count >= 2 and f2.out_item.id == &"copper_bar" and (f2.in_count == 0 or f2.in_item.id == &"copper_ore"), "furnace input / output (it keeps smelting after the load, so counts add up)")
	_check(sts.size() == 1 and sts[0].global_position.distance_to(home + Vector2(150, 80)) < 1.0, "station where it stood")
	var bags := get_nodes_in_group("death_bag")
	_check(bags.size() == 1 and (bags[0] as DeathBag).total() == 9, "death bag with its contents")
	# the unloaded chunk loads later: the node must not appear
	m2.teleport_player(m2.result.obstacles[far]["pos"])
	await process_frame
	await process_frame
	var n := m2._streamer.node_of(far) as ResourceNode
	_check(n == null or n.is_broken(), "the gathered node is a stump / gone when its chunk loads")

	# --- a loaded second weapon starts no swap cast ---
	var lo2: Loadout = p2.get_node("Loadout")
	inv2.give_dev_kit()   # sword slot 0, bow slot 1
	var sg2: SaveGame = arena2.get_node("SaveGame")
	lo2.rearm()
	lo2.select_instant(1)
	_check(not lo2.is_casting() and lo2.active_weapon() == inv2.slot_item(1).weapon and lo2.selected_slot == 1, "select_instant: bow in hand at once, no cast")

	# --- win -> save allowed, boss_defeated written ---
	var boss2: Boss = arena2.get_node("Boss")
	boss2.aggro = Boss.Aggro.ENGAGED
	boss2.health.take_damage(1000000.0, null, false)
	await process_frame
	_check(boss2.mode == Boss.Mode.DEAD and boss2.aggro != Boss.Aggro.ENGAGED, "a defeated boss is not engaged")
	_check(sg2.save() == "", "saving works after the boss died")
	_check(bool(SaveGame.read_save()["boss_defeated"]), "boss_defeated is written")

	SaveGame.delete_save()
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
