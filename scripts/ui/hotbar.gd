extends VBoxContainer
class_name Hotbar
## The 9 hotbar slots of the Inventory (no words: the hover tooltip shows the name). Reads Inventory + Loadout by polling;
## combat never calls into this. Slots are ItemSlot scenes in an HBoxContainer; sizes, gap and looks come
## from the InventorySkin (art = a skin swap). While the bag is open the slots take clicks and report
## them with `slot_clicked` (a request: this node never changes the inventory).

signal slot_clicked(index: int, button: int, shift: bool)

const SLOT_SCENE := preload("res://scenes/ui/item_slot.tscn")

@export var skin: InventorySkin
@export var icon_tilt_degrees := -45.0
## Pixels between slots; -1 = framed hotbar: `art_gap` art px, otherwise the skin's slot_gap (the bag's copy sets its own).
@export var gap_override := -1
## The HUD hotbar sits on the carved panel (hotbar_panel, real size); the copy inside the bag window does not.
var framed := false
@export var art_gap := 1                     ## 23 art px step - 22 px slot (assets/game/ui/skin/README.md)
@export var pad_left := 8                    ## art px from the panel box to the first slot
@export var pad_top := 11
@export var panel_w := 223
@export var panel_h := 44
@export var panel_pad := 8                   ## transparent pad around the panel box inside hotbar_panel.png

var _loadout: Loadout
var _inv: Inventory
var interactive := false   ## set by the bag panel while it is open
var _slots: Array[ItemSlot] = []
var _row: HBoxContainer
var _pad: MarginContainer

func bind(l: Loadout, inv: Inventory) -> void:
	_loadout = l
	_inv = inv

func slots() -> Array[ItemSlot]:
	return _slots

func get_skin() -> InventorySkin:
	if skin == null:
		skin = load("res://data/ui/inventory_skin.tres")
	return skin

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if framed:   # the panel is drawn behind (see _draw); the row sits on its carved strip
		_pad = MarginContainer.new()
		_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_pad)
		_pad.add_child(_row)
		draw.connect(_draw_panel)
	else:
		add_child(_row)
	for i in Inventory.HOTBAR:
		var s: ItemSlot = SLOT_SCENE.instantiate()
		s.index = i
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.key_text = _key_text(i)
		s.slot_clicked.connect(func(idx: int, b: int, sh: bool): slot_clicked.emit(idx, b, sh))
		_row.add_child(s)
		_slots.append(s)

## The key shown in the corner comes from the input action, so a rebind shows up.
func _key_text(i: int) -> String:
	var action := "slot_%d" % (i + 1)
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				return (ev as InputEventKey).as_text_physical_keycode()
	return str(i + 1)

func _process(_delta: float) -> void:
	if _loadout == null or _inv == null or _row == null:
		return
	var sk := get_skin()
	_row.add_theme_constant_override("separation", _gap(sk))
	if _pad:
		var sc := sk.art_scale
		_pad.add_theme_constant_override("margin_left", pad_left * sc)
		_pad.add_theme_constant_override("margin_top", pad_top * sc)
		if sk.hotbar_panel_tex:
			var bs := _panel_box(sk)
			custom_minimum_size = bs.size
			_pad.custom_minimum_size = bs.size
		queue_redraw()
	var owner_node := _loadout.get_parent()
	var pending: int = owner_node.pending_slot() if owner_node.has_method("pending_slot") else -1
	var shown := pending if pending >= 0 else _loadout.selected_slot
	for i in _slots.size():
		var s := _slots[i]
		s.skin = sk
		s.icon_tilt_degrees = icon_tilt_degrees
		s.set_item(_inv.slot_item(i), _inv.slot_count(i))
		s.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
		s.selected = i == shown
		s.refresh()

func _gap(sk: InventorySkin) -> int:
	if gap_override >= 0:
		return gap_override
	return art_gap * sk.art_scale if framed else sk.slot_gap

## Panel box (the carved strip) in screen px.
func _panel_box(sk: InventorySkin) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(panel_w, panel_h) * sk.art_scale)

func _draw_panel() -> void:
	var sk := get_skin()
	if sk.hotbar_panel_tex == null:
		return
	var sc := sk.art_scale
	draw_texture_rect(sk.hotbar_panel_tex, Rect2(Vector2(-panel_pad, -panel_pad) * sc, sk.hotbar_panel_tex.get_size() * sc), false)
