class_name Inventory
extends Node
## What the player carries (v1 §5, decision 0029): 36 slots. Slots 0-8 are the hotbar, 9-35 the bag.
## A slot = one ItemData + a count. Stacks to `ItemData.stack_limit()`. The hotbar holds at most
## `max_hotbar_weapons` weapons (decision 0003): a 3rd one can only live in the bag.
## Pure data + rules: the bag panel, hotbar and Loadout all read it; none of them own any item.

signal changed

const HOTBAR := 9
const SIZE := 36

@export var start_items: Array[ItemData] = []   ## starting kit, placed in order (v1: a wooden sword; the rest is crafted, decision 0031)
@export var max_hotbar_weapons := 2
## Bag moves are refused while a Boss is ENGAGED (decision 0003: "bag is locked in combat").
@export var lock_in_boss_fight := true

## The stack on the "cursor" while the bag panel is open (click picks it up, click places it).
var held_item: ItemData
var held_count := 0

var _item: Array[ItemData] = []
var _count: Array[int] = []
var _known := {}        # id -> ItemData, so item(id) works after the last stack is gone
var _held_from := -1    # slot the held stack came from; add() leaves it free so it can go back

func _init() -> void:
	_item.resize(SIZE)
	_count.resize(SIZE)
	_count.fill(0)

func _ready() -> void:
	for it in start_items:
		add(it, 1)

# ------------------------------------------------------------------ reading

func slot_item(i: int) -> ItemData:
	return _item[i]

func slot_count(i: int) -> int:
	return _count[i]

func count(item_id: StringName) -> int:
	var n := 0
	for i in SIZE:
		if _item[i] != null and _item[i].id == item_id:
			n += _count[i]
	return n

## id -> total count over all slots.
func items() -> Dictionary:
	var d := {}
	for i in SIZE:
		if _item[i] != null:
			d[_item[i].id] = d.get(_item[i].id, 0) + _count[i]
	return d

func item(id: StringName) -> ItemData:
	return _known.get(id)

func used_slots() -> int:
	var n := 0
	for i in SIZE:
		n += 1 if _item[i] != null else 0
	return n

func hotbar_weapon_count(except := -1) -> int:
	var n := 0
	for i in HOTBAR:
		if i != except and _item[i] != null and _item[i].category == "weapon":
			n += 1
	return n

## Boss fight in progress: the bag may not be rearranged.
func locked() -> bool:
	if not lock_in_boss_fight or not is_inside_tree():
		return false
	for b in get_tree().get_nodes_in_group("boss"):
		if b.get("aggro") == Boss.Aggro.ENGAGED:
			return true
	return false

## May `it` sit in slot `i` (the max-weapons rule)?
func can_place(i: int, it: ItemData) -> bool:
	return i >= HOTBAR or it.category != "weapon" or hotbar_weapon_count(i) < max_hotbar_weapons

# ------------------------------------------------------------------ adding

## Fills existing stacks first, then empty slots. Tools and weapons try the hotbar first, everything
## else the bag first (so wood never takes a hotbar slot while the bag has room). Returns the
## leftover that did not fit: a pickup with a leftover stays on the ground.
func add(it: ItemData, amount: int) -> int:
	if it == null or amount <= 0:
		return 0
	_known[it.id] = it
	var left := _insert(it, amount, _order(it))
	if left < amount:
		changed.emit()
	return left

## How many more of `it` would fit (capped at 9999); the Collector asks before it pulls a pickup in.
func room_for(it: ItemData) -> int:
	return 9999 - _insert(it, 9999, _order(it), false)

func _order(it: ItemData) -> Array:
	# Tools, weapons and placeable stations try the hotbar first (you use them); materials the bag first.
	var r := range(0, SIZE) if (it.weapon != null or it.placeable != null) else range(HOTBAR, SIZE) + range(0, HOTBAR)
	return r

func _insert(it: ItemData, amount: int, slots: Array, commit := true) -> int:
	var left := amount
	var limit := it.stack_limit()
	var used_empty := {}
	for s in slots:
		if left <= 0:
			break
		if _item[s] != null and _item[s].id == it.id and s != _held_from:
			var put := mini(limit - _count[s], left)
			if put > 0:
				left -= put
				if commit:
					_count[s] += put
	for s in slots:
		if left <= 0:
			break
		if _item[s] == null and s != _held_from and not used_empty.has(s) and can_place(s, it):
			var put := mini(limit, left)
			left -= put
			used_empty[s] = true
			if commit:
				_item[s] = it
				_count[s] = put
	return left

## Takes `n` of item `id` from the slots (bag first, so a hotbar stack is the last to shrink). False and
## nothing taken if there is not enough.
func take(id: StringName, n: int) -> bool:
	if count(id) < n:
		return false
	var left := n
	for s in range(HOTBAR, SIZE) + range(0, HOTBAR):
		if left <= 0:
			break
		if _item[s] != null and _item[s].id == id:
			var t := mini(_count[s], left)
			_put(s, _item[s], _count[s] - t)
			left -= t
	changed.emit()
	return true

## Takes up to `n` out of slot `i`; returns how many left.
func remove_from_slot(i: int, n: int) -> int:
	if i < 0 or i >= SIZE or _item[i] == null:
		return 0
	var t := mini(n, _count[i])
	_put(i, _item[i], _count[i] - t)
	changed.emit()
	return t

## Adds `n` of `it`; what does not fit drops on the ground at the player, so a crafted item is never lost.
## Returns what could neither be stored nor dropped (0 unless there is no world to drop into).
func give_or_drop(it: ItemData, n: int) -> int:
	var left := add(it, n)
	if left > 0 and _drop_on_ground(it, left):
		left = 0
	return left

## Puts a stack on the cursor (only when it is empty): the furnace hands over what you take out of it.
func hold(it: ItemData, n: int) -> bool:
	if held_item != null or it == null or n <= 0:
		return false
	_known[it.id] = it
	held_item = it
	held_count = n
	_held_from = -1
	changed.emit()
	return true

## Sets how much is left on the cursor after something took some (0 = cursor empty).
func set_held_count(n: int) -> void:
	if n <= 0:
		_drop_held()
	else:
		held_count = n
	changed.emit()

## Dev / test kit (F3 "Give W3 kit"): replaces every slot with sword, bow, axe, pickaxe in slots 1-4 and
## re-arms the first weapon, like the old start kit (decision 0031).
func give_dev_kit() -> void:
	for i in SIZE:
		_item[i] = null
		_count[i] = 0
	_drop_held()
	for id in ["sword", "bow", "stone_axe", "stone_pickaxe"]:
		add(load("res://data/items/%s.tres" % id), 1)
	var lo = get_parent().get_node_or_null("Loadout") if get_parent() else null
	if lo != null and lo.has_method("rearm"):
		lo.rearm()

## Removes every material stack. Tools and weapons stay (F3 "Clear items").
func clear() -> void:
	for i in SIZE:
		if _item[i] != null and _item[i].category == "material":
			_item[i] = null
			_count[i] = 0
	if held_item != null and held_item.category == "material":
		held_item = null
		held_count = 0
		_held_from = -1
	changed.emit()

# ------------------------------------------------------------------ bag clicks

## Left click on slot `i`: pick up / place / merge / swap. Right click (`half`) picks up half.
func click_slot(i: int, half := false) -> bool:
	if locked() or i < 0 or i >= SIZE:
		return false
	var it := _item[i]
	var n := _count[i]
	if held_item == null:
		if it == null:
			return false
		var take := ceili(n / 2.0) if half else n
		held_item = it
		held_count = take
		_held_from = i
		_put(i, it, n - take)
	elif it == null:
		if not can_place(i, held_item):
			return false
		_put(i, held_item, held_count)
		_drop_held()
	elif it.id == held_item.id:
		var put := mini(it.stack_limit() - n, held_count)
		_put(i, it, n + put)
		held_count -= put
		if held_count <= 0:
			_drop_held()
	else:
		if not can_place(i, held_item):
			return false
		var old_it := it
		var old_n := n
		_put(i, held_item, held_count)
		held_item = old_it
		held_count = old_n
		_held_from = i
	changed.emit()
	return true

## Shift click: moves the whole stack between hotbar and bag. What does not fit stays where it was.
func shift_move(i: int) -> bool:
	if locked() or held_item != null or i < 0 or i >= SIZE or _item[i] == null:
		return false   # not while a stack is on the cursor: it could slip a 3rd weapon into the hotbar
	var it := _item[i]
	var n := _count[i]
	var target := range(HOTBAR, SIZE) if i < HOTBAR else range(0, HOTBAR)
	_put(i, null, 0)
	var left := _insert(it, n, target)
	if left > 0:
		_put(i, it, left)
	if left == n:
		return false
	changed.emit()
	return true

## Bag closed with a stack on the cursor: back where it came from if that still fits, else anywhere
## that fits, else dropped on the ground at the player. Nothing is ever deleted: if even the drop is
## impossible the stack stays on the cursor.
func return_held() -> void:
	if held_item == null:
		return
	var it := held_item
	var n := held_count
	var from := _held_from
	_drop_held()
	if from >= 0 and can_place(from, it) and (_item[from] == null or _item[from].id == it.id):
		var put := mini(it.stack_limit() - _count[from], n)
		_put(from, it, _count[from] + put)
		n -= put
	if n > 0:
		n = _insert(it, n, _order(it))
	if n > 0 and not _drop_on_ground(it, n):
		held_item = it
		held_count = n
	changed.emit()

func _drop_on_ground(it: ItemData, n: int) -> bool:
	var me := get_parent() as Node2D
	if me == null or me.get_parent() == null or not is_inside_tree():
		return false
	Pickup.spawn(me.get_parent(), it, n, me.position, me.position)
	return true

func _drop_held() -> void:
	held_item = null
	held_count = 0
	_held_from = -1

func _put(i: int, it: ItemData, n: int) -> void:
	_item[i] = it if n > 0 else null
	_count[i] = n if n > 0 else 0
	if it != null:
		_known[it.id] = it
