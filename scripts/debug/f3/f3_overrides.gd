class_name F3Overrides
extends RefCounted
# F3 persistence: live tuning edits live in a ConfigFile (section = debug_name, key = prop).
# Each override keeps `value` and `base` (what the object had before the first F3 change).
# Resource overrides also remember their .tres path so they can be written back later.

const PINS := "_pins"
const BASE := "base:"      # key prefix for the stored base value
const PATH := "__path"     # key holding the resource path of the section's object

var path := "user://tuning.cfg"
var force := false         # tests only: apply even in headless
var _cfg := ConfigFile.new()

func _init(p := "user://tuning.cfg") -> void:
	path = p
	_cfg.load(path)   # missing file is fine

func _save() -> void:
	_cfg.save(path)

func set_override(section: String, obj: Object, prop: String, value) -> void:
	if not _cfg.has_section_key(section, BASE + prop):
		_cfg.set_value(section, BASE + prop, obj.get(prop))   # first base wins
	_cfg.set_value(section, prop, value)
	if can_write_to_tres(obj):
		_cfg.set_value(section, PATH, (obj as Resource).resource_path)
	_save()

func clear(section: String, prop: String) -> void:
	if not _cfg.has_section_key(section, prop):
		return
	_cfg.erase_section_key(section, prop)
	_cfg.erase_section_key(section, BASE + prop)
	_drop_empty(section)
	_save()

func clear_all() -> void:
	for s in _sections():
		_cfg.erase_section(s)
	_save()

func _drop_empty(section: String) -> void:
	if _props(section).is_empty() and _cfg.has_section(section):
		_cfg.erase_section(section)

func _sections() -> Array:
	return Array(_cfg.get_sections()).filter(func(s): return s != PINS)

func _props(section: String) -> Array:
	if not _cfg.has_section(section):
		return []
	return Array(_cfg.get_section_keys(section)).filter(
		func(k): return k != PATH and not k.begins_with(BASE))

func count() -> int:
	var n := 0
	for s in _sections():
		n += _props(s).size()
	return n

func get_base(section: String, prop: String):
	return _cfg.get_value(section, BASE + prop)

func has_override(section: String, prop: String) -> bool:
	return _cfg.has_section_key(section, prop)

func get_value(section: String, prop: String):
	return _cfg.get_value(section, prop)

# lookup: Callable(section) -> Object or null; `skip` = sections to leave alone (already applied). `sections` in the result = those found.
# lookup: Callable(section) -> Object or null. Returns {applied, stale (texts), stale_keys ([section, prop] pairs), unknown (sections)}.
func apply_all(lookup: Callable, skip: Dictionary = {}) -> Dictionary:
	var res := {"applied": 0, "stale": [], "stale_keys": [], "unknown": [], "sections": []}
	if DisplayServer.get_name() == "headless" and not force:
		return res
	for s in _sections():
		if skip.has(s):   # applied by an earlier call
			continue
		var obj = lookup.call(s)
		if obj == null:
			res.unknown.append(s)
			continue
		res["sections"].append(s)
		for p in _props(s):
			var base = _cfg.get_value(s, BASE + p)
			var cur = obj.get(p)
			if cur != base:
				res.stale.append("%s.%s  cfg %s / file %s" % [s, p, base, cur])
				res.stale_keys.append([s, p])
				continue
			obj.set(p, _cfg.get_value(s, p))
			res.applied += 1
	return res

static func can_write_to_tres(obj: Object) -> bool:
	if not (obj is Resource):
		return false
	var rp: String = (obj as Resource).resource_path
	return rp.ends_with(".tres") and not rp.contains("::")

# Write one section's props into a fresh copy of its .tres, then drop them from the cfg.
# Returns {written: int, errors: Array}.
func write_to_tres(section: String) -> Dictionary:
	var res := {"written": 0, "errors": []}
	var rp = _cfg.get_value(section, PATH, "")
	if rp == "":
		res.errors.append("%s: scene-only, no .tres" % section)
		return res
	var fresh = ResourceLoader.load(rp, "", ResourceLoader.CACHE_MODE_IGNORE)
	if fresh == null:
		res.errors.append("%s: cannot load %s" % [section, rp])
		return res
	var props := _props(section)
	for p in props:
		fresh.set(p, _cfg.get_value(section, p))
	var err := ResourceSaver.save(fresh, rp)
	if err != OK:
		res.errors.append("%s: save failed (%d)" % [section, err])
		return res
	for p in props:
		_cfg.erase_section_key(section, p)
		_cfg.erase_section_key(section, BASE + p)
	res.written = props.size()
	_cfg.erase_section(section)
	_save()
	return res

func write_all_tres() -> Dictionary:
	var res := {"written": 0, "errors": []}
	for s in _sections():
		if _cfg.get_value(s, PATH, "") == "":
			continue
		var r := write_to_tres(s)
		res.written += r.written
		res.errors.append_array(r.errors)
	return res

# Override list for the UI: [[section, prop]].
func keys() -> Array:
	var out := []
	for s in _sections():
		for p in _props(s):
			out.append([s, p])
	return out

func is_tres_section(section: String) -> bool:
	return _cfg.get_value(section, PATH, "") != ""

# How many overrides can go to .tres vs are scene-only.
func tres_count() -> int:
	var n := 0
	for s in _sections():
		if _cfg.get_value(s, PATH, "") != "":
			n += _props(s).size()
	return n

func get_pins() -> Array:
	return _cfg.get_value(PINS, "pins", [])

func set_pins(a: Array) -> void:
	_cfg.set_value(PINS, "pins", a)
	_save()

func get_pinned_status() -> Array:
	return _cfg.get_value(PINS, "status", [])

func set_pinned_status(a: Array) -> void:
	_cfg.set_value(PINS, "status", a)
	_save()
