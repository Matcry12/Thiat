extends SceneTree
# One shared hover tooltip: names on hotbar / bag / ability slots, HP on the health bar; nothing when the
# mouse is elsewhere or a stack is on the cursor; it never takes clicks; its look comes from the skin.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var screen := SubViewport.new()
	screen.size = Vector2i(1152, 648)
	root.add_child(screen)
	var arena = load("res://scenes/arena.tscn").instantiate()
	screen.add_child(arena)
	var boss: Boss = arena.get_node("Boss")
	boss.passive = true
	boss.set_physics_process(false)
	await process_frame
	boss.aggro = Boss.Aggro.IDLE
	await process_frame
	var hud: HUD = arena.get_node("HUD")
	var tip := hud.tooltip()
	var inv: Inventory = arena.get_node("Player/Inventory")
	inv.give_dev_kit()   # W4: the start kit is only a wooden sword (decision 0031)
	var hp: Health = arena.get_node("Player/Health")
	hp.immortal = true

	async_hover(tip, Vector2(2000, 2000))
	await process_frame
	_check(not tip.visible and tip.shown_text() == "", "mouse elsewhere: nothing shows")
	_check(tip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the tooltip ignores the mouse (never blocks a click)")

	var s0 := hud.hotbar().slots()[0]
	tip.mouse_override = s0.get_global_rect().get_center()
	await process_frame
	_check(tip.visible and tip.shown_text() == inv.slot_item(0).display_name, "over the sword slot: its display_name (%s)" % tip.shown_text())
	tip.mouse_override = hud.hotbar().slots()[2].get_global_rect().get_center()
	await process_frame
	_check(tip.shown_text() == "Stone Axe", "over the axe: Stone Axe")
	tip.mouse_override = hud.hotbar().slots()[8].get_global_rect().get_center()
	await process_frame
	_check(not tip.visible, "over an empty slot: nothing")
	tip.mouse_override = Vector2(2000, 2000)
	await process_frame
	_check(not tip.visible, "moving away hides it again")

	var ab := hud.abilities().slots()
	for i in 3:
		tip.mouse_override = ab[i].get_global_rect().get_center()
		await process_frame
		_check(tip.visible and tip.shown_text() != "" and not tip.shown_text().contains("/"), "ability slot %d shows a name (%s)" % [i, tip.shown_text()])
	_check(ab[0].tip_text() == "Dodge" and ab[2].tip_text() == "Guard", "dodge and guard names")

	hp.hp = 73.0
	tip.mouse_override = hud.health_bar().get_global_rect().get_center()
	await process_frame
	_check(tip.shown_text() == "73 / 100", "over the health bar: 73 / 100 (%s)" % tip.shown_text())

	# bag cells: hidden while the bag is closed, named when open
	var cell := hud.bag().cells()[0]
	inv.add(load("res://data/items/wood.tres"), 5)
	await process_frame
	tip.mouse_override = cell.get_global_rect().get_center()
	await process_frame
	_check(not tip.visible, "bag closed: its slots show nothing")
	hud.bag().toggle()
	await process_frame
	await process_frame
	tip.mouse_override = cell.get_global_rect().get_center()
	await process_frame
	_check(tip.shown_text() == "Wood", "bag open, over a wood stack: Wood (%s)" % tip.shown_text())

	# a held stack hides it
	inv.click_slot(Inventory.HOTBAR)
	await process_frame
	_check(inv.held_item != null and not tip.visible, "stack on the cursor: no tooltip")
	inv.click_slot(Inventory.HOTBAR)
	await process_frame
	await process_frame
	_check(tip.visible, "stack put down: it shows again")

	# look from the skin
	var sk := hud.hotbar().get_skin()
	sk.tooltip_tex = null   # the old flat-placeholder contract; the baked note look is the Island Workshop part
	await process_frame
	await process_frame
	var big := tip.size
	sk.tooltip_font_size = 28
	sk.tooltip_pad = 12
	await process_frame
	await process_frame
	_check(tip.size.x > big.x and tip.size.y > big.y, "tooltip size follows the skin (font + padding)")
	_check(tip._flat.visible, "no texture: flat placeholder panel")
	# mid-fight: no hotbar names (boss engaged, bag closed)
	inv.return_held()
	boss._set_aggro(Boss.Aggro.ENGAGED)
	await process_frame
	await process_frame
	tip.mouse_override = hud.hotbar().slots()[0].get_global_rect().get_center()
	await process_frame
	_check(not hud.bag().is_open() and not tip.visible, "boss engaged, bag closed: no hotbar name pops up")
	boss._set_aggro(Boss.Aggro.IDLE)
	await process_frame
	await process_frame
	_check(tip.visible and tip.shown_text() == inv.slot_item(0).display_name, "boss asleep again: the name is back")
	sk.tooltip_border_width = 5
	await process_frame
	_check((tip._flat.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left == 5, "tooltip border width comes from the skin")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)

func async_hover(tip: HudTooltip, p: Vector2) -> void:
	tip.mouse_override = p
