extends SceneTree
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var wood: ItemData = load("res://data/items/wood.tres")
	var stone: ItemData = load("res://data/items/stone.tres")
	var ore: ItemData = load("res://data/items/copper_ore.tres")
	_check(wood.id == &"wood" and stone.id == &"stone" and ore.id == &"copper_ore", "3 items with ids")
	var inv := Inventory.new()
	root.add_child(inv)
	var fired := [0]
	inv.changed.connect(func(): fired[0] += 1)
	_check(inv.add(wood, 3) == 0 and inv.count(&"wood") == 3, "add 3 wood")
	inv.add(wood, 2)
	_check(inv.count(&"wood") == 5 and fired[0] == 2, "stacks, changed fires per add")
	_check(inv.add(stone, 0) == 0 and inv.count(&"stone") == 0 and fired[0] == 2, "add 0 does nothing")
	_check(inv.add(stone, -4) == 0 and inv.count(&"stone") == 0, "negative does nothing")
	_check(inv.item(&"wood") == wood, "item lookup by id")
	inv.clear()
	_check(inv.items().is_empty() and fired[0] == 3, "clear empties and fires")
	var w := WeaponData.new()
	_check(w.gather_damage == 0.0 and w.tool_power == 0, "weapons can't gather by default")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
