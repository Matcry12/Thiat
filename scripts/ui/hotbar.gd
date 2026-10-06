extends Control
class_name Hotbar
## Terraria-style item bar: one slot per Loadout weapon (any N), the selected
## slot bigger and brighter, the item name under it. Reads Loadout by polling;
## combat never calls into this. Slot looks are StyleBox slots (null = flat default).

@export var slot_size := 44
@export var slot_gap := 6
@export var selected_grow := 3
@export var name_gap := 4
@export var font_size := 12
@export var name_font_size := 14
@export var frame_style: StyleBox
@export var selected_style: StyleBox
@export var icon_tilt_degrees := -45.0
@export var cast_color := Color(1, 1, 1, 0.4)
@export var cooldown_color := Color(0, 0, 0, 0.6)

var _loadout: Loadout
var _slots: Array[HotbarSlot] = []
var _cast_to := -1
var _layout_key := []
var name_label: Label

func bind(l: Loadout) -> void:
	_loadout = l
	l.swap_started.connect(func(i: int): _cast_to = i)
	l.swap_finished.connect(func(_w): _cast_to = -1)
	l.swap_cancelled.connect(func(): _cast_to = -1)
	_rebuild()

func slots() -> Array[HotbarSlot]:
	return _slots

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_label.add_theme_font_size_override("font_size", name_font_size)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(name_label)
	if frame_style == null:
		frame_style = _flat(Color(0.12, 0.14, 0.2, 0.8), Color(0.35, 0.4, 0.55))
	if selected_style == null:
		selected_style = _flat(Color(0.2, 0.24, 0.34, 0.95), Color(1.0, 0.9, 0.45))
	if _loadout:
		_rebuild()

func _flat(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	return s

func _rebuild() -> void:
	for s in _slots:
		s.queue_free()
	_slots.clear()
	if name_label == null or _loadout == null:
		return
	var n := _loadout.weapons.size()
	for i in n:
		var s := HotbarSlot.new()
		s.size = Vector2(slot_size, slot_size)
		s.position = Vector2(i * (slot_size + slot_gap), 0)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.key_text = _key_text(i)
		s.set_weapon(_loadout.weapons[i])
		add_child(s)
		_slots.append(s)
	var w := maxi(n * slot_size + maxi(n - 1, 0) * slot_gap, 1)
	var label_h := int(ceilf(ThemeDB.fallback_font.get_height(name_font_size))) + 2
	custom_minimum_size = Vector2(w, slot_size + selected_grow + name_gap + label_h)
	size = custom_minimum_size
	name_label.position = Vector2(0, slot_size + selected_grow + name_gap)
	name_label.size = Vector2(w, label_h)

## The key shown in the corner comes from the input action, so a rebind shows up.
func _key_text(i: int) -> String:
	var action := "weapon_%d" % (i + 1)
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				return (ev as InputEventKey).as_text_physical_keycode()
	return str(i + 1)

func _process(_delta: float) -> void:
	if _loadout == null or name_label == null:
		return
	var key := [slot_size, slot_gap, selected_grow, name_gap, name_font_size]
	var stale := key != _layout_key or _slots.size() != _loadout.weapons.size()
	for i in mini(_slots.size(), _loadout.weapons.size()):
		stale = stale or _slots[i].weapon != _loadout.weapons[i]   # a weapon was replaced in place
	if stale:
		_layout_key = key
		name_label.add_theme_font_size_override("font_size", name_font_size)
		_rebuild()
	var active := _loadout.active_index()
	var cd := _loadout.cooldown_left()
	var cd_frac := clampf(cd / maxf(_loadout.swap_cooldown, 0.001), 0.0, 1.0)
	var cast_frac := clampf(1.0 - _loadout.cast_left() / maxf(_loadout.swap_cast, 0.001), 0.0, 1.0)
	for i in _slots.size():
		var s := _slots[i]
		s.frame_style = frame_style
		s.selected_style = selected_style
		s.selected_grow = selected_grow
		s.font_size = font_size
		s.icon_tilt_degrees = icon_tilt_degrees
		s.cast_color = cast_color
		s.cooldown_color = cooldown_color
		s.selected = i == active and not _loadout.is_holstered()
		s.cast_progress = cast_frac if (_loadout.is_casting() and i == _cast_to) else 0.0
		s.cooldown_frac = cd_frac if (cd > 0.0 and i != active) else 0.0
		s.cooldown_text = "%.1f" % cd
		s.queue_redraw()
	var w := _loadout.active_weapon()
	name_label.text = w.item_name() if w else ""
