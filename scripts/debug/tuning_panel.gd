extends CanvasLayer
class_name TuningPanel
## F3: Minecraft-F3-style panel. Left = live status readout. Right = live
## tuning sliders. See docs/wiki/prototype-v0.md §1c.
##
## The slider list is NOT hardcoded. `_collect_tunable_properties()` walks
## `get_property_list()` on each registered target and keeps FLOAT/INT/BOOL
## properties with PROPERTY_USAGE_SCRIPT_VARIABLE + PROPERTY_USAGE_EDITOR —
## i.e. every `@export`. Add a new `@export` anywhere on a registered target
## and it appears here with zero changes to this file.
##
## Dev-only: disabled in release exports unless `enabled_in_release` is set.

@export var enabled_in_release := false

@export var player_path: NodePath
@export var dummy_path: NodePath
@export var debug_overlay_path: NodePath

## Per-property range override, for the few properties where "derive from the
## current value" (see `_range_for`) gives a bad slider range. Keyed by
## property name only — NOT a hardcoded list of which properties exist.
@export var range_overrides: Dictionary = {
	"arc_degrees": {"min": 10.0, "max": 360.0},
	"radius": {"min": 10.0, "max": 200.0},
	"art_angle_degrees": {"min": -180.0, "max": 180.0},
	"rest_angle_degrees": {"min": -180.0, "max": 180.0},
}

const SAVE_PATH := "user://tuning.json"

var _player: CharacterBody2D
var _dummy: StaticBody2D
var _debug_overlay: CanvasLayer
var _weapon_holder: WeaponHolder
var _dummy_health: Health
var _player_health: Health
var _dodge: Dodge
var _attacker: Attacker
var _guard: Guard
var _guard_visual: GuardVisual

var _targets: Array = []          # [{"name": String, "object": Object}]
var _controls: Dictionary = {}    # "Target.prop" -> {obj, prop, control, value_label, is_bool, is_int}
var _initial_values: Dictionary = {}  # "Target.prop" -> value captured at startup, for Reset

var _status_label: Label
var _tuning_list: VBoxContainer

var _total_damage := 0.0
var _last_damage := 0.0
var _hits := 0
var _swings := 0


func _ready() -> void:
	if not enabled_in_release and not OS.is_debug_build():
		queue_free()
		return

	_player = get_node(player_path)
	_dummy = get_node(dummy_path)
	_debug_overlay = get_node(debug_overlay_path)
	_weapon_holder = _player.get_node("WeaponHolder")
	_dummy_health = _dummy.get_node("Health")
	_player_health = _player.get_node("Health")
	_dodge = _player.get_node("Dodge")
	_attacker = _dummy.get_node("Attacker")
	_guard = _player.get_node("Guard")
	_guard_visual = _player.get_node("GuardVisual")

	_weapon_holder.state_changed.connect(_on_weapon_state_changed)
	_dummy_health.damaged.connect(_on_dummy_damaged)

	_targets = [
		{"name": "Player", "object": _player},
		{"name": "Sword", "object": _weapon_holder.weapon},
		{"name": "WeaponVisual", "object": _player.get_node("WeaponVisual")},
		{"name": "Visual", "object": _player.visual},
		{"name": "Dodge", "object": _dodge},
		{"name": "Guard", "object": _guard},
		{"name": "GuardVisual", "object": _guard_visual},
		{"name": "CoverArc", "object": _guard_visual.get_node("CoverArc")},
		{"name": "GuardBar", "object": _guard_visual.get_node("GuardBar")},
		{"name": "Player Health", "object": _player_health},
		{"name": "Dummy Health", "object": _dummy_health},
		{"name": "Attacker", "object": _attacker},
		{"name": "Debug", "object": _debug_overlay},
	]

	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_panel"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible:
		return
	_update_status_text()


# ---------------------------------------------------------------- status ---

func _update_status_text() -> void:
	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / maxf(fps, 1.0)

	var vel: Vector2 = _player.velocity
	var move_state := "run" if vel.length() > 1.0 else "idle"
	var facing := "left" if _player.aim_direction.x < 0.0 else "right"
	var aim_deg := rad_to_deg(_player.aim_direction.angle())

	var weapon: WeaponData = _weapon_holder.weapon
	var weapon_name := "(none)"
	if weapon != null:
		weapon_name = weapon.resource_path.get_file().get_basename() if weapon.resource_path != "" else "(unsaved)"
	var phase_names := ["idle", "windup", "active", "recovery"]
	var phase_name: String = phase_names[_weapon_holder.phase]
	var phase_duration := 0.0
	if weapon != null:
		match _weapon_holder.phase:
			WeaponHolder.Phase.WINDUP: phase_duration = weapon.windup
			WeaponHolder.Phase.ACTIVE: phase_duration = weapon.active
			WeaponHolder.Phase.RECOVERY: phase_duration = weapon.recovery
	# ponytail: reaches into WeaponHolder._phase_time (no getter exists) because
	# adding one would mean editing combat code, which the brief disallows.
	var time_left := maxf(0.0, phase_duration - _weapon_holder._phase_time)

	var hurtbox_count := get_tree().get_nodes_in_group("hurtbox").size()
	var hit_rate := (float(_hits) / _swings * 100.0) if _swings > 0 else 0.0

	_status_label.text = "\n".join([
		"[Engine]",
		"fps: %d  frame: %.1f ms  time_scale: %.2f" % [fps, frame_ms, Engine.time_scale],
		"",
		"[Player]",
		"pos: (%d, %d)" % [roundi(_player.global_position.x), roundi(_player.global_position.y)],
		"vel: %.0f  state: %s  facing: %s" % [vel.length(), move_state, facing],
		"aim: %.0f deg" % aim_deg,
		"",
		"[Weapon]",
		"%s  phase: %s  left: %.2fs" % [weapon_name, phase_name, time_left],
		"",
		"[Combat]",
		"last dmg: %.1f  total: %.1f" % [_last_damage, _total_damage],
		"hits: %d  swings: %d  rate: %.0f%%" % [_hits, _swings, hit_rate],
		"",
		"[Entities]",
		"hurtboxes: %d  dummy hp: %.0f" % [hurtbox_count, _dummy_health.hp],
		"",
		"[Dodge]",
		"cooldown left: %.2fs  i-frames active: %s" % [_dodge.cooldown_remaining(), _dodge.iframes_active()],
		"",
		"[Guard]",
		"state: %s  tank: %.0f/%.0f" % [Guard.State.keys()[_guard.state].to_lower(), _guard.tank, _guard.tank_max],
		"",
		"[Player Health]",
		"shield: %.0f/%.0f  hp: %.0f/%.0f" % [_player_health.shield, _player_health.shield_max, _player_health.hp, _player_health.max_hp],
		"",
		"[Enemy Attack]",
		"state: %s" % Attacker.Phase.keys()[_attacker.phase].to_lower(),
	])


func _on_weapon_state_changed(state: String) -> void:
	if state == "windup":
		_swings += 1


func _on_dummy_damaged(amount: float) -> void:
	_last_damage = amount
	_total_damage += amount
	_hits += 1


# ------------------------------------------------------------- reflection ---

func _collect_tunable_properties(obj: Object) -> Array:
	var result: Array = []
	for prop in obj.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		if usage & PROPERTY_USAGE_EDITOR == 0:
			continue
		if prop["type"] != TYPE_FLOAT and prop["type"] != TYPE_INT and prop["type"] != TYPE_BOOL:
			continue
		result.append({"name": prop["name"], "type": prop["type"]})
	return result


func _range_for(prop_name: String, current: float) -> Vector2:
	if range_overrides.has(prop_name):
		var o: Dictionary = range_overrides[prop_name]
		return Vector2(o["min"], o["max"])
	if current > 0.0:
		return Vector2(0.0, maxf(current * 4.0, 1.0))
	elif current < 0.0:
		var a := maxf(absf(current) * 4.0, 1.0)
		return Vector2(-a, a)
	return Vector2(0.0, 1.0)


# --------------------------------------------------------------------- UI ---

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color = Color(0, 0, 0, 0.55)
	panel_bg.content_margin_left = 8
	panel_bg.content_margin_right = 8
	panel_bg.content_margin_top = 6
	panel_bg.content_margin_bottom = 6

	# --- status, top-left. Blocks its own small area only, not the screen. ---
	var status_panel := PanelContainer.new()
	status_panel.position = Vector2(8, 8)
	status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	status_panel.add_theme_stylebox_override("panel", panel_bg)
	root.add_child(status_panel)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 13)
	status_panel.add_child(_status_label)

	# --- tuning, top-right, scrollable ---
	var tuning_panel := PanelContainer.new()
	tuning_panel.anchor_left = 1.0
	tuning_panel.anchor_right = 1.0
	tuning_panel.offset_left = -360
	tuning_panel.offset_right = -8
	tuning_panel.offset_top = 8
	tuning_panel.offset_bottom = -8
	tuning_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	tuning_panel.add_theme_stylebox_override("panel", panel_bg)
	root.add_child(tuning_panel)

	var tuning_vbox := VBoxContainer.new()
	tuning_panel.add_child(tuning_vbox)

	var button_row := HBoxContainer.new()
	tuning_vbox.add_child(button_row)
	_add_button(button_row, "Save", _on_save_pressed)
	_add_button(button_row, "Load", _on_load_pressed)
	_add_button(button_row, "Reset", _on_reset_pressed)

	var action_row := HBoxContainer.new()
	tuning_vbox.add_child(action_row)
	_add_button(action_row, "Heal dummy", _on_heal_dummy)
	_add_button(action_row, "Heal player", _on_heal_player)
	_add_button(action_row, "Reset stats", _on_reset_stats)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 480)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tuning_vbox.add_child(scroll)

	_tuning_list = VBoxContainer.new()
	_tuning_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tuning_list)

	for target in _targets:
		_add_target_section(target["name"], target["object"])


func _add_button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)


func _add_target_section(target_name: String, obj: Object) -> void:
	if obj == null:
		return
	var props := _collect_tunable_properties(obj)
	if props.is_empty():
		return

	var heading := Label.new()
	heading.text = "-- %s --" % target_name
	heading.add_theme_font_size_override("font_size", 14)
	_tuning_list.add_child(heading)

	for prop_info in props:
		_add_property_row(target_name, obj, prop_info["name"], prop_info["type"])


func _add_property_row(target_name: String, obj: Object, prop_name: String, type: int) -> void:
	var key := "%s.%s" % [target_name, prop_name]
	var current = obj.get(prop_name)
	_initial_values[key] = current

	var row := HBoxContainer.new()
	_tuning_list.add_child(row)

	var name_label := Label.new()
	name_label.text = prop_name
	name_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(name_label)

	if type == TYPE_BOOL:
		var check := CheckBox.new()
		check.button_pressed = current
		check.toggled.connect(func(pressed: bool): _apply_value(key, pressed))
		row.add_child(check)
		_controls[key] = {"obj": obj, "prop": prop_name, "control": check, "value_label": name_label, "is_bool": true, "is_int": false}
	else:
		var is_int := type == TYPE_INT
		var range_v := _range_for(prop_name, float(current))
		var slider := HSlider.new()
		slider.min_value = range_v.x
		slider.max_value = range_v.y
		slider.step = 1.0 if is_int else maxf((range_v.y - range_v.x) / 200.0, 0.001)
		slider.value = float(current)
		slider.custom_minimum_size = Vector2(140, 0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)

		var value_label := Label.new()
		value_label.text = _format_value(current)
		value_label.custom_minimum_size = Vector2(55, 0)
		row.add_child(value_label)

		slider.value_changed.connect(func(v: float): _apply_value(key, v))
		_controls[key] = {"obj": obj, "prop": prop_name, "control": slider, "value_label": value_label, "is_bool": false, "is_int": is_int}


func _format_value(v) -> String:
	if typeof(v) == TYPE_BOOL:
		return "true" if v else "false"
	elif typeof(v) == TYPE_FLOAT:
		return "%.2f" % v
	return str(v)


# ---------------------------------------------------------- apply / save ---

## Single entry point for every value change: slider drag, checkbox toggle,
## Load, and Reset all go through this — so all of them print the change
## line and keep the widget in sync with the target.
func _apply_value(key: String, value) -> void:
	if not _controls.has(key):
		return
	var entry: Dictionary = _controls[key]
	var obj: Object = entry["obj"]
	var prop: String = entry["prop"]
	var old = obj.get(prop)

	var new_value
	if entry["is_bool"]:
		new_value = bool(value)
		obj.set(prop, new_value)
		entry["control"].set_pressed_no_signal(new_value)
	elif entry["is_int"]:
		new_value = roundi(float(value))
		obj.set(prop, new_value)
		entry["control"].set_value_no_signal(new_value)
	else:
		new_value = float(value)
		obj.set(prop, new_value)
		entry["control"].set_value_no_signal(new_value)
		entry["value_label"].text = _format_value(new_value)

	print("%s: %s -> %s" % [key, old, new_value])


func _on_save_pressed() -> void:
	var data := {}
	for key in _controls.keys():
		var entry: Dictionary = _controls[key]
		data[key] = entry["obj"].get(entry["prop"])
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("tuning: saved -> %s" % SAVE_PATH)


func _on_load_pressed() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("tuning: no save file at %s" % SAVE_PATH)
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		print("tuning: save file is corrupt")
		return
	for key in data.keys():
		_apply_value(key, data[key])
	print("tuning: loaded <- %s" % SAVE_PATH)


func _on_reset_pressed() -> void:
	for key in _initial_values.keys():
		_apply_value(key, _initial_values[key])
	print("tuning: reset to startup values")


func _on_heal_dummy() -> void:
	_dummy_health.hp = _dummy_health.max_hp
	print("tuning: dummy healed -> %.0f" % _dummy_health.hp)


func _on_heal_player() -> void:
	_player_health.hp = _player_health.max_hp
	_player_health.shield = _player_health.shield_max
	print("tuning: player healed -> hp %.0f, shield %.0f" % [_player_health.hp, _player_health.shield])


func _on_reset_stats() -> void:
	_total_damage = 0.0
	_last_damage = 0.0
	_hits = 0
	_swings = 0
	print("tuning: stats reset")
