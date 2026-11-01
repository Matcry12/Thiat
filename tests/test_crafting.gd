extends SceneTree
# W4 crafting rules: consume + give, refuse without ingredients, the station-range filter, a full inventory
# drops the result, a recipe added as a .tres appears with no code change, locked in the boss fight.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _recipe(c: Crafter, result: String) -> RecipeData:
	for r in c.recipes:
		if r.result.id == StringName(result):
			return r
	return null

func _init() -> void:
	var arena = await World.make(self)
	var player: Node2D = arena.get_node("Player")
	var inv: Inventory = player.get_node("Inventory")
	var cr: Crafter = player.get_node("Crafter")
	var placer: Placer = player.get_node("Placer")
	var boss: Boss = arena.get_node("Boss")
	boss.set_physics_process(false)
	boss.aggro = Boss.Aggro.IDLE
	await physics_frame

	# --- the recipe table is real data ---
	_check(cr.recipes.size() >= 9, "the recipe folder loaded (%d recipes)" % cr.recipes.size())
	var wb := _recipe(cr, "workbench")
	_check(wb != null and wb.station == &"" and wb.ingredients.size() == 1, "workbench is a by-hand recipe")
	_check(_recipe(cr, "copper_sword").station == &"anvil" and _recipe(cr, "anvil").station == &"workbench", "copper sword at the anvil, anvil at the workbench")

	# --- by hand: refused without wood, then consumes and gives ---
	_check(not cr.can_craft(wb) and not cr.craft(wb), "no wood: the craft is refused")
	_check(inv.count(&"workbench") == 0 and inv.count(&"wood") == 0, "a refused craft changes nothing")
	inv.add(World.item("wood"), 25)
	_check(cr.craft(wb), "10 wood: the workbench is crafted")
	_check(inv.count(&"wood") == 15 and inv.count(&"workbench") == 1, "10 wood left the inventory, 1 workbench arrived (%d wood)" % inv.count(&"wood"))
	_check(cr.last_craft == "Workbench x1", "F3 remembers the last craft")
	var in_hotbar := false
	for i in Inventory.HOTBAR:
		in_hotbar = in_hotbar or (inv.slot_item(i) != null and inv.slot_item(i).id == &"workbench")
	_check(in_hotbar, "the workbench sits in the hotbar")

	# --- station-range filter ---
	var by_hand := cr.visible_recipes()
	_check(by_hand.size() == 1 and by_hand[0] == wb, "no station near: only the by-hand recipe shows")
	var pick := _recipe(cr, "stone_pickaxe")
	inv.add(World.item("stone"), 20)
	_check(not cr.can_craft(pick), "the pickaxe needs a workbench in range")
	var st := placer.place_free(World.item("workbench"))
	_check(st != null, "a workbench stands near the player")
	_check(cr.station_ids_in_range() == [&"workbench"] and cr.visible_recipes().has(pick) and not cr.visible_recipes().has(_recipe(cr, "copper_sword")), "workbench in range: its recipes show, the anvil's do not")
	_check(cr.craft(pick) and inv.count(&"stone_pickaxe") == 2 and inv.count(&"stone") == 14 and inv.count(&"wood") == 11, "stone pickaxe: 4 wood + 6 stone taken, 1 pickaxe given")
	player.global_position += Vector2(st.get_node("CraftStation").craft_radius + 40.0, 0)
	_check(cr.station_ids_in_range().is_empty() and not cr.visible_recipes().has(pick) and not cr.can_craft(pick), "walked out of the radius: the recipe is gone")
	player.global_position -= Vector2(st.get_node("CraftStation").craft_radius + 40.0, 0)
	_check(cr.can_craft(pick) or inv.count(&"stone") < 6, "back in range it is available again (or short of stone)")

	# --- the list order: nearest station first, then what you can craft now, then the rest ---
	var anvil_st := placer.place_free(World.item("anvil"))
	_check(anvil_st != null and cr.nearest_station().station_id == &"workbench", "two stations: the workbench (placed first, nearer) is the nearest")
	var vis := cr.visible_recipes()
	_check(vis[0].station == &"workbench" and vis[1].station == &"workbench", "its recipes come first")
	anvil_st.global_position = player.global_position + Vector2(20, 0)
	vis = cr.visible_recipes()
	_check(cr.nearest_station().station_id == &"anvil" and vis[0].station == &"anvil" and vis[1].station == &"anvil" and vis[2].station == &"anvil", "stand next to the anvil: its 3 copper recipes are the first 3 rows")
	var seen_uncraftable := false
	var sorted_ok := true
	for r in vis.slice(3):
		if cr.can_craft(r):
			sorted_ok = sorted_ok and not seen_uncraftable
		else:
			seen_uncraftable = true
	_check(sorted_ok, "after them, what you can craft now comes before what you cannot")
	anvil_st.free()

	# --- a full inventory drops the result at the player ---
	var pickups_before := get_nodes_in_group("pickup").size()
	inv.add(World.item("wood"), 99999)   # every free slot becomes wood
	var bow := _recipe(cr, "bow")
	_check(inv.room_for(World.item("bow")) == 0, "inventory is full")
	_check(cr.craft(bow), "craftable while full (the wood stacks are consumed, no slot frees)")
	var bow_drop: Pickup
	for p in get_nodes_in_group("pickup"):
		if p.item.id == &"bow":
			bow_drop = p
	_check(bow_drop != null and inv.count(&"bow") == 0 and get_nodes_in_group("pickup").size() == pickups_before + 1, "the bow dropped on the ground, not lost")
	_check(bow_drop.position.distance_to(player.position) < 5.0, "it dropped at the player")

	# --- click = onto the cursor; the ingredients are taken then; stacking; refusals ---
	inv.clear()
	var wb_before := inv.count(&"workbench")
	inv.add(World.item("wood"), 30)
	_check(cr.holds_any_ingredient(wb) and cr.listed_recipes().has(wb), "30 wood: the workbench is listed (craftable)")
	_check(cr.craft_to_cursor(wb) and inv.held_item == World.item("workbench") and inv.held_count == 1 and inv.count(&"wood") == 20, "craft_to_cursor: 1 workbench on the cursor, 10 wood gone at once")
	_check(cr.craft_to_cursor(wb) and inv.held_count == 2 and inv.count(&"wood") == 10, "again: it stacks on the cursor (2)")
	_check(cr.craft_to_cursor(wb) and inv.held_count == 3 and inv.count(&"wood") == 0, "and again (3), wood used up")
	_check(not cr.craft_to_cursor(wb) and inv.held_count == 3, "no wood left: refused, nothing changes")
	inv.add(World.item("wood"), 10)
	var held_bow_recipe := _recipe(cr, "bow")
	_check(not cr.craft_to_cursor(held_bow_recipe) and inv.count(&"wood") == 10, "holding a workbench: another item is refused")
	inv.return_held()
	_check(inv.held_item == null and inv.count(&"workbench") == wb_before + 3, "return_held puts the stack into the inventory")
	# a stack never goes past its max
	inv.add(World.item("wood"), 200)
	var cap := World.item("workbench").stack_limit()
	inv.hold(World.item("workbench"), cap)
	_check(not cr.craft_to_cursor(wb) and inv.held_count == cap, "a full cursor stack (%d) takes no more" % cap)
	inv.return_held()
	# listing rules: lit / dimmed ("you hold a part") / hidden (walk away from the stations first)
	player.global_position += Vector2(3000, 0)
	inv.clear()
	_check(cr.listed_recipes().is_empty(), "nothing in the bag: no recipe is listed")
	inv.add(World.item("stone"), 1)
	var with_stone := cr.listed_recipes()
	_check(not with_stone.has(wb) and with_stone.size() == 3, "stone alone: the 3 recipes that use stone are listed (dim), the workbench is not (%d)" % with_stone.size())
	_check(with_stone.all(func(r): return not cr.can_craft(r) and not cr.station_ok(r)), "...all dim, and each lacks its station")
	_check(cr.ingredient_status(with_stone[0]).back()["item"] == World.item("workbench") and cr.ingredient_status(with_stone[0]).back()["have"] == 0, "the tooltip data ends with the missing station (the workbench), have 0 = red")
	inv.add(World.item("wood"), 1)
	var with_wood := cr.listed_recipes()
	_check(with_wood[0] == wb and not cr.can_craft(wb), "1 wood: the workbench is listed first, dimmed (you hold part of it)")
	_check(with_wood.size() > 1 and with_wood.slice(1).all(func(r): return r.station != &""), "...then the out-of-range station recipes that use wood, last")
	_check(cr.ingredient_status(wb).size() == 1, "a by-hand recipe has no station row")

	player.global_position -= Vector2(3000, 0)
	# --- shift click path: craft() straight into the inventory, dropping if full ---
	inv.clear()
	inv.add(World.item("wood"), 99999)
	var drops0 := get_nodes_in_group("pickup").size()
	_check(cr.craft(bow) and get_nodes_in_group("pickup").size() == drops0 + 1, "a full inventory: a straight craft drops the result (never lost)")

	# --- station icons come from the placeable items, found through the recipes ---
	_check(cr.station_item(&"anvil") == World.item("anvil") and cr.station_item(&"workbench") == World.item("workbench") and cr.station_item(&"furnace") == World.item("furnace"), "station_item maps a station id to its placeable item")
	_check(cr.station_item(&"nope") == null, "unknown station: null")

	# --- a recipe added as a .tres appears with no code change ---
	DirAccess.make_dir_recursive_absolute("user://test_recipes")
	var r := RecipeData.new()
	r.result = World.item("stone")
	r.result_count = 5
	var g := IngredientData.new()
	g.item = World.item("wood")
	g.count = 1
	r.ingredients = [g]
	ResourceSaver.save(r, "user://test_recipes/new_recipe.tres")
	var c2 := Crafter.new()
	c2.recipe_dir = "user://test_recipes"
	c2.inventory_path = cr.inventory_path
	player.add_child(c2)
	_check(c2.recipes.size() == 1 and c2.recipes[0].result_count == 5, "a new .tres in the folder is a recipe")
	_check(c2.visible_recipes().size() == 1 and c2.craft(c2.recipes[0]), "it shows and crafts with no code change")
	DirAccess.remove_absolute("user://test_recipes/new_recipe.tres")
	c2.queue_free()

	# --- locked while the boss is engaged ---
	boss.aggro = Boss.Aggro.ENGAGED
	inv.clear()
	inv.add(World.item("wood"), 20)
	_check(inv.locked() and not cr.can_craft(wb) and not cr.craft(wb), "boss engaged: crafting is locked")
	boss.aggro = Boss.Aggro.IDLE
	_check(cr.craft(wb), "boss asleep again: crafting works")
	quit(0 if _ok else 1)
