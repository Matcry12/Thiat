extends SceneTree
# F3 wiring: every edit is an override (survives a new store on the same file), Clear overrides needs a second click,
# stale ones are listed and droppable, F3 cycles full -> watch -> off, the Status tab feeds the watch card, the old wall is gone.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	for i in 5:
		await process_frame
	var panel: TuningPanel = arena.get_node("TuningPanel")
	var player = arena.get_node("Player")
	var cfg := "user://test_f3_wiring.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	panel.use_overrides(F3Overrides.new(cfg))
	var v0: float = player.speed

	# --- an edit is an override, kept on disk ---
	panel.apply_value("Player.speed", v0 + 40.0)
	_check(panel.overrides.has_override("Player", "speed") and panel.overrides.count() == 1, "an edit creates an override")
	var again := F3Overrides.new(cfg)
	_check(again.count() == 1 and again.get_value("Player", "speed") == v0 + 40.0, "it survives a new store on the same file")
	_check(panel.footer._info.text.begins_with("1 overrides") and panel.footer._chip.tooltip_text.contains("scene-only"), "footer counts it (scene node = scene-only)")
	panel.apply_value("Player.speed", v0)
	_check(panel.overrides.count() == 0, "back at the startup value: the override goes away")

	# --- startup: apply + stale ---
	panel.apply_value("Player.speed", v0 + 40.0)
	player.speed = v0 + 5.0   # the scene default changed since the edit
	var o2 := F3Overrides.new(cfg)
	o2.force = true
	panel.use_overrides(o2)
	panel._apply_overrides()
	_check(panel.stale["stale"].size() == 1 and player.speed == v0 + 5.0, "stale override is skipped, not applied")
	_check(panel.last_toast == "0 F3 overrides applied - 1 stale skipped", "startup toast text: " + panel.last_toast)
	_check(panel.footer._stale.visible and panel.footer._stale.tooltip_text.contains("Player.speed"), "stale button names it")
	panel.footer._stale.pressed.emit()
	_check(panel.overrides.count() == 0 and not panel.footer._stale.visible, "click drops the stale ones")
	player.speed = v0
	panel.overrides.force = true
	panel.apply_value("Player.speed", v0 + 40.0)
	panel.overrides.apply_all(panel._find_section)   # same value + base: applies
	_check(player.speed == v0 + 40.0, "apply_all puts an override back")

	# --- Clear overrides: second click within 2 s ---
	var clear: Button = panel.footer._clear
	clear.pressed.emit()
	_check(panel.overrides.count() == 1 and clear.text.begins_with("Sure?"), "first click only asks")
	clear.pressed.emit()
	_check(panel.overrides.count() == 0 and F3Overrides.new(cfg).count() == 0, "second click clears (and the file)")
	_check(player.speed == v0, "the live value is back at the startup value")
	panel.apply_value("Player.speed", v0 + 40.0)
	clear.pressed.emit()
	await create_timer(2.2).timeout
	_check(clear.text == "Clear" and panel.overrides.count() == 1, "after 2 s the ask lapses")
	panel.reset_value("Player.speed")
	_check(panel.overrides.count() == 0 and player.speed == v0, "row reset clears that override")

	# --- danger buttons in Actions ---
	panel.dock.flush(true)
	var dangers := 0
	var stack := [panel.dock]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Button and n.has_meta("armed") and n.text in ["Kill player", "Delete save", "Restart"]:
			dangers += 1
	_check(dangers == 3, "Kill player / Delete save / Restart are danger buttons (%d)" % dangers)

	# --- F3 cycle ---
	var cam: Camera2D = root.get_viewport().get_camera_2d()
	_check(panel.mode() == "off" and not panel.visible, "starts off")
	panel.cycle()
	for i in 60:
		await process_frame
	_check(panel.mode() == "full" and panel.dock.is_visible_in_tree() and panel.right_panel_width() > 300.0, "F3 once: dock + card")
	_check(cam.position.x > 100.0, "camera is shifted for the dock")
	panel.cycle()
	for i in 90:
		await process_frame
	_check(panel.mode() == "watch" and not panel.dock.is_visible_in_tree() and panel.right_panel_width() == 0.0, "F3 twice: watch only, no dock")
	_check(absf(cam.position.x) < 1.0, "camera is back where it was")
	panel.cycle()
	_check(panel.mode() == "off" and not panel.visible, "F3 thrice: off")
	panel.cycle()
	_check(panel.mode() == "full" and panel.dock.visible, "and round again to full")

	# --- Status tab -> watch card ---
	panel.status_view.toggle_pin("Engine")
	panel.apply_value("Player.speed", v0 + 40.0)
	panel.cycle()   # watch
	for i in 40:
		await process_frame
	_check(panel.overrides.get_pinned_status() == ["Engine"], "pinned status names persist in the store")
	_check(panel.card.visible and panel.card.shown_text().contains("Engine") and panel.card.shown_text().contains("fps"), "watch card shows the pinned block")
	_check(panel.card.shown_text().contains("1 F3 overrides"), "and the override count")
	_check(F3Overrides.new(cfg).get_pinned_status() == ["Engine"], "pinned status is in the cfg file")
	_check(panel.status_view.row_names().size() >= 20, "Status tab lists every block (%d)" % panel.status_view.row_names().size())

	# --- the old wall is gone ---
	var wall := false
	stack = [panel]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Label and (n.text.contains("[Engine]") or n.text.contains("[Weapon]")):
			wall = true
	_check(not wall and panel.get("_status_label") == null and panel.get("_status_panel") == null, "no status wall in the tree")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
