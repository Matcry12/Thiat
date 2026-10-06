extends SceneTree
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").map_seed = 11
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var m: ArenaMap = arena.get_node("ArenaMap")
	var style := m.style
	var by_kind := {}
	var by_area := {}
	for n in get_nodes_in_group("resource_node"):
		var k: StringName = n.data.id
		by_kind[k] = by_kind.get(k, 0) + 1
		var key := "%s@%d" % [k, m.area_at(n.global_position)]
		by_area[key] = by_area.get(key, 0) + 1
	print("  nodes: %s" % [by_area])
	_check(by_kind.get(&"tree", 0) > 100 and by_kind.get(&"rock", 0) > 50 and by_kind.get(&"copper_rock", 0) > 10, "trees, rocks and copper on the island %s" % [by_kind])
	_check(by_area.get("tree@0", 0) > by_area.get("tree@1", 0) * 3, "trees mostly in the forest")
	_check(by_area.get("copper_rock@0", 0) == 0 and by_area.get("copper_rock@2", 0) == 0, "copper only in the rocky area")
	_check(get_nodes_in_group("map_obstacle").size() == get_nodes_in_group("resource_node").size(), "no plain cover rocks left on the island")
	var zone: Rect2 = m.layout()["zone"]
	var in_zone := 0
	for n in get_nodes_in_group("resource_node"):
		if zone.has_point(n.global_position):
			in_zone += 1
	_check(in_zone == 0, "nothing in the fight zone")
	var p := m.make_params()
	_check(MapGen.floor_reachable(p, m.result.obstacles, m.result.land), "all walkable land still reachable from home")
	var a := MapGen.generate(style, p, 11)
	var b := MapGen.generate(style, p, 11)
	_check(a.obstacles == b.obstacles, "same seed = same trees and rocks")
	_check(m.build_ms < 2000, "build with nodes under budget (%d ms)" % m.build_ms)
	var flat := MapGen.Params.new()
	var fr := MapGen.generate(style, flat, 11)
	var plain := true
	for o in fr.obstacles:
		plain = plain and o["node"] == -1
	_check(plain and not fr.obstacles.is_empty(), "flat map keeps its plain rocks")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
