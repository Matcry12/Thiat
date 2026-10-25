extends SceneTree
# F3Overrides: cfg round-trip, stale skip, unknown section, headless guard, write to a .tres copy.
var _ok := true

class Dummy extends RefCounted:
	var f := 1.5
	var i := 3
	var b := false
	var v := Vector2(1, 2)
	var c := Color(1, 0, 0)

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var cfg := "user://test_tuning.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	var o := F3Overrides.new(cfg)
	var d := Dummy.new()
	o.set_override("D", d, "f", 9.5)
	o.set_override("D", d, "f", 9.75)   # base stays 1.5
	o.set_override("D", d, "i", 7)
	o.set_override("D", d, "b", true)
	o.set_override("D", d, "v", Vector2(5, 6))
	o.set_override("D", d, "c", Color(0, 1, 0))
	o.set_pins(["D.f"])
	_check(o.count() == 5, "count 5")
	# headless: nothing applied without force
	var r0 := F3Overrides.new(cfg).apply_all(func(_s): return d)
	_check(r0.applied == 0, "headless skips apply")
	# fresh load round-trips every type
	var o2 := F3Overrides.new(cfg)
	o2.force = true
	var d2 := Dummy.new()
	var r := o2.apply_all(func(s): return d2 if s == "D" else null)
	_check(r.applied == 5 and d2.f == 9.75 and d2.i == 7 and d2.b and d2.v == Vector2(5, 6) and d2.c == Color(0, 1, 0), "round-trip all types")
	_check(o2.get_pins() == ["D.f"], "pins persist")
	# stale: base changed
	var d3 := Dummy.new()
	d3.f = 2.0
	var r3 := o2.apply_all(func(_s): return d3)
	_check(r3.stale.size() == 1 and r3.applied == 4 and d3.f == 2.0, "stale skipped")
	_check(str(r3.stale[0]).contains("cfg 1.5 / file 2.0"), "stale text")
	# unknown section
	var r4 := o2.apply_all(func(_s): return null)
	_check(r4.unknown == ["D"] and r4.applied == 0, "unknown reported")
	# clear
	o2.clear("D", "f")
	_check(o2.count() == 4, "clear one")
	o2.clear_all()
	_check(o2.count() == 0 and F3Overrides.new(cfg).count() == 0, "clear_all persists")

	# write_to_tres on a copy of a real rig
	var src := "res://data/body_rigs/tiny_soldier.tres"
	var tmp := "user://tiny_copy.tres"
	var orig_text := FileAccess.get_file_as_string(src)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(orig_text)
	f.close()
	var rig: BodyRig = ResourceLoader.load(tmp, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(F3Overrides.can_write_to_tres(rig), "can_write_to_tres on rig copy")
	_check(not F3Overrides.can_write_to_tres(rig.duplicate()), "duplicate (no path) cannot")
	_check(not F3Overrides.can_write_to_tres(d), "plain object cannot")
	var before_back := rig.hand_idle_back
	var before_scale := rig.visual_scale
	rig.hand_idle_back = Vector2(23, 7)
	rig.save_note = "runtime only"
	var o5 := F3Overrides.new(cfg)
	o5.set_override("Rig", rig, "hand_idle_back", Vector2(23, 7))
	var w := o5.write_to_tres("Rig")
	_check(w.written == 1 and w.errors.is_empty(), "wrote 1")
	var saved := FileAccess.get_file_as_string(tmp)
	_check(saved.contains("hand_idle_back = Vector2(23, 7)"), "file has new value")
	_check(saved.contains("sprite_frames = ExtResource("), "sprite_frames link kept")
	_check(not saved.contains("save_note"), "save_note not written")
	var back: BodyRig = ResourceLoader.load(tmp, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(back.visual_scale == before_scale and back.hand_idle_back == Vector2(23, 7) and back.hand_idle_back != before_back, "only changed prop differs")
	_check(o5.count() == 0, "keys dropped after write")
	# repo file untouched
	_check(FileAccess.get_file_as_string(src) == orig_text, "repo .tres untouched")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	quit(0 if _ok else 1)
