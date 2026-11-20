extends SceneTree
# Food bar HUD (decision 0071): FoodBar follows Hunger, starving state + pulse, same length as the life bar, tooltip text,
# potion cooldown sweep fraction on hotbar slots (heal_value > 0 only) and the sweep reaching the slot.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	var screen := SubViewport.new()
	screen.size = Vector2i(1152, 648)
	root.add_child(screen)
	screen.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	var hunger: Hunger = player.get_node("Hunger")
	var consumer: Consumer = player.get_node("Consumer")
	var inv: Inventory = player.get_node("Inventory")
	var hud: HUD = arena.get_node("HUD")
	var bar := hud.food_bar()
	_check(bar != null, "HUD has a FoodBar")
	bar._process(0.016)
	_check(is_equal_approx(bar.fraction(), 1.0) and not bar.is_starving(), "full at start, not starving")
	hunger.set_food(55.0)
	bar._process(0.016)
	_check(is_equal_approx(bar.fraction(), 0.55) and not bar.is_starving(), "follows Hunger (55%)")
	_check(bar.tip_text() == "55 / 100", "tooltip '55 / 100' (got '%s')" % bar.tip_text())
	var sk := bar.get_skin()
	_check(bar.custom_minimum_size.x == hud.health_bar().custom_minimum_size.x, "same length as the life bar")
	_check(bar.custom_minimum_size == sk.food_frame_tex.get_size() * sk.art_scale, "frame at real size")
	hunger.set_food(0.0)
	bar._process(0.016)
	_check(bar.is_starving() and is_equal_approx(bar.fraction(), 0.0), "starving at 0")
	var lo := INF
	var hi := -INF
	for i in 120:
		bar._process(1.0 / 60.0)
		lo = minf(lo, bar.starve_alpha())
		hi = maxf(hi, bar.starve_alpha())
	_check(is_equal_approx(lo, bar.starve_pulse_min) or lo < bar.starve_pulse_min + 0.02, "pulse reaches its minimum")
	_check(hi > 0.98, "pulse reaches full red")
	hunger.set_food(100.0)
	bar._process(0.016)
	_check(not bar.is_starving(), "eating ends starving")
	var names: Array = hud.debug_children().map(func(c): return c["name"])
	_check("FoodBar" in names, "FoodBar in HUD debug_children")

	# potion sweep
	var potion: ItemData = load("res://data/items/healing_potion.tres")
	var bread: ItemData = load("res://data/items/bread.tres")
	consumer._cooldown_left = consumer.potion_cooldown * 0.4
	_check(is_equal_approx(Hotbar.potion_sweep(potion, consumer), 0.4), "sweep = left / potion_cooldown")
	_check(Hotbar.potion_sweep(bread, consumer) == 0.0 and Hotbar.potion_sweep(null, consumer) == 0.0, "non-healing items and empty slots: no sweep")
	consumer._cooldown_left = 0.0
	_check(Hotbar.potion_sweep(potion, consumer) == 0.0, "no sweep when ready")
	inv._insert(potion, 3, [4])
	consumer._cooldown_left = 12.0
	await process_frame
	await process_frame
	var slot := hud.hotbar().slots()[4]
	_check(absf(slot.cooldown_frac - 12.0 / consumer.potion_cooldown) < 0.05 and slot.cooldown_secs > 11.0, "potion slot gets the sweep")
	_check(slot.get_node("Count").text == str(ceili(slot.cooldown_secs)), "seconds (rounded up) show in the count spot")
	_check(hud.hotbar().slots()[0].cooldown_frac == 0.0, "other slots stay clear")
	quit(0 if _ok else 1)
