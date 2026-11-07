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
@export var row_height := 28.0
@export var section_height := 26.0
@export var category_height := 30.0        ## category / Pinned
@export var pad_x := 8                      ## padding inside the dock body and between columns (name / field / slider / icons)
@export var button_gap := 6                 ## between action buttons
@export var group_gap := 6                  ## extra space above each @export_group sub-heading
@export var vector_gap := 4                 ## between the x and y fields of a Vector2
@export var footer_height := 44.0          ## one line inside the footer card
@export var tab_height := 28.0             ## idle tab; the active one is 4 px taller
@export var row_indent := 8.0
@export var name_min_width := 48.0
@export var number_width := 52.0
@export var slider_width := 44.0
@export var icon_width := 20.0
@export var scroll_width := 12.0
@export var max_results := 60
@export var name_ellipsis_chars := 28      ## names longer than this may be cut with "..." (shorter ones wrap after `_`)
@export_group("Behaviour")
@export var camera_ease_speed := 10.0
@export var sync_interval := 0.25
@export_group("Look")
@export var art_scale := 2                 ## screen px per art px (slices.json art_scale); fonts use the same factor
@export var text_font: Font               ## names, numbers, search, status lines, hints. null = Godot's default font
@export var text_size := 15
@export var small_text_size := 13         ## captions, counts, hints
@export var text_outline := 0             ## 0 or 1 (1 px OUT ring behind the text)
@export var label_font: Font              ## tabs, headers, buttons. null = the pixel Bold (assets/game/ui/fonts)
@export var label_size := 18              ## 2x the pixel font's native 9
@export var button_pad_y := 3.0            ## px added above and below the button art content
@export var button_pad := 4.0              ## px added to each side of the button art content margins
@export var search_lift := 10             ## art px the search field sits higher: it lies INSIDE the top plank
@export var sticky_color := Color8(86, 42, 38)   ## COVER_D: behind the sticky header copies
@export var out_color := Color8(62, 36, 39)           ## ink: text on paper (buttons, fields)
@export var outline_from_skin := true     ## the pixel-font outline colour = InventorySkin text_outline_color (one source)
@export var line_color := Color8(118, 64, 65)
@export var text_color := Color8(252, 242, 222)      ## cream: text on leather (always with the OUT outline)
@export var dim_color := Color8(234, 208, 170)       ## small captions on leather
@export var muted_color := Color8(150, 104, 86)
@export var accent_color := Color8(150, 214, 96)     ## axis handles, "enough"
@export var mod_color := Color8(244, 200, 76)        ## changed / typing hint / gold text
@export var hp_color := Color8(222, 52, 52)
@export var hp_dark_color := Color8(150, 26, 44)

var panel   # TuningPanel
var dragging := false          ## a row slider is being dragged
var extra_ui: Array = []       ## other F3 pictures that count as "over F3" (the world map)

var _sections: Array = []        # [{name, cat, obj, heavy, props: [info]}]
var _search: LineEdit
var _tab := "Tune"
var _tab_buttons := {}
var _info: Label
var _info_row: HBoxContainer
var _last_tab := "Tune"
var _sticky_bg: ColorRect
var _render_id := 0
var _last_q := ""
var _keycap: Button
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
	theme = F3Theme.build(look())
	theme_type_variation = "F3Dock"
	_layout()
	_load_pins()

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	add_child(vb)

	# search sits on the plank (the frame's top part)
	_search = LineEdit.new()
	_search.theme_type_variation = "F3Search"
	_search.placeholder_text = "Search (press /)"
	_search.custom_minimum_size.y = 16 * art_scale
	_search.text_changed.connect(func(t: String):
		_keycap.text = "x" if t != "" else "/"
		_render())
	vb.add_child(_search)
	var mag := TextureRect.new()
	mag.texture = F3Theme.tex("icon_search", art_scale)
	mag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mag.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	mag.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	mag.offset_left = 6 * art_scale
	mag.offset_right = 15 * art_scale
	_search.add_child(mag)
	_keycap = Button.new()   # "/" = press it to search; "x" = clear
	_keycap.theme_type_variation = "F3Keycap"
	_keycap.text = "/"
	_keycap.focus_mode = Control.FOCUS_NONE
	_keycap.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_keycap.offset_left = -15 * art_scale
	_keycap.offset_right = -4 * art_scale
	_keycap.offset_top = 2 * art_scale
	_keycap.offset_bottom = -2 * art_scale
	_keycap.pressed.connect(func():
		if _search.text != "":
			set_search("")
		else:
			_search.grab_focus())
	_search.add_child(_keycap)
	var gap := Control.new()   # the typing hint hangs in this gap, so it never moves the layout
	gap.custom_minimum_size.y = (2 + search_lift) * art_scale
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(gap)
	_typing = Label.new()
	_typing.theme_type_variation = "F3Hint"
	_typing.text = "TYPING: GAME KEYS PAUSED  (ESC LEAVES)"
	_typing.visible = false
	_typing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_typing.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_typing.offset_top = -art_scale
	_typing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gap.add_child(_typing)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", art_scale)
	vb.add_child(tabs)
	var group := ButtonGroup.new()
	for t in ["Tune", "Actions", "Status"]:
		var b := Button.new()
		b.theme_type_variation = "F3Tab"
		b.text = t
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = t == _tab
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.pressed.connect(show_tab.bind(t))
		tabs.add_child(b)
		_tab_buttons[t] = b
	_size_tabs()

	var info_row := HBoxContainer.new()
	_info_row = info_row
	info_row.custom_minimum_size.y = row_height + 2.0 * art_scale
	vb.add_child(info_row)
	var pad := Control.new()
	pad.custom_minimum_size.x = 4 * art_scale
	info_row.add_child(pad)
	_info = Label.new()
	_info.theme_type_variation = "F3Small"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_info.clip_text = true
	info_row.add_child(_info)
	_collapse_btn = Button.new()
	_collapse_btn.theme_type_variation = "F3Link"
	_collapse_btn.text = "Collapse all"
	_collapse_btn.focus_mode = Control.FOCUS_NONE
	_collapse_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_collapse_btn.pressed.connect(collapse_all)
	info_row.add_child(_collapse_btn)

	_banner = Label.new()
	_banner.theme_type_variation = "F3Banner"
	_banner.visible = false
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	_sticky.offset_right = -scroll_width
	_sticky_bg = ColorRect.new()   # opaque behind the copies: the rows scrolling under never show through
	_sticky_bg.color = sticky_color
	_sticky_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(_sticky_bg)
	wrap.add_child(_sticky)

	# footer: the card baked into the frame; the content sits inside it (one line)
	var foot := MarginContainer.new()
	foot.add_theme_constant_override("margin_top", 2 * art_scale)
	foot.custom_minimum_size.y = footer_height + 4.0 * art_scale
	vb.add_child(foot)
	var fb := VBoxContainer.new()
	fb.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_child(fb)
	_footer_box = fb
	_render()


func look() -> Dictionary:
	var outline := out_color
	if outline_from_skin and ResourceLoader.exists("res://data/ui/inventory_skin.tres"):
		var skin = load("res://data/ui/inventory_skin.tres")
		if skin != null and "text_outline_color" in skin:
			outline = skin.text_outline_color
	return {"ink": out_color, "button_pad_y": button_pad_y,"text_font": text_font, "text_size": text_size, "small_text_size": small_text_size, "text_outline": text_outline,
		"label_font": label_font, "button_pad": button_pad, "search_lift": search_lift, "label_size": label_size, "scale": art_scale, "out": outline, "line": line_color, "cream": text_color, "gold": mod_color, "muted": muted_color,
		"dim": dim_color, "hp": hp_color, "hp_dark": hp_dark_color, "ok": accent_color, "footer_height": footer_height}


func _size_tabs() -> void:
	for n in _tab_buttons:
		_tab_buttons[n].custom_minimum_size.y = tab_height + (4.0 if n == _tab else 0.0)


func _page(parent: Node) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	return v


## Width of the name column of a row (px). `two_line` rows (Vector2, Color) have the whole row.
func name_width(two_line: bool) -> float:
	var inner := dock_width - 2.0 * 6.0 * art_scale - scroll_width - 4.0
	var w := inner - row_indent - icon_width * 2.0 - pad_x * 5.0
	return w if two_line else w - number_width - slider_width


var _name_cache := {}

## A name as 1-2 lines: it wraps after a `_` (line 2 is indented by the row), never in the middle of a word. A name that still does
## not fit stays one line and the Label cuts it with "...".
func name_lines(prop: String, width: float) -> PackedStringArray:
	var k := "%s|%d" % [prop, int(width)]
	if _name_cache.has(k):
		return _name_cache[k]
	var f: Font = text_font if text_font != null else ThemeDB.fallback_font
	var fs := text_size
	var out := PackedStringArray([prop])
	if prop.length() * fs * 0.7 > width and f.get_string_size(prop, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		var best := -1
		var i := prop.find("_")
		while i != -1:
			if f.get_string_size(prop.substr(0, i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
				break
			best = i
			i = prop.find("_", i + 1)
		if best != -1:
			out = PackedStringArray([prop.substr(0, best + 1), prop.substr(best + 1)])
	_name_cache[k] = out
	return out


## A small icon picture (a part of the baked set) that never takes the mouse.
func icon_rect(part: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = F3Theme.tex(part, art_scale)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


# ------------------------------------------------------------------ look ---

func _layout() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	var o := frame_overhang()   # the frame art (clips, moss) is drawn this far outside the control
	offset_left = -(dock_width + margin + o)
	offset_right = -(margin + o)
	offset_top = margin + o
	offset_bottom = -(margin + o)
	mouse_filter = Control.MOUSE_FILTER_STOP   # nothing under the dock gets a click


func _set_dock_width(v: float) -> void:
	dock_width = v
	_layout()


func _set_margin(v: float) -> void:
	margin = v
	_layout()


## From the screen edge: what the HUD and the boss bar keep clear of.
func occupied_width() -> float:
	return dock_width + margin + 2.0 * frame_overhang()


func frame_overhang() -> float:
	return 8.0 * art_scale


# ----------------------------------------------------------------- state ---

func show_tab(t: String) -> void:
	_tab = t
	for n in _tab_buttons:
		_tab_buttons[n].set_pressed_no_signal(n == t)
	_size_tabs()
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


func collapse_all() -> void:
	_open_cat = ""
	_open_secs.clear()
	_render()


## Scroll so the header of an open section is at the top (tests, shots).
func scroll_to_section(sec_name: String) -> void:
	flush(true)
	if _sec_blocks.has(sec_name):
		await get_tree().process_frame
		await get_tree().process_frame
		# the section header lands right under the sticky category band, so its first row is not hidden under the stack
		_scroll.scroll_vertical = int(_sec_blocks[sec_name].global_position.y - _tune.global_position.y - category_height)


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


func add_action_group(title: String, count := -1) -> HFlowContainer:
	if _groups.has(title):
		return _groups[title]
	var h := _make_header({"kind": "cat", "title": title, "count": "" if count < 0 else str(count), "open": true})
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE   # a title, not a fold
	_actions.add_child(h)
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", button_gap)
	f.add_theme_constant_override("v_separation", button_gap)
	var fm := MarginContainer.new()
	fm.add_theme_constant_override("margin_left", int(row_indent / 2))
	fm.add_theme_constant_override("margin_right", int(row_indent / 2))
	fm.add_theme_constant_override("margin_top", button_gap)
	fm.add_theme_constant_override("margin_bottom", button_gap)
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
		var f := add_action_group(g["title"], g["actions"].size())
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
		e.placeholder_text = a.get("hint", label.to_lower())
		e.max_length = 6
		e.theme_type_variation = "F3Field"
		e.custom_minimum_size = Vector2(number_width + 48, row_height)
		e.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	b.theme_type_variation = "F3Button"
	b.text = text
	b.focus_mode = Control.FOCUS_NONE   # only text fields take keyboard focus: Enter / Space must never re-press "Kill player"
	b.pressed.connect(cb)
	return b


func _refresh_toggles() -> void:
	for t in _toggles:
		var on: bool = _cur[t["id"]]["toggle"].call()
		if t.get("on", null) == on:
			continue   # only a flip touches text and look
		t["on"] = on
		t["btn"].text = "%s %s" % [t["label"], "on" if on else "off"]
		t["btn"].theme_type_variation = "F3Primary" if on else "F3Button"   # gold when on


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


## Red button: the first click only asks "Sure? 2s" (cream look + shrinking bar); a second one within `confirm_seconds` runs `cb`.
func danger_button(text: String, cb: Callable, confirm_seconds := 2.0) -> Button:
	return F3DangerButton.new().setup(text, cb, confirm_seconds, art_scale)


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
	var keep := _scroll.scroll_vertical if _tab == _last_tab and (q == "") == (_last_q == "") else 0   # each tab starts at its top
	_last_tab = _tab
	_last_q = q
	_render_id += 1
	var rid := _render_id
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
	_info_row.visible = _info.visible
	if q != "":
		_render_results(q)
	elif _tab == "Tune":
		_render_tree()
	if _tune.visible:
		await get_tree().process_frame   # the content grows next frame: put the scroll back after it
		if rid == _render_id:   # (a newer render owns the scroll)
			_scroll.scroll_vertical = keep
	else:
		_scroll.scroll_vertical = keep


func _render_results(q: String) -> void:
	var hits := F3Search.run(_sections, q)
	_info.text = "%d settings%s" % [hits.size(), "  (showing %d)" % max_results if hits.size() > max_results else ""]
	if hits.is_empty():
		var l := Label.new()
		l.text = "No settings match \"%s\"." % q
		l.theme_type_variation = "F3Dim"
		_tune.add_child(l)
	for i in mini(hits.size(), max_results):
		_add_row(_tune, hits[i]["prop"], true)
		_tune.get_child(_tune.get_child_count() - 1).highlight(q)


## Tune tree. Blocks: pin block = [header, rows]; category block = [header, section blocks]; section block = [header, rows].
## A click rebuilds ONLY the block it changes (a section of 180 rows must not rebuild the other sections).
func _render_tree() -> void:
	var n_settings := 0
	for s in _sections:
		n_settings += s["props"].size()
	_info.text = "%d settings" % n_settings
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
		"tres": F3Overrides.can_write_to_tres(s["obj"]), "changed": panel.changed_count(s["props"]),
		"cb": func(): _toggle_sec(sname)}))
	if not sec_open:
		return
	var group := ""
	for info in s["props"]:
		if info["group"] != group:
			group = info["group"]
			if group != "":
				var gl := Label.new()
				gl.theme_type_variation = "F3Group"
				gl.text = group.to_upper()
				var gm := MarginContainer.new()
				gm.add_theme_constant_override("margin_left", int(row_indent))
				gm.add_theme_constant_override("margin_top", art_scale * 2 + group_gap)
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
	var sec: bool = a["kind"] == "sec"
	b.theme_type_variation = "F3Section" if sec else "F3Category"
	b.custom_minimum_size.y = section_height if sec else category_height
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = (row_indent + 4.0) if sec else 8.0
	h.offset_right = -8.0
	h.add_theme_constant_override("separation", art_scale * 2)
	b.add_child(h)
	if a["kind"] == "pin":
		h.add_child(icon_rect("icon_star_on"))
	else:
		h.add_child(icon_rect("icon_tri_open" if a["open"] else "icon_tri_closed"))
	var title := Label.new()
	title.theme_type_variation = "F3Title"
	title.text = a["title"]
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(title)
	if a.get("tres", false):
		h.add_child(_header_chip(".TRES", "F3Badge"))
	if a.get("heavy", false):
		h.add_child(_header_chip("⟳", "F3Gold"))
	if a.get("changed", 0) > 0:
		h.add_child(icon_rect("icon_dot_changed"))
		h.add_child(_header_chip(str(a["changed"]), "F3Gold"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sp)
	if a["count"] != "":
		h.add_child(_header_chip(str(a["count"]).to_upper(), "F3Small"))
	if a.has("cb"):
		b.pressed.connect(a["cb"])
	return b


func _header_chip(text: String, variation: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


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
		elif kind == "sec" and cat_i >= 0 and y <= category_height:
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
	_sticky.offset_right = -maxf(0.0, _wrap.size.x - _tune.size.x)   # as wide as the rows: up to the scroll bar
	_sticky_bg.visible = _sticky.get_child_count() > 0
	_sticky_bg.size = Vector2(_wrap.size.x + _sticky.offset_right, _sticky.get_combined_minimum_size().y)
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
