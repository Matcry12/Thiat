extends SceneTree
# W4 crafting window (Minecraft-style, but you SELECT a recipe instead of placing items): one centred window
# with the bag + a hotbar copy below, a recipe grid / read-only ingredient grid / result slot above, a furnace
# tab, tooltips, no words, skin fields, F3 clearance, locked in the boss fight.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _frames(n := 3) -> void:
	for i in n:
		await process_frame

func _labels(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Label and c.text != "" and not c.text.is_valid_int() and not "/" in c.text:
			out.append(c.text)
		_labels(c, out)

func _init() -> void:
	var arena = await World.make(self, Vector2i(1152, 648))
	var player: Node2D = arena.get_node("Player")
	var inv: Inventory = player.get_node("Inventory")
	var cr: Crafter = player.get_node("Crafter")
	var pl: Placer = player.get_node("Placer")
	var boss: Boss = arena.get_node("Boss")
	boss.set_physics_process(false)
	boss.aggro = Boss.Aggro.IDLE
	var hud: HUD = arena.get_node("HUD")
	var win := hud.craft_window()
	var bag := hud.bag()
	var sk := win.get_skin()
	var vp := arena.get_viewport().get_visible_rect().size
	await _frames()
	_check(win != null and not win.is_open() and hud.hotbar().visible, "closed: no window, the HUD hotbar shows")
	bag.toggle()
	await _frames()

	# --- one centred window, bag + hotbar copy inside, nothing overlapping ---
	var fr := win.frame_rect()
	_check(bag.is_open() and win.is_open() and fr.has_area(), "Tab opens the window")
	_check(absf(fr.get_center().x - vp.x * 0.5) < 3.0 and absf(fr.get_center().y - vp.y * 0.5) < 3.0, "it is centred (%s in %s)" % [fr, vp])
	_check(Rect2(Vector2.ZERO, vp).encloses(fr), "and fits the screen (%.0f x %.0f of %.0f x %.0f)" % [fr.size.x, fr.size.y, vp.x, vp.y])
	_check(fr.encloses(bag.get_global_rect()) and fr.encloses(win.hotbar().get_global_rect()), "the bag and the hotbar copy are inside it")
	_check(win.hotbar().get_global_rect().position.y > bag.get_global_rect().end.y - 1.0 and bag.get_global_rect().position.y > win.marker().get_global_rect().end.y, "top = crafting area, then the bag, then the hotbar row (bottom)")
	_check(win.hotbar().slots().size() == Inventory.HOTBAR and bag.cells().size() == 27, "bag 3 x 9 + hotbar 1 x 9")
	_check(not hud.hotbar().visible, "the HUD hotbar hides while the window is open (it would show the same slots twice)")
	_check(not fr.intersects(hud.abilities().get_global_rect()) and not fr.intersects(hud.health_bar().get_global_rect()), "the window is clear of the ability icons and the health bar")

	# --- nothing held: nothing listed; hold part of a recipe: dimmed; hold it all: lit ---
	_check(win.shown_recipes().is_empty(), "empty bag, no station: no recipe icon at all (hidden)")
	_check(win.marker().tip_text() == "Hand" and win.marker().visible, "the station marker says: by hand (no tabs, so it shows)")
	_check(sk.hand_icon != null and sk.craft_tab_icon != null and win.marker().has_picture(), "the hand and Crafting-tab icons are real pictures, not squares")
	inv.add(World.item("wood"), 3)
	await _frames()
	_check(win.shown_recipes()[0].result.id == &"workbench", "3 wood: the workbench icon shows first")
	_check(win.shown_recipes().size() > 1 and win.recipe_slots()[1].modulate == sk.craft_dim_color, "...and the recipes of stations out of range show dimmed after it")
	_check(win.recipe_slots()[0].modulate == sk.craft_dim_color, "...dimmed: you hold a part of it")
	win.recipe_slots()[0].slot_clicked.emit(0, MOUSE_BUTTON_LEFT, false)
	_check(inv.held_item == null and inv.count(&"wood") == 3, "clicking a dimmed icon does nothing")
	await _frames()
	_check(win.recipe_slots()[0].modulate == sk.craft_flash_color, "...it flashes red for a moment")
	await _frames(40)
	inv.add(World.item("wood"), 27)
	await _frames()
	_check(win.recipe_slots()[0].modulate == sk.craft_lit_color, "30 wood: the icon is lit")
	_check(win.recipe_slots()[0].backdrop == sk.craft_lit_backdrop and win.recipe_slots()[1].backdrop == sk.craft_dim_backdrop and sk.craft_lit_backdrop.get_luminance() > sk.craft_dim_backdrop.get_luminance() + 0.4, "lit = a light backdrop, dim = a dark one: independent of the art's colours")
	_check(win.recipe_slots()[0].get_node("Backdrop").visible and win.recipe_slots()[0].get_node("Backdrop").color == sk.craft_lit_backdrop, "the backdrop node is drawn")
	_check(win.recipe_slots()[0].get_node("Count") != null and win.recipe_slots()[0].custom_minimum_size.x == sk.craft_slot_size, "the icon is a normal slot")

	# --- tooltip: the name, then the ingredient icons with need counts (the only place they show) ---
	var tip := hud.tooltip()
	tip.mouse_override = win.recipe_slots()[0].get_global_rect().get_center()
	await _frames(3)
	_check(tip.get_index() > win.get_index(), "the tooltip draws above the window (it is the later sibling)")
	_check(tip.shown_text() == "Workbench" and tip.shown_ingredients() == [[&"wood", 10, false]], "hover: the name and one wood icon, need 10 (%s)" % [tip.shown_ingredients()])
	tip.mouse_override = Vector2(-1, -1)

	# --- a dim icon whose station is out of range: the tooltip shows that station, red ---
	var far_i := -1
	for i in win.shown_recipes().size():
		if win.shown_recipes()[i].result.id == &"stone_pickaxe":
			far_i = i
	tip.mouse_override = win.recipe_slots()[far_i].get_global_rect().get_center()
	await _frames(3)
	_check(tip.shown_ingredients().back() == [&"workbench", 1, true], "stone pickaxe, no workbench near: the last tooltip row is the workbench, red (%s)" % [tip.shown_ingredients()])
	tip.mouse_override = Vector2(-1, -1)

	# --- click: the item is on the cursor, the ingredients are gone; click again: it stacks ---
	win.recipe_slots()[0].slot_clicked.emit(0, MOUSE_BUTTON_LEFT, false)
	_check(inv.held_item != null and inv.held_item.id == &"workbench" and inv.held_count == 1 and inv.count(&"wood") == 20, "click a lit icon: a workbench is on the cursor, 10 wood taken now")
	win.recipe_slots()[0].slot_clicked.emit(0, MOUSE_BUTTON_LEFT, false)
	_check(inv.held_count == 2 and inv.count(&"wood") == 10, "click again: it stacks on the cursor (2)")
	await _frames(2)
	var cur: ItemSlot = bag._cursor
	bag.mouse_override = Vector2(500, 400)
	await _frames(2)
	var mouse := bag.mouse_override
	_check(cur.visible and cur.position.is_equal_approx(mouse + sk.cursor_offset) and is_equal_approx(cur.scale.x, sk.cursor_scale), "the held stack is drawn offset from the pointer (%s) and %.1fx big: held, not placed" % [sk.cursor_offset, sk.cursor_scale])
	var shadow: Panel = cur.get_node("HeldShadow")
	var sbox := shadow.get_theme_stylebox("panel") as StyleBoxFlat
	_check(sbox.shadow_size == sk.cursor_shadow_size and sbox.shadow_color == sk.cursor_shadow_color and cur.get_child(0) == shadow, "...with a soft drop shadow behind it, from the skin")
	bag.mouse_override = Vector2(-1, -1)
	var bag_cell: ItemSlot = bag.cells()[5]
	bag_cell.slot_clicked.emit(bag_cell.index, MOUSE_BUTTON_LEFT, false)   # the HUD answers with Inventory.click_slot
	await _frames()
	_check(inv.held_item == null and inv.slot_item(bag_cell.index) != null and inv.slot_item(bag_cell.index).id == &"workbench" and inv.slot_count(bag_cell.index) == 2, "click a bag slot: the stack is put down there (like any bag stack)")

	# --- closing while holding: back into the inventory, never lost ---
	win.recipe_slots()[0].slot_clicked.emit(0, MOUSE_BUTTON_LEFT, false)
	_check(inv.held_item != null and inv.count(&"wood") == 0, "craft once more (the last 10 wood), holding it")
	bag.close()
	await _frames()
	_check(inv.held_item == null and inv.count(&"workbench") == 3, "close the window while holding: it went into the inventory (3 workbenches)")
	bag.toggle()
	await _frames()

	# --- shift click: straight into the inventory, no cursor ---
	inv.add(World.item("wood"), 10)
	await _frames()
	win.recipe_slots()[0].slot_clicked.emit(0, MOUSE_BUTTON_LEFT, true)
	_check(inv.held_item == null and inv.count(&"workbench") == 4 and inv.count(&"wood") == 0, "shift click: straight into the inventory, the cursor stays empty")

	# --- at a workbench: more icons, sorted nearest-station first; no words ---
	inv.add(World.item("wood"), 20)
	inv.add(World.item("stone"), 20)
	var wb := World.station(arena, "workbench", player.global_position + Vector2(40, 0))
	await _frames()
	_check(win.marker().tip_text() == "Workbench" and win.shown_recipes().size() == 8, "workbench in range: the marker shows it; 8 icons (the anvil itself needs bars you do not hold: hidden; the 3 copper tools use wood: dim)")
	_check(win.shown_recipes()[0].station == &"workbench" and win.shown_recipes()[win.shown_recipes().size() - 1].station == &"anvil", "the workbench recipes come first, the out-of-range anvil ones last")
	var texts := []
	_labels(win, texts)
	_check(texts.is_empty(), "no words anywhere in the window (only numbers): %s" % [texts])
	var pick_i := -1
	for i in win.shown_recipes().size():
		if win.shown_recipes()[i].result.id == &"stone_pickaxe":
			pick_i = i
	tip.mouse_override = win.recipe_slots()[pick_i].get_global_rect().get_center()
	await _frames(3)
	_check(tip.shown_text() == "Stone Pickaxe" and tip.shown_ingredients() == [[&"wood", 4, false], [&"stone", 6, false]], "hover the pickaxe: 4 wood, 6 stone as icons (%s)" % [tip.shown_ingredients()])
	inv.take(&"stone", 18)   # 2 stone left: short of 6
	await _frames(3)
	_check(tip.shown_ingredients()[1] == [&"stone", 6, true], "short of stone: its need count is red")
	tip.mouse_override = win.hotbar().slots()[0].get_global_rect().get_center()
	await _frames(3)
	_check(tip.shown_text() != "" and tip.shown_ingredients().is_empty(), "hover the hotbar copy: the item name, no ingredient row")
	tip.mouse_override = Vector2(-1, -1)

	# --- the furnace tab ---
	var fst := World.station(arena, "furnace", player.global_position + Vector2(-30, 10))   # nearer than the workbench
	await _frames()
	_check(win.current_tab() == "furnace" and win.furnace_visible() and not win.craft_visible(), "furnace nearest: the window opens on the Furnace tab")
	_check(win.tab_slots()[0].visible and win.tab_slots()[1].visible and win.tab_slots()[0].has_picture(), "both tabs show (a choice exists), the Crafting tab has its icon")
	_check(not win.marker().visible, "with tabs the station marker hides (the furnace icon would show twice)")
	_check(win.tab_slots()[1].modulate == Color.WHITE, "idle furnace: the Furnace tab does not pulse")
	var f: Furnace = fst.furnace()
	f.set_physics_process(false)   # the test drives the clock: live smelting adds the frames' real time (0.58+ under CPU load)
	f.put_input(World.item("copper_ore"), 3)
	f.advance(1.5)
	await _frames()
	var seen_glow := false
	for k in 12:   # the pulse swings with time: sample it
		await process_frame
		seen_glow = seen_glow or win.tab_slots()[1].modulate != Color.WHITE
	_check(seen_glow, "smelting: the Furnace tab pulses")
	_check(win.furnace_slots()[0].item.id == &"copper_ore" and win.furnace_slots()[0].count == 3 and absf(win.furnace_fraction() - 0.5) < 0.05, "input slot + progress arrow fill (%.2f)" % win.furnace_fraction())
	win.tab_slots()[0].slot_clicked.emit(0, MOUSE_BUTTON_LEFT, false)
	await _frames()
	_check(win.current_tab() == "craft" and win.craft_visible(), "click the Crafting tab: back to recipes")
	bag.close()
	await _frames()
	bag.toggle()
	await _frames()
	_check(win.current_tab() == "craft", "close and reopen near the same stations: your last tab is remembered")
	win.tab_slots()[1].slot_clicked.emit(1, MOUSE_BUTTON_LEFT, false)
	await _frames()
	win.furnace_input_clicked.emit(true)
	_check(f.in_item == null and inv.count(&"copper_ore") == 3, "shift click on the input slot: the ore comes back")
	f.put_input(World.item("copper_ore"), 2)
	f.finish_all()
	win.furnace_output_clicked.emit(false)
	_check(inv.held_item == World.item("copper_bar") and inv.held_count == 2, "click on the output: the bars are on the cursor")
	inv.return_held()
	fst.global_position = player.global_position + Vector2(400, 0)   # out of reach
	await _frames()
	_check(win.current_tab() == "craft" and not win.tab_slots()[1].visible, "furnace out of range: Crafting only")

	# --- F3 hides its status text rather than sit under the window ---
	var tp: CanvasLayer = arena.get_node("TuningPanel")
	tp.visible = true
	await _frames()
	var stat: Control = tp._status_panel
	_check(not stat.visible or not stat.get_global_rect().intersects(win.frame_rect()), "F3 open: the status text hides or clips, never under the window")
	_check(win.frame_rect().end.x <= vp.x - tp.right_panel_width(), "the window slides left to stay clear of the F3 tuning panel (right edge %.0f, panel starts %.0f)" % [win.frame_rect().end.x, vp.x - tp.right_panel_width()])
	tp.visible = false
	await _frames()
	_check(win.shift() == 0.0, "F3 closed: it is centred again")

	# --- the skin reshapes it live ---
	sk.craft_slot_size = 52
	await _frames()
	_check(win.recipe_slots()[0].custom_minimum_size.x == 52, "craft_slot_size applies live")
	sk.craft_slot_size = 44

	# --- locked in the boss fight ---
	boss.aggro = Boss.Aggro.ENGAGED
	await _frames()
	_check(not bag.is_open() and not win.is_open(), "boss engaged: the window closes")
	bag.toggle()
	await _frames()
	_check(not win.is_open() and win.hint_icon().visible and bag.hint_visible(), "it cannot open: the lock icon shows")
	_check(not cr.can_craft(cr.recipes[0]), "and crafting is refused")
	boss.aggro = Boss.Aggro.IDLE
	quit(0 if _ok else 1)
