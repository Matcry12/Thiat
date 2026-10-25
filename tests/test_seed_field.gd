extends SceneTree
# F3 seed box: digits only, Generate / Enter builds EXACTLY that seed (identical to map_seed = N set
# in the scene), the field gives the keys back to the game after Generate, and while it has focus
# the player ignores movement keys.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _same(a: MapGen.Result, b: MapGen.Result) -> bool:
	return a.patches == b.patches and a.grass == b.grass and a.dirt == b.dirt and a.deco == b.deco \
		and a.obstacles == b.obstacles and a.border == b.border

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var m: ArenaMap = arena.get_node("ArenaMap")
	var panel = arena.get_node("TuningPanel")
	var edit: LineEdit = panel._seed_edit
	var player: CharacterBody2D = arena.get_node("Player")
	_check(edit != null, "F3 has a seed field")

	edit.text = "1a2b"
	panel._on_seed_text_changed(edit.text)
	_check(edit.text == "12", "non-digits are dropped (%s)" % edit.text)

	edit.text = "4242"
	panel._on_generate_pressed()
	await process_frame
	await process_frame
	_check(m.current_seed == 4242 and m.map_seed == 4242, "Generate builds seed 4242 (current %d)" % m.current_seed)
	var typed := m.result
	var typed_obstacles := m.result.obstacles.size()

	# a reference arena with the seed set in the scene, the layout untouched
	var ref = load("res://scenes/arena.tscn").instantiate()
	ref.get_node("ArenaMap").map_seed = 4242
	root.add_child(ref)
	ref.get_node("Boss").passive = true
	await process_frame
	_check(_same(typed, ref.get_node("ArenaMap").result), "the typed seed gives the identical map (%d rocks, %d patches)" % [typed_obstacles, typed.patches.size()])
	ref.queue_free()

	# Enter
	edit.text = "77"
	edit.text_submitted.emit("77")
	await process_frame
	await process_frame
	_check(m.current_seed == 77, "Enter works like Generate")
	# same seed again still rebuilds without error, and the range is clamped
	edit.text = "0"
	panel._on_generate_pressed()
	_check(m.current_seed == 1, "0 is clamped to 1")
	edit.text = "99999"
	panel._on_generate_pressed()
	_check(m.current_seed == 9999, "99999 is clamped to 9999")
	edit.text = ""
	panel._on_generate_pressed()
	_check(m.current_seed == 9999, "empty field does nothing")
	_check(panel._controls["Map.map_seed"]["control"].value == 9999.0, "the seed slider shows it")
	m.load_all_chunks()   # 0038 step 2: nodes exist per chunk near the player; load them all to compare with the world data
	await process_frame
	_check(get_nodes_in_group("map_obstacle").size() == m.result.obstacles.size(), "no stale rocks")

	# typing must not move the player; Generate gives the keys back
	arena.get_node("Boss").passive = true
	var pos0 := player.global_position
	edit.grab_focus()
	await process_frame
	_check(root.gui_get_focus_owner() == edit, "the field took focus")
	Input.action_press("move_right")
	for i in 20:
		await physics_frame
	_check(player.global_position == pos0, "focus in the field: the player does not move")
	edit.text = "5"
	panel._on_generate_pressed()
	_check(root.gui_get_focus_owner() == null, "Generate releases focus")
	for i in 20:
		await physics_frame
	_check(player.global_position.x > pos0.x + 20.0, "focus gone: the player moves again")
	Input.action_release("move_right")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
