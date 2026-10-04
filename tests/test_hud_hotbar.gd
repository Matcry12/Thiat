extends SceneTree
# Top-right HUD (decision 0024): life bar follows Health, trail lags then catches up; hotbar has one slot per
# weapon, highlight follows the active weapon, cast fill during a swap, cooldown shade after it, item name.
var _ok := true
func check(name: String, cond: bool) -> void:
	print("%s: %s" % [name, "ok" if cond else "FAIL"])
	if not cond:
		_ok = false

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
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
	check("text shows Life x/y", true if bar._health != null else false)

	# --- hotbar ---
	hb._process(0.016)
	check("slot count == weapons count", hb.slots().size() == lo.weapons.size() and hb.slots().size() >= 2)
	check("key numbers 1,2", hb.slots()[0].key_text == "1" and hb.slots()[1].key_text == "2")
	check("slot 0 selected", hb.slots()[0].selected and not hb.slots()[1].selected)
	check("name label = item name", hb.name_label.text == lo.active_weapon().item_name() and hb.name_label.text != "")
	check("prettified file name", WeaponData.new().item_name() == "Weapon")
	var w := WeaponData.new()
	w.display_name = "Zed"
	check("display_name wins", w.item_name() == "Zed")
	check("icon fallback found (model art)", hb.slots()[0]._icon != null)
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
	check("name changed", hb.name_label.text == lo.active_weapon().item_name())
	check("cooldown shade on the inactive slot only", hb.slots()[0].cooldown_frac > 0.9 and hb.slots()[1].cooldown_frac == 0.0)
	check("cooldown text", hb.slots()[0].cooldown_text != "")
	lo._cooldown_left = 0.0
	hb._process(0.016)
	check("shade gone when cooldown ends", hb.slots()[0].cooldown_frac == 0.0)

	# --- N slots ---
	lo.weapons.append(lo.weapons[0])
	hb._process(0.016)
	check("a third weapon makes a third slot", hb.slots().size() == 3 and hb.slots()[2].key_text == "3")
	lo.weapons.pop_back()

	# --- F3 overlap ---
	var tp: CanvasLayer = arena.get_node("TuningPanel")
	hud._process(0.016)
	var right_closed: float = hud._block.offset_right
	tp.visible = true
	hud._process(0.016)
	check("HUD block moves out of the way of F3", hud._block.offset_right < right_closed)
	quit(0 if _ok else 1)
