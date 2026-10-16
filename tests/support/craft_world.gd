extends RefCounted
## W4 test world: the island arena on a fixed seed, passive boss, player standing in a cleared patch
## of the forest. Everything near the player that could block a station is removed, so a test decides
## what is there.
static func make(tree: SceneTree, screen := Vector2i.ZERO) -> Node:
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").map_seed = 11
	if screen != Vector2i.ZERO:   # layout tests need a real 1152 x 648 screen (the headless root is tiny)
		var sv := SubViewport.new()
		sv.size = screen
		tree.root.add_child(sv)
		sv.add_child(arena)
	else:
		tree.root.add_child(arena)
	arena.get_node("Boss").passive = true
	await tree.process_frame
	var player: Node2D = arena.get_node("Player")
	player.set_physics_process(false)
	for n in tree.get_nodes_in_group("map_obstacle"):
		if n.global_position.distance_to(player.global_position) < 500.0:
			n.free()
	return arena

static func item(id: String) -> ItemData:
	return load("res://data/items/%s.tres" % id)

## A station placed at `pos` for free, ignoring the placing rules (tests decide what stands where).
static func station(arena: Node, id: String, pos: Vector2) -> Station:
	var it := item(id)
	var st: Station = it.placeable.instantiate()
	st.item = it
	arena.add_child(st)
	st.global_position = pos
	return st
