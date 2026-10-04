extends Control
class_name HotbarSlot
## One hotbar square: frame, key number (top-left), icon, and two overlays
## (swap cast fill, cooldown shade). Pure view — Hotbar sets the fields.
## Icon = WeaponData.icon if set, else the Art sprite of the weapon's model
## scene, else the weapon's first letter. A real icon is a data swap.

var weapon: WeaponData
var key_text := ""
var selected := false
var cast_progress := 0.0      ## 0..1, > 0 only on the slot being swapped to
var cooldown_frac := 0.0      ## 0..1 of the swap cooldown left, > 0 only on inactive slots
var cooldown_text := ""
var frame_style: StyleBox
var selected_style: StyleBox
var selected_grow := 3
var frame_inset := 3
var icon_tilt_degrees := -45.0
var icon_fill := 1.0
var cast_color := Color(1, 1, 1, 0.4)
var cooldown_color := Color(0, 0, 0, 0.6)
var font_size := 12

var _icon: Texture2D
var _icon_rot := 0.0
var _letter := ""

func set_weapon(w: WeaponData) -> void:
	weapon = w
	_icon = null
	_icon_rot = 0.0
	_letter = w.item_name().left(1).to_upper() if w else ""
	if w == null:
		return
	if w.icon:
		_icon = w.icon
	elif w.model:
		var m := w.model.instantiate()      # never added to the tree: only read, then freed
		var art := m.get_node_or_null("Art") as Sprite2D
		if art and art.texture:
			_icon = art.texture
			_icon_rot = art.rotation
		m.free()
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if selected:
		r = r.grow(selected_grow)
	var st := selected_style if selected else frame_style
	if st:
		draw_style_box(st, r)
	var inner := r.grow(-frame_inset)
	var font := ThemeDB.fallback_font
	if _icon:
		var rot := _icon_rot + deg_to_rad(icon_tilt_degrees if weapon.icon == null else 0.0)
		var ts := _icon.get_size()
		var bw := absf(ts.x * cos(rot)) + absf(ts.y * sin(rot))
		var bh := absf(ts.x * sin(rot)) + absf(ts.y * cos(rot))
		var s := minf(inner.size.x / bw, inner.size.y / bh) * icon_fill
		draw_set_transform(inner.get_center().round(), rot, Vector2(s, s))
		draw_texture(_icon, -ts * 0.5)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	elif _letter != "":
		var big := int(inner.size.y * 0.7)
		draw_string(font, inner.get_center() + Vector2(-big * 0.3, big * 0.35), _letter, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color.WHITE)
	if cast_progress > 0.0:
		var h := roundi(inner.size.y * cast_progress)
		draw_rect(Rect2(inner.position.x, inner.end.y - h, inner.size.x, h), cast_color)
	if cooldown_frac > 0.0:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, roundi(inner.size.y * cooldown_frac))), cooldown_color)
		var tw := font.get_string_size(cooldown_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_shadow_text(font, Vector2(roundf(inner.get_center().x - tw * 0.5), roundf(inner.get_center().y + font_size * 0.35)), cooldown_text)
	_shadow_text(font, r.position + Vector2(4, font_size), key_text)

func _shadow_text(font: Font, p: Vector2, t: String) -> void:
	draw_string(font, p + Vector2(1, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.9))
	draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
