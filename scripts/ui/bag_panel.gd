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
var _cursor: ItemSlot
var _hint: TextureRect   # lock icon: the bag cannot open now (skin lock_texture)
var _hint_tint: ColorRect
var _hint_left := 0.0
var _open := false
var _applied: InventorySkin

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
	_cursor.modulate.a = 0.85
	_cursor.visible = false
	add_child(_cursor)
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
		_cursor.position = get_viewport().get_mouse_position() - _cursor.size * 0.5
