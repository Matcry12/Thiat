extends SceneTree
# F3 at start: saved Map edits are in before the map's FIRST build (one build, not two), the startup toast shows with F3 closed,
# an edit for a section that appears later (a weapon picked up) is applied when it appears, opening a big section is quick,
# and the rig-driven Hands numbers are not Hands rows (BodyRig owns them).
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var cfg := "user://test_f3_startup.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	# 1. write a store with a heavy Map edit + an edit for a section that does not exist yet
	var probe = load("res://scenes/arena.tscn").instantiate()
	root.add_child(probe)
	await process_frame
	var pmap: ArenaMap = probe.get_node("ArenaMap")
	var base_share := pmap.land_share
	var o := F3Overrides.new(cfg)
	o.set_override("Map", pmap, "land_share", base_share + 0.05)
	o.set_override("Late", pmap, "map_cols", 700)   # (any object: only its name matters, it is looked up by section)
	await process_frame
	root.remove_child(probe)
	probe.free()

	# 2. a fresh arena reads that file and applies it
	TuningPanel.test_cfg_path = cfg
	TuningPanel.test_force = true
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	for i in 8:
		await process_frame
	var map: ArenaMap = arena.get_node("ArenaMap")
	var panel: TuningPanel = arena.get_node("TuningPanel")
	_check(is_equal_approx(map.land_share, base_share + 0.05), "saved Map edit is applied")
	_check(map.build_count == 1, "ONE map build at start (%d)" % map.build_count)
	_check(not panel.visible and panel.toast.visible and panel.last_toast.begins_with("1 F3 overrides applied"), "startup toast shows with F3 closed: " + panel.last_toast)
	_check(panel.stale.get("unknown", []).has("Late"), "the section that is not there yet is reported, not lost")

	# 3. the section appears later: its edit goes in
	var gd := GDScript.new()
	gd.source_code = "extends Node\n@export var map_cols := 512\nfunc debug_name(): return 'Late'\nfunc debug_category(): return 'Misc'\n"
	gd.reload()
	var late := Node.new()
	late.set_script(gd)
	late.add_to_group("debug")
	arena.add_child(late)
	await create_timer(1.5).timeout   # F3 stays closed: the panel looks again by itself while edits wait
	_check(not panel.visible, "(F3 closed)")
	_check(late.map_cols == 700, "an edit for a section that shows up later is applied (%d)" % late.map_cols)
	_check(panel.stale.get("unknown", []).is_empty(), "nothing unknown any more")

	# 4. opening a big section
	panel.cycle()
	await process_frame
	panel.dock.show_tab("Tune")
	var t0 := Time.get_ticks_msec()
	panel.dock.open_section("Map")
	var ms := Time.get_ticks_msec() - t0
	_check(panel.dock.row_count() > 100 and ms < 600, "Map section: %d rows in %d ms" % [panel.dock.row_count(), ms])
	t0 = Time.get_ticks_usec()
	for i in 20:
		panel.dock.sync_all()
	var sync_ms := (Time.get_ticks_usec() - t0) / 20000.0
	_check(sync_ms < 10.0, "steady sync with Map open: %.2f ms" % sync_ms)
	t0 = Time.get_ticks_usec()
	panel.rescan()
	_check((Time.get_ticks_usec() - t0) < 20000, "rescan with nothing changed: %d us" % (Time.get_ticks_usec() - t0))

	# 5. Hands: the rig owns those numbers
	_check(not panel.settings.has("Hands.hand_radius") and not panel.settings.has("Hands.idle_front") and panel.settings.has("BodyRig.hand_radius"), "hand numbers are BodyRig rows only")

	TuningPanel.test_cfg_path = ""
	TuningPanel.test_force = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
