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
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_label)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	move_child(margin, -1)

func watch(c: Control, text: Callable) -> void:
	_watched.append([c, text])

func shown_text() -> String:
	return _label.text if visible else ""

func _mouse() -> Vector2:
	return mouse_override if mouse_override.x >= 0.0 else get_viewport().get_mouse_position()

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
	if not (blocked.is_valid() and blocked.call()):
		var m := _mouse()
		for w in _watched:
			var c: Control = w[0]
			if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(m):
				text = w[1].call()
				if text != "":
					break
	visible = text != ""
	if visible:
		_label.text = text
		reset_size()
		var vp := get_viewport().get_visible_rect().size
		position = (_mouse() + skin.tooltip_offset).min(vp - size).max(Vector2.ZERO)
