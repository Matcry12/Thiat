class_name Crafter
extends Node
## Crafting rules (decision 0031). Instant, Terraria-style: a recipe is shown when it is "by hand" or its
## station is within `craft_radius` of the player; crafting takes the ingredients and gives the result at
## once. A full inventory drops the result at the player (never lost). Recipes are the .tres files in
## `recipe_dir`: add a file, get a recipe, no code. The panel only ASKS (`craft(recipe)`); this decides.

signal crafted(recipe: RecipeData)

@export var recipe_dir := "res://data/recipes"
@export var inventory_path: NodePath = ^"../Inventory"

var recipes: Array[RecipeData] = []
var _station_items := {}   # station_id -> the placeable ItemData (icon for the window)
var last_craft := ""      ## for F3

func _ready() -> void:
	add_to_group("crafter")
	reload()

func reload() -> void:
	recipes.clear()
	for r in RecipeBook.load_dir(recipe_dir):
		if r is RecipeData:
			recipes.append(r)
	_station_items.clear()
	for r in recipes:   # which placeable item stands for which station: read from the station scene itself
		if r.result != null and r.result.placeable != null:
			var st := r.result.placeable.instantiate()
			var cs := st.get_node_or_null("CraftStation") as CraftStation
			if cs != null:
				_station_items[cs.station_id] = r.result
			st.free()
	recipes.sort_custom(func(a: RecipeData, b: RecipeData): return a.order < b.order or (a.order == b.order and a.resource_path < b.resource_path))

func inventory() -> Inventory:
	return get_node_or_null(inventory_path) as Inventory

func _pos() -> Vector2:
	return (get_parent() as Node2D).global_position

## Every CraftStation whose radius reaches the player.
func stations_in_range() -> Array[CraftStation]:
	var out: Array[CraftStation] = []
	for s: CraftStation in get_tree().get_nodes_in_group("craft_station"):
		if s.reaches(_pos()):
			out.append(s)
	return out

func station_ids_in_range() -> Array[StringName]:
	var ids: Array[StringName] = []
	for s in stations_in_range():
		if not ids.has(s.station_id):
			ids.append(s.station_id)
	return ids

## Furnaces whose station is in range, nearest first (the panel shows the first).
func furnaces_in_range() -> Array[Furnace]:
	var out: Array[Furnace] = []
	for s in stations_in_range():
		var f := s.get_parent().get_node_or_null("Furnace") as Furnace
		if f != null:
			out.append(f)
	out.sort_custom(func(a: Furnace, b: Furnace): return (a.get_parent() as Node2D).global_position.distance_to(_pos()) < (b.get_parent() as Node2D).global_position.distance_to(_pos()))
	return out

## The nearest station that has recipes (a furnace has none: it must not push the others down). Null if none.
func nearest_station() -> CraftStation:
	var best: CraftStation
	for s in stations_in_range():
		if not recipes.any(func(r: RecipeData): return r.station == s.station_id):
			continue
		if best == null or s.world_pos().distance_to(_pos()) < best.world_pos().distance_to(_pos()):
			best = s
	return best

## Recipes usable right now: by hand, plus every one whose station is in range. Sorted so what you came for
## is on top: first the recipes of the NEAREST station, then the ones you can craft now, then the rest
## (each group keeps the recipes' `order`).
func visible_recipes() -> Array[RecipeData]:
	var ids := station_ids_in_range()
	var near := nearest_station()
	var near_id: StringName = near.station_id if near else &""
	var rank := {}
	var out: Array[RecipeData] = []
	for r in recipes:
		if r.station == &"" or ids.has(r.station):
			out.append(r)
			rank[r] = 0 if (near != null and r.station == near_id) else (1 if can_craft(r) else 2)
	out.sort_custom(func(a: RecipeData, b: RecipeData): return rank[a] < rank[b] or (rank[a] == rank[b] and (a.order < b.order or (a.order == b.order and a.resource_path < b.resource_path))))
	return out

## The nearest station of any kind in range (a furnace counts): the window opens on its tab.
func nearest_station_any() -> CraftStation:
	var best: CraftStation
	for s in stations_in_range():
		if best == null or s.world_pos().distance_to(_pos()) < best.world_pos().distance_to(_pos()):
			best = s
	return best

## The placeable item of a station (its icon, its name), found through the recipes; null if none.
func station_item(id: StringName) -> ItemData:
	return _station_items.get(id)

## Does the inventory hold at least one of this recipe's ingredients? ("you are on the way")
func holds_any_ingredient(r: RecipeData) -> bool:
	var inv := inventory()
	if inv == null:
		return false
	for g in r.ingredients:
		if g.item != null and inv.count(g.item.id) > 0:
			return true
	return false

## What the window lists: craftable now, or you hold at least one ingredient ("you are on the way"), even when its
## station is not in range (then it is dimmed and the tooltip shows the station you need). Recipes you have
## nothing for stay hidden. Order: the nearest station's recipes, then craftable, then the rest, then the ones
## whose station is out of range (each group by `order`).
func listed_recipes() -> Array[RecipeData]:
	var near := nearest_station()
	var near_id: StringName = near.station_id if near else &""
	var rank := {}
	var out: Array[RecipeData] = []
	for r in recipes:
		var here := station_ok(r)
		if can_craft(r) or holds_any_ingredient(r):
			out.append(r)
			rank[r] = 0 if (here and near != null and r.station == near_id) else (1 if can_craft(r) else (2 if here else 3))
	out.sort_custom(func(a: RecipeData, b: RecipeData): return rank[a] < rank[b] or (rank[a] == rank[b] and (a.order < b.order or (a.order == b.order and a.resource_path < b.resource_path))))
	return out

## The ingredients of `r` as {item, need, have}: what the recipe tooltip shows.
func ingredient_status(r: RecipeData) -> Array:
	var inv := inventory()
	var out := []
	for g in r.ingredients:
		out.append({"item": g.item, "need": g.count, "have": inv.count(g.item.id) if inv else 0})
	if not station_ok(r):   # why it is dim: the station you are not near (shown red, like a missing ingredient)
		var st := station_item(r.station)
		if st != null:
			out.append({"item": st, "need": 1, "have": 0})
	return out

## Click on a lit recipe icon: takes the ingredients now and puts the result on the CURSOR (the held stack, like
## picking up a bag stack). Clicking again while holding the same item stacks one more, up to its max stack.
## Refused (changes nothing) if you cannot craft it, or hold something else, or the stack is full.
func craft_to_cursor(r: RecipeData) -> bool:
	if not can_craft(r):
		return false
	var inv := inventory()
	var held := inv.held_item
	if held != null and (held.id != r.result.id or inv.held_count + r.result_count > held.stack_limit()):
		return false
	for g in r.ingredients:
		inv.take(g.item.id, g.count)
	if held == null:
		inv.hold(r.result, r.result_count)
	else:
		inv.set_held_count(inv.held_count + r.result_count)
	last_craft = "%s x%d (cursor)" % [r.result.display_name, r.result_count]
	crafted.emit(r)
	return true

func station_ok(r: RecipeData) -> bool:
	return r.station == &"" or station_ids_in_range().has(r.station)

func has_ingredients(r: RecipeData) -> bool:
	var inv := inventory()
	if inv == null:
		return false
	for g in r.ingredients:
		if g.item == null or inv.count(g.item.id) < g.count:
			return false
	return true

func can_craft(r: RecipeData) -> bool:
	var inv := inventory()
	return inv != null and r.result != null and not inv.locked() and station_ok(r) and has_ingredients(r)

## Takes the ingredients and gives the result. Returns false (and changes nothing) if it cannot.
func craft(r: RecipeData) -> bool:
	if not can_craft(r):
		return false
	var inv := inventory()
	for g in r.ingredients:
		inv.take(g.item.id, g.count)
	inv.give_or_drop(r.result, r.result_count)
	last_craft = "%s x%d" % [r.result.display_name, r.result_count]
	crafted.emit(r)
	return true
