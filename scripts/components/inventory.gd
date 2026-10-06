class_name Inventory
extends Node
## What the player carries. W2: unlimited counts per item. W3 makes it slot-based behind the same
## add / count / changed API.
## ponytail: no stack limit yet, W3 adds slots and max stacks.

signal changed

var _counts := {}   # StringName -> int
var _items := {}    # StringName -> ItemData

func add(item: ItemData, amount: int) -> int:
	if item == null or amount <= 0:
		return 0
	_counts[item.id] = _counts.get(item.id, 0) + amount
	_items[item.id] = item
	changed.emit()
	return 0

func count(item_id: StringName) -> int:
	return _counts.get(item_id, 0)

func items() -> Dictionary:
	return _counts.duplicate()

func item(id: StringName) -> ItemData:
	return _items.get(id)

func clear() -> void:
	_counts.clear()
	changed.emit()
