class_name F3StatusView
extends ScrollContainer
## Status tab: one row per block (name + first line), click to expand the wrapped detail, a labelled
## "pin to game" chip. Pinned blocks sort first. Only open or pinned blocks call their text Callable.
## providers = [{name: String, text: Callable -> String}]

signal pinned_changed(names: Array)

@export var refresh_rate := 4.0   # text refreshes per second
@export var font_size := 12
@export var detail_font_size := 11
@export var row_gap := 3
@export var summary_color := Color("c4cdd9")
@export var detail_color := Color("9aa5b4")
@export var row_color := Color("171a21")
@export var pinned_row_color := Color("1c2433")
@export var chip_on_color := Color("e6b450")
@export var chip_off_color := Color("7a8494")

var _providers: Array = []
var _pinned: Array = []
var _open: Dictionary = {}
var _rows: Dictionary = {}   # name -> {panel, summary, detail, chip}
var _box := VBoxContainer.new()
var _since := 0.0
var _dirty := false

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
	var panel := PanelContainer.new()
	panel.name = n
	var sb := StyleBoxFlat.new()
	sb.bg_color = pinned_row_color if pinned else row_color
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(5)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var head := Button.new()
	head.flat = true
	head.focus_mode = Control.FOCUS_NONE
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.clip_text = true
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_theme_font_size_override("font_size", font_size)
	head.add_theme_color_override("font_color", summary_color)
	head.pressed.connect(toggle_open.bind(n))
	h.add_child(head)
	var chip := Button.new()
	chip.focus_mode = Control.FOCUS_NONE
	chip.add_theme_font_size_override("font_size", detail_font_size)
	chip.add_theme_color_override("font_color", chip_on_color if pinned else chip_off_color)
	chip.text = "on game ✓" if pinned else "pin to game"
	chip.tooltip_text = "Keep this block in the card over the game"
	chip.pressed.connect(toggle_pin.bind(n))
	h.add_child(chip)
	var detail := Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", detail_font_size)
	detail.add_theme_color_override("font_color", detail_color)
	detail.visible = false
	v.add_child(detail)
	_rows[n] = {"head": head, "detail": detail}
	return panel

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
	row.head.text = "%s   %s" % [n, first] if (open or n in _pinned) else n   # ponytail: closed + unpinned rows have no live line (not evaluated)
	var d: Label = row.detail
	d.text = "\n".join(lines.slice(1))
	d.visible = open and d.text != ""   # first line is already in the head

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
