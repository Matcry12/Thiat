extends SceneTree
## Screenshots of every item picture in the real UI (decision 0060, icon auto-fit): Items tab + bag, Craft tab, furnace tab,
## ground pickups + the item in the hand, a stack on the cursor.
##   timeout 120 xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/icon_fit_shot.gd -- <out_dir>
var _out := ""

func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(_out)
	ArenaMap.yard_mode = true
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("DebugOverlay").enabled = false
	var hud: HUD = arena.get_node("HUD")
	var player: Node2D = arena.get_node("Player")
	var inv: Inventory = player.get_node("Inventory")
	var items: Array[ItemData] = []
	for f in DirAccess.get_files_at("res://data/items"):
		if f.ends_with(".tres"):
			items.append(load("res://data/items/" + f))
	await _frames(420)   # let the "F3 overrides applied" toast fade
	for it in items:
		inv.add(it, 12 if it.category == "material" else 1)
	inv.give_materials(20)
	# Items tab, every item
	hud.bag().toggle()
	await _frames(15)
	var win := hud.craft_window()
	win.select_tab("items")
	await _frames(10)
	await _shot("icons_bag_items")
	# Craft tab with a chosen recipe, stations beside the player
	var placer: Placer = player.get_node("Placer")
	placer.place_free(load("res://data/items/workbench.tres"))
	var fst := placer.place_free(load("res://data/items/furnace.tres"))
	placer.place_free(load("res://data/items/anvil.tres"))
	hud.bag().toggle()
	await _frames(10)
	hud.bag().toggle()
	await _frames(15)
	win.select_tab("craft")
	await _frames(5)
	win.select_recipe(2)
	await _frames(10)
	await _shot("icons_book_craft")
	var tip := hud.tooltip()   # hover a recipe: the name + ingredient icons
	tip.mouse_override = win.recipe_slots()[3].get_global_rect().get_center()
	await _frames(8)
	await _shot("icons_book_tooltip")
	tip.mouse_override = Vector2(-1, -1)
	# furnace tab
	if fst != null:
		var f: Furnace = fst.furnace()
		f.set_physics_process(false)
		f.put_input(load("res://data/items/copper_ore.tres"), 3)
		f.advance(1.5)
		win.select_tab("furnace")
		await _frames(10)
		await _shot("icons_furnace")
	# a stack on the cursor
	win.select_tab("craft")
	inv.click_slot(Inventory.HOTBAR)
	await _frames(10)
	await _shot("icons_cursor")
	hud.bag().toggle()
	await _frames(10)
	# ground + hand
	arena.get_node("ArenaMap").camera_zoom = 3.0
	var base := player.global_position + Vector2(-10, -75)   # above the player, clear of rocks and stations
	for i in items.size():
		var p := base + Vector2((i % 8) * 14.0, (i / 8) * 14.0)
		Pickup.spawn(arena, items[i], 1, p, p)
	await _frames(90)
	await _shot("icons_ground")
	# the item in the hand: a material, then a placeable
	player.hide_idle_held = false
	arena.get_node("ArenaMap").camera_zoom = 4.0
	var lo: Loadout = player.get_node("Loadout")
	inv.remove_from_slot(7, 1)   # the hotbar is full: free two slots for the shift move
	inv.remove_from_slot(8, 1)
	for id in [&"wood", &"furnace"]:
		for s in range(Inventory.HOTBAR, Inventory.SIZE):
			if inv.slot_item(s) != null and inv.slot_item(s).id == id:
				inv.shift_move(s)
		for s in Inventory.HOTBAR:
			if inv.slot_item(s) != null and inv.slot_item(s).id == id:
				lo.select(s)
		player.get_node("WeaponVisual").set_aim_angle(0.0)
		await _frames(40)
		await _shot("icons_held_" + String(id))
	quit()

func _frames(n: int) -> void:
	await create_timer(n / 60.0).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
