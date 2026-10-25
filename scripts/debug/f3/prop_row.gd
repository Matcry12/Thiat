class_name F3PropRow
extends HBoxContainer
## One setting: name | number field | slider (only when a range is known) | reset (only when changed) | pin star.
## Number field: Enter commits, Esc cancels (the dock does it), Up/Down steps. Drag the name to scrub (Shift fine, Ctrl coarse).
## Vector2 = two number fields, each with its own scrub handle. Color = ColorPickerButton. Bool = CheckBox.
## A "heavy" row (it rebuilds the world) applies on slider release / Enter / focus-out only; until then the field is amber.
## Every change goes through panel.request_value(key, value) (-> apply_value -> F3Overrides): the one owner of "set the property".

var key := ""
var info_section := ""
var obj: Object
var prop := ""
var type := TYPE_FLOAT
var heavy := false
var _dock: F3Dock
var _or_less := false
var _or_greater := false
var _range = null   # Vector3(min, max, step) or null: no range hint, no slider
var _name: Label
var _fields: Array[LineEdit] = []
var _slider: HSlider
var _check: CheckBox
var _picker: ColorPickerButton
var _reset: Button
var _s_val = null     # last value shown
var _s_state := -1    # last (changed, copy) state shown
var _s_pin := -1
var _copy: Button
var _pin: Button
var _dragging := false
var _pending := false
var _scrub_axis := -1
var _scrub_val := 0.0


func setup(dock: F3Dock, info: Dictionary, show_section: bool) -> void:
	_dock = dock
	key = info["key"]
	info_section = info["section"]
	obj = info["obj"]
	prop = info["name"]
	type = info["type"]
	heavy = info["heavy"]
	_range = info.get("range")
	_or_less = info.get("or_less", false)
	_or_greater = info.get("or_greater", false)
	add_theme_constant_override("separation", dock.row_gap)
	custom_minimum_size.y = dock.row_height
	var indent := Control.new()
	indent.custom_minimum_size.x = dock.row_indent
	add_child(indent)

	var nm_box := VBoxContainer.new()
	nm_box.add_theme_constant_override("separation", 0)
	nm_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm_box.custom_minimum_size.x = dock.name_min_width
	nm_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(nm_box)
	if show_section:
		var sl := Label.new()
		sl.text = info["section"]
		sl.add_theme_font_size_override("font_size", dock.small_font_size)
		sl.add_theme_color_override("font_color", dock.dim_color)
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm_box.add_child(sl)
	_name = Label.new()
	_name.text = prop
	_name.clip_text = true
	_name.mouse_filter = Control.MOUSE_FILTER_STOP
	_name.mouse_default_cursor_shape = Control.CURSOR_HSIZE if (type == TYPE_FLOAT or type == TYPE_INT) else Control.CURSOR_ARROW
	_name.tooltip_text = _tooltip(info)
	_name.add_theme_font_size_override("font_size", dock.font_size)
	_name.gui_input.connect(_scrub_input.bind(0))
	nm_box.add_child(_name)

	match type:
		TYPE_BOOL:
			_check = CheckBox.new()
			_check.focus_mode = Control.FOCUS_NONE
			_check.toggled.connect(func(on: bool): _dock.panel.request_value(key, on))
			add_child(_check)
		TYPE_COLOR:
			_picker = ColorPickerButton.new()
			_picker.focus_mode = Control.FOCUS_NONE
			_picker.custom_minimum_size = Vector2(dock.number_width, dock.row_height - 6)
			_picker.edit_alpha = true
			_picker.color_changed.connect(func(c: Color): _dock.panel.request_value(key, c))
			add_child(_picker)
		TYPE_VECTOR2:
			for axis in 2:
				var h := Label.new()
				h.text = "<>" + ("x" if axis == 0 else "y")
				h.add_theme_font_size_override("font_size", dock.small_font_size)
				h.add_theme_color_override("font_color", dock.accent_color)
				h.mouse_filter = Control.MOUSE_FILTER_STOP
				h.mouse_default_cursor_shape = Control.CURSOR_HSIZE
				h.tooltip_text = "drag to scrub (Shift fine, Ctrl coarse)"
				h.gui_input.connect(_scrub_input.bind(axis))
				add_child(h)
				add_child(_make_field(axis))
		_:
			add_child(_make_field(0))
			if _range != null:
				_slider = HSlider.new()
				_slider.focus_mode = Control.FOCUS_NONE
				_slider.scrollable = false
				_slider.allow_greater = _or_greater
				_slider.allow_lesser = _or_less
				_slider.min_value = _range.x
				_slider.max_value = _range.y
				_slider.step = 1.0 if type == TYPE_INT else _range.z
				_slider.custom_minimum_size.x = dock.slider_width
				_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				_slider.drag_started.connect(func():
					_dragging = true
					_dock.dragging = true)
				_slider.drag_ended.connect(func(_c: bool):
					_dragging = false
					_dock.dragging = false
					if heavy:
						_apply(_slider.value))
				_slider.value_changed.connect(func(v: float):
					if heavy and _dragging:
						_set_pending(true)
						_fields[0].text = _fmt(v)
					else:
						_apply(v))
				add_child(_slider)
			else:
				var gap := Control.new()   # no slider: keep the number fields in one column
				gap.custom_minimum_size.x = dock.slider_width
				add_child(gap)

	_reset = Button.new()
	_reset.icon = F3Icons.get_icon("reset")
	_reset.flat = true
	_reset.focus_mode = Control.FOCUS_NONE
	_reset.custom_minimum_size.x = dock.icon_width
	_reset.tooltip_text = "reset to the startup value"
	_reset.pressed.connect(func(): _dock.panel.reset_value(key))
	add_child(_reset)
	_copy = Button.new()   # scene-only override (no .tres to write): copy "prop = value" to paste into the .tscn / script
	_copy.icon = F3Icons.get_icon("copy")
	_copy.flat = true
	_copy.focus_mode = Control.FOCUS_NONE
	_copy.custom_minimum_size.x = dock.icon_width
	_copy.tooltip_text = "scene-only: copy \"prop = value\" to paste into the scene or script"
	_copy.visible = false
	_copy.pressed.connect(func(): DisplayServer.clipboard_set("%s = %s" % [prop, var_to_str(obj.get(prop))]))
	add_child(_copy)
	_pin = Button.new()
	_pin.flat = true
	_pin.focus_mode = Control.FOCUS_NONE
	_pin.custom_minimum_size.x = dock.icon_width
	_pin.tooltip_text = "pin to the top of Tune"
	_pin.pressed.connect(func(): _dock.toggle_pin(key))
	add_child(_pin)
	sync()


func _tooltip(info: Dictionary) -> String:
	var t: String = info["key"]
	if _range != null:
		t += "\nrange %s .. %s" % [String.num(_range.x, 4), String.num(_range.y, 4)]
	else:
		t += "\nno range (number + scrub only)"
	if heavy:
		t += "\nrebuilds the world (applies on release / Enter)"
	return t


func _make_field(axis: int) -> LineEdit:
	var f := LineEdit.new()
	f.custom_minimum_size.x = _dock.number_width
	f.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	f.add_theme_font_size_override("font_size", _dock.small_font_size + 1)
	f.select_all_on_focus = true
	f.context_menu_enabled = false
	f.text_submitted.connect(func(_t: String): _commit(); f.release_focus())
	f.focus_exited.connect(func(): if is_inside_tree(): _commit())
	f.gui_input.connect(_field_input.bind(axis))
	_fields.append(f)
	return f


# ------------------------------------------------------------------ values ---

func _fmt(v) -> String:
	return str(roundi(v)) if type == TYPE_INT or is_equal_approx(v, roundf(v)) else String.num(v, 4)


func _current_axis(axis: int) -> float:
	var v = obj.get(prop)
	return float(v[axis]) if type == TYPE_VECTOR2 else float(v)


func _field_value(axis: int) -> float:
	var t := _fields[axis].text.strip_edges()
	return float(t) if t.is_valid_float() else _current_axis(axis)


func _apply(v: float) -> void:
	if type == TYPE_VECTOR2:
		return
	_set_pending(false)
	_dock.panel.request_value(key, v)


## Enter / focus-out: take what the fields say.
func _commit() -> void:
	if _fields.is_empty():
		return
	_set_pending(false)
	if type == TYPE_VECTOR2:
		var v := Vector2(_field_value(0), _field_value(1))
		if v != obj.get(prop):
			_dock.panel.request_value(key, v)
	elif not is_equal_approx(_field_value(0), _current_axis(0)):
		_dock.panel.request_value(key, _field_value(0))
	sync(true)


## Esc: drop what was typed.
func cancel_edit() -> void:
	_set_pending(false)
	sync(true)


func _set_pending(on: bool) -> void:
	_pending = on
	for f in _fields:
		f.add_theme_color_override("font_color", _dock.mod_color if on else _dock.text_color)


func is_editing() -> bool:
	for f in _fields:
		if f.has_focus():
			return true
	return _pending or _scrub_axis >= 0


func is_changed() -> bool:
	return _dock.panel.is_changed(key)


## Show the live value (the property can change from elsewhere). `force` also overwrites a field being typed in.
## Cheap by design (it runs for every row on screen): text and theme overrides are only touched when the value / state flipped.
func sync(force := false) -> void:
	var v = obj.get(prop)
	if force or (typeof(v) != typeof(_s_val) or v != _s_val) and not is_editing():
		_s_val = v
		match type:
			TYPE_BOOL:
				_check.set_pressed_no_signal(v)
			TYPE_COLOR:
				_picker.color = v
			TYPE_VECTOR2:
				_fields[0].text = _fmt(v.x)
				_fields[1].text = _fmt(v.y)
			_:
				_fields[0].text = _fmt(v)
				if _slider:
					_slider.set_value_no_signal(v)
	var ch := is_changed()
	var cp: bool = ch and _dock.panel.overrides.has_override(info_section, prop) and not F3Overrides.can_write_to_tres(obj)
	var st := (1 if ch else 0) + (2 if cp else 0)
	if st != _s_state:
		_s_state = st
		_name.add_theme_color_override("font_color", _dock.mod_color if ch else _dock.text_color)
		_name.text = ("● " if ch else "") + prop
		_reset.modulate.a = 1.0 if ch else 0.0
		_reset.disabled = not ch
		_copy.visible = cp
	var pinned := _dock.is_pinned(key)
	if int(pinned) != _s_pin:
		_s_pin = int(pinned)
		_pin.icon = F3Icons.get_icon("star" if pinned else "star_o")
		_pin.self_modulate = _dock.pin_color if pinned else _dock.dim_color


# ------------------------------------------------------------ keys / scrub ---

func _step(axis := 0) -> float:
	if type == TYPE_INT:
		return 1.0
	if _range != null:
		return maxf(_range.z, (_range.y - _range.x) / 400.0)
	return maxf(pow(10.0, floorf(log(maxf(absf(_current_axis(axis)), 0.1)) / log(10.0)) - 1.0), 0.001)


func _snap(v: float, axis: int) -> float:
	if type == TYPE_INT:
		v = roundf(v)
	else:
		v = snappedf(v, 0.0001)
	if _range != null and type != TYPE_VECTOR2:
		if not _or_less:
			v = maxf(v, _range.x)
		if not _or_greater:
			v = minf(v, _range.y)
	return v


## A new value for field `axis`: applied now, or (heavy) only shown amber until Enter / release.
func _set_field_value(v: float, axis: int) -> void:
	v = _snap(v, axis)
	_fields[axis].text = _fmt(v)
	if heavy:
		_set_pending(true)
	elif type == TYPE_VECTOR2:
		_commit()
	else:
		_apply(v)


func _field_input(ev: InputEvent, axis: int) -> void:
	if ev is InputEventKey and ev.pressed and (ev.keycode == KEY_UP or ev.keycode == KEY_DOWN):
		var mult := 0.1 if ev.shift_pressed else (10.0 if ev.ctrl_pressed else 1.0)
		_set_field_value(_field_value(axis) + (1.0 if ev.keycode == KEY_UP else -1.0) * _step(axis) * mult, axis)
		_fields[axis].accept_event()


func _scrub_input(ev: InputEvent, axis: int) -> void:
	if _fields.is_empty():
		return   # bool / colour: nothing to scrub
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_scrub_axis = axis
			_scrub_val = _field_value(axis)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_end_scrub()
	elif ev is InputEventMouseMotion and _scrub_axis == axis:
		var unit: float = (_range.y - _range.x) / 300.0 if _range != null and type != TYPE_VECTOR2 else (0.25 if type == TYPE_INT else maxf(absf(_current_axis(axis)) * 0.01, 0.01))
		_scrub_val += ev.relative.x * unit * (0.1 if ev.shift_pressed else (10.0 if ev.ctrl_pressed else 1.0))
		_set_field_value(_scrub_val, axis)


func _end_scrub() -> void:
	if _scrub_axis < 0:
		return
	_scrub_axis = -1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _pending:
		_commit()


func _exit_tree() -> void:
	if _dragging and _dock:
		_dock.dragging = false
	if _scrub_axis >= 0:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
