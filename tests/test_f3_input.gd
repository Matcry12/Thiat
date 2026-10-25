extends SceneTree
# F3 dock input rules (DESIGN.md build requirements 1-5, 12): the pointer over the dock never attacks, aims or
# scrolls the hotbar; only text fields take focus; typing in a field does not move the player; Esc leaves a field
# before the pause menu sees it.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _mouse_to(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	for i in 2:
		await process_frame   # motion is buffered until the end of a frame

func _button(p: Vector2, idx: int, down: bool) -> void:
	var b := InputEventMouseButton.new()
	b.position = p
	b.global_position = p
	b.button_index = idx
	b.pressed = down
	Input.parse_input_event(b)

func _focusables(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Window:
			continue   # the colour picker popup is its own window
		if c is Button or c is Range:
			out.append(c)
		_focusables(c, out)

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	var player = arena.get_node("Player")
	var lo: Loadout = player.get_node("Loadout")
	var wh: WeaponHolder = player.get_node("WeaponHolder")
	var panel = arena.get_node("TuningPanel")
	for i in 5:
		await process_frame
	root.size = Vector2i(1152, 648)   # headless windows are 64x64
	for i in 3:
		await process_frame
	panel.visible = true
	var dock: F3Dock = panel.dock
	dock.open_section("BodyRig")
	await process_frame
	await process_frame
	var rows := dock.row_count()
	_check(rows > 0 and rows < 100, "rows exist only for the open section (%d of %d settings)" % [rows, panel.settings.size()])

	# --- every dock Button / Range / CheckBox refuses focus (also on the other tabs) ---
	dock.show_tab("Actions")
	await process_frame
	var all: Array = []
	_focusables(dock, all)
	var bad := 0
	for c in all:
		if c.focus_mode != Control.FOCUS_NONE:
			bad += 1
			print("  focusable: ", c.get_path(), " ", c)
	_check(all.size() > 30 and bad == 0, "%d dock buttons / sliders, all FOCUS_NONE (%d not)" % [all.size(), bad])
	dock.show_tab("Tune")
	await process_frame

	# --- the pointer over the dock: no attack, no aim change, no wheel -> hotbar, no slider change ---
	await _mouse_to(Vector2(20, 300))   # on the game
	for i in 90:   # (the camera is still sliding for a moment after F3 opens: the aim follows it)
		await physics_frame
	var aim_game: Vector2 = player.aim_direction
	var r := dock.get_global_rect()
	var edge := Vector2(r.position.x + 2.0, r.position.y + r.size.y * 0.5)   # the dock's own padding: no control under it
	await _mouse_to(edge)
	await process_frame
	_check(dock.pointer_over() and player.mouse_over_ui(), "the pointer on the dock counts as over the UI")
	for i in 8:
		await physics_frame
	_check(player.aim_direction.distance_to(aim_game) < 0.02 and player.aim_direction.x < -0.5, "aim keeps its last value while the pointer is on the dock")
	var slot0: int = lo.selected_slot
	var slider: HSlider = null
	for row in dock._rows.values():
		if row[0]._slider != null:
			slider = row[0]._slider
			break
	_check(slider != null, "BodyRig has a row with a slider")
	var sv: float = slider.value
	var sp := slider.get_global_rect().get_center()
	await _mouse_to(sp)
	await process_frame
	for k in 3:
		_button(sp, MOUSE_BUTTON_WHEEL_DOWN, true)
		_button(sp, MOUSE_BUTTON_WHEEL_DOWN, false)
	await create_timer(0.4).timeout
	_check(lo.selected_slot == slot0, "wheel over the dock does not change the hotbar slot")
	_check(slider.value == sv, "wheel over a slider does not change it (scrollable = false)")
	await _mouse_to(edge)
	await process_frame
	_button(edge, MOUSE_BUTTON_LEFT, true)
	for i in 4:
		await physics_frame
	_check(wh.phase == WeaponHolder.Phase.IDLE, "a mouse press on the dock starts no attack")
	_button(edge, MOUSE_BUTTON_LEFT, false)
	for i in 4:
		await physics_frame
	# control: the same press over the game DOES attack
	await _mouse_to(Vector2(20, 300))
	await process_frame
	await physics_frame
	_button(Vector2(20, 300), MOUSE_BUTTON_LEFT, true)
	var swung := false
	for i in 6:
		await physics_frame
		swung = swung or wh.phase != WeaponHolder.Phase.IDLE
	_button(Vector2(20, 300), MOUSE_BUTTON_LEFT, false)
	_check(swung, "control: the same press over the game starts an attack")
	for i in 90:
		await physics_frame

	# --- typing in a field: the player stays; Esc leaves the field and does not pause ---
	player.aim_override = Vector2.RIGHT
	var pos0: Vector2 = player.global_position
	var search := dock.search_field()
	search.grab_focus()
	await process_frame
	_check(root.gui_get_focus_owner() == search and dock.is_typing(), "the search field took focus")
	Input.action_press("move_right")
	for i in 20:
		await physics_frame
	_check(player.global_position.is_equal_approx(pos0), "typing in the search field: game keys do not move the player")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	_check(root.gui_get_focus_owner() == null and not paused, "first Esc leaves the field, the pause menu does not see it")
	for i in 20:
		await physics_frame
	_check(player.global_position.x > pos0.x + 15.0, "focus gone: the player moves again")
	Input.action_release("move_right")
	var esc_up := esc.duplicate() as InputEventKey
	esc_up.pressed = false
	Input.parse_input_event(esc_up)
	await process_frame
	Input.parse_input_event(esc)
	await process_frame
	await process_frame
	_check(paused, "second Esc pauses (the old order resumes)")
	paused = false

	# --- the camera slides left while the dock is open ---
	var cam := root.get_camera_2d()
	for i in 90:
		await process_frame
	_check(cam != null and absf(cam.position.x - dock.occupied_width() * 0.5 / cam.zoom.x) < 1.0, "camera is offset by half the dock (%.1f)" % (cam.position.x if cam else -1.0))
	panel.visible = false
	for i in 120:
		await process_frame
	_check(absf(cam.position.x) < 1.0, "and eases back when F3 closes")

	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
