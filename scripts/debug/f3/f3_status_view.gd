class_name F3StatusView
extends ScrollContainer
## Status tab: one row per block (name + first line), click to expand the wrapped detail, a labelled
## "pin to game" chip. Pinned blocks sort first. Only open or pinned blocks call their text Callable.
## providers = [{name: String, text: Callable -> String}]

signal pinned_changed(names: Array)

@export var refresh_rate := 4.0   # text refreshes per second
@export var row_gap := 2
@export var detail_pack_chars := 28   # two short facts share a detail line up to this many characters
@export var detail_indent := 20.0
@export var open_bar_color := Color8(150, 214, 96)   # the thin bar at the left of an open block
@export var open_bar_width := 4.0
@export var detail_line_spacing := 2
@export var pin_icon_tint := Color(2.0, 1.8, 1.5)
@export var chip_height := 24.0

var _providers: Array = []
var _pinned: Array = []
var _open: Dictionary = {}
var _rows: Dictionary = {}   # name -> {head, summary, detail, bar, detail_box}
var _box := VBoxContainer.new()
var _since := 0.0
var _dirty := false
var art_scale := 2

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", row_gap)
	add_child(_box)

func set_providers(providers: Array, pinned: Array = []) -> void:
	_providers = providers
	_pinned = pinned.duplicate()
	_dirty = true   # rows are built when the tab is on screen (or when someone asks for them)
	if is_visible_in_tree():
		_flush()


func _flush() -> void:
	if _dirty:
		_dirty = false
		_rebuild()

func pinned_names() -> Array:
	return _pinned.duplicate()

## Pinned blocks with their current text, for the watch card (pinned order = list order).
func pinned_blocks() -> Array:
	var out := []
	for p in _providers:
		if p.name in _pinned:
			out.append({"name": p.name, "text": str(p.text.call())})
	return out

func row_names() -> Array:   # display order
	_flush()
	var out := []
	for c in _box.get_children():
		out.append(str(c.name))
	return out

func is_open(n: String) -> bool:
	return _open.get(n, false)

func toggle_open(n: String) -> void:
	_flush()
	_open[n] = not is_open(n)
	_refresh_row(n)

func toggle_pin(n: String) -> void:
	if n in _pinned:
		_pinned.erase(n)
	else:
		_pinned.append(n)
	_rebuild()
	pinned_changed.emit(_pinned.duplicate())

func _provider(n: String) -> Dictionary:
	for p in _providers:
		if p.name == n:
			return p
	return {}

func _rebuild() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_rows.clear()
	var pin_first := _providers.filter(func(p): return p.name in _pinned)
	pin_first.append_array(_providers.filter(func(p): return not (p.name in _pinned)))
	for p in pin_first:
		_box.add_child(_make_row(p.name))
		_refresh_row(p.name)

func _make_row(n: String) -> Control:
	var pinned := n in _pinned
	var row := HBoxContainer.new()   # [open bar][block]
	row.name = n
	row.add_theme_constant_override("separation", 2)
	var bar := ColorRect.new()
	bar.color = open_bar_color
	bar.custom_minimum_size.x = open_bar_width
	bar.visible = false
	row.add_child(bar)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	row.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	v.add_child(h)
	var head := Button.new()   # name; the whole line is the click target (the summary + chip sit on top of it)
	head.theme_type_variation = "F3Block"
	head.focus_mode = Control.FOCUS_NONE
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.expand_icon = false
	head.custom_minimum_size.y = chip_height
	head.pressed.connect(toggle_open.bind(n))
	h.add_child(head)
	var summary := Label.new()   # first line of the text, small caps, tail-ellipsis (never under the chip)
	summary.theme_type_variation = "F3Small"
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	summary.clip_text = true
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.mouse_filter = Control.MOUSE_FILTER_STOP   # a click on it opens the block too
	summary.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			toggle_open(n))
	h.add_child(summary)
	var chip := Button.new()
	chip.focus_mode = Control.FOCUS_NONE
	if pinned:
		chip.theme_type_variation = "F3ChipOn"
		chip.text = "On game"
		chip.icon = F3Theme.tex("icon_check", art_scale)
		chip.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		chip.theme_type_variation = "F3Icon"
		chip.icon = F3Theme.tex("icon_pin_game", art_scale)
		chip.custom_minimum_size.x = chip_height
		for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:   # the baked pin is dark: lift it on the leather
			chip.add_theme_color_override(c, pin_icon_tint)
	chip.tooltip_text = "Keep this block in the card over the game" if not pinned else "Remove this block from the card over the game"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.pressed.connect(toggle_pin.bind(n))
	h.add_child(chip)
	var detail := Label.new()
	detail.theme_type_variation = "F3Name"
	detail.add_theme_constant_override("line_spacing", detail_line_spacing)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.visible = false
	var dm := MarginContainer.new()
	dm.add_theme_constant_override("margin_left", int(detail_indent))
	dm.add_theme_constant_override("margin_bottom", 4)
	dm.add_child(detail)
	v.add_child(dm)
	_rows[n] = {"head": head, "summary": summary, "detail": detail, "bar": bar, "detail_box": dm}
	return row


## Short facts share a line: "frame 4/6" + "fps 7.0" -> "frame 4/6  fps 7.0" (up to `detail_pack_chars`), so a block is not a tall list.
func _pack(lines: PackedStringArray) -> String:
	var out := PackedStringArray()
	for l in lines:
		if not out.is_empty() and out[out.size() - 1].length() + 2 + l.length() <= detail_pack_chars:
			out[out.size() - 1] += "  " + l
		else:
			out.append(l)
	return "\n".join(out)


func _refresh_row(n: String) -> void:
	var row: Dictionary = _rows.get(n, {})
	if row.is_empty():
		return
	var open := is_open(n)
	var txt := ""
	if open or n in _pinned:   # perf: closed + unpinned blocks are never evaluated
		var p := _provider(n)
		txt = str(p.text.call()) if not p.is_empty() else ""
	var lines := txt.split("\n")
	var first: String = lines[0] if lines.size() > 0 else ""
	row.head.text = n
	row.summary.text = first.split("  ")[0]   # ponytail: closed + unpinned rows have no live line (not evaluated)
	var d: Label = row.detail
	d.text = _pack(lines.slice(1))
	d.visible = open and d.text != ""   # first line is already in the summary
	row.detail_box.visible = d.visible
	row.bar.visible = open
	row.head.icon = F3Theme.tex("icon_tri_open" if open else "icon_tri_closed", art_scale)

func _process(delta: float) -> void:
	if _dirty and is_visible_in_tree():
		_flush()
	_since += delta
	if _since < 1.0 / maxf(refresh_rate, 0.1):
		return
	_since = 0.0
	for n in _rows:
		if is_open(n) or n in _pinned:
			_refresh_row(n)
