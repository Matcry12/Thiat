extends SceneTree
# Headless: the F3 panel discovers tunable properties by REFLECTION (not a
# hardcoded list) and its apply path actually changes the target.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame
	var panel = arena.get_node("TuningPanel")

	var count: int = panel.settings.size()
	print("discovered properties: ", count)
	var ok: bool = count > 8

	# Apply through the panel's own path (the same one Save/Load/sliders use),
	# not by poking the target object directly.
	var any_key := "Player.speed"   # (a quiet one: the first key is a map size)
	var entry: Dictionary = panel.settings[any_key]
	var target: Object = entry["obj"]
	var prop: String = entry["name"]
	var before = target.get(prop)
	var new_value
	if entry["type"] == TYPE_BOOL:
		new_value = not bool(before)
	elif entry["type"] == TYPE_INT:
		new_value = int(before) + 1
	else:
		new_value = float(before) + 1.0
	panel.apply_value(any_key, new_value)
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
	# a slider only exists with a KNOWN range: none for a plain number, one from @export_range (the tree table ranges are @export_range too)
	var sr = panel.settings["Biome taiga.tree3_season"].get("range")
	var mr = panel.settings["Biome taiga.tree3_model"].get("range")
	ok = ok and sr != null and sr.x == 0.0 and sr.y == 6.0 and mr != null and mr.y == 3.0
	ok = ok and panel._known_range({"type": TYPE_FLOAT, "name": "no_such_prop", "hint": 0, "hint_string": ""}) == null
	var hinted = panel._known_range({"type": TYPE_FLOAT, "name": "no_such_prop", "hint": PROPERTY_HINT_RANGE, "hint_string": "0.2,3.0,0.01"})
	ok = ok and hinted == Vector3(0.2, 3.0, 0.01) and panel.settings["Map.map_cols"]["range"].y == 1024.0
	# heavy = the owner's debug_heavy(prop)
	ok = ok and panel.settings["Biome taiga.tree_tries"]["heavy"] and panel.settings["Biome taiga.ground_alt"]["heavy"] and not panel.settings["Biome taiga.tint_bright"]["heavy"]
	ok = ok and not panel.settings["Map.ground_brightness"]["heavy"] and panel.settings["Map.tree_fade_lo"]["heavy"]
	var wm = panel._world_map
	wm.toggle()
	var img_w: int = wm._tex.texture.get_width()
	var d0: int = wm.drawn_count
	panel._map.rebuild(true)
	var wm_ok: bool = wm.visible and img_w == panel._map.result.cols and wm.drawn_count == d0 + 1
	print("World map: visible=%s image width %d, drawn %d -> %d" % [wm.visible, img_w, d0, wm.drawn_count])
	ok = ok and wm_ok

	# F3 button rows wrap (HFlowContainer): on the Actions tab every button sits inside the window width at 1280x720 and 1920x1080;
	# the dock's fixed buttons (tabs, footer) also sit inside the height. (The Actions list scrolls vertically on purpose.)
	var e := InputEventKey.new()
	e.keycode = KEY_F3
	e.physical_keycode = KEY_F3
	e.pressed = true
	Input.parse_input_event(e)
	panel.dock.show_tab("Actions")
	for sz in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = sz
		for _f in 5:
			await process_frame
		var btns: Array = []
		_buttons(panel.dock, btns)
		var off := 0
		for b in btns:
			var r: Rect2 = b.get_global_rect()
			var in_list: bool = panel.dock._scroll.is_ancestor_of(b)
			if b.is_visible_in_tree() and (r.position.x < 0 or r.end.x > sz.x + 1 or (not in_list and (r.position.y < 0 or r.end.y > sz.y + 1))):
				off += 1
				print("OFFSCREEN ", b.text, " ", r)
		print("buttons %d, off-screen %d at %s" % [btns.size(), off, sz])
		ok = ok and btns.size() > 10 and off == 0

	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)


func _buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button:
			out.append(c)
		_buttons(c, out)
