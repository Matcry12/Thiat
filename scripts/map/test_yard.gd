class_name TestYard
extends Node
## Test yard (decision 0056): dev-only. The title's "Test yard" button starts the normal arena on a small flat map (ArenaMap.yard_mode)
## with one of each testable thing laid out round home. ArenaMap owns the map side (MapGen `yard`: all land, one Plains biome, no water,
## no vegetation, nodes = node_list()); this node lays the list out, puts the stations, dummy and slime down and gives the F3 line + Reset.
## It also adds the ItemPicker (every item, click = into the bag) as the crafting book's Items tab. Trees / rocks are real MapGen obstacles, so chop / mine / chunks behave exactly like the island.

@export_range(32, 256, 1) var cells := 64   ## map size in cells (square)
@export var dummy_offset := Vector2(240.0, -60.0)   ## from home; read by ArenaMap.layout
@export_group("Layout")
@export_range(40.0, 300.0, 1.0, "or_greater") var tree_col_spacing := 90.0   ## one column per season
@export_range(40.0, 300.0, 1.0, "or_greater") var tree_row_spacing := 120.0   ## one row per age (sapling at the bottom, old at the top)
@export_range(60.0, 600.0, 1.0, "or_greater") var tree_first_row := 150.0   ## px above home to the first tree row
@export_range(40.0, 300.0, 1.0, "or_greater") var rock_spacing := 90.0
@export_range(60.0, 600.0, 1.0, "or_greater") var rock_row_offset := 120.0   ## px below home
@export_range(60.0, 400.0, 1.0, "or_greater") var station_spacing := 130.0
@export_range(60.0, 600.0, 1.0, "or_greater") var station_row_offset := 260.0   ## px below home
@export var slime_offset := Vector2(-260.0, 40.0)
@export var station_items: Array[ItemData] = []   ## placed in a row; empty = workbench, furnace, anvil
@export var give_kit := true   ## sword, bow, axe, pickaxe at the start (Inventory.give_dev_kit)

var map: ArenaMap
var picker: ItemPicker
var last_reset := "never"
var _spawner: EnemySpawner
var _slime: Node2D

func _ready() -> void:
	add_to_group("debug")
	_spawner = get_parent().get_node_or_null("EnemySpawner") as EnemySpawner
	if _spawner != null:
		_spawner.enabled = false   # the yard is the whole test: no random packs
	if give_kit:
		var inv := get_parent().get_node_or_null("Player/Inventory") as Inventory
		if inv != null:
			inv.give_dev_kit()
	var hud := get_parent().get_node_or_null("HUD") as HUD
	var pinv := get_parent().get_node_or_null("Player/Inventory") as Inventory
	if hud != null and pinv != null and hud.craft_window() != null:   # the item picker (its only maker): every item, click = into the bag
		picker = ItemPicker.new()
		picker.bind(hud, pinv)
		add_child(picker)
	map.rebuilt.connect(_populate)
	_populate()

## The resource nodes of the yard around `origin` (home): a grid of every Pixel Plains oak (season columns x age rows),
## then rocks and a copper rock. Pure: called by ArenaMap.make_params before this node is in the tree.
func node_list(origin: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seasons: Array[String] = []
	var ages: Array[String] = []
	for k in map.style.resource_nodes:
		var parts := String(k.id).split("_")   # treepp_oak_<season>_<age>
		if parts.size() == 4 and parts[0] == "treepp":
			if not seasons.has(parts[2]):
				seasons.append(parts[2])
			if not ages.has(parts[3]):
				ages.append(parts[3])
	ages.sort_custom(func(a: String, b: String) -> bool: return MapGen.AGES.find(StringName(a)) < MapGen.AGES.find(StringName(b)))
	for r in ages.size():
		for c in seasons.size():
			var id := StringName("treepp_oak_%s_%s" % [seasons[c], ages[r]])
			var pos := origin + Vector2((c - (seasons.size() - 1) * 0.5) * tree_col_spacing, -tree_first_row - r * tree_row_spacing)
			out.append({"id": id, "pos": pos})
	var rocks: Array[StringName] = [&"rock", &"rock", &"copper_rock"]
	for i in rocks.size():
		out.append({"id": rocks[i], "pos": origin + Vector2((i - 1) * rock_spacing, rock_row_offset)})
	return out

func _items() -> Array[ItemData]:
	if not station_items.is_empty():
		return station_items
	var out: Array[ItemData] = []
	for id in ["workbench", "furnace", "anvil"]:
		out.append(load("res://data/items/%s.tres" % id) as ItemData)
	return out

## Stations, slime. (Trees / rocks / dummy come with the map.) Runs after every map build.
func _populate() -> void:
	_free_stations()
	var origin := map.home_point()
	var items := _items()
	for i in items.size():
		var st: Station = items[i].placeable.instantiate()
		st.item = items[i]
		st.set_meta(&"yard", true)
		get_parent().add_child(st)
		st.global_position = origin + Vector2((i - (items.size() - 1) * 0.5) * station_spacing, station_row_offset)
	if is_instance_valid(_slime):
		_slime.queue_free()
	_slime = null
	if _spawner != null and not _spawner.enemy_types.is_empty():
		_slime = _spawner.spawn(_spawner.enemy_types[0], origin + slime_offset)

func _free_stations() -> void:
	for st: Station in get_tree().get_nodes_in_group("station"):
		if st.has_meta(&"yard"):   # only the yard's own: stations the player placed stay
			st.remove_from_group("station")
			st.queue_free()

## Regrows every tree / rock, puts the stations back, respawns the slime.
func reset() -> void:
	_free_stations()
	var resized := map.map_cols != cells or map.map_rows != cells
	map.map_cols = cells   # the setters queue a rebuild; the explicit one below is the one that counts
	map.map_rows = cells
	map.rebuild(false, resized)   # layout exports are read again by node_list / _populate; a new size also moves the actors
	last_reset = "%d ms" % map.build_ms

func nodes_alive() -> int:
	var broken := map.streamer().broken
	var n := 0
	for b in broken:
		n += 1 - b
	return n

func debug_name() -> String:
	return "TestYard"

func debug_category() -> String:
	return "World"

func debug_actions() -> Array:
	return [{"label": "Reset yard", "run": reset}]

func status_text() -> String:
	var slimes := 0
	for e: Enemy in get_tree().get_nodes_in_group("enemy"):
		slimes += int(e.state != Enemy.State.DIE)
	return "on  %dx%d cells\nnodes %d / %d  stations %d  slimes %d\nlast reset: %s" % [
		map.map_cols, map.map_rows, nodes_alive(), map.result.obstacles.size(), get_tree().get_nodes_in_group("station").size(), slimes, last_reset]
