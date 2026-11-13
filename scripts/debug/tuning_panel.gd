extends CanvasLayer
class_name TuningPanel
## F3 panel. It owns NO list of what is tunable: every node in group "debug" says who it is (debug_name / debug_category),
## what it contains (debug_children), its buttons (debug_actions), its status (status_text) and which numbers rebuild the world
## (debug_heavy). The panel rescans on start and every time F3 opens, so a new feature needs zero edits here.
## What it adds itself: the dock, overrides (F3Overrides), status view + watch card, the world-map picture.
## Contract: tools/f3_mock/DESIGN.md "Extension contract", tests/test_debug_contract.gd.

const WORLD_MAP_PANEL := preload("res://scripts/debug/world_map_panel.gd")

@export var enabled_in_release := false
@export var map_path: NodePath   # saved Map / Biome edits are applied through this before the map's first build

## Tests: another cfg file, and apply saved edits even in a headless run.
static var test_cfg_path := ""
static var test_force := false
## Reflection is the slow part of a scan; the property list of a script never changes, so it is read once per script.
static var _prop_cache := {}

var _player: CharacterBody2D
var _map: ArenaMap
var _world_map: PanelContainer   # WorldMapPanel

## Every F3 edit lives here (user://tuning.cfg); a headless run gets its own throw-away file, never applied.
var overrides: F3Overrides
var dock: F3Dock
var status_view: F3StatusView     # Status tab
var card: F3WatchCard             # pinned status blocks + override count, over the game (click-through)
var toast: F3Toast
var footer: F3Footer
var stale: Dictionary = {}        # last apply_all result: {stale, stale_keys, unknown}
## Every tunable setting, "Section.prop" -> {key, section, name, type, group, obj, heavy, range?}. The dock reads it; rows are built lazily from it.
var settings: Dictionary:
	get:
		_ensure_scanned()
		return _settings
var _settings: Dictionary = {}
var _sections: Array = []         # [{name, cat, obj, heavy, props: [info]}] in scan order (use sections())
var _initial_values: Dictionary = {}  # "Section.prop" -> value at first sight, for the reset arrows
var last_toast := ""
var _pend_left := 1.0
var _tally := [0, 0]            # [applied, stale] not yet told in a toast
var _applied := {}               # override sections already put on their object
var _scan_sig := ""
var _scanned := false
var _toast_layer: CanvasLayer
var _card_left := 0.0
var _ready_done := false


func _dev_enabled() -> bool:
	return enabled_in_release or OS.is_debug_build()


func _enter_tree() -> void:
	if not _dev_enabled():
		return   # an exported game never applies dev tuning
	# The map builds itself in its own _ready, which comes before ours: saved Map / Biome / Ground edits go in NOW, so the first
	# build already has them (a second build at every start would cost seconds).
	overrides = F3Overrides.new(_cfg_path())
	overrides.force = test_force
	var map := get_node_or_null(map_path) as ArenaMap
	if map and overrides.count() > 0:
		var r := overrides.apply_all(func(sec: String):
			if sec == "Map":
				return map
			if map.style:
				for bd in map.style.biomes:
					if sec == "Biome " + bd.label:
						return bd
			return null)
		_note_applied(r)


func _ready() -> void:
	if not _dev_enabled():
		queue_free()
		return
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	_map = get_tree().get_first_node_in_group("arena_map") as ArenaMap
	_build_ui()
	visible = false
	visibility_changed.connect(func(): if visible and _ready_done: rescan())
	# Nothing is scanned until F3 opens (or something asks for `settings`) - except when saved edits wait for their objects.
	# Some nodes overwrite their own @exports a moment after startup (the rig drives the body), and the arena joins the group last:
	# so that scan waits 3 frames.
	if overrides.count() > 0:
		for _f in 3:
			await get_tree().process_frame
		rescan(true)
	_ready_done = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_panel"):
		cycle()


## F3 states: off -> full (dock + card) -> watch (card only, no dock, camera back) -> off.
func mode() -> String:
	if not visible:
		return "off"
	return "full" if dock == null or dock.visible else "watch"


func cycle() -> void:
	match mode():
		"off":
			dock.visible = true
			visible = true
		"full":
			dock.visible = false
		"watch":
			visible = false
			dock.visible = true


func _process(_delta: float) -> void:
	if not visible:
		_pend_left -= _delta   # F3 closed: saved edits for a section that is not there yet (a bow picked up) go in when it shows up
		if _pend_left <= 0.0:
			_pend_left = 1.0
			if _ready_done and _pending_count() > 0:
				rescan()
		return
	_place_card()
	_card_left -= _delta
	if _card_left <= 0.0:
		_card_left = 1.0 / maxf(status_view.refresh_rate, 0.1)
		card.set_blocks(status_view.pinned_blocks())


# ------------------------------------------------------------------ scan ---

## Walk the "debug" group (+ debug_children, recursively) and rebuild sections, settings, the Actions tab and the status providers.
func rescan(fresh := false) -> void:
	var entries: Array = []
	for n in get_tree().get_nodes_in_group("debug"):
		if n.has_method("debug_name"):
			_walk(n.debug_name(), n, n.debug_category() if n.has_method("debug_category") else "Misc", entries)
	var sig := _signature(entries)
	if sig == _scan_sig and _scanned and not fresh:
		return   # the same nodes, children and buttons as last time: nothing to do (opening F3 costs next to nothing)
	_scan_sig = sig
	_scanned = true
	if fresh:
		_initial_values.clear()
	var prev := _settings.duplicate()
	_sections.clear()
	_settings.clear()
	var seen := {}
	var providers: Array = [{"name": "Engine", "text": func():   # panel-only: not a game node
		var fps := Engine.get_frames_per_second()
		return "fps: %d  frame: %.1f ms  time_scale: %.2f" % [fps, 1000.0 / maxf(fps, 1.0), Engine.time_scale]}]
	var groups: Array = []
	for e in entries:
		if seen.has(e["name"]):
			continue
		seen[e["name"]] = true
		_index_target(e["name"], e["object"], e["cat"], prev)
		var o: Object = e["object"]
		if o.has_method("status_text"):
			providers.append({"name": e["name"], "text": func(): return str(o.status_text()) if is_instance_valid(o) else "gone"})
		if o.has_method("debug_actions"):
			groups.append({"title": e["name"], "actions": o.debug_actions()})
	if _map:   # panel-only: the world picture
		var extra := {"label": "World map", "run": func(): _world_map.toggle()}
		var g = groups.filter(func(x): return x["title"] == _map.debug_name())
		if g.is_empty():
			groups.append({"title": "F3", "actions": [extra]})
		else:
			g[0]["actions"].append(extra)
	if dock:
		dock.set_actions(groups)
		dock.refresh()
	if status_view:
		status_view.set_providers(providers, overrides.get_pinned_status())
	_apply_pending()


func _ensure_scanned() -> void:
	if not _scanned and is_inside_tree():
		rescan()


func sections() -> Array:
	_ensure_scanned()
	return _sections


## Same set of nodes + children + buttons = same signature.
func _signature(entries: Array) -> String:
	var parts := PackedStringArray()
	for e in entries:
		var o: Object = e["object"]
		var line: String = "%s#%d" % [e["name"], o.get_instance_id()]
		if o.has_method("debug_actions"):
			for a in o.debug_actions():
				line += "|" + String(a["label"])
		parts.append(line)
	return ";".join(parts)

func _walk(name_: String, obj: Object, cat: String, out: Array) -> void:
	out.append({"name": name_, "object": obj, "cat": cat})
	if obj.has_method("debug_children"):
		for c in obj.debug_children():
			if c.get("object") != null:
				_walk(c["name"], c["object"], c.get("cat", cat), out)


## Lists one target's tunable properties (reflection) into `settings` / `_sections`. No widgets: the dock builds rows lazily.
func _index_target(target_name: String, obj: Object, cat: String, prev: Dictionary) -> void:
	var props := _collect_tunable_properties(obj)
	if props.is_empty():
		return
	var sec := {"name": target_name, "cat": cat, "obj": obj, "heavy": false, "props": []}
	for info in props:
		var key := "%s.%s" % [target_name, info["name"]]
		info["key"] = key
		info["section"] = target_name
		info["obj"] = obj
		info["heavy"] = obj.has_method("debug_heavy") and obj.debug_heavy(info["name"])
		sec["heavy"] = sec["heavy"] or info["heavy"]
		_settings[key] = info
		if not (prev.has(key) and prev[key]["obj"] == obj and _initial_values.has(key)):
			var v = obj.get(info["name"])
			# an edit already put in (before the map's first build): the startup value is the one it was saved over
			if overrides and overrides.has_override(target_name, info["name"]) and v == overrides.get_value(target_name, info["name"]):
				v = overrides.get_base(target_name, info["name"])
			_initial_values[key] = v
		sec["props"].append(info)
	_sections.append(sec)


# ------------------------------------------------------------- reflection ---

func _collect_tunable_properties(obj: Object) -> Array:
	var sc = obj.get_script()
	if sc != null and _prop_cache.has(sc):
		return _prop_cache[sc].map(func(i): return i.duplicate())
	var result := _reflect(obj)
	if sc != null:
		_prop_cache[sc] = result.map(func(i): return i.duplicate())
	return result


func _reflect(obj: Object) -> Array:
	var result: Array = []
	var group := ""   # @export_group title: the properties after it belong to it, until the next group
	for prop in obj.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_CATEGORY != 0:
			group = ""   # a new class in the chain (the script's own): the engine's "Transform" group does not carry over
			continue
		if usage & PROPERTY_USAGE_GROUP != 0:
			group = prop["name"]
			continue
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		if usage & PROPERTY_USAGE_EDITOR == 0:
			continue
		var t: int = prop["type"]
		if t != TYPE_FLOAT and t != TYPE_INT and t != TYPE_BOOL and t != TYPE_VECTOR2 and t != TYPE_COLOR:
			continue
		var info := {"name": prop["name"], "type": t, "group": group}
		var rng = _known_range(prop)
		if rng != null:
			info["range"] = rng
			var hs := String(prop["hint_string"])
			info["or_greater"] = hs.contains("or_greater")   # the field / scrub may go past the slider end
			info["or_less"] = hs.contains("or_less")
		result.append(info)
	return result


## A slider exists only when the range is KNOWN: an @export_range hint.
## Returns Vector3(min, max, step) or null. (Numbers without a range get a number field + scrub, no slider.)
func _known_range(prop: Dictionary):
	var t: int = prop["type"]
	if t != TYPE_FLOAT and t != TYPE_INT:
		return null
	var pn: String = prop["name"]
	var step := 1.0 if t == TYPE_INT else 0.0
	var lo := 0.0
	var hi := 0.0
	var found := false
	if int(prop["hint"]) == PROPERTY_HINT_RANGE:
		var parts := String(prop["hint_string"]).split(",")
		if parts.size() >= 2 and parts[0].is_valid_float() and parts[1].is_valid_float():
			lo = float(parts[0])
			hi = float(parts[1])
			if parts.size() >= 3 and parts[2].is_valid_float() and float(parts[2]) > 0.0:
				step = float(parts[2])
			found = true
	if not found:
		return null
	if t == TYPE_FLOAT and step <= 0.0:
		step = nice_step((hi - lo) / 200.0)
	return Vector3(lo, hi, step)


## A round step near `x`: 1, 2 or 5 times a power of ten (so a slider reads 10, 12, 14 and not 10.95, 11.9).
static func nice_step(x: float) -> float:
	x = maxf(x, 0.0001)
	var e := pow(10.0, floorf(log(x) / log(10.0)))
	var m := x / e
	return (1.0 if m < 1.5 else 2.0 if m < 3.5 else 5.0 if m < 7.5 else 10.0) * e


# --------------------------------------------------------------------- UI ---

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	dock = F3Dock.new()
	root.add_child(dock)
	dock.setup(self, _sections)

	status_view = F3StatusView.new()
	status_view.art_scale = dock.art_scale
	dock.attach_status(status_view)
	status_view.pinned_changed.connect(func(names: Array):
		overrides.set_pinned_status(names)
		card.set_blocks(status_view.pinned_blocks()))
	card = F3WatchCard.new()
	card.theme = dock.theme   # the one look (F3Theme): the note is outside the dock tree
	root.add_child(card)
	toast = F3Toast.new()
	toast.theme = dock.theme
	_toast_layer = CanvasLayer.new()   # its own layer: the startup toast must show with F3 closed
	_toast_layer.layer = 128
	add_child(_toast_layer)
	_toast_layer.add_child(toast)
	footer = F3Footer.new()
	dock.footer_box().add_child(footer)
	footer.setup(self)

	if _map:   # F3 "World map": the whole island as a picture, just left of the dock
		_world_map = WORLD_MAP_PANEL.new()
		_world_map.setup(_map, _player)
		_world_map.anchor_left = 1.0
		_world_map.anchor_right = 1.0
		_world_map.offset_right = -(dock.occupied_width() + 8.0)
		_world_map.offset_left = _world_map.offset_right - _world_map.map_width - 12
		_world_map.offset_top = 8
		_world_map.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		root.add_child(_world_map)
		dock.extra_ui.append(_world_map)   # a click on the picture is a click on F3, not an attack


func initial_value(key: String):
	return _initial_values[key]


func is_changed(key: String) -> bool:
	if not settings.has(key):
		return false
	var info: Dictionary = settings[key]
	var a = info["obj"].get(info["name"])
	var b = _initial_values[key]
	return not is_equal_approx(a, b) if typeof(a) == TYPE_FLOAT and typeof(b) == TYPE_FLOAT else a != b


func changed_count(props: Array) -> int:
	var n := 0
	for info in props:
		if is_changed(info["key"]):
			n += 1
	return n


# ------------------------------------------------------- apply / overrides ---

func _cfg_path() -> String:
	if test_cfg_path != "":
		return test_cfg_path
	if DisplayServer.get_name() == "headless":   # test runs never touch the real file
		var p := "user://tuning_headless.cfg"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		return p
	return "user://tuning.cfg"


## Tests and shots: swap in another store.
func use_overrides(o: F3Overrides) -> void:
	overrides = o
	_applied.clear()
	stale = {}
	_tally = [0, 0]
	_scan_sig = ""   # force one scan (it also applies what the new store holds, when its force flag allows)
	rescan()
	dock.reload_pins()
	refresh_footer()


func _find_section(name_: String):
	for sec in _sections:
		if sec["name"] == name_:
			return sec["obj"]
	return null


## Saved edits whose object exists now and have not been put back yet (start, and every scan: a weapon picked up later brings its edits).
func _apply_pending() -> void:
	if overrides.count() == 0:
		return
	var r := overrides.apply_all(_find_section, _applied)
	_note_applied(r)
	stale["unknown"] = r["unknown"]
	refresh_footer()
	_flush_toast()


func _pending_count() -> int:
	var n := 0
	for sp in overrides.keys():
		if not _applied.has(sp[0]):
			n += 1
	return n


func _note_applied(r: Dictionary) -> void:
	for sec in r["sections"]:
		_applied[sec] = true
	_tally[0] += r["applied"]
	_tally[1] += r["stale"].size()
	stale["stale"] = stale.get("stale", []) + r["stale"]
	stale["stale_keys"] = stale.get("stale_keys", []) + r["stale_keys"]


## "N F3 overrides applied - M stale skipped": at the top of the game even with F3 closed.
func _flush_toast() -> void:
	if _tally[0] + _tally[1] > 0 and toast:
		last_toast = "%d F3 overrides applied - %d stale skipped" % _tally
		toast.show_toast(last_toast, -1.0, right_panel_width())
		_tally = [0, 0]


## Tests: forget what was applied and do it again.
func _apply_overrides() -> void:
	_applied.clear()
	stale = {}
	_apply_pending()


## Single entry point for every value change from outside the dock (tests, startup).
## Sets the property and records it as an override (or drops the override when it is back at the startup value).
func apply_value(key: String, value) -> void:
	if not settings.has(key):
		return
	var info: Dictionary = settings[key]
	var obj: Object = info["obj"]
	var prop: String = info["name"]
	var old = obj.get(prop)
	var new_value
	match int(info["type"]):
		TYPE_BOOL: new_value = bool(value)
		TYPE_INT: new_value = roundi(float(value))
		TYPE_FLOAT: new_value = float(value)
		_: new_value = value
	if overrides:
		if _initial_values.has(key) and not is_changed_value(key, new_value):
			overrides.clear(info["section"], prop)
		else:
			overrides.set_override(info["section"], obj, prop, new_value)   # (the base is read before the set below)
	obj.set(prop, new_value)
	if dock:
		dock.sync_key(key)
	refresh_footer()
	print("%s: %s -> %s" % [key, old, new_value])


## What the dock rows call. A heavy value (it rebuilds the map) shows the banner first, lets one frame draw it, then rebuilds.
func request_value(key: String, value) -> void:
	if not (settings.has(key) and settings[key]["heavy"]) or dock == null or not is_inside_tree():
		apply_value(key, value)
		return
	dock.show_banner("Rebuilding map…")
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	apply_value(key, value)
	if _map:
		_map._apply_pending_now()   # run the queued rebuild now so the time is real
	dock.show_banner("last rebuild %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0), 3.0)


## The row reset arrow: back to the startup value, and the override goes away.
func reset_value(key: String) -> void:
	if settings.has(key):
		apply_value(key, _initial_values[key])


func is_changed_value(key: String, v) -> bool:
	var b = _initial_values[key]
	return not is_equal_approx(v, b) if typeof(v) == TYPE_FLOAT and typeof(b) == TYPE_FLOAT else v != b


func refresh_footer() -> void:
	if footer:
		footer.refresh()
	if card:
		card.set_override_count(overrides.count())


## Footer `Write K to .tres`: the overrides of resource sections go into a fresh copy of each file. Those values are the new startup values.
func write_to_tres() -> Dictionary:
	var keys := []   # panel keys that will be written
	for sec in _sections:
		if overrides.is_tres_section(sec["name"]):
			for info in sec["props"]:
				if overrides.has_override(sec["name"], info["name"]):
					keys.append(info["key"])
	var res := overrides.write_all_tres()
	for k in keys:
		if not overrides.has_override(settings[k]["section"], settings[k]["name"]):   # written (a failed section keeps its keys)
			_initial_values[k] = settings[k]["obj"].get(settings[k]["name"])
	for e in res["errors"]:
		printerr("F3 write: ", e)
	if dock:
		dock.refresh()
	refresh_footer()
	if toast:
		toast.show_toast("Wrote %d to .tres%s" % [res["written"], "" if res["errors"].is_empty() else " - %d errors (see log)" % res["errors"].size()], -1.0, right_panel_width())
	return res


## Footer `Clear overrides`: forget them all and put the live values back to the startup ones.
func clear_overrides() -> void:
	var back := []
	for sp in overrides.keys():
		for k in settings:
			if settings[k]["section"] == sp[0] and settings[k]["name"] == sp[1]:
				back.append(k)
	overrides.clear_all()
	for k in back:
		settings[k]["obj"].set(settings[k]["name"], _initial_values[k])
	stale = {}
	if dock:
		dock.refresh()
	refresh_footer()


## Footer stale button: forget the overrides that were skipped at start.
func drop_stale() -> void:
	for sp in stale.get("stale_keys", []):
		overrides.clear(sp[0], sp[1])
	stale = {}
	refresh_footer()


## The watch card sits at the top between the hotbar and the dock (or the screen edge when the dock is hidden).
func _place_card() -> void:
	card.set_span(get_viewport().get_visible_rect().size.x - right_panel_width())


## For the HUD: how wide the dock is (from the screen edge); 0 in watch-only mode, so the game is not shifted or squeezed.
func right_panel_width() -> float:
	return dock.occupied_width() if dock and dock.visible else 0.0


## Right edge of the left-hand F3 UI. The old status wall is gone: nothing sits on the left any more.
func left_panel_right() -> float:
	return 0.0
