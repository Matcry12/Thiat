extends SceneTree
# W3: slot-based Inventory. Stacking + leftover, per-item max stack, the hotbar's max-2-weapons rule,
# click pick up / place / merge / swap / half, shift move, room_for, clear keeps tools.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var wood: ItemData = load("res://data/items/wood.tres")
	var stone: ItemData = load("res://data/items/stone.tres")
	var sword: ItemData = load("res://data/items/wooden_sword.tres")
	var bow: ItemData = load("res://data/items/bow.tres")
	var axe: ItemData = load("res://data/items/stone_axe.tres")
	var inv := Inventory.new()
	root.add_child(inv)

	# --- stacking ---
	_check(wood.max_stack == 64 and wood.category == "material", "wood: material, stacks to 64")
	_check(sword.stack_limit() == 1 and sword.category == "weapon" and sword.weapon != null, "wooden sword: weapon item, stack 1")
	var big_sword: ItemData = sword.duplicate()
	big_sword.max_stack = 64   # the shipped weapons all say max_stack = 1, which would hide a broken stack_limit()
	_check(big_sword.stack_limit() == 1, "a weapon never stacks, even if its file says max_stack 64")
	_check(inv.add(wood, 100) == 0 and inv.count(&"wood") == 100, "100 wood fit")
	_check(inv.slot_count(Inventory.HOTBAR) == 64 and inv.slot_count(Inventory.HOTBAR + 1) == 36, "wood fills the BAG first: 64 + 36")
	_check(inv.slot_item(0) == null, "materials do not take hotbar slots while the bag has room")
	inv.add(wood, 28)
	_check(inv.slot_count(Inventory.HOTBAR + 1) == 64 and inv.count(&"wood") == 128, "tops up the open stack before a new one")

	# --- leftover when full ---
	var big := Inventory.new()
	root.add_child(big)
	var left := big.add(wood, 36 * 64 + 10)
	_check(left == 10 and big.count(&"wood") == 36 * 64 and big.used_slots() == 36, "full inventory returns the leftover (%d)" % left)
	_check(big.room_for(wood) == 0 and big.room_for(stone) == 0, "room_for is 0 when full")
	_check(inv.room_for(stone) > 0, "room_for > 0 when there is space")
	_check(big.add(stone, 1) == 1, "a different item does not fit either")

	# --- tools and weapons go to the hotbar first ---
	var kit := Inventory.new()
	kit.start_items.assign([sword, bow, axe])
	root.add_child(kit)
	await process_frame
	_check(kit.slot_item(0) == sword and kit.slot_item(1) == bow and kit.slot_item(2) == axe, "start kit lands in slots 0, 1, 2")

	# --- any number of weapons in the hotbar ---
	var spare: ItemData = sword
	_check(kit.add(spare, 1) == 0 and kit.slot_item(3) == spare, "a 3rd weapon goes to the hotbar")
	for i in 5:
		kit.add(bow, 1)
	var wcount := 0
	for i in Inventory.HOTBAR:
		wcount += 1 if kit.slot_item(i) != null and kit.slot_item(i).category == "weapon" else 0
	_check(wcount == 8 and kit.slot_item(8) == bow, "weapons fill the hotbar (8 weapons + axe)")
	kit.add(bow, 1)
	_check(kit.slot_item(Inventory.HOTBAR) == bow, "a full hotbar overflows to the first bag slot")
	kit.click_slot(Inventory.HOTBAR)    # pick the overflow weapon up
	_check(kit.held_item == bow and kit.click_slot(8) and kit.held_item == bow, "a weapon can be put on a hotbar slot over another weapon")
	_check(kit.click_slot(2) and kit.held_item == axe and kit.slot_item(2) == bow, "...and over a tool")
	kit.return_held()
	_check(kit.held_item == null, "return_held empties the cursor")
	_check(kit.add(sword, 1) == 0 and kit.used_slots() == 11, "no weapon is lost")

	# --- clicks ---
	var c := Inventory.new()
	root.add_child(c)
	c.add(wood, 64)
	c.add(wood, 10)
	var a := Inventory.HOTBAR
	_check(c.click_slot(a) and c.held_item == wood and c.held_count == 64 and c.slot_item(a) == null, "click picks the whole stack up")
	_check(c.click_slot(a + 5) and c.held_item == null and c.slot_count(a + 5) == 64, "click on an empty slot places it")
	_check(c.click_slot(a + 1, true) and c.held_count == 5 and c.slot_count(a + 1) == 5, "right click takes half, rounded up (10 -> 5)")
	_check(c.click_slot(a + 5) and c.slot_count(a + 5) == 64 and c.held_count == 5, "merge stops at max_stack, the rest stays on the cursor")
	_check(c.click_slot(a + 2) and c.held_item == null, "put the rest down")
	c.add(stone, 3)
	var s_slot := -1
	for i in range(a, Inventory.SIZE):
		if c.slot_item(i) == stone:
			s_slot = i
	c.click_slot(s_slot)
	c.click_slot(a + 5)   # swap stone with the full wood stack
	_check(c.held_item == wood and c.held_count == 64 and c.slot_item(a + 5) == stone, "clicking a different item swaps them")
	c.return_held()
	_check(c.count(&"wood") == 74 and c.count(&"stone") == 3, "nothing lost or made: 74 wood, 3 stone")

	# --- shift move ---
	var sm := Inventory.new()
	sm.start_items.assign([sword])
	root.add_child(sm)
	await process_frame
	sm.add(wood, 10)
	_check(sm.shift_move(Inventory.HOTBAR) and sm.slot_item(1) == wood, "shift click: bag -> first free hotbar slot")
	_check(sm.shift_move(0) and sm.slot_item(0) == null and sm.slot_item(Inventory.HOTBAR) == sword, "shift click: hotbar -> bag")
	_check(not sm.shift_move(20), "shift click on an empty slot does nothing")

	# --- clear keeps tools ---
	kit.add(wood, 5)
	kit.clear()
	_check(kit.count(&"wood") == 0 and kit.count(axe.id) == 1 and kit.slot_item(2) == bow, "clear() removes materials, keeps tools and weapons")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
