extends SceneTree
# Headless: the F3 panel discovers tunable properties by REFLECTION (not a
# hardcoded list) and its apply path actually changes the target.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame
	var panel = arena.get_node("TuningPanel")

	var count: int = panel._controls.size()
	print("discovered properties: ", count)
	var ok: bool = count > 8

	# Apply through the panel's own path (the same one Save/Load/sliders use),
	# not by poking the target object directly.
	var any_key: String = panel._controls.keys()[0]
	var entry: Dictionary = panel._controls[any_key]
	var target: Object = entry["obj"]
	var prop: String = entry["prop"]
	var before = target.get(prop)
	var new_value
	if entry["is_bool"]:
		new_value = not bool(before)
	elif entry["is_int"]:
		new_value = int(before) + 1
	else:
		new_value = float(before) + 1.0
	panel._apply_value(any_key, new_value)
	var after = target.get(prop)
	var changed: bool = after != before
	print("%s: %s -> %s (changed=%s)" % [any_key, before, after, changed])
	ok = ok and changed

	# 0038 water v2: the Map section is grouped (@export_group) and the World map panel shows the whole island, redrawn on every rebuild
	var groups := {}
	for pi in panel._collect_tunable_properties(panel._map):
		groups[pi["group"]] = groups.get(pi["group"], 0) + 1
	print("Map groups: ", groups)
	for g in ["Island", "Climate", "Water", "Biomes", "Vegetation", "Chunks", "Looks"]:
		ok = ok and groups.get(g, 0) > 0
	# 0038 step 4: every vegetation number of a biome is in F3 under "Biome <label>" (grouped), a vegetation slider is a heavy one (applies on drag end), a tint is live
	var bd: BiomeData = panel._map.style.biomes[MapGen.Biome.TAIGA]
	var bprops: Array = panel._collect_tunable_properties(bd)
	var bgroups := {}
	var bnames := {}
	for pi in bprops:
		bgroups[pi["group"]] = bgroups.get(pi["group"], 0) + 1
		bnames[pi["name"]] = true
	print("Biome taiga groups: ", bgroups)
	for g in ["Trees", "Rocks", "Bushes", "Flowers", "Mushrooms and tufts", "Water edge and snow", "Ground mix"]:
		ok = ok and bgroups.get(g, 0) > 0
	for n in ["tree_tries", "tree1_model", "tree1_season", "tree1_weight", "max_stage", "age_rule", "rock_per_block", "bush_per_block", "flower_per_block", "tuft_p", "reed_per_shore", "stump_per_block", "ground_alt"]:
		ok = ok and bnames.has(n)
	ok = ok and panel._range_for("tree3_season", 0.0) == Vector2(0.0, 6.0) and panel._range_for("tree3_model", 0.0) == Vector2(0.0, 3.0)
	ok = ok and panel._is_heavy(bd, "tree_tries") and panel._is_heavy(bd, "ground_alt") and panel._is_heavy(bd, "ground_alt_share") and panel._is_heavy(bd, "ground_alt_period") and not panel._is_heavy(bd, "tint_bright")
	ok = ok and not panel._is_heavy(panel._map, "ground_brightness") and panel._is_heavy(panel._map, "tree_fade_lo")
	var wm = panel._world_map
	wm.toggle()
	var img_w: int = wm._tex.texture.get_width()
	var d0: int = wm.drawn_count
	panel._map.rebuild(true)
	var wm_ok: bool = wm.visible and img_w == panel._map.result.cols and wm.drawn_count == d0 + 1
	print("World map: visible=%s image width %d, drawn %d -> %d" % [wm.visible, img_w, d0, wm.drawn_count])
	ok = ok and wm_ok

	# F3 button rows wrap (HFlowContainer): every button sits inside the window at 1280x720 and 1920x1080
	var e := InputEventKey.new()
	e.keycode = KEY_F3
	e.physical_keycode = KEY_F3
	e.pressed = true
	Input.parse_input_event(e)
	for sz in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = sz
		for _f in 5:
			await process_frame
		var btns: Array = []
		_buttons(panel, btns)
		var off := 0
		for b in btns:
			var r: Rect2 = b.get_global_rect()
			if b.is_visible_in_tree() and (r.position.x < 0 or r.end.x > sz.x + 1 or r.position.y < 0 or r.end.y > sz.y + 1):
				off += 1
				print("OFFSCREEN ", b.text, " ", r)
		print("buttons %d, off-screen %d at %s" % [btns.size(), off, sz])
		ok = ok and btns.size() > 10 and off == 0

	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)


func _buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is ScrollContainer:
			continue   # the tuning list scrolls on purpose
		if c is Button:
			out.append(c)
		_buttons(c, out)
