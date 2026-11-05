class_name ItemSlot
extends Control
## One slot square, used by BOTH the hotbar and the bag. The script holds the state (item, count,
## selected, hovered, locked, ...); every look lives in a child node named by its role: Frame,
## SelectedFrame, Icon, Tint, Count, KeyLabel, LockOverlay, ... Textures, sizes and fonts come from
## the InventorySkin, so drawn art is a skin swap. It never changes the inventory: a click is only a
## request (`slot_clicked`) that someone else answers.

signal slot_clicked(index: int, button: int, shift: bool)

var index := -1
## Square size when it should not follow `skin.slot_size` (the small crafting icons). 0 = follow the skin.
var size_override := 0
## Replaces the plain count ("6/10" for an ingredient); empty = the count as usual.
var count_text := ""
## Colour of the count text; alpha 0 = the skin's count_color.
var count_tint := Color(0, 0, 0, 0)
## A different frame picture for this slot (the big result slot); null = the skin's slot_texture.
var frame_override: Texture2D
## A square behind the picture (alpha 0 = none): the crafting grid uses it so lit / dim never depends on the art's colours.
var backdrop := Color(0, 0, 0, 0)
## The look. Assigning it (cheap if unchanged) applies it once; later edits arrive through `changed`.
var skin: InventorySkin:
	set(v):
		if v == skin:
			return
		if skin != null and skin.changed.is_connected(apply_skin):
			skin.changed.disconnect(apply_skin)
		skin = v
		if skin != null:
			skin.changed.connect(apply_skin)
		apply_skin()
var item: ItemData
var count := 0
var weapon: WeaponData
var key_text := ""
var selected := false
var hovered := false
var locked := false
var tip_override := ""        ## hover name for slots that hold no item (the ability slots)
var icon_tilt_degrees := -45.0
## Island Workshop look (skin parts): icon top in art px inside the 22 px slot (hotbar / bag 4, book 3).
var icon_top_art := 4
var station_locked := false   ## padlock at the slot corner (recipe that needs a station you are not near)
var grey_icon := false        ## icon drawn grey (recipe you lack the items for)
var icon_modulate := Color.WHITE   ## tints the icon only (a recipe you cannot make), not the frame
var bare := false             ## no frame picture (an icon on the page)
var _padlock: TextureRect
var _frame_src: Texture2D
var _frame_scale := 0
var _count_col := Color(-1, -1, -1, -1)   ## last font colour set on $Count (refresh() runs every frame; setting it again re-themes the label)
var color_tint := Color(0, 0, 0, 0)
var _picture: Texture2D
var _tilt := 0.0
var _fit := false   ## the picture is an item icon: crop it to its visible pixels and centre those in the box (ItemIcon). Symbols and the tilted model keep the full box.
var _box := Vector4.ZERO   ## the icon box as offsets from the slot corners (left, top, right, bottom); set by the apply functions
var _placed_pic: Texture2D   ## what _place_icon() last placed, so refresh() (every frame) only re-places on a change
var _placed_px := 0.0
var _slot_px := 0.0   ## square side the apply functions set (custom_minimum_size only reaches `size` a frame later, so the icon never reads `size`)
var _placed_box := Vector4.ZERO
var _placed_fit := false

func _ready() -> void:
	_padlock = TextureRect.new()
	_padlock.name = "Padlock"
	_padlock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_padlock.stretch_mode = TextureRect.STRETCH_KEEP
	add_child(_padlock)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func(): hovered = true; refresh())
	mouse_exited.connect(func(): hovered = false; refresh())
	apply_skin()
	refresh()

## Name shown by the hover tooltip ("" = nothing to show).
func tip_text() -> String:
	if tip_override != "":
		return tip_override
	return item.display_name if item != null else ""

## The colour the slot is shaded with now (icon only in the Island Workshop look, the whole slot in the old one).
func shade() -> Color:
	return icon_modulate if PixelArt.art_mode(skin) and modulate == Color.WHITE else modulate

## Second tooltip line ("Material  x37"); "" for slots with no item.
func tip_sub() -> String:
	if item == null or tip_override != "":
		return ""
	var t := item.category.capitalize()
	return t + ("  x%d" % count if count > 1 else "")

## A slot that is not an item (dodge / skill / guard): a picture, or a plain colour while there is none.
func set_picture(tex: Texture2D, fallback: Color) -> void:
	item = null
	count = 0
	weapon = null
	_picture = tex
	_fit = false
	_tilt = 0.0
	color_tint = fallback

func has_picture() -> bool:
	return _picture != null

func set_item(it: ItemData, n: int) -> void:
	if it == item and n == count:
		return
	item = it
	count = n
	weapon = it.weapon if it else null
	_picture = null
	_fit = false
	_tilt = 0.0
	color_tint = Color(0, 0, 0, 0)
	if it != null:
		if it.icon:
			_picture = it.icon
			_fit = true
		elif weapon != null and weapon.icon:
			_picture = weapon.icon
			_fit = true
		elif weapon != null and weapon.model:
			var m := weapon.model.instantiate()   # never added to the tree: only read, then freed
			var art := m.get_node_or_null("Art") as Sprite2D
			if art and art.texture:
				_picture = art.texture
				_tilt = art.rotation + deg_to_rad(icon_tilt_degrees)
			m.free()
		if _picture == null:   # no picture anywhere: the item colour (+ a letter for tools)
			color_tint = it.color

func _on_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		slot_clicked.emit(index, ev.button_index, ev.shift_pressed)

## Skin -> nodes. Only values that come from the skin, only when it changes. Where things sit
## (anchors, offsets, alignment) is the scene's job.
func apply_skin() -> void:
	if not is_node_ready() or skin == null:
		return
	_frame_src = null   # the skin / scale may have changed: pick the frame copy again
	_count_col = Color(-1, -1, -1, -1)
	refresh.call_deferred()   # some slots only refresh when rebuilt: a live F3 edit must still reach them
	if PixelArt.art_mode(skin):
		_apply_art()
		return
	var sz := size_override if size_override > 0 else skin.slot_size
	custom_minimum_size = Vector2(sz, sz)
	_slot_px = sz
	_padlock.visible = false
	_nine($Frame, frame_override if frame_override != null else skin.slot_texture, skin.slot_patch_margin, skin.frame_color, skin.frame_border)
	_nine($SelectedFrame, skin.slot_selected_texture, skin.selected_patch_margin, Color(0, 0, 0, 0), skin.selected_border)
	$SelectedFrame.offset_left = -skin.selected_grow
	$SelectedFrame.offset_top = -skin.selected_grow
	$SelectedFrame.offset_right = skin.selected_grow
	$SelectedFrame.offset_bottom = skin.selected_grow
	var inset := float(skin.icon_inset)
	_box = Vector4(inset, inset, -inset, -inset)
	for n in [$Hover, $Backdrop]:
		n.offset_left = inset
		n.offset_top = inset
		n.offset_right = -inset
		n.offset_bottom = -inset
	for l: Label in [$Count, $KeyLabel]:
		if skin.font:
			l.add_theme_font_override("font", skin.font)
		l.add_theme_font_size_override("font_size", skin.count_font_size if l == $Count else skin.key_font_size)
		l.add_theme_color_override("font_color", skin.count_color if l == $Count else skin.key_color)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
	$LockOverlay.texture = skin.lock_texture
	$LockOverlay/LockTint.visible = skin.lock_texture == null
	$LockOverlay/LockTint.color = skin.lock_color

## Island Workshop parts: frame picture (idle / hover / pick) at art scale, icon 16 art px, small-font count + key.
func _apply_art() -> void:
	var S := skin.art_scale
	var sz := size_override if size_override > 0 else 22 * S
	custom_minimum_size = Vector2(sz, sz)
	_slot_px = sz
	var pad := float(S) * (sz / (22.0 * S))   # the 1 px pad of the picture
	$Frame.patch_margin_left = 0
	$Frame.patch_margin_top = 0
	$Frame.patch_margin_right = 0
	$Frame.patch_margin_bottom = 0
	$Frame.offset_left = -pad
	$Frame.offset_top = -pad
	$Frame.offset_right = pad
	$Frame.offset_bottom = pad
	$Frame/Placeholder.visible = false
	$SelectedFrame.visible = false
	var k := sz / (22.0 * S)
	_box = Vector4(3 * S * k, icon_top_art * S * k, -3 * S * k, -(22 - icon_top_art - 16) * S * k)
	if bare and sz < 22 * S:   # an icon on its own (tooltip ingredients): it fills the whole square
		_box = Vector4.ZERO
	for n in [$Hover, $Backdrop]:
		n.offset_left = 0
		n.offset_top = 0
		n.offset_right = 0
		n.offset_bottom = 0
	PixelArt.style_label($Count, skin, "small", skin.pal_cream, true)
	PixelArt.style_label($KeyLabel, skin, "small", skin.pal_cream, true)   # the slot number: small font at 2x (the mock's size), skin outline
	$Count.offset_left = 0
	$Count.offset_top = 0
	$Count.offset_right = -3 * S
	$Count.offset_bottom = -2 * S
	$KeyLabel.offset_left = 2 * S
	$KeyLabel.offset_top = 2 * S
	$LockOverlay.texture = skin.lock_texture
	$LockOverlay/LockTint.visible = skin.lock_texture == null
	$LockOverlay/LockTint.color = skin.lock_color
	PixelArt.set_pic(_padlock, skin.padlock_tex, S)
	_padlock.position = Vector2(15, 15) * S * k
	_refresh_frame()

func _refresh_frame() -> void:
	var tex: Texture2D = frame_override
	if tex == null:
		tex = skin.slot_pick_tex if selected else (skin.slot_hover_tex if hovered and mouse_filter != Control.MOUSE_FILTER_IGNORE else skin.slot_idle_tex)
	if tex != _frame_src or skin.art_scale != _frame_scale:   # refresh() runs every frame: look the copy up only when it changes
		_frame_src = tex
		_frame_scale = skin.art_scale
		$Frame.texture = PixelArt.up(tex, _frame_scale)
	$Frame.visible = not bare

## State -> nodes (item, count, selected, ...). Cheap; call after changing anything.
func refresh() -> void:
	if not is_node_ready() or skin == null:
		return
	var art := PixelArt.art_mode(skin)
	$SelectedFrame.visible = selected and not art
	$Backdrop.visible = backdrop.a > 0.0 and not art
	$Backdrop.color = backdrop
	$Tint.visible = color_tint.a > 0.0 and _picture == null
	$Tint.color = color_tint
	if _picture != _placed_pic or _fit != _placed_fit or _slot_px != _placed_px or _box != _placed_box:
		_place_icon()
	$Icon.visible = _picture != null
	$Icon.pivot_offset = $Icon.size * 0.5
	$Icon.rotation = _tilt
	$Icon.scale = Vector2.ONE * (0.75 if _tilt != 0.0 else 1.0)
	$Hover.visible = hovered and mouse_filter != Control.MOUSE_FILTER_IGNORE and not art
	if art:
		_refresh_frame()
		_padlock.visible = station_locked
		$Icon.material = PixelArt.grey_material() if grey_icon else null
		$Icon.modulate = icon_modulate
		_set_count_color(count_tint if count_tint.a > 0.0 else skin.pal_cream)
	$Count.text = count_text if count_text != "" else (str(count) if count > 1 else "")
	if not art:
		_set_count_color(count_tint if count_tint.a > 0.0 else skin.count_color)
	$KeyLabel.text = key_text
	$LockOverlay.visible = locked

## Picture + rectangle of $Icon. An item icon is cropped to its visible pixels and centred in the box, at the scale
## its whole file would have. Anything else fills the box as it is.
func _place_icon() -> void:
	_placed_pic = _picture
	_placed_fit = _fit
	_placed_px = _slot_px
	_placed_box = _box
	var ic: TextureRect = $Icon
	var tex: Texture2D = ItemIcon.crop(_picture) if _fit else _picture
	ic.texture = tex
	if tex == null or not _fit or skin == null:
		ic.anchor_right = 1.0   # full-rect anchors + box offsets
		ic.anchor_bottom = 1.0
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.offset_left = _box.x
		ic.offset_top = _box.y
		ic.offset_right = _box.z
		ic.offset_bottom = _box.w
		return
	var box := Vector2(_slot_px - _box.x + _box.z, _slot_px - _box.y + _box.w)
	var sc := minf(box.x / _picture.get_width(), box.y / _picture.get_height())   # the whole file fits the box, as always: only the position changes
	var px := (tex.get_size() * sc).round()
	var pos := (Vector2(_box.x, _box.y) + (box - px) * 0.5).round()
	ic.anchor_right = 0.0   # top-left anchors: the rect is absolute, right from the first frame whatever `size` is
	ic.anchor_bottom = 0.0
	ic.stretch_mode = TextureRect.STRETCH_SCALE
	ic.offset_left = pos.x
	ic.offset_top = pos.y
	ic.offset_right = pos.x + px.x
	ic.offset_bottom = pos.y + px.y

func _set_count_color(c: Color) -> void:
	if c != _count_col:
		_count_col = c
		$Count.add_theme_color_override("font_color", c)

func _nine(r: NinePatchRect, tex: Texture2D, margin: int, fill: Color, border: Color) -> void:
	r.texture = tex
	r.patch_margin_left = margin
	r.patch_margin_top = margin
	r.patch_margin_right = margin
	r.patch_margin_bottom = margin
	var ph: Panel = r.get_node("Placeholder")
	ph.visible = tex == null
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(skin.slot_border_width)
	ph.add_theme_stylebox_override("panel", sb)
