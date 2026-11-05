extends Node
class_name Loadout
## What is in the player's hands. A component like dodge.gd - never reads Input; the owner calls
## select(). Every switch (weapon, tool, material, empty slot) is instant: no cast, no cooldown.

signal swap_finished(weapon: WeaponData)

## The weapons in the hotbar, in slot order. Owned by the Inventory: sync() rewrites it whenever the
## inventory changes. Only set it by hand in a test without an Inventory.
@export var weapons: Array[WeaponData] = []
@export var inventory_path: NodePath
@export var weapon_holder_path: NodePath

## Bare hands (v1 W2). A tool, a material or an empty slot is "hands" too: select() holds that tool
## (or these fists) at once.
@export var unarmed: WeaponData

## Hotbar slot that is selected (what is in the player's hands). Code-owned.
var selected_slot := 0
## Set by the Respawner when a death took the weapon out of your hands: the first weapon that comes back is put
## straight into them.
var arm_on_next_weapon := false

var _weapon_holder: WeaponHolder
var _holstered := false
var _held_tool: WeaponData   # while holstered: the tool in hand; null = bare hands
var _inventory: Inventory
var _synced := false
var _weapon_slots: Array[int] = []   # hotbar slot of weapons[i]
var _active_index := 0

func _ready() -> void:
	add_to_group("debug")
	_weapon_holder = get_node_or_null(weapon_holder_path) as WeaponHolder
	_inventory = get_node_or_null(inventory_path) as Inventory
	if _inventory:
		_inventory.changed.connect(sync)   # the start kit arrives with Inventory._ready, after this

## Treats the next sync as the first one: armed with the first weapon (F3 "Give W3 kit", tests).
func rearm() -> void:
	_synced = false
	sync()

## Hotbar slot of weapons[i] (-1 if none).
func weapon_slot(i: int) -> int:
	return _weapon_slots[i] if i >= 0 and i < _weapon_slots.size() else -1

## Rebuilds `weapons` from the hotbar and keeps what is in the hands valid.
func sync() -> void:
	var before := active_weapon()
	weapons.clear()
	_weapon_slots.clear()
	for s in Inventory.HOTBAR:
		var it := _inventory.slot_item(s)
		if it != null and it.category == "weapon" and it.weapon != null:
			weapons.append(it.weapon)
			_weapon_slots.append(s)
	if not _synced:   # first sync (the start kit): armed with the first weapon
		_synced = true
		_active_index = 0
		_holstered = weapons.is_empty()
		_held_tool = null
		selected_slot = weapon_slot(0) if not weapons.is_empty() else 0
	else:
		# What sits in the selected slot is what is in hand (a weapon too). Exception: a held weapon
		# that moved to another slot follows it.
		var sel_idx := _weapon_slots.find(selected_slot)
		var sel_w: WeaponData = weapons[sel_idx] if sel_idx >= 0 else null
		var follow := -1
		if not _holstered and not (sel_w != null) and before != null:
			follow = weapons.find(before)
		if follow >= 0:
			_active_index = follow
			selected_slot = _weapon_slots[follow]
		elif sel_idx >= 0:
			_active_index = sel_idx
			_holstered = false
			_held_tool = null
		else:   # tool, material, empty or the held weapon left: that is in hand
			_holstered = true
			_held_tool = _tool_in(selected_slot)
			_active_index = -1
	if arm_on_next_weapon and not weapons.is_empty() and _holstered:
		arm_on_next_weapon = false
		select_instant(_weapon_slots[0])
		return
	if active_weapon() != before:
		if _weapon_holder:
			_weapon_holder.cancel()
		swap_finished.emit(active_weapon())

func _tool_in(slot: int) -> WeaponData:
	var it := _inventory.slot_item(slot)
	return it.weapon if it != null and it.category == "tool" else null

## Selects hotbar slot `slot` (keys 1-9, wheel). Instant for everything. Refused while a swing or draw
## runs (a switch would cancel it and skip its recovery) and when `slot` is already in hand.
func select(slot: int) -> bool:
	if _inventory == null or slot < 0 or slot >= Inventory.HOTBAR:
		return false
	if _weapon_holder and _weapon_holder.phase != WeaponHolder.Phase.IDLE:
		return false
	var it := _inventory.slot_item(slot)
	if it != null and it.category == "weapon" and it.weapon != null:
		var idx := _weapon_slots.find(slot)
		if idx < 0 or (not _holstered and idx == _active_index):
			return false
		_set_weapon(idx, slot)
		return true
	var tool := _tool_in(slot)
	if _holstered and slot == selected_slot and tool == _held_tool:
		return false
	_holstered = true
	_held_tool = tool
	selected_slot = slot
	if _weapon_holder:
		_weapon_holder.cancel()
	swap_finished.emit(active_weapon())
	return true

func _set_weapon(idx: int, slot: int) -> void:
	_active_index = idx
	_holstered = false
	_held_tool = null
	selected_slot = slot
	if _weapon_holder:
		_weapon_holder.cancel()
	swap_finished.emit(active_weapon())

func active_weapon() -> WeaponData:
	if _holstered:
		return _held_tool if _held_tool != null else unarmed
	return weapons[_active_index] if _active_index < weapons.size() else unarmed

func active_index() -> int:
	return _active_index

## Load a save / respawn: put the weapon of hotbar slot `slot` straight in the hands, even mid-swing.
## Anything else (tool, material, empty) goes through select().
func select_instant(slot: int) -> void:
	var idx := _weapon_slots.find(slot)
	if idx < 0:
		select(slot)
		return
	_set_weapon(idx, slot)

func is_holstered() -> bool:
	return _holstered

## False with bare hands (empty slot, material, placeable): attack input is ignored (decision 0052). A held tool still swings.
func can_attack() -> bool:
	return not _holstered or _held_tool != null

# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")
func debug_name() -> String:
	return "Loadout"

func debug_category() -> String:
	return "Combat"

func status_text() -> String:
	var active := active_weapon()
	var active_name := "(none)"
	if active != null:
		active_name = active.resource_path.get_file().get_basename() if active.resource_path != "" else "(unsaved)"
	return "active: %s (%d)%s" % [active_name, active_index(), " HOLSTERED" if is_holstered() else ""]
