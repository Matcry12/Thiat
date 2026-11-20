extends SceneTree
# Top-right HUD (decision 0024): life bar follows Health, trail lags then catches up; hotbar has 9 slots (W3), highlight follows the selected slot, item name.
var _ok := true
func check(name: String, cond: bool) -> void:
	print("%s: %s" % [name, "ok" if cond else "FAIL"])
	if not cond:
		_ok = false

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	var screen := SubViewport.new()   # headless starts with a 64 px window; layout checks need a real screen
	screen.size = Vector2i(1152, 648)
	root.add_child(screen)
	screen.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	player.get_node("Inventory").give_dev_kit()   # W4: the start kit is only a wooden sword (decision 0031)
	player.set_physics_process(false)
	var hud: HUD = arena.get_node("HUD")
	var hp: Health = player.get_node("Health")
	var bar := hud.health_bar()
	var hb := hud.hotbar()
	var lo: Loadout = player.get_node("Loadout")
	hp.immortal = true

	# --- life bar ---
	bar._process(0.016)
	check("bar full at start", is_equal_approx(bar.fraction(), 1.0))
	hp.hp = hp.max_hp * 0.5
	bar._process(0.016)
	check("bar follows Health", is_equal_approx(bar.fraction(), 0.5))
	check("trail still at old value right after damage", is_equal_approx(bar.trail_fraction(), 1.0))
	bar._process(bar.trail_delay * 0.5)
	check("trail waits during trail_delay", is_equal_approx(bar.trail_fraction(), 1.0))
	bar._process(bar.trail_delay)
	bar._process(0.1)
	check("trail drains after the delay", bar.trail_fraction() < 1.0 and bar.trail_fraction() > 0.5)
	for i in 100:
		bar._process(0.1)
	check("trail catches up", is_equal_approx(bar.trail_fraction(), 0.5))
	hp.hp = hp.max_hp
	bar._process(0.016)
	check("healing snaps the trail up", is_equal_approx(bar.trail_fraction(), 1.0))
	check("rope frame at real size: art height x art_scale", bar.custom_minimum_size == bar.get_skin().hp_frame_tex.get_size() * bar.get_skin().art_scale)
	check("hover text is the HP number", bar.tip_text() == "%d / %d" % [roundi(hp.max_hp), roundi(hp.max_hp)])
	bar.get_skin().art_scale = 3
	bar._process(0.016)
	check("skin art_scale re-measures live", bar.custom_minimum_size.y == 26 * 3 and bar.size.y == 26 * 3)
	bar.get_skin().art_scale = 2
	bar._process(0.016)

	# --- hotbar ---
	var inv: Inventory = player.get_node("Inventory")
	hb._process(0.016)
	check("9 slots, one per hotbar slot", hb.slots().size() == Inventory.HOTBAR)
	check("key numbers 1..9", hb.slots()[0].key_text == "1" and hb.slots()[1].key_text == "2" and hb.slots()[8].key_text == "9")
	check("slot 0 selected", hb.slots()[0].selected and not hb.slots()[1].selected)
	check("prettified file name", WeaponData.new().item_name() == "Weapon")
	var w := WeaponData.new()
	w.display_name = "Zed"
	check("display_name wins", w.item_name() == "Zed")
	check("icon fallback found (model art)", hb.slots()[0].has_picture())
	check("tool shows its icon (no letter, no word)", hb.slots()[2].item == inv.slot_item(2) and hb.slots()[2].has_picture() and inv.slot_item(2).icon != null)
	check("empty slot shows nothing", hb.slots()[8].item == null)
	check("select weapon slot 2 is instant", lo.select(1))
	hb._process(0.016)
	check("highlight moved to slot 1", hb.slots()[1].selected and not hb.slots()[0].selected)

	# --- tool selected: highlight + name follow ---
	lo.select(2)
	hb._process(0.016)
	check("axe selected: slot 3 highlighted", hb.slots()[2].selected and not hb.slots()[1].selected)

	# --- items show their count ---
	inv.add(load("res://data/items/wood.tres"), 12)
	hb._process(0.016)
	check("shift click sends the stack to the first free hotbar slot", inv.shift_move(Inventory.HOTBAR) and inv.slot_item(4) != null and inv.slot_item(4).id == &"wood")
	hb._process(0.016)
	check("a stack placed in the hotbar shows its count and icon", hb.slots()[4].count == 12 and hb.slots()[4].has_picture())

	# --- live tuning ---
	var sk := hb.get_skin()
	sk.art_scale = 3
	hb._process(0.016)
	await process_frame
	await process_frame
	check("skin art_scale applies live (slot = 22 art px)", hb.slots()[0].size.x == 66 and hb.slots()[1].position.x == 66 + hb.art_gap * 3)
	sk.art_scale = 2
	hb._process(0.016)

	# --- layout: hotbar top-left, health + abilities bottom-left ---
	await process_frame
	await process_frame
	var vh: float = screen.get_visible_rect().size.y
	var hbr := hb.get_global_rect()
	check("hotbar sits in the top-left corner", hbr.position.x == hud.margin_x and hbr.position.y == hud.margin_y)
	check("food bar sits in the bottom-left corner, the life bar right above it", is_equal_approx(hud.food_bar().get_global_rect().end.y, vh - hud.margin_y) and bar.get_global_rect().position.x == hud.margin_x and bar.get_global_rect().end.y <= hud.food_bar().get_global_rect().position.y + hud.vitals_overlap * 2.0 + 1.0)
	check("ability icons sit above the health bar", hud.abilities().get_global_rect().end.y <= bar.get_global_rect().position.y)
	check("three ability slots", hud.abilities().slots().size() == 3)
	check("health bar and hotbar do not overlap", not hbr.intersects(bar.get_global_rect()))

	# --- F3 overlap: the status panel keeps clear of the HUD ---
	var tp: CanvasLayer = arena.get_node("TuningPanel")
	tp.visible = true
	await process_frame
	await process_frame
	check("F3 watch card sits right of the hotbar, above the bottom-left block", not tp.card.get_global_rect().intersects(hbr) and tp.card.get_global_rect().end.y <= hud.abilities().get_global_rect().position.y)
	check("block is above the F3 layer", hud._layer.layer > tp.layer)
	quit(0 if _ok else 1)
