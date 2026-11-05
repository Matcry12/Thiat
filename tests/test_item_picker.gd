extends SceneTree
# Test yard item picker (decision 0056): every item in data/items, click = into the inventory, only in the yard.
var _ok := true
var _n := 0   # only failures are printed (the runner shows 15 lines)

func _check(cond: bool, msg: String) -> void:
	_n += 1
	if not cond:
		print("FAIL " + msg)
		_ok = false

var _win: CraftWindow
var _p: ItemPicker

func _click(cell: ItemSlot, button: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	cell.gui_input.emit(ev)

## Click item `it` in the Items tab: go to its page, wait for the icons, click its slot.
func _take(it: ItemData, button: int) -> void:
	var k := _p.items.find(it)
	_win.select_tab("items")
	_win.set_catalog_page(k / 24)
	for i in 3:
		await process_frame
	_click(_win.catalog_slots()[k % 24], button)

## Every ItemData reachable from the custom resources in `dir` (results, outputs, drops), found by walking the properties.
func _items_in(dir: String, out: Dictionary) -> void:
	for r in RecipeBook.load_dir(dir):
		_walk(r, out, 0)

func _walk(v: Variant, out: Dictionary, depth: int) -> void:
	if depth > 4:
		return
	if v is ItemData:
		out[v.id] = v
	elif v is Array:
		for e in v:
			_walk(e, out, depth + 1)
	elif v is Resource and (v as Resource).get_script() != null:
		for p in (v as Resource).get_property_list():
			if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				_walk((v as Resource).get(p["name"]), out, depth + 1)

func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n
	for c in n.get_children():
		var f := _find_button(c, text)
		if f != null:
			return f
	return null

func _find_class(n: Node, cls: String, out: Array) -> void:
	if n.get_script() != null and n.get_script().get_global_name() == cls:
		out.append(n)
	for c in n.get_children():
		_find_class(c, cls, out)

func _init() -> void:
	OS.set_environment("BOSSFIGHT_TEST_MAP_CELLS", "192")
	ArenaMap.yard_mode = true
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	await process_frame
	var y: TestYard = arena.get_node("TestYard")
	var p: ItemPicker = y.picker
	var hud: HUD = arena.get_node("HUD")
	var win: CraftWindow = hud.craft_window()
	var inv: Inventory = arena.get_node("Player/Inventory")
	var lo: Loadout = arena.get_node("Player/Loadout")
	_p = p
	_win = win
	_check(p != null and p.get_parent() == y, "yard makes the picker (a plain Node, no panel of its own)")
	_check(win.tab_count() == 4 and win.catalog.size() == p.items.size(), "yard: the book has 4 tabs and the catalog is the list")

	# the list = a separate scan of data/items
	var scan := {}
	var d := DirAccess.open("res://data/items")
	for f in d.get_files():
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres") and load("res://data/items/" + f) is ItemData:
			scan[(load("res://data/items/" + f) as ItemData).id] = true
	var listed := {}
	for it in p.items:
		listed[it.id] = true
	_check(listed.size() == p.items.size() and listed.keys().size() == scan.keys().size() and scan.keys().all(func(k): return listed.has(k)),
		"list = every file in data/items (%d)" % p.items.size())
	var bad := 0
	for it in p.items:
		bad += int(it.icon == null and it.color.a == 0.0)
	_check(bad == 0, "every item has a picture or a colour")
	var cats: Array = p.items.map(func(it: ItemData) -> int: return ItemPicker.ORDER.find(it.category))
	var sorted := cats.duplicate()
	sorted.sort()
	_check(cats == sorted, "ordered weapon, tool, placeable, material")

	# sweep: nothing in the game's data can be obtained that the picker does not list
	var seen := {}
	for dir in ["res://data/recipes", "res://data/smelting", "res://data/resource_nodes", "res://data/enemies"]:
		_items_in(dir, seen)
	var missing: Array = seen.keys().filter(func(k): return not listed.has(k))
	_check(seen.size() >= 6 and missing.is_empty(), "every recipe / smelt / node / enemy item is listed (%d checked) missing=%s" % [seen.size(), missing])
	var no_taker: Array[String] = []
	for f in DirAccess.open("res://data/weapons").get_files():
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres") and f != "fists.tres":
			var w := load("res://data/weapons/" + f) as WeaponData
			var found := p.items.any(func(it: ItemData) -> bool: return it.weapon == w)
			if not found:
				no_taker.append(f)
	_check(no_taker.is_empty(), "every weapon (not fists) is held by a listed item, no taker: %s" % [no_taker])

	# the book: Items tab
	await process_frame
	_check(not win.is_open(), "closed while the bag is closed")
	root.size = Vector2i(1152, 648)   # headless windows are 64 x 64
	hud.bag().toggle()
	for i in 4:
		await process_frame
	_check(win.is_open() and win.items_tab().visible and win.current_tab() == "craft", "bag open: Items tab shown, book on Craft")
	win.select_tab("items")
	for i in 3:
		await process_frame
	var per := 24
	_check(win.current_tab() == "items" and win.catalog_slots().size() == mini(per, p.items.size()), "Items tab shows the first page (%d icons)" % win.catalog_slots().size())
	_check(win.catalog_slots().all(func(c: ItemSlot) -> bool: return c.item != null), "every shown icon holds an item")
	_check(not win.craft_button().visible and win.craft_button().get_global_rect().size.x > 0, "no Craft button on the Items tab")
	# stable: no icon is rebuilt while nothing changes (same instances, no `rebuilt`)
	var ids0 := win.catalog_slots().map(func(c: ItemSlot) -> int: return c.get_instance_id())
	var rebuilt_n := [0]
	win.rebuilt.connect(func(): rebuilt_n[0] += 1)
	for i in 10:
		await process_frame
	_check(win.catalog_slots().map(func(c: ItemSlot) -> int: return c.get_instance_id()) == ids0 and rebuilt_n[0] == 0, "idle frames keep the same icons (rebuilt fired %d times)" % rebuilt_n[0])
	# a real recipe is chosen, then the Items tab must still refuse to craft
	inv.give_dev_kit()
	var wb := load("res://data/recipes/workbench.tres") as RecipeData
	for g in wb.ingredients:
		inv.give_or_drop(g.item, g.count)
	win.select_tab("craft")
	for i in 3:
		await process_frame
	win.select_recipe(0)
	_check(win.selected_recipe() != null and win.craft_enabled(), "a craftable recipe is chosen on the Craft tab")
	win.select_tab("items")
	for i in 3:
		await process_frame
	var held0 = inv.held_item
	_check(not win.craft_selected(false) and not win.craft_selected(true) and inv.held_item == held0, "Craft cannot craft from the Items tab (a recipe IS chosen)")
	_check(win.items_tab() in win.tab_slots(), "Items tab has a hover name (in tab_slots)")
	_check(p.status_text().contains("pages 1") and p.status_text().contains("tab items"), "F3 line: pages + tab (%s)" % p.status_text().replace("\n", " "))
	# hover name: both lines, no ingredients
	var c0: ItemSlot = win.catalog_slots()[0]
	_check(c0.tip_text() == p.items[0].display_name and c0.tip_sub() == p.items[0].category.capitalize(), "icon hover: name + kind (%s / %s)" % [c0.tip_text(), c0.tip_sub()])
	# a station nearby does not move the book off Items
	var pl = arena.get_node("Player")
	var near_st = get_nodes_in_group("station")
	_check(not near_st.is_empty(), "the yard has stations to walk to")
	pl.global_position = (near_st[0] as Node2D).global_position + Vector2(10, 0)
	for i in 6:
		await process_frame
	_check(win.current_tab() == "items", "station in range: the book stays on Items (tab %s)" % win.current_tab())
	win.select_tab("craft")
	for i in 3:
		await process_frame
	_check(win.craft_visible() and win.recipe_slots().size() > 0 and win.catalog_slots().is_empty(), "back on Craft: recipes are back, catalog icons gone: vis %s recipes %d cat %d tab %s" % [win.craft_visible(), win.recipe_slots().size(), win.catalog_slots().size(), win.current_tab()])
	win.select_tab("items")
	for i in 3:
		await process_frame
	# F3 dock open: the window slides, the Items tab still works
	win.set_shift(-190.0)
	for i in 3:
		await process_frame
	_check(win.catalog_slots().size() > 0 and win.catalog_slots()[0].get_global_rect().position.x >= 0.0, "window slid for the F3 dock: Items icons still on screen")
	win.set_shift(0.0)

	# more than one page: a longer catalog
	var many: Array[ItemData] = []
	for i in 30:
		many.append(p.items[i % p.items.size()])
	win.set_catalog(many)
	win.select_tab("items")
	for i in 3:
		await process_frame
	_check(win.catalog_pages() == 2 and win.catalog_slots().size() == 24, "30 items = 2 pages, 24 on the first")
	var plus := _find_button(win, ">")
	_check(plus != null and not plus.disabled and plus.is_visible_in_tree(), "pager '>' is shown and live on page 1")
	plus.pressed.emit()
	for i in 3:
		await process_frame
	_check(win.catalog_page() == 1 and win.catalog_slots().size() == 6, "'>' goes to page 2 (6 icons)")
	var want: ItemData = many[24 + 2]
	var got0 := inv.count(want.id)
	_click(win.catalog_slots()[2], MOUSE_BUTTON_RIGHT)
	_check(inv.count(want.id) == got0 + 1 and win.catalog_selected() == want, "click on page 2 icon 3 gives item #26 (%s)" % want.id)
	win.set_catalog(p.items)   # the real list again
	win.select_tab("items")
	for i in 3:
		await process_frame

	# clicks
	inv.give_dev_kit()
	var wood := p.items.filter(func(it: ItemData) -> bool: return it.id == &"wood")[0] as ItemData
	var wi := p.items.find(wood)
	await _take(p.items[wi], MOUSE_BUTTON_LEFT)
	_check(inv.count(&"wood") == wood.stack_limit(), "left click = a full stack (%d)" % wood.stack_limit())
	await _take(p.items[wi], MOUSE_BUTTON_RIGHT)
	_check(inv.count(&"wood") == wood.stack_limit() + 1, "right click = 1")
	_check(p.status_text().contains("Wood x1"), "F3 shows the last taken (%s)" % p.last_taken.replace("\n", " "))
	# bag full: fill every slot with stone, then take wood
	var stone := p.items.filter(func(it: ItemData) -> bool: return it.id == &"stone")[0] as ItemData
	for i in Inventory.SIZE:
		inv.remove_from_slot(i, 9999)
	for i in Inventory.SIZE:
		inv.add(stone, stone.stack_limit())
	var ground := get_nodes_in_group("pickup").size()
	await _take(p.items[wi], MOUSE_BUTTON_LEFT)
	_check(inv.count(&"wood") == 0 and get_nodes_in_group("pickup").size() > ground, "full bag: the stack drops at the player, not lost")

	# take every item once
	inv.give_dev_kit()
	for it in p.items:
		await _take(it, MOUSE_BUTTON_RIGHT)
	_check(p.items.all(func(it: ItemData) -> bool: return inv.count(it.id) >= 1), "took every item once, each in the inventory")

	# the new sword, for real
	inv.give_dev_kit()
	var s1 := p.items.filter(func(it: ItemData) -> bool: return it.id == &"sword1")[0] as ItemData
	_check(s1 != null and s1.weapon != null and s1.icon != null, "sword1 is listed with an icon and a weapon")
	await _take(s1, MOUSE_BUTTON_LEFT)
	var bi := -1
	for i in Inventory.SIZE:
		if inv.slot_item(i) == s1:
			bi = i
	_check(bi >= Inventory.HOTBAR, "sword1 lands in the bag (hotbar holds 2 weapons)")
	_check(inv.click_slot(bi) and inv.click_slot(0), "pick it up and swap it onto the wooden sword's slot")
	hud.bag().toggle()
	inv.return_held()
	await process_frame
	for tries in 2:   # the first press of a number key can only take the hands out (holstered after the kit / bag)
		if lo.active_weapon() != s1.weapon:
			lo.select(0)
			while lo.is_casting():
				await physics_frame
	await process_frame
	_check(inv.slot_item(0) == s1 and lo.active_weapon() == s1.weapon, "sword1 is the active weapon: slot0=%s active=%s ws=%s" % [inv.slot_item(0), lo.active_weapon().display_name, lo.weapons.map(func(w): return w.display_name)])
	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	player.set_physics_process(false)
	dummy.attacker.set_physics_process(false)
	player.global_position = dummy.global_position - Vector2(45, 0)
	arena.get_node("Player/WeaponVisual").set_aim_angle(0.0)
	await physics_frame
	var hp0: float = dummy.get_node("Health").hp
	var holder = arena.get_node("Player/WeaponHolder")
	holder.try_attack()
	var guard := 0
	while (holder.phase != 0 or guard < 5) and guard < 600:
		await physics_frame
		guard += 1
	_check(dummy.get_node("Health").hp < hp0, "a real sword1 swing hurts the dummy (%.0f -> %.0f)" % [hp0, dummy.get_node("Health").hp])
	_check(s1.weapon.model.instantiate().get_node("Art").texture.resource_path.ends_with("sword1.png"), "sword1 model uses the new picture")

	# picked stations still place, picked materials still craft
	inv.give_dev_kit()
	var bench := p.items.filter(func(it: ItemData) -> bool: return it.id == &"workbench")[0] as ItemData
	await _take(bench, MOUSE_BUTTON_RIGHT)
	var placer: Placer = arena.get_node("Player/Placer")
	var slot := -1
	for i in Inventory.HOTBAR:
		if inv.slot_item(i) == bench:
			slot = i
	_check(slot >= 0 and lo.select(slot) and placer.held_item() == bench and placer.is_holding(), "picked workbench is held by the Placer")
	var st := placer.place_free(bench)
	_check(st != null and st.item == bench, "and the Placer puts it down")
	inv.give_dev_kit()
	var rec := load("res://data/recipes/workbench.tres") as RecipeData
	for g in rec.ingredients:
		for k in g.count:
			await _take(g.item, MOUSE_BUTTON_RIGHT)
	var crafter: Crafter = arena.get_node("Player/Crafter")
	_check(crafter.craft_to_cursor(rec) and inv.held_item == bench, "picked materials are crafted by the Crafter as usual")

	# normal run: nothing of it
	arena.queue_free()
	await process_frame
	await process_frame
	ArenaMap.yard_mode = false
	var normal = load("res://scenes/arena.tscn").instantiate()
	root.add_child(normal)
	await process_frame
	await process_frame
	var found: Array = []
	_find_class(root, "ItemPicker", found)
	_find_class(root, "TestYard", found)
	var nwin: CraftWindow = normal.get_node("HUD").craft_window()
	normal.get_node("HUD").bag().toggle()
	for i in 4:
		await process_frame
	_check(found.is_empty() and normal.get_node_or_null("TestYard") == null, "normal run: no ItemPicker, no TestYard")
	_check(nwin.catalog.is_empty() and nwin.tab_count() == 3 and not nwin.items_tab().visible, "normal run: empty catalog, exactly 3 tabs")
	print("%d checks, %s" % [_n, "all ok" if _ok else "FAILED"])
	quit(0 if _ok else 1)
