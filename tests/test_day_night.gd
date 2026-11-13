extends SceneTree
# Day / night core (0067): clock advance + wrap + day count, phase signal order, tint noon vs midnight, light level ramps,
# skip buttons, LightSource (night_only follows clock, radius), save round-trip, old save without time, HUD dial + F3 status.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	SaveGame.path = "user://test_save_dn.json"
	SaveGame.force_io = true
	SaveGame.delete_save()
	var arena = await World.make(self)
	var clock: DayClock = arena.get_node("DayClock")
	var d: DayNightData = clock.data
	_check(clock.frozen, "frozen by default in a test run")
	_check(is_equal_approx(clock.time, d.start_time) and clock.day_count == 1, "starts at start_time, day 1")
	_check(clock.phase == DayNightData.Phase.DAY, "0.30 is day")
	_check(clock.clock_text() == "07:12", "clock text 07:12 (%s)" % clock.clock_text())

	# frozen: process does nothing; unfrozen: advances by delta / day_length
	clock._process(10.0)
	_check(is_equal_approx(clock.time, d.start_time), "frozen: time does not move")
	clock.frozen = false
	clock._process(72.0)   # 72 s of 720 = 0.1
	_check(absf(clock.time - 0.4) < 1e-4, "advances by delta / day_length_s (%.4f)" % clock.time)
	clock.time_scale = 10.0
	clock._process(7.2)
	_check(absf(clock.time - 0.5) < 1e-4, "time_scale multiplies")
	clock.time_scale = 1.0
	clock.frozen = true

	# phase order and wrap
	var seen: Array = []
	clock.phase_changed.connect(func(p): seen.append(p))
	clock.set_time(0.5)
	clock.advance(0.3)    # 0.8 -> dusk
	clock.advance(0.1)    # 0.9 -> night
	_check(clock.is_night(), "night at 0.9")
	clock.advance(0.2)    # 1.1 -> 0.1 still night, day 2
	_check(clock.day_count == 2 and absf(clock.time - 0.1) < 1e-4, "wrap at midnight: day 2 (%d, %.3f)" % [clock.day_count, clock.time])
	clock.advance(0.15)   # 0.25 dawn
	clock.advance(0.1)    # 0.35 day
	_check(seen == [DayNightData.Phase.DUSK, DayNightData.Phase.NIGHT, DayNightData.Phase.DAWN, DayNightData.Phase.DAY], "phase signal order dusk, night, dawn, day: %s" % str(seen))
	seen.clear()
	clock.advance(0.01)
	_check(seen.is_empty(), "no signal inside a phase")

	# tint + lights
	_check(d.tint_at(0.5).is_equal_approx(Color.WHITE), "noon is white")
	var night := d.tint_at(0.0)
	_check(night.b > night.r and night.get_luminance() < 0.3, "midnight dark blue (%s)" % str(night))
	_check(d.tint_at(0.8).r > d.tint_at(0.8).b, "dusk is warm")
	_check(d.light_level(0.5) == 0.0 and d.light_level(0.0) == 1.0, "lights off at noon, on at midnight")
	var mid_dusk := (d.dusk_start + d.night_start) * 0.5
	_check(absf(d.light_level(mid_dusk) - 0.5) < 1e-3, "lights half way through dusk")
	_check(d.light_level(d.dawn_start + 0.001) > 0.9 and d.light_level(d.day_start - 0.001) < 0.1, "lights fade out over dawn")

	# skip buttons (forward only)
	clock.set_time(0.5)
	clock.skip_to(DayNightData.Phase.DUSK)
	_check(clock.phase == DayNightData.Phase.DUSK and clock.day_count == 2, "skip to dusk from noon, same day")
	clock.skip_to(DayNightData.Phase.DAWN)
	_check(clock.phase == DayNightData.Phase.DAWN and clock.day_count == 3, "skip to dawn passes midnight: next day")
	clock.skip_to(DayNightData.Phase.DAY)
	clock.skip_to(DayNightData.Phase.NIGHT)
	_check(clock.is_night() and is_equal_approx(clock.time, d.night_start), "skip to day, then night")
	var labels: Array = clock.debug_actions().map(func(a): return a["label"])
	_check(labels == ["Skip to dawn", "Skip to day", "Skip to dusk", "Skip to night", "Freeze time"], "F3 action labels")
	clock.debug_actions()[4]["run"].call()
	_check(not clock.frozen, "Freeze time toggles")
	clock.frozen = true

	# lights
	clock.set_time(0.5)
	await process_frame
	var lights := get_nodes_in_group("light_source")
	_check(lights.size() >= 2, "home campfire + player glow exist (%d)" % lights.size())
	var camp: LightSource = arena.get_node("HomePoint/NightLight")
	var glow: LightSource = arena.get_node("Player/NightGlow")
	_check(camp.radius == 220.0 and absf(camp.texture_scale - 220.0 / 128.0) < 1e-4, "campfire radius 220 -> texture scale")
	_check(glow.radius == 48.0, "player glow radius 48")
	_check(not camp.enabled and not glow.enabled, "lights off at noon")
	clock.set_time(0.95)
	await process_frame
	_check(camp.enabled and camp.energy > 0.5, "campfire on at night (energy %.2f)" % camp.energy)
	var tint: DayTint = arena.get_node("DayTint")
	_check(tint.color.b > tint.color.r, "CanvasModulate is dark blue at night")
	var free_light: LightSource = load("res://scenes/world/light_source.tscn").instantiate()
	free_light.night_only = false
	free_light.radius = 100.0
	arena.add_child(free_light)
	clock.set_time(0.5)
	await process_frame
	_check(free_light.enabled and is_equal_approx(free_light.texture_scale, 100.0 / 128.0), "night_only=false stays on at noon")
	free_light.free()
	_check(clock.status_text().begins_with(clock.clock_text()), "F3 status text")

	# HUD: dial exists on the HUD layer (not darkened by the CanvasModulate), tooltip text
	var dial: DayDial = arena.get_node("HUD").find_child("DayDial", true, false)
	_check(dial != null and dial.tip_text().begins_with("Day "), "HUD has a day dial with a tooltip")
	_check(dial != null and dial.get_viewport() == root and dial.get_parent_control() != null, "dial is inside the HUD canvas layer")
	var cl: Node = dial.get_parent()
	while cl != null and not cl is CanvasLayer:
		cl = cl.get_parent()
	_check(cl != null, "dial sits under a CanvasLayer (CanvasModulate does not reach it)")

	# save round-trip
	var sg: SaveGame = arena.get_node("SaveGame")
	clock.restore(0.62, 5)
	var data: Dictionary = sg.collect()
	_check(data["day_night"] == {"time": 0.62, "day": 5}, "save collects time + day")
	clock.restore(0.1, 1)
	sg.apply(JSON.parse_string(JSON.stringify(data)))
	_check(absf(clock.time - 0.62) < 1e-6 and clock.day_count == 5 and clock.phase == DayNightData.Phase.DAY, "load restores time + day + phase")
	var old: Dictionary = JSON.parse_string(JSON.stringify(data))
	old.erase("day_night")
	clock.restore(0.9, 4)
	sg.apply(old)
	_check(absf(clock.time - 0.9) < 1e-6 and clock.day_count == 4, "old save without time: clock untouched, no crash")

	SaveGame.delete_save()
	quit(0 if _ok else 1)
