extends SceneTree
# F3 `Write K to .tres`: a live BodyRig edit becomes an override, and Write puts it into the rig's own .tres
# (only the changed value, sprite_frames link kept); then the repo file is put back as it was.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	for i in 5:
		await process_frame
	var panel: TuningPanel = arena.get_node("TuningPanel")
	panel.use_overrides(F3Overrides.new("user://test_save_rig.cfg"))
	var rig: BodyRig = arena.get_node("Player").visual.rig
	var path := rig.resource_path
	var original := FileAccess.get_file_as_string(path)
	var old_back: float = rig.slash_scale
	panel.apply_value("BodyRig.slash_scale", 1.25)
	_check(panel.overrides.count() == 1 and panel.overrides.tres_count() == 1, "the edit is one override that can go to .tres")
	_check(FileAccess.get_file_as_string(path) == original, "nothing is written before Write")
	panel.footer._write.pressed.emit()   # the footer button
	var saved := FileAccess.get_file_as_string(path)
	_check(saved.contains("slash_scale = 1.25"), "rig file holds the new value")
	_check(saved.contains("sprite_frames = ExtResource("), "rig file keeps its sprite frames link")
	_check(panel.overrides.count() == 0, "written overrides are dropped from the cfg")
	_check(not panel.is_changed("BodyRig.slash_scale"), "the written value is the new startup value (row no longer marked)")
	var f := FileAccess.open(path, FileAccess.WRITE)   # put the repo file back
	f.store_string(original)
	f.close()
	rig.slash_scale = old_back
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save_rig.cfg"))
	quit(0 if _ok else 1)
