extends SceneTree
# W3: selecting hotbar slots. Tool / empty slot = instant (no cast, no cooldown); weapon <-> weapon keeps
# the decision 0003 cast + cooldown; real key input; bag lock while the boss is engaged; tool bonus.
const ClassicArena = preload("res://tests/support/classic_arena.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _node(arena: Node, path: String, at: Vector2) -> ResourceNode:
	var n: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	n.setup(load(path), 0)
	n.position = at
	arena.add_child(n)
	return n

func _swing(wh: WeaponHolder) -> void:
	wh.aim_direction = Vector2.RIGHT
	wh.try_attack()
	for i in 30:
		await physics_frame

func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame
	Input.action_release(action)
	await physics_frame

func _init() -> void:
	var arena = ClassicArena.make()
	root.add_child(arena)
	var boss: Boss = arena.get_node("Boss")
	boss.passive = true
	await process_frame
	var player = arena.get_node("Player")
	var lo: Loadout = player.get_node("Loadout")
	var inv: Inventory = player.get_node("Inventory")
	var wh: WeaponHolder = player.get_node("WeaponHolder")
	var hud: HUD = arena.get_node("HUD")
	player.aim_override = Vector2.RIGHT
	player.global_position += Vector2(0, 160)
	lo.swap_cast = 0.2
	lo.swap_cooldown = 0.5
	await physics_frame

	# --- the kit ---
	_check(inv.slot_item(0).id == &"sword" and inv.slot_item(1).id == &"bow" and inv.slot_item(2).id == &"stone_axe" and inv.slot_item(3).id == &"stone_pickaxe", "start kit: sword, bow, axe, pickaxe in slots 1-4")
	_check(lo.weapons.size() == 2 and lo.active_weapon() == inv.slot_item(0).weapon and lo.selected_slot == 0, "sword in hand, slot 1 selected")

	# --- tool: instant, no cast, no cooldown ---
	_check(lo.select(2) and not lo.is_casting() and lo.cooldown_left() == 0.0, "axe: switches at once, no cast, no cooldown")
	_check(lo.active_weapon() == inv.slot_item(2).weapon and wh.weapon == lo.active_weapon() and lo.selected_slot == 2, "axe is the holder's weapon, slot 3 selected")
	_check(lo.select(3) and lo.active_weapon() == inv.slot_item(3).weapon, "tool to tool is instant too")
	_check(lo.select(7) and lo.active_weapon() == lo.unarmed and lo.selected_slot == 7, "empty slot = bare hands, at once")
	_check(lo.select(0) and not lo.is_casting() and lo.cooldown_left() == 0.0 and lo.active_weapon() == inv.slot_item(0).weapon, "back to the last weapon: instant, free")

	# --- weapon <-> weapon: cast + cooldown ---
	_check(lo.select(1) and lo.is_casting(), "sword -> bow starts a swap cast")
	lo.swap_cooldown = 5.0
	var n0 := 0
	while lo.is_casting() and n0 < 100:
		await physics_frame
		n0 += 1
	_check(not lo.is_casting() and lo.active_weapon() == inv.slot_item(1).weapon and lo.selected_slot == 1 and lo.cooldown_left() > 0.0, "bow arrives after the cast, cooldown running")
	_check(lo.select(2) and lo.active_weapon() == inv.slot_item(2).weapon, "tool switch is allowed during the swap cooldown")
	_check(lo.select(1) and not lo.is_casting(), "back to the bow (the last weapon) is instant even during the cooldown")
	_check(not lo.select(0), "...but the OTHER weapon is refused until the cooldown ends")
	lo._cooldown_left = 0.0

	# --- real keys through player.gd ---
	await _tap("slot_3")
	_check(lo.active_weapon() == inv.slot_item(2).weapon, "key 3 selects the axe")
	await _tap("slot_1")
	_check(lo.selected_slot == 0 or lo.is_casting(), "key 1 goes back toward the sword")
	for i in 60:
		await physics_frame
	await _tap("slot_9")
	_check(lo.active_weapon() == lo.unarmed, "key 9 (empty) = hands")
	await _tap("slot_1")
	_check(lo.active_weapon() == inv.slot_item(0).weapon, "key 1: sword back")
	# mouse wheel: settles on the last slot only
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	for k in 2:
		player._unhandled_input(ev)
	_check(lo.selected_slot == 0, "wheel does not select (and start a swap cast) on the way")
	for i in 30:
		await physics_frame
	_check(lo.selected_slot == 2 and lo.active_weapon() == inv.slot_item(2).weapon, "after the settle time the wheel lands on slot 3 (2 clicks down from 1)")

	# --- tool bonus on real nodes ---
	var axe: WeaponData = inv.slot_item(2).weapon
	var pick: WeaponData = inv.slot_item(3).weapon
	var fists: WeaponData = lo.unarmed
	var spot: Vector2 = player.global_position
	var tree := _node(arena, "res://data/resource_nodes/tree.tres", spot + Vector2(40, 0))
	await physics_frame
	player.get_node("WeaponVisual").set_aim_angle(0.0)
	await _swing(wh)    # axe in hand (slot 3)
	_check(tree.hp == tree.data.max_hp - axe.gather_damage * tree.data.tool_bonus, "axe swing on a tree takes gather_damage x tool_bonus (hp %.0f)" % tree.hp)
	await _swing(wh)
	_check(tree.is_broken(), "tree is down after 2 axe swings")
	var tree2 := _node(arena, "res://data/resource_nodes/tree.tres", spot + Vector2(300, 0))
	var hits := 0
	while not tree2.is_broken():
		tree2.take_gather_hit(fists, player)
		hits += 1
	_check(hits == 6, "bare hands need 6 hits for the same tree (%d)" % hits)
	var tree3 := _node(arena, "res://data/resource_nodes/tree.tres", spot + Vector2(400, 0))
	tree3.take_gather_hit(pick, player)
	_check(tree3.hp == tree3.data.max_hp - pick.gather_damage, "pickaxe on a tree: no bonus")
	var ore := _node(arena, "res://data/resource_nodes/copper_rock.tres", spot + Vector2(500, 0))
	var before := ore.hp
	_check(not ore.take_gather_hit(axe, player) and ore.hp == before, "axe on copper: clink, no damage (power %d < %d)" % [axe.tool_power, ore.data.required_power])
	_check(ore.take_gather_hit(pick, player) and ore.hp == before - pick.gather_damage * ore.data.tool_bonus, "pickaxe on copper: damage x tool_bonus")
	var n := 1
	while not ore.is_broken():
		ore.take_gather_hit(pick, player)
		n += 1
	_check(n == 4, "copper breaks in 4 pickaxe hits (%d)" % n)

	# --- bag lock while the boss is engaged ---
	var bag: BagPanel = hud.bag()
	for pk in get_nodes_in_group("pickup"):
		pk.free()   # drops still flying in would change the counts below
	await physics_frame
	boss.set_physics_process(false)   # its own aggro logic would flip the state back
	boss.aggro = Boss.Aggro.IDLE
	inv.add(load("res://data/items/wood.tres"), 5)
	var wood_before := inv.count(&"wood")
	await process_frame
	await _tap("bag")
	await process_frame
	_check(bag.is_open() and not inv.locked(), "Tab opens the bag out of combat")
	var wslot := Inventory.HOTBAR
	_check(inv.click_slot(wslot) and inv.held_item != null, "...and you can pick a stack up")
	wood_before = inv.count(&"wood") + inv.held_count   # pickups may still be flying in
	boss.aggro = Boss.Aggro.ENGAGED
	await process_frame
	await process_frame
	_check(inv.locked() and not bag.is_open() and inv.held_item == null, "boss engaged: the bag closes and the held stack goes back")
	_check(inv.count(&"wood") == wood_before, "no item lost by the forced close")
	_check(not inv.click_slot(wslot) and not inv.shift_move(wslot), "locked: clicks and shift moves are refused")
	bag.toggle()
	_check(not bag.is_open() and bag.hint_visible(), "locked: the bag does not open, a lock icon shows")
	_check(bag._hint is TextureRect and bag._hint.texture == bag.get_skin().lock_texture and bag.get_skin().lock_texture != null, "the lock hint is the skin's lock picture, not text")
	boss.aggro = Boss.Aggro.IDLE
	await process_frame
	bag.toggle()
	_check(bag.is_open(), "boss gone: opens again")
	bag.close()

	# --- the 3rd weapon cannot sit in the hotbar ---
	inv.add(inv.slot_item(0), 1)
	_check(inv.hotbar_weapon_count() == 2 and lo.weapons.size() == 2, "a 3rd sword goes to the bag; Loadout still has 2 weapons")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
