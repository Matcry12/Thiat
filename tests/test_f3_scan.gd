extends SceneTree
# F3 extension contract: a node that joins group "debug" at runtime (with an @export, debug_actions, status_text) shows up in
# the dock - its section, its button, its status block - the next time F3 opens, with no change in the panel.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	for i in 6:
		await process_frame
	var panel: TuningPanel = arena.get_node("TuningPanel")
	panel.use_overrides(F3Overrides.new("user://test_f3_scan.cfg"))
	_check(not panel.settings.has("Fake.gain"), "no Fake section yet")

	var gd := GDScript.new()
	gd.source_code = "extends Node\n@export var gain := 1.5\nvar poked := 0\nvar flag := false\nfunc debug_name(): return 'Fake'\nfunc debug_category(): return 'Run'\nfunc debug_actions(): return [{'label': 'Fake poke', 'run': func(): poked += 1}, {'label': 'Fake flag', 'toggle': func(): return flag, 'run': func(): flag = not flag}, {'label': 'Fake wipe', 'danger': true, 'run': func(): poked = -1}]\nfunc status_text(): return 'fake ok ' + str(poked)\n"
	_check(gd.reload() == OK, "fake script compiles")
	var fake := Node.new()
	fake.set_script(gd)
	fake.add_to_group("debug")
	arena.add_child(fake)

	panel.cycle()   # off -> full: the dock opens and rescans
	await process_frame
	await process_frame
	_check(panel.mode() == "full", "F3 open")
	_check(panel.settings.has("Fake.gain") and panel.settings["Fake.gain"]["obj"] == fake, "its @export is a setting")
	_check(panel._sections.any(func(s): return s["name"] == "Fake" and s["cat"] == "Run"), "section in its own category")
	var labels: Array = panel.dock.action_labels()
	_check(labels.has("Fake poke") and labels.has("Fake wipe"), "its actions are buttons")
	_check(panel.status_view.row_names().has("Fake"), "its status block is listed")
	panel.status_view.toggle_open("Fake")
	await process_frame
	_check(str(panel.status_view._rows["Fake"].summary.text).contains("fake ok"), "and shows its text")

	# the buttons work
	var stack: Array = [panel.dock]
	var poke: Button
	var flag_btn: Button
	var wipe: Button
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Button and n.text == "Fake poke":
			poke = n
		elif n is Button and n.text.begins_with("Fake flag"):
			flag_btn = n
		elif n is Button and n.text == "Fake wipe":
			wipe = n
	poke.pressed.emit()
	_check(fake.poked == 1, "action runs")
	_check(flag_btn.text.ends_with("off"), "toggle shows off")
	flag_btn.pressed.emit()
	_check(fake.flag and flag_btn.text.ends_with("on"), "toggle flips and shows on")
	wipe.pressed.emit()
	_check(fake.poked == 1 and wipe.text.begins_with("Sure?"), "danger needs a second click")
	wipe.pressed.emit()
	_check(fake.poked == -1, "second click runs it")

	# an edit on it is an override
	panel.apply_value("Fake.gain", 3.0)
	_check(fake.gain == 3.0 and panel.overrides.has_override("Fake", "gain"), "edits become overrides")

	# gone again after the node leaves and F3 reopens
	panel.cycle()
	panel.cycle()
	fake.queue_free()
	await process_frame
	panel.cycle()
	await process_frame
	_check(not panel.settings.has("Fake.gain") and not panel.status_view.row_names().has("Fake") and not panel.dock.action_labels().has("Fake poke"), "removed node disappears on the next open")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_f3_scan.cfg"))
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
