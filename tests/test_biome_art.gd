extends SceneTree
## Per-biome oak / hedge sheets (BiomeArt): a tree in biome X draws from X's sheet; a redrawn pixel changes only that biome's trees.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false


func _tree(d: ResourceNodeData, biome: int) -> ResourceNode:
	var rn: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	rn.setup(d, 0)
	rn.biome = biome
	root.add_child(rn)
	return rn


func _init() -> void:
	var art := BiomeArt.get_default()
	var d: ResourceNodeData = load("res://data/resource_nodes/treepp_oak_green_old.tres")
	_check(art.status_text().contains("oaks loaded 9") and art.status_text().contains("hedges loaded 9"), "all 18 biome sheets load")
	var orig_img := (d.texture as Texture2D).get_image()
	for b in BiomeArt.NAMES.size():
		var t := art.texture(&"oaks", b)
		_check(t != null and t.get_image().get_data() == orig_img.get_data(), "%s oaks = copy of the original" % BiomeArt.NAMES[b])
	# redraw one pixel in forest (in memory)
	var img := orig_img.duplicate() as Image
	img.set_pixel(20, 60, Color(1, 0, 1))
	var forest_tex := ImageTexture.create_from_image(img)
	BiomeArt.override(&"oaks", 1, forest_tex)
	var f := _tree(d, 1)
	var p := _tree(d, 0)
	var n := _tree(d, -1)
	await process_frame
	var fb: Sprite2D = f.get_node("Visual/Body")
	_check(fb.texture == forest_tex, "forest tree draws the forest sheet")
	_check(p.get_node("Visual/Body").texture == art.texture(&"oaks", 0), "plains tree draws the plains sheet")
	_check(p.get_node("Visual/Body").texture != forest_tex and n.get_node("Visual/Body").texture == d.texture, "plains + no-biome trees unchanged")
	_check(fb.region_rect == p.get_node("Visual/Body").region_rect, "same region in every biome")
	# the stump after chopping comes from the biome's hedge sheet
	var h := art.texture(&"hedges", 1)
	f.get_node("Visual").show_remains(d)
	await process_frame
	_check(fb.texture == h, "forest stump draws the forest hedge sheet")
	# missing file -> original
	BiomeArt.override(&"oaks", 2, null)
	_check(BiomeArt.sheet(d.texture, 2) == d.texture, "missing sheet falls back to the original")
	BiomeArt.clear_cache()
	await _streamer_case()
	print("RESULT: ", "PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)


## Trees built by the chunk streamer get the biome under them (nothing set by hand) and draw that biome's sheet.
func _streamer_case() -> void:
	var d: ResourceNodeData = load("res://data/resource_nodes/treepp_oak_green_old.tres")
	var img := (d.texture as Texture2D).get_image().duplicate() as Image
	img.set_pixel(20, 60, Color(1, 0, 1))
	var forest_tex := ImageTexture.create_from_image(img)
	BiomeArt.override(&"oaks", 1, forest_tex)
	var arena = load("res://scenes/arena.tscn").instantiate()
	var m: ArenaMap = arena.get_node("ArenaMap")
	m.map_seed = 3
	m.map_cols = 200
	m.map_rows = 120
	load("res://tests/support/small_map.gd").apply(m)
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	await process_frame
	var seen := {}
	var wrong := 0
	for n in root.get_tree().get_nodes_in_group("resource_node"):
		var rn := n as ResourceNode
		if not arena.is_ancestor_of(rn) or rn.data.texture == null or not String(rn.data.id).begins_with("treepp"):
			continue
		var b := m.biome_id_at(rn.position)
		seen[b] = true
		var want: Texture2D = forest_tex if b == 1 else BiomeArt.get_default().texture(&"oaks", b)
		if rn.biome != b or rn.get_node("Visual/Body").texture != want:
			wrong += 1
	print("  streamer trees: biomes seen ", seen.keys())
	_check(seen.size() >= 2 and wrong == 0, "streamer trees carry their biome and draw its sheet (%d wrong)" % wrong)
	BiomeArt.clear_cache()
