extends SceneTree
# Art is a swap: putting textures into the InventorySkin must not change the slot count or the layout,
# and clearing them gives the placeholder back. Slots use named child nodes; the UI only emits requests.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _tex(c: Color, n: int) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

func _layout(hb: Hotbar, bag: BagPanel) -> Array:
	var out := []
	for s in hb.slots():
		out.append(s.global_position)
		out.append(s.size)
	for c in bag.cells():
		out.append(c.global_position)
	return out

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var hud: HUD = arena.get_node("HUD")
	var bag := hud.bag()
	var hb := hud.craft_window().hotbar()   # the bag opens inside the window: its hotbar copy is the one on screen
	var inv: Inventory = arena.get_node("Player/Inventory")
	bag.toggle()
	for i in 3:
		await process_frame
	var sk := hb.get_skin()
	_check(sk == bag.get_skin(), "hotbar and bag share one skin")
	var s0 := hb.slots()[0]
	for role in ["Frame", "SelectedFrame", "Icon", "Count", "KeyLabel", "LockOverlay"]:
		_check(s0.get_node_or_null(role) != null, "slot has a child named " + role)
	_check(hb.slots().size() == 9 and bag.cells().size() == 27, "9 hotbar slots, 27 bag slots")
	_check(s0.get_node("Frame/Placeholder").visible and not s0.get_node("SelectedFrame").visible or s0.selected, "no texture = placeholder frame")
	var before := _layout(hb, bag)

	sk.slot_texture = _tex(Color.RED, 16)
	sk.slot_selected_texture = _tex(Color.GREEN, 16)
	sk.bag_panel_texture = _tex(Color.BLUE, 16)
	for i in 3:
		await process_frame
	_check(hb.slots().size() == 9 and bag.cells().size() == 27, "slot counts unchanged with textures")
	_check(_layout(hb, bag) == before, "layout unchanged with textures")
	_check(s0.get_node("Frame").texture == sk.slot_texture and not s0.get_node("Frame/Placeholder").visible, "slot frame takes the texture, placeholder hides")
	_check(bag.cells()[0].get_node("Frame").texture == sk.slot_texture, "the bag slots use the same slot texture")
	_check(s0.get_node("SelectedFrame").texture == sk.slot_selected_texture, "selected frame takes its texture")

	sk.slot_size = 56
	sk.slot_gap = 10
	for i in 3:
		await process_frame
	_check(hb.slots()[1].position.x - hb.slots()[0].position.x == 66.0, "size + gap come from the skin (56 + 10)")
	_check(bag.cells()[1].position.x - bag.cells()[0].position.x == 66.0, "...in the bag too")

	sk.slot_texture = null
	sk.slot_selected_texture = null
	sk.bag_panel_texture = null
	sk.slot_size = 44
	sk.slot_gap = 6
	for i in 3:
		await process_frame
	_check(_layout(hb, bag) == before and s0.get_node("Frame/Placeholder").visible, "removing the textures restores the placeholder look")

	# The UI only requests: a click on a slot changes nothing by itself until the HUD answers.
	var asked := []
	bag.slot_clicked.connect(func(i, b, sh): asked.append(i))
	bag.cells()[0].slot_clicked.emit(9, MOUSE_BUTTON_LEFT, false)
	_check(asked == [9], "a bag cell emits slot_clicked(index, button, shift)")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
