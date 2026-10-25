class_name F3Dock
extends PanelContainer
## The F3 dock (right side, opaque): search, tabs Tune / Actions / Status, footer.
## Tune = pinned rows, then category > section > @export_group > row. Rows exist ONLY for open sections / search results.
## It owns the layout and the input rules (pointer over the dock never reaches the game, only text fields take focus,
## Esc leaves a field first, the camera slides left so the player stays in the free part of the screen).
## What a setting is, and how it is set, belongs to the TuningPanel (`panel`): rows only call panel.apply_value().

@export_group("Layout")
@export var dock_width := 380.0: set = _set_dock_width
@export var margin := 8.0: set = _set_margin
@export var row_height := 24.0
@export var row_gap := 5
@export var row_indent := 14.0
@export var header_height := 26.0
@export var name_min_width := 48.0
@export var number_width := 58.0
@export var slider_width := 64.0
@export var icon_width := 20.0
@export var max_results := 60
@export_group("Behaviour")
@export var camera_ease_speed := 10.0
@export var sync_interval := 0.25
@export_group("Look")
@export var font_size := 12
@export var small_font_size := 10
@export var bg_color := Color(0.059, 0.067, 0.086)
@export var cat_bg_color := Color(0.114, 0.133, 0.169)
@export var sec_bg_color := Color(0.086, 0.102, 0.129)
@export var field_bg_color := Color(0.055, 0.063, 0.078)
@export var line_color := Color(0.17, 0.196, 0.239)
@export var text_color := Color(0.84, 0.87, 0.9)
@export var dim_color := Color(0.49, 0.53, 0.58)
@export var accent_color := Color(0.42, 0.71, 1.0)
@export var mod_color := Color(1.0, 0.71, 0.33)
@export var pin_color := Color(1.0, 0.82, 0.29)

var panel   # TuningPanel
var dragging := false          ## a row slider is being dragged
var extra_ui: Array = []       ## other F3 pictures that count as "over F3" (the world map)

var _sections: Array = []        # [{name, cat, obj, heavy, props: [info]}]
var _search: LineEdit
var _tab := "Tune"
var _tab_buttons := {}
var _info: Label
var _collapse_btn: Button
var _scroll: ScrollContainer
var _tune: VBoxContainer
var _actions: VBoxContainer
var _status_view: Control
var _wrap: Control
var _banner: Label
var _banner_left := 0.0
var _footer_box: VBoxContainer
var _sticky: VBoxContainer
var _typing: Label
var _open_cat := "Character"
var _open_secs := {"Player": true}
var _pins: Array = []
var _rows := {}       # key -> [F3PropRow]
var _pin_block: VBoxContainer
var _cat_blocks := {}
var _sec_blocks := {}
var _headers: Array = []   # [{btn, a}] in tree order (for the sticky copy)
var _sticky_ids := Vector2i(-1, -1)
var _sync_left := 0.0
var _groups := {}
var _pending_groups = null   # actions to build when the dock shows
var _render_dirty := false
var _toggles: Array = []   # [{btn, label, fn}] on/off pills, refreshed with the rows
var _actions_sig := ""
var _cur := {}             # "group/label" -> the action dict the buttons call through, so a rescan can re-point them
var _args := {}            # action label -> {edit, go}


func setup(p, sections: Array) -> void:
	panel = p
	_sections = sections
	add_to_group("f3_dock")
	theme = _make_theme()
	add_theme_stylebox_override("panel", _box(bg_color, line_color, 1, 6))
	_layout()
	_load_pins()

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	add_child(vb)

	var top := MarginContainer.new()
	for side in ["left", "right", "top"]:
		top.add_theme_constant_override("margin_" + side, 8)
	vb.add_child(top)
	var top_box := VBoxContainer.new()
	top.add_child(top_box)
	_search = LineEdit.new()
	_search.placeholder_text = "Search settings...  ( / )"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String): _render())
	top_box.add_child(_search)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	top_box.add_child(tabs)
	var group := ButtonGroup.new()
	for t in ["Tune", "Actions", "Status"]:
		var b := Button.new()
		b.text = t
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = t == _tab
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), line_color, 0, 0, 2))
		b.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.04), line_color, 0, 0, 2))
		b.add_theme_stylebox_override("pressed", _box(Color(0, 0, 0, 0), accent_color, 0, 0, 2))
		b.add_theme_stylebox_override("hover_pressed", _box(Color(1, 1, 1, 0.04), accent_color, 0, 0, 2))
		b.add_theme_color_override("font_color", dim_color)
		b.add_theme_color_override("font_pressed_color", text_color)
		b.add_theme_color_override("font_hover_pressed_color", text_color)
		b.pressed.connect(show_tab.bind(t))
		tabs.add_child(b)
		_tab_buttons[t] = b

	var info_row := HBoxContainer.new()
	info_row.custom_minimum_size.y = row_height + 4.0
	vb.add_child(info_row)
	var pad := Control.new()
	pad.custom_minimum_size.x = 4
	info_row.add_child(pad)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", small_font_size + 1)
	_info.add_theme_color_override("font_color", dim_color)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.clip_text = true
	info_row.add_child(_info)
	_collapse_btn = Button.new()
	_collapse_btn.text = "collapse all"
	_collapse_btn.focus_mode = Control.FOCUS_NONE
	_collapse_btn.add_theme_font_size_override("font_size", small_font_size + 1)
	_collapse_btn.pressed.connect(func():
		_open_cat = ""
		_open_secs.clear()
		_render())
	info_row.add_child(_collapse_btn)

	_banner = Label.new()
	_banner.add_theme_color_override("font_color", mod_color)
	_banner.add_theme_font_size_override("font_size", small_font_size + 2)
	_banner.visible = false
	vb.add_child(_banner)

	var wrap := Control.new()
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.clip_contents = true
	vb.add_child(wrap)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wrap.add_child(_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	_scroll.add_child(content)
	_tune = _page(content)
	_actions = _page(content)
	_wrap = wrap
	_sticky = VBoxContainer.new()
	_sticky.add_theme_constant_override("separation", 0)
	_sticky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sticky.anchor_right = 1.0
	_sticky.offset_right = -8
	wrap.add_child(_sticky)

	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", _box(field_bg_color, line_color, 0, 0, 0, 1))
	vb.add_child(foot)
	var fb := VBoxContainer.new()
	foot.add_child(fb)
	_footer_box = fb
	_typing = Label.new()
	_typing.text = "typing: game keys paused  (Esc leaves)"
	_typing.add_theme_color_override("font_color", mod_color)
	_typing.add_theme_font_size_override("font_size", small_font_size + 1)
	_typing.visible = false
	fb.add_child(_typing)
	_render()


func _page(parent: Node) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	return v


# ------------------------------------------------------------------ look ---

func _box(bg: Color, border := Color(0, 0, 0, 0), width := 0, radius := 0, bottom := 0, top := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	if bottom > 0:
		s.border_width_bottom = bottom
	if top > 0:
		s.border_width_top = top
	s.set_corner_radius_all(radius)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = font_size
	t.set_color("font_color", "Label", text_color)
	t.set_color("font_color", "Button", text_color)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_color", "LineEdit", text_color)
	t.set_color("font_color", "CheckBox", text_color)
	t.set_stylebox("normal", "Button", _box(Color(0.15, 0.17, 0.22), Color(0.22, 0.25, 0.31), 1, 4))
	t.set_stylebox("hover", "Button", _box(Color(0.19, 0.22, 0.28), accent_color, 1, 4))
	t.set_stylebox("pressed", "Button", _box(Color(0.12, 0.23, 0.32), accent_color, 1, 4))
	t.set_stylebox("disabled", "Button", _box(Color(0, 0, 0, 0)))
	t.set_stylebox("normal", "LineEdit", _box(field_bg_color, Color(0.15, 0.17, 0.22), 1, 3))
	t.set_stylebox("focus", "LineEdit", _box(Color(0.063, 0.082, 0.11), accent_color, 1, 3))
	t.set_stylebox("read_only", "LineEdit", _box(field_bg_color, Color(0.15, 0.17, 0.22), 1, 3))
	return t


func _layout() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -(dock_width + margin)
	offset_right = -margin
	offset_top = margin
	offset_bottom = -margin
	mouse_filter = Control.MOUSE_FILTER_STOP   # nothing under the dock gets a click


func _set_dock_width(v: float) -> void:
	dock_width = v
	_layout()


func _set_margin(v: float) -> void:
	margin = v
	_layout()


## From the screen edge: what the HUD and the boss bar keep clear of.
func occupied_width() -> float:
	return dock_width + margin


# ----------------------------------------------------------------- state ---

func show_tab(t: String) -> void:
	_tab = t
	for n in _tab_buttons:
		_tab_buttons[n].set_pressed_no_signal(n == t)
	_render()


func current_tab() -> String:
	return _tab


func search_text() -> String:
	return _search.text


func set_search(t: String) -> void:
	_search.text = t
	_render()


func search_field() -> LineEdit:
	return _search


func open_section(sec_name: String) -> void:
	for s in _sections:
		if s["name"] == sec_name:
			_open_cat = s["cat"]
			_open_secs[sec_name] = true
	if _search.text != "":
		_search.text = ""
	show_tab("Tune")


func row_for(key: String) -> F3PropRow:
	flush(true)
	var a: Array = _rows.get(key, [])
	return a[0] if not a.is_empty() else null


func row_count() -> int:
	flush(true)
	var n := 0
	for k in _rows:
		n += _rows[k].size()
	return n


func is_typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


## "The pointer is on F3": over the dock or another F3 picture (world map), or while a slider drag / number scrub is on
## (a scrub captures the mouse, so the pointer is not over the dock any more but a held click must not attack).
func pointer_over() -> bool:
	if not is_visible_in_tree():
		return false
	if dragging or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return true
	var mp := get_viewport().get_mouse_position()
	if get_global_rect().has_point(mp):
		return true
	for c in extra_ui:
		if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(mp):
			return true
	return false


func add_action_group(title: String) -> HFlowContainer:
	if _groups.has(title):
		return _groups[title]
	var l := Label.new()
	l.text = title.to_upper()
	l.add_theme_font_size_override("font_size", small_font_size)
	l.add_theme_color_override("font_color", dim_color)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_top", 8)
	m.add_child(l)
	_actions.add_child(m)
	var f := HFlowContainer.new()
	var fm := MarginContainer.new()
	fm.add_theme_constant_override("margin_left", 10)
	fm.add_theme_constant_override("margin_right", 10)
	fm.add_child(f)
	_actions.add_child(fm)
	_groups[title] = f
	return f


## The Actions tab, from debug_actions(): groups = [{title, actions: [{label, run, danger?, toggle?, arg?}]}].
## danger -> red, second click; toggle -> on/off pill; arg "int" -> a number field + the button (Enter also runs).
func set_actions(groups: Array) -> void:
	if not is_visible_in_tree():
		_pending_groups = groups   # closed: build it when F3 opens (a hidden dock costs nothing)
		return
	_pending_groups = null
	_set_actions_now(groups)


func _set_actions_now(groups: Array) -> void:
	var sig := ""
	for g in groups:
		for a in g["actions"]:
			sig += "%s/%s|" % [g["title"], a["label"]]
	if sig == _actions_sig:
		_remember(groups)   # same buttons: only point them at the (possibly new) callables, keep typed text and focus
		return
	_actions_sig = sig
	_remember(groups)
	_clear(_actions)
	_groups.clear()
	_toggles.clear()
	_args.clear()
	for g in groups:
		if g["actions"].is_empty():
			continue
		var f := add_action_group(g["title"])
		for a in g["actions"]:
			_add_action(f, "%s/%s" % [g["title"], a["label"]], a)


func _remember(groups: Array) -> void:
	_cur.clear()
	for g in groups:
		for a in g["actions"]:
			_cur["%s/%s" % [g["title"], a["label"]]] = a


func _add_action(f: HFlowContainer, id: String, a: Dictionary) -> void:
	var label: String = a["label"]
	var run := func(): _cur[id]["run"].call()
	if a.has("arg"):
		var h := HBoxContainer.new()
		var e := LineEdit.new()
		e.placeholder_text = label.to_lower()
		e.max_length = 6
		e.custom_minimum_size = Vector2(64, 0)
		e.add_theme_font_size_override("font_size", 11)
		if a["arg"] == "int":
			e.text_changed.connect(func(t: String):   # digits only
				var clean := ""
				for ch in t:
					if ch >= "0" and ch <= "9":
						clean += ch
				if clean != t:
					var caret := e.caret_column
					e.text = clean
					e.caret_column = mini(caret, clean.length()))
		var go := func():
			if e.text.strip_edges().is_empty():
				return
			var v = int(e.text) if a["arg"] == "int" else e.text
			e.release_focus()   # give the keys back to the game
			_cur[id]["run"].call(v)
		e.text_submitted.connect(func(_t: String): go.call())
		h.add_child(e)
		var b := _action_button(label, go)
		h.add_child(b)
		f.add_child(h)
		_args[label] = {"edit": e, "go": go}
	elif a.get("danger", false):
		f.add_child(danger_button(label, run))
	elif a.has("toggle"):
		var b := _action_button(label, func():
			run.call()
			_refresh_toggles())
		f.add_child(b)
		_toggles.append({"btn": b, "label": label, "id": id})
		_refresh_toggles()
	else:
		f.add_child(_action_button(label, run))


func _action_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE   # only text fields take keyboard focus: Enter / Space must never re-press "Kill player"
	b.pressed.connect(cb)
	b.add_theme_font_size_override("font_size", 11)   # small buttons: all rows (wrapped) fit in a 720 px window
	return b


func _refresh_toggles() -> void:
	for t in _toggles:
		var on: bool = _cur[t["id"]]["toggle"].call()
		if t.get("on", null) == on:
			continue   # only a flip touches text and colour
		t["on"] = on
		t["btn"].text = "%s  %s" % [t["label"], "on" if on else "off"]
		t["btn"].add_theme_color_override("font_color", accent_color if on else dim_color)


## Tests: the number field of an `arg` action, and a way to press its button.
func arg_field(label: String) -> LineEdit:
	flush(true)
	return _args[label]["edit"] if _args.has(label) else null


func run_arg(label: String) -> void:
	flush(true)
	if _args.has(label):
		_args[label]["go"].call()


func action_labels() -> Array:
	flush(true)
	var out := []
	var stack: Array = [_actions]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Button:
			out.append(n.text)
	return out


# ------------------------------------------------------------------ pins ---

func is_pinned(key: String) -> bool:
	return _pins.has(key)


func toggle_pin(key: String) -> void:
	if _pins.has(key):
		_pins.erase(key)
	else:
		_pins.append(key)
	panel.overrides.set_pins(_pins)   # one store: the F3Overrides cfg
	if _pin_block != null and _search.text.strip_edges() == "" and _tab == "Tune":
		_fill_pins()
		_after_partial()
		sync_key(key)
	else:
		_render()


func _load_pins() -> void:
	_pins = Array(panel.overrides.get_pins())   # (unknown keys are skipped when drawing: the scan may not have run yet)


func reload_pins() -> void:
	_load_pins()
	_render()


## Status tab: the status view fills the page (it scrolls itself).
func attach_status(v: Control) -> void:
	_status_view = v
	_wrap.add_child(v)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.visible = _tab == "Status"
	_scroll.visible = not v.visible


func footer_box() -> VBoxContainer:
	return _footer_box


## Rebuild what is shown (rows read their override state when they sync).
func refresh() -> void:
	if not is_visible_in_tree():
		_render_dirty = true
		return
	_render()


## Build what was held back while the dock was closed. `force`: even when closed (tests read rows / buttons directly).
func flush(force := false) -> void:
	if not (force or is_visible_in_tree()):
		return
	if _pending_groups != null:
		var g = _pending_groups
		_pending_groups = null
		_set_actions_now(g)
	if _render_dirty:
		_render_dirty = false
		_render()


## One line under the tabs (rebuild notice). `seconds` 0 = stays until replaced.
func show_banner(text: String, seconds := 0.0) -> void:
	_banner.text = text
	_banner.visible = true
	_banner_left = seconds


## Red button: the first click only asks "Sure?"; a second one within `confirm_seconds` runs `cb`.
func danger_button(text: String, cb: Callable, confirm_seconds := 2.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", Color(1.0, 0.55, 0.52))
	b.add_theme_stylebox_override("normal", _box(Color(0.24, 0.1, 0.11), Color(0.55, 0.2, 0.2), 1, 4))
	b.add_theme_stylebox_override("hover", _box(Color(0.32, 0.12, 0.13), Color(0.9, 0.3, 0.3), 1, 4))
	b.add_theme_stylebox_override("pressed", _box(Color(0.5, 0.12, 0.12), Color(1, 0.4, 0.4), 1, 4))
	b.set_meta("armed", 0)   # 0 = idle, else the arm number (a late timer from an earlier arm must not disarm a new one)
	b.pressed.connect(func():
		if int(b.get_meta("armed")) != 0:
			b.set_meta("armed", 0)
			b.text = text
			b.add_theme_color_override("font_color", Color(1.0, 0.55, 0.52))
			cb.call()
			return
		var n := Time.get_ticks_msec() + 1
		b.set_meta("armed", n)
		b.text = "Sure?"
		b.add_theme_color_override("font_color", Color.WHITE)
		get_tree().create_timer(confirm_seconds).timeout.connect(func():
			if is_instance_valid(b) and int(b.get_meta("armed")) == n:
				b.set_meta("armed", 0)
				b.text = text
				b.add_theme_color_override("font_color", Color(1.0, 0.55, 0.52))))
	return b


# ---------------------------------------------------------------- render ---

func sync_key(key: String) -> void:
	for r in _rows.get(key, []):
		r.sync()


## Rows that are on screen only (the others sync when they are built and when they scroll in); each sync is a no-op unless something changed.
func sync_all() -> void:
	_refresh_toggles()
	if not _tune.visible:
		return
	var vr := _scroll.get_global_rect()
	for k in _rows:
		for r in _rows[k]:
			if r.get_global_rect().intersects(vr):
				r.sync()


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _render() -> void:
	var q := _search.text.strip_edges()
	var keep := _scroll.scroll_vertical
	_rows.clear()
	_headers.clear()
	_pin_block = null
	_sec_blocks.clear()
	_sticky_ids = Vector2i(-1, -1)
	_clear(_sticky)
	_clear(_tune)
	_tune.visible = q != "" or _tab == "Tune"
	_actions.visible = q == "" and _tab == "Actions"
	if _status_view:
		_status_view.visible = q == "" and _tab == "Status"
	_scroll.visible = not (_status_view and _status_view.visible)
	_collapse_btn.visible = q == "" and _tab == "Tune"
	_info.visible = q != "" or _tab == "Tune"
	if q != "":
		_render_results(q)
	elif _tab == "Tune":
		_render_tree()
	if _tune.visible:
		await get_tree().process_frame   # the content grows next frame: put the scroll back after it
		_scroll.scroll_vertical = keep


func _render_results(q: String) -> void:
	var hits := F3Search.run(_sections, q)
	_info.text = "%d settings%s" % [hits.size(), "  (showing %d)" % max_results if hits.size() > max_results else ""]
	if hits.is_empty():
		var l := Label.new()
		l.text = "No settings match \"%s\"." % q
		l.add_theme_color_override("font_color", dim_color)
		_tune.add_child(l)
	for i in mini(hits.size(), max_results):
		_add_row(_tune, hits[i]["prop"], true)


## Tune tree. Blocks: pin block = [header, rows]; category block = [header, section blocks]; section block = [header, rows].
## A click rebuilds ONLY the block it changes (a section of 180 rows must not rebuild the other sections).
func _render_tree() -> void:
	var n_settings := 0
	for s in _sections:
		n_settings += s["props"].size()
	_info.text = "%d sections  %d settings" % [_sections.size(), n_settings]
	_pin_block = VBoxContainer.new()
	_pin_block.add_theme_constant_override("separation", 0)
	_tune.add_child(_pin_block)
	_fill_pins()
	_cat_blocks.clear()
	for cat in F3Categories.names:
		var secs: Array = _sections.filter(func(s): return s["cat"] == cat)
		if secs.is_empty():
			continue
		var blk := VBoxContainer.new()
		blk.add_theme_constant_override("separation", 0)
		_tune.add_child(blk)
		_cat_blocks[cat] = blk
		_fill_cat(cat)
	_collect_headers()


func _fill_pins() -> void:
	_forget_rows(_pin_block)
	_clear(_pin_block)
	var pins: Array = _pins.filter(func(k): return panel.settings.has(k))
	if pins.is_empty():
		return
	_pin_block.add_child(_make_header({"kind": "pin", "title": "Pinned", "count": str(pins.size()), "open": true}))
	for k in pins:
		_add_row(_pin_block, panel.settings[k], true)


func _fill_cat(cat: String) -> void:
	var blk: VBoxContainer = _cat_blocks[cat]
	_forget_rows(blk)
	_clear(blk)
	var secs: Array = _sections.filter(func(s): return s["cat"] == cat)
	var changed := 0
	for s in secs:
		changed += panel.changed_count(s["props"])
	var open := _open_cat == cat
	blk.add_child(_make_header({"kind": "cat", "title": cat, "count": "%d sections" % secs.size(), "open": open, "changed": changed,
		"cb": func(): _toggle_cat(cat)}))
	if not open:
		return
	for s in secs:
		var sb := VBoxContainer.new()
		sb.add_theme_constant_override("separation", 0)
		sb.name = "sec_" + str(s["name"]).validate_node_name()
		blk.add_child(sb)
		_sec_blocks[s["name"]] = sb
		_fill_sec(s)


func _fill_sec(s: Dictionary) -> void:
	var sb: VBoxContainer = _sec_blocks[s["name"]]
	_forget_rows(sb)
	_clear(sb)
	var sname: String = s["name"]
	var sec_open: bool = _open_secs.has(sname)
	sb.add_child(_make_header({"kind": "sec", "title": sname, "count": str(s["props"].size()), "open": sec_open, "heavy": s["heavy"],
		"changed": panel.changed_count(s["props"]),
		"cb": func(): _toggle_sec(sname)}))
	if not sec_open:
		return
	var group := ""
	for info in s["props"]:
		if info["group"] != group:
			group = info["group"]
			if group != "":
				var gl := Label.new()
				gl.text = group.to_upper()
				gl.add_theme_font_size_override("font_size", small_font_size)
				gl.add_theme_color_override("font_color", accent_color)
				var gm := MarginContainer.new()
				gm.add_theme_constant_override("margin_left", 22)
				gm.add_theme_constant_override("margin_top", 5)
				gm.add_child(gl)
				sb.add_child(gm)
		_add_row(sb, info, false)


func _toggle_cat(cat: String) -> void:
	var old := _open_cat
	_open_cat = "" if old == cat else cat
	if old != "" and _cat_blocks.has(old):
		_fill_cat(old)
	if _open_cat != "" and _cat_blocks.has(_open_cat):
		_fill_cat(_open_cat)
	_after_partial()


func _toggle_sec(sname: String) -> void:
	if _open_secs.has(sname):
		_open_secs.erase(sname)
	else:
		_open_secs[sname] = true
	for s in _sections:
		if s["name"] == sname and _sec_blocks.has(sname):
			_fill_sec(s)
	_after_partial()


func _after_partial() -> void:
	_collect_headers()
	_sticky_ids = Vector2i(-1, -1)
	_clear(_sticky)


## Header buttons in tree order (the sticky copy reads their position and `a`).
func _collect_headers() -> void:
	_headers.clear()
	var stack: Array = [_tune]
	var order: Array = []
	_walk_headers(_tune)


func _walk_headers(n: Node) -> void:
	for c in n.get_children():
		if c is Button and c.has_meta("a"):
			_headers.append({"btn": c, "a": c.get_meta("a")})
		elif c is VBoxContainer:
			_walk_headers(c)


func _forget_rows(n: Node) -> void:
	for c in n.get_children():
		if c is F3PropRow:
			var arr: Array = _rows.get(c.key, [])
			arr.erase(c)
			if arr.is_empty():
				_rows.erase(c.key)
		else:
			_forget_rows(c)


func _add_row(parent: Node, info: Dictionary, show_section: bool) -> void:
	var r := F3PropRow.new()
	parent.add_child(r)
	r.setup(self, info, show_section)
	if not _rows.has(info["key"]):
		_rows[info["key"]] = []
	_rows[info["key"]].append(r)


func _make_header(a: Dictionary) -> Button:
	var b := Button.new()
	b.set_meta("a", a)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = header_height
	var bg := cat_bg_color if a["kind"] != "sec" else sec_bg_color
	b.add_theme_stylebox_override("normal", _box(bg, line_color, 0, 0, 1))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.08), line_color, 0, 0, 1))
	b.add_theme_stylebox_override("pressed", _box(bg.lightened(0.08), line_color, 0, 0, 1))
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 18.0 if a["kind"] == "sec" else 8.0
	h.offset_right = -8.0
	h.add_theme_constant_override("separation", 6)
	b.add_child(h)
	var arrow := "" if a["kind"] == "pin" else ("v" if a["open"] else ">")
	_header_label(h, arrow, dim_color, small_font_size)
	_header_label(h, a["title"], text_color if a["kind"] != "sec" else Color(0.78, 0.82, 0.88), font_size)
	if a.get("heavy", false):
		_header_label(h, "[rebuild]", mod_color, small_font_size)
	if a.get("changed", 0) > 0:
		_header_label(h, "● %d" % a["changed"], mod_color, small_font_size)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sp)
	_header_label(h, a["count"], dim_color, small_font_size + 1)
	if a.has("cb"):
		b.pressed.connect(a["cb"])
	return b


func _header_label(parent: Node, text: String, col: Color, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)


## Category + section header that scrolled off the top stay visible (copies of the real ones: same click).
func _update_sticky() -> void:
	var top := _scroll.global_position.y
	var cat_i := -1
	var sec_i := -1
	for i in _headers.size():
		var kind: String = _headers[i]["a"]["kind"]
		var y: float = _headers[i]["btn"].global_position.y - top
		if kind == "cat" and y <= 0.0:
			cat_i = i
			sec_i = -1
		elif kind == "sec" and cat_i >= 0 and y <= header_height:
			sec_i = i
	if Vector2i(cat_i, sec_i) == _sticky_ids:
		return
	_sticky_ids = Vector2i(cat_i, sec_i)
	_clear(_sticky)
	for i in [cat_i, sec_i]:
		if i >= 0:
			var c := _make_header(_headers[i]["a"])
			c.gui_input.connect(func(ev: InputEvent):   # the wheel over a sticky header still scrolls the list
				if ev is InputEventMouseButton and ev.pressed and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
					_scroll.scroll_vertical += (-48 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 48))
			_sticky.add_child(c)


# ----------------------------------------------------------------- input ---

func _process(delta: float) -> void:
	var dt := delta / maxf(Engine.time_scale, 0.0001)
	_ease_camera(dt)
	if not is_visible_in_tree():
		return
	if _pending_groups != null or _render_dirty:
		flush()
	_typing.visible = is_typing()
	if _banner.visible and _banner_left > 0.0:
		_banner_left -= dt
		if _banner_left <= 0.0:
			_banner.visible = false
	if _tune.visible and _search.text.strip_edges() == "":
		_update_sticky()
	_sync_left -= dt
	if _sync_left <= 0.0:
		_sync_left = sync_interval
		sync_all()


## The camera moves right by half the dock, so the player stays in the middle of the part of the screen that is still free.
func _ease_camera(dt: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var want := occupied_width() * 0.5 / cam.zoom.x if is_visible_in_tree() else 0.0
	cam.position.x = lerpf(cam.position.x, want, 1.0 - exp(-camera_ease_speed * dt))
	if absf(cam.position.x - want) < 0.05:
		cam.position.x = want


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("pause"):
		if focus is LineEdit and is_ancestor_of(focus):   # first Esc step: leave the field (the pause menu never sees it)
			var n: Node = focus
			while n != null and not n is F3PropRow:
				n = n.get_parent()
			if n:
				(n as F3PropRow).cancel_edit()
			focus.release_focus()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and focus is LineEdit and not focus.get_global_rect().has_point(event.position):
		focus.release_focus()   # a click anywhere else ends typing (buttons take no focus, so nothing else would)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_SLASH or event.unicode == 47) and not is_typing():
		_search.grab_focus()
		get_viewport().set_input_as_handled()
