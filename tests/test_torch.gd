extends SceneTree
# Torch: recipe (1 wood + 1 gel at the workbench = 4), held torch adds a LightSource and drops it when deselected,
# a placed torch has a light, the ghost has none, a pickaxe-style pick_up returns the item, items on a station save.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var torch := World.item("torch")
	var rec: RecipeData = load("res://data/recipes/torch.tres")
	_check(rec.result == torch and rec.result_count == 4 and rec.station == &"workbench" and rec.ingredients.size() == 2, "recipe: workbench, 4 torches")
	_check(torch.light != null and torch.light.radius == 160.0 and torch.placeable != null and torch.max_stack == 99, "item data: light 160, placeable, stack 99")

	var arena = await World.make(self)
	var player: CharacterBody2D = arena.get_node("Player")
	var inv: Inventory = player.get_node("Inventory")
	var lo: Loadout = player.get_node("Loadout")
	var pl: Placer = player.get_node("Placer")
	var lights0 := get_nodes_in_group("light_source").size()
	inv.add(torch, 5)
	var slot := -1
	for i in Inventory.HOTBAR:
		if inv.slot_item(i) == torch:
			slot = i
	lo.select(slot)
	player.set_physics_process(true)
	await physics_frame
	await physics_frame
	await process_frame
	_check(get_nodes_in_group("light_source").size() == lights0 + 1, "torch selected: one light added")
	var held := player.get_node("WeaponVisual/HeldItem") as HeldItemVisual
	var hl := player.get_node_or_null("ItemLight") as LightSource
	_check(hl != null and hl.is_visible_in_tree() and player.get_node("WeaponVisual").visible and held.visible, "idle: torch stays in the hand and its light shines")
	torch.light.radius = 222.0
	await process_frame
	_check(hl != null and hl.radius == 222.0, "F3 edit of the LightData reaches the live light")
	torch.light.radius = 160.0
	_check(pl.ghost() != null and pl.ghost().get_node_or_null("ItemLight") == null, "the placing ghost has no light")
	lo.select(0 if slot != 0 else 1)
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	_check(get_nodes_in_group("light_source").size() == lights0, "torch deselected: light removed")

	player.health.take_damage(99999.0)
	lo.select(slot)
	await physics_frame
	await process_frame
	_check(get_nodes_in_group("light_source").size() == lights0 and player.dead, "dead: held light is gone at once")
	player.respawn()
	lo.select(0 if slot != 0 else 1)
	await physics_frame
	await process_frame
	var st := World.station(arena, "torch", player.global_position + Vector2(200, 0))
	await process_frame
	_check(st.get_node_or_null("ItemLight") is LightSource and get_nodes_in_group("light_source").size() == lights0 + 1, "placed torch has a light")
	_check(st.get_node_or_null("Flame") != null and st.get_node("Visual/Art").visible, "placed torch has the flame art")
	_check(st.collision_layer == 0 and not st.safe_zone and st.footprint().x > 0.0, "placed torch is walk-through, no safe zone")
	var sg: SaveGame = arena.get_node("SaveGame")
	var st_pos := st.global_position
	var d := sg.collect()
	sg.apply(d)
	await process_frame
	await process_frame
	var back: Array = get_nodes_in_group("station").filter(func(x): return x.item == torch)
	_check(back.size() == 1 and back[0].get_node_or_null("ItemLight") != null and back[0].global_position.distance_to(st_pos) < 1.0, "save round trip: torch and its light come back")
	st = back[0]
	lo.select(0 if inv.slot_item(0) != torch else 1)   # the save may have put the torch back in the selected slot
	for i in 30:
		await physics_frame
	await process_frame
	await process_frame
	var n: int = inv.count(&"torch")
	st.pick_up(inv, true)
	await process_frame
	await process_frame
	_check(get_nodes_in_group("light_source").size() == lights0, "picked up: light gone")
	_check(inv.count(&"torch") == n + 1, "picked up: torch back in the bag")
	print("RESULT ", "PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
