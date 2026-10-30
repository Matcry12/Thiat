extends SceneTree
# F3 dock: search ranks name hits above section hits (whole words only), a found Vector2 row edits the live BodyRig,
# number fields (Enter / Esc / Up / Down / scrub), heavy rows wait for Enter, pins persist in the cfg file.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e

func _init() -> void:
	OS.set_environment("BOSSFIGHT_TEST_MAP_CELLS", "192")   # small island: this test does not need the full map
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	for i in 5:
		await process_frame
	var panel = arena.get_node("TuningPanel")
	panel.visible = true
	var dock: F3Dock = panel.dock
	var cfg_path := "user://test_f3_dock.cfg"
	DirAccess.remove_absolute(cfg_path)
	panel.use_overrides(F3Overrides.new(cfg_path))
	var rig: BodyRig = arena.get_node("Player").visual.rig

	# --- search: pure ---
	var secs: Array = panel.sections()
	var hits := F3Search.run(secs, "hand")
	var keys := hits.map(func(h): return h["prop"]["key"])
	_check(keys.has("BodyRig.hand_idle_front"), "search 'hand' finds BodyRig.hand_idle_front (%d hits)" % hits.size())
	var seen_section_hit := false
	var ordered := true
	for h in hits:
		if not h["name_hit"]:
			seen_section_hit = true
		elif seen_section_hit:
			ordered = false
	_check(ordered, "name hits come before section hits")
	var heal := F3Search.run(secs, "heal").map(func(h): return h["prop"]["section"])
	_check(not heal.has("HealthBar") and not heal.has("Player Health"), "'heal' is not a whole word of HealthBar / Player Health")
	var hb := F3Search.run(secs, "health").map(func(h): return h["prop"]["section"])
	_check(hb.has("HealthBar") and hb.has("Player Health"), "'health' is a whole word of HealthBar / Player Health")

	# --- search in the dock: a live row, edit its x field ---
	dock.set_search("hand")
	await process_frame
	await process_frame
	var row: F3PropRow = dock.row_for("BodyRig.hand_idle_front")
	_check(row != null and row._fields.size() == 2, "the result is a live Vector2 row with two fields")
	var old_y := rig.hand_idle_front.y
	row._fields[0].text = "13.5"
	row._fields[0].text_submitted.emit("13.5")
	_check(is_equal_approx(rig.hand_idle_front.x, 13.5) and is_equal_approx(rig.hand_idle_front.y, old_y), "editing x changes the rig, y untouched (%s)" % rig.hand_idle_front)
	_check(row.is_changed() and row._reset.modulate.a == 1.0, "the row shows it changed and offers reset")
	row._reset.pressed.emit()
	_check(rig.hand_idle_front == panel.initial_value("BodyRig.hand_idle_front"), "reset arrow restores the startup value")

	# --- number fields on a plain float row (Player.speed) ---
	dock.set_search("")
	dock.open_section("Player")
	await process_frame
	await process_frame
	var sp: F3PropRow = dock.row_for("Player.speed")
	var player = arena.get_node("Player")
	var v0: float = player.speed
	sp._fields[0].text = "300"
	sp._fields[0].text_submitted.emit("300")
	_check(player.speed == 300.0, "Enter commits")
	sp._fields[0].grab_focus()
	await process_frame
	sp._fields[0].text = "999"
	var esc := _key(KEY_ESCAPE)
	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	_check(player.speed == 300.0 and sp._fields[0].text == "300", "Esc cancels the typed value")
	sp._field_input(_key(KEY_UP), 0)
	var up: float = player.speed
	_check(up > 300.0, "Up steps (%s)" % up)
	var shift_down := _key(KEY_DOWN)
	shift_down.shift_pressed = true
	sp._field_input(shift_down, 0)
	_check(player.speed < up and player.speed > up - (up - 300.0), "Shift+Down steps finer")
	var mv := InputEventMouseMotion.new()
	mv.relative = Vector2(10, 0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	var before: float = player.speed
	sp._scrub_input(press, 0)
	sp._scrub_input(mv, 0)
	_check(player.speed > before, "dragging the name scrubs the value")
	press.pressed = false
	sp._scrub_input(press, 0)
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "scrub gives the mouse back")
	panel.apply_value("Player.speed", v0)

	# --- heavy row: waits for Enter ---
	dock.open_section("Map")
	await process_frame
	await process_frame
	var hv: F3PropRow = dock.row_for("Map.land_share")
	var m: ArenaMap = arena.get_node("ArenaMap")
	var ls: float = m.land_share
	_check(hv != null and hv.heavy and hv._slider != null, "Map.land_share is a heavy row with a slider")
	hv._field_input(_key(KEY_UP), 0)
	_check(m.land_share == ls and hv._pending, "Up on a heavy row only edits the text")
	hv._fields[0].text_submitted.emit(hv._fields[0].text)
	_check(dock._banner.visible and dock._banner.text.begins_with("Rebuilding"), "heavy apply: the banner shows first")
	await process_frame
	await process_frame
	_check(dock._banner.text.begins_with("last rebuild"), "then it says how long the rebuild took")
	_check(m.land_share != ls and not hv._pending, "Enter applies it")
	panel.apply_value("Map.land_share", ls)

	# --- pins persist ---
	dock.open_section("Player")   # (opening Map closed the Character category: it is an accordion)
	dock.toggle_pin("BodyRig.hand_idle_front")
	dock.toggle_pin("Player.speed")
	await process_frame
	await process_frame
	_check(dock.row_for("Player.speed") != null and dock._rows["Player.speed"].size() == 2, "a pinned row also shows in the Pinned block")
	_check(F3Overrides.new(cfg_path).get_pins() == ["BodyRig.hand_idle_front", "Player.speed"], "pins are in the cfg file")
	panel.use_overrides(F3Overrides.new(cfg_path))   # a fresh store from the same file
	_check(dock._pins.size() == 2, "a fresh load gets them back")
	DirAccess.remove_absolute(cfg_path)
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
