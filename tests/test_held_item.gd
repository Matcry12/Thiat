extends SceneTree
# Decision 0048: no hands. Bare fists gather nothing, the start kit has axe + pickaxe, and the item in the hand
# (wood, a workbench) shows its icon on HeldItem; an empty slot or a tool shows nothing.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var arena = await World.make(self)
	var player = arena.get_node("Player")
	var inv: Inventory = player.get_node("Inventory")
	var lo: Loadout = player.get_node("Loadout")
	var held: HeldItemVisual = player.get_node("WeaponVisual/HeldItem")
	player.set_physics_process(true)   # World.make turns it off; HeldItem is fed from player.gd each physics frame
	await physics_frame
	_check(inv.count(&"stone_axe") == 1 and inv.count(&"stone_pickaxe") == 1 and inv.count(&"wooden_sword") == 1, "start kit: sword + stone axe + stone pickaxe")
	var tree: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	tree.setup(load("res://data/resource_nodes/tree.tres"), 0)
	arena.add_child(tree)
	await physics_frame
	for i in 5:
		tree.take_gather_hit(lo.unarmed, player)
	_check(tree.hp == tree.data.max_hp, "fists do 0 to a tree")
	_check(tree.take_gather_hit(load("res://data/weapons/stone_axe.tres"), player) and tree.hp < tree.data.max_hp, "stone axe damages it")
	_check(not held.visible, "sword in hand: HeldItem hidden")
	inv.add(World.item("wood"), 5)
	inv.add(World.item("workbench"), 1)
	for s in range(Inventory.HOTBAR, Inventory.SIZE):
		if inv.slot_item(s) != null and inv.slot_item(s).id == &"wood":
			inv.shift_move(s)   # wood goes to the bag first: move it to the hotbar
			break
	for s in Inventory.HOTBAR:
		if inv.slot_item(s) != null and inv.slot_item(s).id == &"wood":
			lo.select(s)
	await physics_frame
	await physics_frame
	_check(held.visible and held.texture == ItemIcon.crop(World.item("wood").icon), "holding wood: HeldItem shows the wood icon")
	player.weapon_visual.set_aim_angle(PI)   # aim left mirrors WeaponVisual (scale.y = -1)
	held._process(0.0)
	_check(held.global_transform.determinant() > 0.0 and held.global_transform.y.y > 0.0, "aiming left: icon upright, not flipped")
	for s in Inventory.HOTBAR:
		if inv.slot_item(s) != null and inv.slot_item(s).id == &"workbench":
			lo.select(s)
	await physics_frame
	await physics_frame
	_check(held.visible and held.texture == ItemIcon.crop(World.item("workbench").icon), "holding a workbench: HeldItem shows its icon")
	lo.select(0)
	await physics_frame
	await physics_frame
	_check(not held.visible, "back to the sword: HeldItem hidden")
	for s in Inventory.HOTBAR:
		if inv.slot_item(s) == null:
			lo.select(s)
			break
	await physics_frame
	await physics_frame
	_check(not held.visible, "empty slot: HeldItem hidden")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
