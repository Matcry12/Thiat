extends SceneTree
# Regression tests for the W3 judge findings: (1) return_held never deletes items, (2) no shift move while
# holding / no 3rd hotbar weapon, (3) the free way back is only to the weapon you put away, (4) ItemSlot
# does not rewrite layout or rebuild styles every frame, (minor) the wheel's pending slot is highlighted.
const ClassicArena = preload("res://tests/support/classic_arena.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _ground(it: ItemData) -> int:
	var n := 0
	for p: Pickup in get_nodes_in_group("pickup"):
		if p.item == it:
			n += p.amount
	return n

func _init() -> void:
	var arena = ClassicArena.make()
	root.add_child(arena)
	var boss: Boss = arena.get_node("Boss")
	boss.passive = true
	boss.set_physics_process(false)   # its aggro would lock the bag
	boss.aggro = Boss.Aggro.IDLE
	await process_frame
	boss.aggro = Boss.Aggro.IDLE
	var player = arena.get_node("Player")
	player.get_node("Inventory").give_dev_kit()   # W4: the start kit is only a wooden sword (decision 0031)
	player.set_physics_process(false)
	var inv: Inventory = player.get_node("Inventory")
	var lo: Loadout = player.get_node("Loadout")
	var hud: HUD = arena.get_node("HUD")
	var wood: ItemData = load("res://data/items/wood.tres")
	var axe: ItemData = inv.slot_item(2)
	var sword: ItemData = inv.slot_item(0)

	# --- 1. item loss ---
	inv.add(wood, 99999)     # full
	var a := Inventory.HOTBAR
	inv.click_slot(a, true)          # right click: half of a wood stack
	inv.click_slot(2)                # swap with the axe: the axe is on the cursor
	_check(inv.held_item == axe, "the axe is on the cursor")
	hud.bag().toggle()
	hud.bag().close()                # closes: closed -> return_held
	var have := inv.count(&"stone_axe") + _ground(axe) + (inv.held_count if inv.held_item == axe else 0)
	_check(have == 1, "the axe still exists after closing the full bag (%d)" % have)
	_check(inv.held_item == null and _ground(axe) == 1, "it was dropped on the ground at the player, not deleted")
	var lone := Inventory.new()
	root.add_child(lone)
	lone.add(wood, 99999)
	lone.click_slot(a)
	lone.click_slot(a + 1, true)
	lone.click_slot(a)    # no room, no player to drop at
	lone.return_held()
	_check(lone.count(&"wood") + (lone.held_count if lone.held_item else 0) == 36 * 64, "no player to drop at: the stack stays on the cursor, nothing deleted")

	# --- 2. a 3rd weapon sits in the hotbar; shift click moves it out and back ---
	inv.clear()
	for p in get_nodes_in_group("pickup"):
		p.free()
	inv.add(sword, 1)
	var spare := -1
	for i in range(2, Inventory.HOTBAR):
		if inv.slot_item(i) == sword:
			spare = i
	_check(spare >= 0 and lo.weapons.size() == 3, "a 3rd sword lands in the hotbar (%d weapons)" % lo.weapons.size())
	inv.click_slot(0)    # hold the hotbar sword
	_check(not inv.shift_move(spare), "shift click is refused while a stack is held")
	hud.bag().toggle()
	hud.bag().close()
	_check(lo.weapons.size() == 3 and inv.slot_item(0) == sword, "after closing: the held sword is back, 3 weapons")
	_check(inv.shift_move(spare) and inv.slot_item(spare) == null and lo.weapons.size() == 2, "shift click sends it to the bag")
	var in_bag := -1
	for i in range(Inventory.HOTBAR, Inventory.SIZE):
		if inv.slot_item(i) == sword:
			in_bag = i
	_check(inv.shift_move(in_bag) and lo.weapons.size() == 3, "shift click from the bag puts it in the hotbar again")

	# --- 3. every switch is instant ---
	await physics_frame
	lo.select(0)
	_check(lo.active_weapon() == sword.weapon and lo.select(3) and lo.active_weapon() == inv.slot_item(3).weapon, "pickaxe in hand, sword put away")
	boss.aggro = Boss.Aggro.IDLE   # (the physics frames above let it re-engage)
	_check(lo.select(1) and lo.active_weapon() == inv.slot_item(1).weapon, "the bow comes at once")
	_check(lo.select(0) and lo.active_weapon() == sword.weapon, "and the sword back at once")

	# --- 4. ItemSlot: layout belongs to the scene, styles are built once ---
	var slot: ItemSlot = load("res://scenes/ui/item_slot.tscn").instantiate()
	slot.skin = InventorySkin.new()
	root.add_child(slot)
	await process_frame
	var style_before = slot.get_node("Frame/Placeholder").get_theme_stylebox("panel")
	slot.get_node("Count").offset_right = -9.0
	slot.get_node("Tint").anchor_left = 0.1
	for i in 5:
		slot.set_item(sword, i + 2)
		slot.selected = i % 2 == 0
		slot.refresh()
	_check(slot.get_node("Frame/Placeholder").get_theme_stylebox("panel") == style_before, "refresh() does not rebuild styles")
	_check(slot.get_node("Count").offset_right == -9.0 and is_equal_approx(slot.get_node("Tint").anchor_left, 0.1), "refresh() does not rewrite layout (anchors / offsets)")
	_check(slot.get_node("Count").text == "6", "...but item / count still update")
	slot.skin.frame_color = Color.RED
	_check(slot.get_node("Frame/Placeholder").get_theme_stylebox("panel") != style_before, "a skin change re-applies the look once")

	# --- minor: the pending wheel slot is highlighted ---
	player.set_physics_process(true)
	player.aim_override = Vector2.RIGHT
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	player._unhandled_input(ev)
	var hb := hud.hotbar()
	hb._process(0.016)
	var pend: int = player.pending_slot()
	_check(pend >= 0 and hb.slots()[pend].selected, "the pending wheel slot is highlighted before it is selected")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
