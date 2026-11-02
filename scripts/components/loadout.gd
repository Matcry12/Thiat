extends Node
class_name Loadout
## Weapon swap (decision 0003): a gated cast, then a cooldown before the next
## swap. A component like dodge.gd — never reads Input; the owner calls
## try_swap()/cancel_swap() and reads is_casting()/cooldown_left() for HUD/F3.

signal swap_started(to_index: int)
signal swap_finished(weapon: WeaponData)
signal swap_cancelled

## The weapons in the hotbar, in slot order (max 2, decision 0003). Owned by the Inventory: sync()
## rewrites it whenever the inventory changes. Only set it by hand in a test without an Inventory.
@export var weapons: Array[WeaponData] = []
@export var inventory_path: NodePath
@export var swap_cast := 0.6
@export var swap_cooldown := 5.0
@export var weapon_holder_path: NodePath

## Bare hands (v1 W2). Holstering is instant and free: it always returns to the same weapon, so it can
## never skip the swap cast/cooldown of decision 0003. A tool, a material or an empty slot is
## "hands" too: select() holds that tool (or these fists) at once. Only weapon <-> weapon costs a swap.
@export var unarmed: WeaponData

## Hotbar slot that is selected (what is in the player's hands). Code-owned.
var selected_slot := 0
## Set by the Respawner when a death took the weapon out of your hands: the first weapon that comes back is put
## straight into them (no swap cast, no cooldown).
var arm_on_next_weapon := false

var _weapon_holder: WeaponHolder
var _holstered := false
var _stowed: WeaponData   # the weapon put away while holstered; going back to THIS one is instant
var _held_tool: WeaponData   # while holstered: the tool in hand; null = bare hands
var _inventory: Inventory
var _synced := false
var _weapon_slots: Array[int] = []   # hotbar slot of weapons[i]
var _active_index := 0
var _casting := false
var _cast_left := 0.0
var _cast_to := 0
var _cooldown_left := 0.0

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
	if _casting:
		cancel_swap()   # the list may have moved under the cast
	if not _synced:   # first sync (the start kit): armed with the first weapon
		_synced = true
		_active_index = 0
		_holstered = weapons.is_empty()
		_held_tool = null
		selected_slot = weapon_slot(0) if not weapons.is_empty() else 0
	elif _holstered:
		_held_tool = _tool_in(selected_slot)
		_active_index = weapons.find(_stowed) if _stowed != null else -1   # -1 = it left the hotbar: no free way back
		if _active_index < 0:
			_stowed = null
	else:
		var idx := weapons.find(before)
		if idx >= 0:
			_active_index = idx
			selected_slot = _weapon_slots[idx]
		else:   # the weapon in hand left the hotbar: bare hands
			_holstered = true
			_held_tool = null
			_stowed = null
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

## Selects hotbar slot `slot` (keys 1-9, wheel). A weapon swaps (cast + cooldown, 0003) unless it is the
## one already in the other hand's memory; a tool, material or empty slot switches at once.
func select(slot: int) -> bool:
	if _inventory == null or slot < 0 or slot >= Inventory.HOTBAR:
		return false
	var it := _inventory.slot_item(slot)
	if it != null and it.category == "weapon" and it.weapon != null:
		var idx := _weapon_slots.find(slot)
		if idx < 0:
			return false
		var ok := try_swap(idx)
		if ok and not _casting:   # the instant way back to the same weapon
			selected_slot = slot
		return ok
	if _casting or (_weapon_holder and _weapon_holder.phase != WeaponHolder.Phase.IDLE):
		return false
	var tool := _tool_in(slot)
	if _holstered and slot == selected_slot and tool == _held_tool:
		return false
	if not _holstered:
		_stowed = active_weapon()
	_holstered = true
	_held_tool = tool
	selected_slot = slot
	if _weapon_holder:
		_weapon_holder.cancel()
	swap_finished.emit(active_weapon())
	return true

func active_weapon() -> WeaponData:
	if _holstered:
		return _held_tool if _held_tool != null else unarmed
	return weapons[_active_index] if _active_index < weapons.size() else unarmed

func active_index() -> int:
	return _active_index

func is_casting() -> bool:
	return _casting

func cast_left() -> float:
	return _cast_left

func cooldown_left() -> float:
	return _cooldown_left

## Fails (returns false) if `index` is already active, out of range, a swap
## is already casting, or the cooldown from the last swap hasn't cleared.
func try_swap(index: int) -> bool:
	if _holstered and index == _active_index:
		return toggle_hands()
	if index == _active_index or index < 0 or index >= weapons.size():
		return false
	if _casting or _cooldown_left > 0.0:
		return false
	_casting = true
	_cast_left = swap_cast
	_cast_to = index
	if _weapon_holder:
		_weapon_holder.cancel()   # a swap cancels an in-progress swing
	swap_started.emit(index)
	return true

## Load a save: put the weapon of hotbar slot `slot` straight in the hands, no swap cast, no cooldown.
## Anything else (tool, material, empty) goes through select(), which is instant anyway.
func select_instant(slot: int) -> void:
	var idx := _weapon_slots.find(slot)
	if idx < 0:
		select(slot)
		return
	_casting = false
	_cast_left = 0.0
	_active_index = idx
	_holstered = false
	_stowed = null
	_held_tool = null
	selected_slot = slot
	if _weapon_holder:
		_weapon_holder.cancel()
	swap_finished.emit(active_weapon())

func is_holstered() -> bool:
	return _holstered

## False with bare hands (empty slot, material, placeable): attack input is ignored (decision 0052). A held tool still swings.
func can_attack() -> bool:
	return not _holstered or _held_tool != null

func toggle_hands() -> bool:
	# Not mid-swing / mid-draw: cancelling would skip the recovery for free (0003).
	if unarmed == null or _casting or (_weapon_holder and _weapon_holder.phase != WeaponHolder.Phase.IDLE):
		return false
	if _holstered and _active_index < 0:
		return false   # the put-away weapon left the hotbar: nothing to go back to for free
	if not _holstered:
		_stowed = active_weapon()
	_holstered = not _holstered
	_held_tool = null
	if not _holstered:
		selected_slot = maxi(weapon_slot(_active_index), 0) if _inventory else selected_slot
	if _weapon_holder:
		_weapon_holder.cancel()
	swap_finished.emit(active_weapon())
	return true

## Cancels an in-progress cast (dodge/guard call this). No cooldown charged.
func cancel_swap() -> void:
	if not _casting:
		return
	_casting = false
	_cast_left = 0.0
	swap_cancelled.emit()

func _physics_process(delta: float) -> void:
	if _casting:
		_cast_left -= delta
		if _cast_left <= 0.0:
			_casting = false
			_active_index = _cast_to
			_holstered = false
			_stowed = null
			_held_tool = null
			if weapon_slot(_cast_to) >= 0:
				selected_slot = weapon_slot(_cast_to)
			_cooldown_left = swap_cooldown
			swap_finished.emit(active_weapon())
	elif _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)


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
	var swap_state := "ready"
	if is_casting():
		swap_state = "casting %.2fs" % cast_left()
	elif cooldown_left() > 0.0:
		swap_state = "cooldown %.2fs" % cooldown_left()
	return "active: %s (%d)%s\nswap: %s" % [active_name, active_index(), " HOLSTERED" if is_holstered() else "", swap_state]
