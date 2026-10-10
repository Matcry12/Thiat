class_name ItemSlot
extends Control
## One slot square, used by BOTH the hotbar and the bag. The script holds the state (item, count,
## selected, hovered, locked, ...); every look lives in a child node named by its role: Frame,
## SelectedFrame, Icon, Tint, Count, KeyLabel, LockOverlay, ... Textures, sizes and fonts come from
## the InventorySkin, so drawn art is a skin swap. It never changes the inventory: a click is only a
## request (`slot_clicked`) that someone else answers.

signal slot_clicked(index: int, button: int, shift: bool)

var index := -1
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
var cast_progress := 0.0      ## 0..1 fill while swapping to this slot's weapon
var cooldown_frac := 0.0      ## 0..1 shade while the swap cooldown runs
var tip_override := ""        ## hover name for slots that hold no item (the ability slots)
var icon_tilt_degrees := -45.0
var color_tint := Color(0, 0, 0, 0)
var _picture: Texture2D
var _tilt := 0.0

func _ready() -> void:
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

## A slot that is not an item (dodge / skill / guard): a picture, or a plain colour while there is none.
func set_picture(tex: Texture2D, fallback: Color) -> void:
	item = null
	count = 0
	weapon = null
	_picture = tex
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
	_tilt = 0.0
	color_tint = Color(0, 0, 0, 0)
	if it != null:
		if it.icon:
			_picture = it.icon
		elif weapon != null and weapon.icon:
			_picture = weapon.icon
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
	custom_minimum_size = Vector2(skin.slot_size, skin.slot_size)
	_nine($Frame, skin.slot_texture, skin.slot_patch_margin, skin.frame_color, skin.frame_border)
	_nine($SelectedFrame, skin.slot_selected_texture, skin.selected_patch_margin, Color(0, 0, 0, 0), skin.selected_border)
	$SelectedFrame.offset_left = -skin.selected_grow
	$SelectedFrame.offset_top = -skin.selected_grow
	$SelectedFrame.offset_right = skin.selected_grow
	$SelectedFrame.offset_bottom = skin.selected_grow
	var inset := float(skin.icon_inset)
	for n in [$Icon, $CastFill, $CooldownShade, $Hover]:
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

## State -> nodes (item, count, selected, ...). Cheap; call after changing anything.
func refresh() -> void:
	if not is_node_ready() or skin == null:
		return
	$SelectedFrame.visible = selected
	$Tint.visible = color_tint.a > 0.0 and _picture == null
	$Tint.color = color_tint
	$Icon.texture = _picture
	$Icon.visible = _picture != null
	$Icon.pivot_offset = $Icon.size * 0.5
	$Icon.rotation = _tilt
	$Icon.scale = Vector2.ONE * (0.75 if _tilt != 0.0 else 1.0)
	$CastFill.visible = cast_progress > 0.0
	$CastFill.anchor_top = 1.0 - cast_progress
	$CooldownShade.visible = cooldown_frac > 0.0
	$CooldownShade.anchor_bottom = cooldown_frac
	$Hover.visible = hovered and mouse_filter != Control.MOUSE_FILTER_IGNORE
	$Count.text = str(count) if count > 1 else ""
	$KeyLabel.text = key_text
	$LockOverlay.visible = locked

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
