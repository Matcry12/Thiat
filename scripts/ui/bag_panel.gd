class_name BagPanel
extends VBoxContainer
## The bag: 27 slots (3 x 9) under the hotbar, toggled with Tab / I. Pure view: it reads the Inventory
## and EMITS requests (`slot_clicked`, `closed`); the HUD answers them (Inventory.click_slot / shift_move /
## return_held). Layout = containers; looks = InventorySkin textures (bag_panel_texture is the background).
## Locked (a lock icon shows, no opening) while a boss is engaged. The game keeps running while it is open.

signal slot_clicked(index: int, button: int, shift: bool)
signal closed

const SLOT_SCENE := preload("res://scenes/ui/item_slot.tscn")

@export var skin: InventorySkin
@export var hint_time := 1.6

var _inv: Inventory
var _hotbar: Hotbar
var _body: Control
var _bg: NinePatchRect
var _bg_placeholder: Panel
var _margin: MarginContainer
var _grid: GridContainer
var _cells: Array[ItemSlot] = []
## Automation seam (demo, tests): where the pointer is. (-1,-1) = the real mouse. Not gameplay.
var mouse_override := Vector2(-1, -1)
var _cursor: ItemSlot
var _shadow: Panel
var _hint: TextureRect   # lock icon: the bag cannot open now (skin lock_texture)
var _hint_tint: ColorRect
var _hint_left := 0.0
var _open := false
var _applied: InventorySkin
var _divider: TextureRect   ## Island Workshop: the line between the bag and the hotbar copy (a skin part, tiled)
## Island Workshop layout (art px, relative to the first bag slot): where the hotbar copy row sits under the grid.
@export var hotbar_row_dy_art := 78

func bind(inv: Inventory, hotbar: Hotbar) -> void:
	_inv = inv
	_hotbar = hotbar
	hotbar.slot_clicked.connect(func(i: int, b: int, sh: bool): if _open: slot_clicked.emit(i, b, sh))

func is_open() -> bool:
	return _open

func hint_visible() -> bool:
	return _hint.visible

func cells() -> Array[ItemSlot]:
	return _cells

func get_skin() -> InventorySkin:
	if skin == null:
		skin = load("res://data/ui/inventory_skin.tres")
	return skin

func _ready() -> void:
	add_to_group("bag_panel")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_STOP   # the panel itself eats clicks (no sword swing through it)
	add_child(_body)
	_bg = NinePatchRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_bg)
	_bg_placeholder = Panel.new()
	_bg_placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_child(_bg_placeholder)
	_divider = TextureRect.new()
	_divider.name = "Divider"
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.stretch_mode = TextureRect.STRETCH_TILE
	_divider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_divider.visible = false
	_body.add_child(_divider)
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_margin)
	_grid = GridContainer.new()
	_grid.columns = Inventory.HOTBAR
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(_grid)
	for i in Inventory.SIZE - Inventory.HOTBAR:
		var c: ItemSlot = SLOT_SCENE.instantiate()
		c.index = Inventory.HOTBAR + i
		c.slot_clicked.connect(func(idx: int, b: int, sh: bool): slot_clicked.emit(idx, b, sh))
		_grid.add_child(c)
		_cells.append(c)
	_cursor = SLOT_SCENE.instantiate()   # the stack on the mouse
	_cursor.top_level = true
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.visible = false
	add_child(_cursor)
	_shadow = Panel.new()   # a soft drop shadow behind the held stack (looks lifted, not placed)
	_shadow.name = "HeldShadow"
	_shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.add_child(_shadow)
	_cursor.move_child(_shadow, 0)
	_hint = TextureRect.new()
	_hint.name = "LockHint"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hint_tint = ColorRect.new()   # placeholder while the skin has no lock_texture
	_hint_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(_hint_tint)
	_hint.visible = false
	add_child(_hint)
	_apply_open()

func toggle() -> void:
	if _open:
		close()
	elif _inv.locked():
		_show_hint()
	else:
		_open = true
		_apply_open()

func close() -> void:
	if not _open:
		return
	_open = false
	_apply_open()
	closed.emit()   # the HUD puts a stack on the cursor back

func _show_hint() -> void:
	_hint_left = hint_time

func _apply_open() -> void:
	_body.visible = _open
	if _hotbar:
		_hotbar.interactive = _open

func _apply_skin() -> void:
	var sk := get_skin()
	if PixelArt.art_mode(sk) and sk.bag_panel_tex != null:
		_apply_art(sk)
		return
	_divider.visible = false
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.offset_left = 0
	_bg.offset_top = 0
	_bg.offset_right = 0
	_bg.offset_bottom = 0
	_bg.texture = sk.bag_panel_texture
	for m in ["left", "top", "right", "bottom"]:
		_bg.set("patch_margin_" + m, sk.bag_patch_margin)
		_margin.add_theme_constant_override("margin_" + m, sk.bag_pad)
	_grid.add_theme_constant_override("h_separation", sk.slot_gap)
	_grid.add_theme_constant_override("v_separation", sk.slot_gap)
	add_theme_constant_override("separation", 0)
	_bg_placeholder.visible = sk.bag_panel_texture == null
	var f := StyleBoxFlat.new()
	f.bg_color = sk.bag_color
	f.border_color = sk.frame_border
	f.set_border_width_all(sk.bag_border_width)
	_bg_placeholder.add_theme_stylebox_override("panel", f)
	_hint.texture = sk.lock_texture
	_hint.custom_minimum_size = Vector2(sk.slot_size, sk.slot_size)
	_hint.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hint_tint.visible = sk.lock_texture == null
	_hint_tint.color = sk.lock_hint_color

## Island Workshop: the bag_panel picture at its real size (never stretched) behind the grid, divider under it.
## This control's own rectangle is only the 3 x 9 grid; the picture overflows around it.
func _apply_art(sk: InventorySkin) -> void:
	var S := sk.art_scale
	_bg.texture = PixelArt.up(sk.bag_panel_tex, S)
	for m in ["left", "top", "right", "bottom"]:
		_bg.set("patch_margin_" + m, 0)
		_margin.add_theme_constant_override("margin_" + m, 0)
	_bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_bg.position = Vector2(-16, -20) * S   # the picture has an 8 px pad, the first slot sits at box (8, 12)
	_bg.size = _bg.texture.get_size()
	_bg_placeholder.visible = false
	_grid.add_theme_constant_override("h_separation", S)
	_grid.add_theme_constant_override("v_separation", S)
	add_theme_constant_override("separation", 0)
	_divider.texture = PixelArt.up(sk.divider_line_tex, S)
	_divider.position = Vector2(0, 71) * S   # box y 83 - first slot y 12
	_divider.size = Vector2(206, 2) * S
	_divider.visible = sk.divider_line_tex != null
	_hint.texture = sk.lock_texture
	_hint.custom_minimum_size = Vector2(sk.slot_size, sk.slot_size)
	_hint.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hint_tint.visible = sk.lock_texture == null
	_hint_tint.color = sk.lock_hint_color

## Polled in the physics step like the Player's keys (a scripted press is seen there, not in _process).
func _physics_process(_delta: float) -> void:
	if _inv != null and Input.is_action_just_pressed("bag") and not get_viewport().gui_get_focus_owner() is LineEdit:
		toggle()

func _process(delta: float) -> void:
	if _inv == null:
		return
	var sk := get_skin()
	if sk != _applied:
		if _applied != null:
			_applied.changed.disconnect(_apply_skin)
		_applied = sk
		sk.changed.connect(_apply_skin)
		_apply_skin()
	var locked := _inv.locked()
	if _open and locked:
		close()
		_show_hint()
	_hint_left = maxf(_hint_left - delta, 0.0)
	_hint.visible = _hint_left > 0.0
	if _open:
		for i in _cells.size():
			var c := _cells[i]
			c.skin = sk
			c.locked = locked
			c.set_item(_inv.slot_item(Inventory.HOTBAR + i), _inv.slot_count(Inventory.HOTBAR + i))
			c.refresh()
		_body.custom_minimum_size = _margin.get_combined_minimum_size()
	_cursor.visible = _open and _inv.held_item != null
	if _cursor.visible:
		_cursor.skin = sk
		_cursor.set_item(_inv.held_item, _inv.held_count)
		_cursor.refresh()
		_cursor.size = Vector2(sk.slot_size, sk.slot_size)
		_cursor.scale = Vector2.ONE * sk.cursor_scale
		_cursor.position = (mouse_override if mouse_override.x >= 0.0 else get_viewport().get_mouse_position()) + sk.cursor_offset
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.shadow_color = sk.cursor_shadow_color
		sb.shadow_size = sk.cursor_shadow_size
		sb.shadow_offset = sk.cursor_shadow_offset
		_shadow.add_theme_stylebox_override("panel", sb)
