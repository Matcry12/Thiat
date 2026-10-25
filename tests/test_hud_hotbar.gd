extends SceneTree
# Top-right HUD (decision 0024): life bar follows Health, trail lags then catches up; hotbar has 9 slots (W3), highlight follows the selected slot, cast fill during a swap, cooldown shade after it, item name.
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
	check("bar only: no text line, height = skin health_bar_height", bar.custom_minimum_size.y == bar.get_skin().health_bar_height)
	check("hover text is the HP number", bar.tip_text() == "%d / %d" % [roundi(hp.max_hp), roundi(hp.max_hp)])
	bar.get_skin().health_bar_height = 30
	bar._process(0.016)
	check("skin health_bar_height re-measures live", bar.custom_minimum_size.y == 30 and bar.size.y == 30)
	bar.get_skin().health_bar_height = 18
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
	check("no cast overlay at rest", hb.slots()[1].cast_progress == 0.0 and hb.slots()[1].cooldown_frac == 0.0)

	check("swap starts", lo.try_swap(1))
	hb._process(0.016)
	check("target slot shows cast progress", hb.slots()[1].cast_progress >= 0.0 and hb._cast_to == 1)
	await create_timer(lo.swap_cast * 0.5).timeout
	hb._process(0.016)
	check("cast fill grows while casting", lo.is_casting() and hb.slots()[1].cast_progress > 0.0 and hb.slots()[0].cast_progress == 0.0)
	while lo.is_casting():
		await physics_frame
	hb._process(0.016)
	check("highlight moved to slot 1", hb.slots()[1].selected and not hb.slots()[0].selected)
	check("cooldown shade on the other WEAPON slot only", hb.slots()[0].cooldown_frac > 0.9 and hb.slots()[1].cooldown_frac == 0.0 and hb.slots()[2].cooldown_frac == 0.0)
	lo._cooldown_left = 0.0
	hb._process(0.016)
	check("shade gone when cooldown ends", hb.slots()[0].cooldown_frac == 0.0)

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
	sk.slot_size = 60
	hb._process(0.016)
	await process_frame
	await process_frame
	check("skin slot_size applies live", hb.slots()[0].size.x == 60 and hb.slots()[1].position.x == 60 + sk.slot_gap)
	sk.slot_size = 44
	hb._process(0.016)

	# --- layout: hotbar top-left, health + abilities bottom-left ---
	await process_frame
	await process_frame
	var vh: float = screen.get_visible_rect().size.y
	var hbr := hb.get_global_rect()
	check("hotbar sits in the top-left corner", hbr.position.x == hud.margin_x and hbr.position.y == hud.margin_y)
	check("health bar sits in the bottom-left corner", is_equal_approx(bar.get_global_rect().end.y, vh - hud.margin_y) and bar.get_global_rect().position.x == hud.margin_x)
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
