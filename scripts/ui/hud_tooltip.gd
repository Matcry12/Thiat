class_name HudTooltip
extends PanelContainer
## ONE hover name for the whole HUD (slots, ability icons, health bar). Elements are registered with
## `watch(control, text_callable)`; the tooltip polls the mouse against their rectangles, so it works over
## controls that ignore the mouse (the hotbar while the bag is closed) and never takes a click itself.
## Look = InventorySkin (tooltip_* fields: panel texture or flat placeholder, font, padding). Hidden while
## `blocked` says so (a stack is on the cursor) and whenever the mouse is over nothing.

var skin: InventorySkin
var blocked := Callable()      ## () -> bool, e.g. "a stack is held"
var mouse_override := Vector2(-1, -1)   ## tests only: (-1,-1) = the real mouse

var _watched: Array = []       ## [Control, Callable]
var _label: Label
var _extra: HBoxContainer      ## ingredient icons under the name (a recipe's hover)
var _extra_sig := ""
var _bg: NinePatchRect
var _flat: Panel
var _applied: InventorySkin

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	top_level = true
	_bg = NinePatchRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_flat = Panel.new()
	_flat.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_child(_flat)
	var margin := MarginContainer.new()
	margin.name = "Pad"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_label)
	_extra = HBoxContainer.new()
	_extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_extra.visible = false
	col.add_child(_extra)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	move_child(margin, -1)

## `extra` (optional) returns an Array of {item: ItemData, need: int, have: int}: shown as small icons with the
## need count (red when short) under the name. Used by the recipe icons: the tooltip is the only place a recipe's
## ingredients appear.
func watch(c: Control, text: Callable, extra := Callable()) -> void:
	_watched = _watched.filter(func(w): return is_instance_valid(w[0]))   # rows that were rebuilt are gone
	_watched.append([c, text, extra])

## [item id, need] of the ingredient icons showing now (tests).
func shown_ingredients() -> Array:
	var out := []
	if visible:
		for s: ItemSlot in _extra.get_children():
			out.append([s.item.id, int(s.count_text), s.count_tint == skin.craft_short_color])
	return out

func _show_extra(items: Array) -> void:
	var sig := ",".join(items.map(func(d): return "%s:%d:%d" % [d["item"].id, d["need"], d["have"]]))
	_extra.visible = not items.is_empty()
	if sig == _extra_sig:
		return
	_extra_sig = sig
	for c in _extra.get_children():
		_extra.remove_child(c)
		c.queue_free()
	for d in items:
		var s: ItemSlot = load("res://scenes/ui/item_slot.tscn").instantiate()
		s.size_override = skin.tooltip_icon_size
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.skin = skin
		s.set_item(d["item"], d["need"])
		s.count_text = str(d["need"])
		s.count_tint = skin.craft_enough_color if d["have"] >= d["need"] else skin.craft_short_color
		_extra.add_child(s)
		s.refresh()

func shown_text() -> String:
	return _label.text if visible else ""

func _mouse() -> Vector2:
	return mouse_override if mouse_override.x >= 0.0 else get_viewport().get_mouse_position()

## True when the point is outside a ScrollContainer that holds `c` (a scrolled-away row must not answer).
func _clipped(c: Control, m: Vector2) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer and not (p as ScrollContainer).get_global_rect().has_point(m):
			return true
		p = p.get_parent()
	return false

func _apply_skin() -> void:
	var sk := skin
	_bg.texture = sk.tooltip_texture
	for m in ["left", "top", "right", "bottom"]:
		_bg.set("patch_margin_" + m, sk.tooltip_patch_margin)
		get_node("Pad").add_theme_constant_override("margin_" + m, sk.tooltip_pad)
	_flat.visible = sk.tooltip_texture == null
	var f := StyleBoxFlat.new()
	f.bg_color = sk.tooltip_bg
	f.border_color = sk.tooltip_border
	f.set_border_width_all(sk.tooltip_border_width)
	_flat.add_theme_stylebox_override("panel", f)
	if sk.font:
		_label.add_theme_font_override("font", sk.font)
	_label.add_theme_font_size_override("font_size", sk.tooltip_font_size)
	_label.add_theme_color_override("font_color", sk.tooltip_color)

func _process(_delta: float) -> void:
	if skin == null:
		return
	if skin != _applied:
		if _applied != null:
			_applied.changed.disconnect(_apply_skin)
		_applied = skin
		skin.changed.connect(_apply_skin)
		_apply_skin()
	var text := ""
	var extras := []
	if not (blocked.is_valid() and blocked.call()):
		var m := _mouse()
		for w in _watched:
			var c = w[0]   # untyped: a rebuilt row may be freed already
			if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(m) and not _clipped(c, m):
				text = w[1].call()
				if text != "":
					if w[2].is_valid():
						extras = w[2].call()
					break
	visible = text != ""
	if visible:
		_label.text = text
		_show_extra(extras)
		reset_size()
		var vp := get_viewport().get_visible_rect().size
		position = (_mouse() + skin.tooltip_offset).min(vp - size).max(Vector2.ZERO)
