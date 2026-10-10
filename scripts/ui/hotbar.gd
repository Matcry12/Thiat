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
@export var cast_color := Color(1, 1, 1, 0.4)
@export var cooldown_color := Color(0, 0, 0, 0.6)

var _loadout: Loadout
var _inv: Inventory
var interactive := false   ## set by the bag panel while it is open
var _slots: Array[ItemSlot] = []
var _row: HBoxContainer
var _cast_to := -1

func bind(l: Loadout, inv: Inventory) -> void:
	_loadout = l
	_inv = inv
	l.swap_started.connect(func(i: int): _cast_to = i)
	l.swap_finished.connect(func(_w): _cast_to = -1)
	l.swap_cancelled.connect(func(): _cast_to = -1)

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
	_row.add_theme_constant_override("separation", sk.slot_gap)
	var active := _loadout.active_index()
	var cd := _loadout.cooldown_left()
	var cd_frac := clampf(cd / maxf(_loadout.swap_cooldown, 0.001), 0.0, 1.0)
	var cast_frac := clampf(1.0 - _loadout.cast_left() / maxf(_loadout.swap_cast, 0.001), 0.0, 1.0)
	var owner_node := _loadout.get_parent()
	var pending: int = owner_node.pending_slot() if owner_node.has_method("pending_slot") else -1
	var shown := pending if pending >= 0 else _loadout.selected_slot
	var casting_slot := _loadout.weapon_slot(_cast_to)
	for i in _slots.size():
		var s := _slots[i]
		s.skin = sk
		s.icon_tilt_degrees = icon_tilt_degrees
		s.set_item(_inv.slot_item(i), _inv.slot_count(i))
		s.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
		s.selected = i == shown
		s.cast_progress = cast_frac if (_loadout.is_casting() and i == casting_slot) else 0.0
		# Shade the weapon slots that cannot be swapped to yet: every weapon except the last one drawn.
		var is_weapon := s.item != null and s.item.category == "weapon"
		s.cooldown_frac = cd_frac if (cd > 0.0 and is_weapon and _loadout.weapon_slot(active) != i) else 0.0
		s.refresh()
