extends SceneTree
# The curved shield bar: hidden when full and idle, shown while guarding and
# while refilling, follows the tank exactly, turns red when broken, and keeps a
# position the user dragged in the editor.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	dummy.get_node("Attacker").set_physics_process(false)   # no surprise hits
	player.aim_override = dummy.global_position - player.global_position
	var guard = player.get_node("Guard")
	var health = player.get_node("Health")
	var gv = player.get_node("GuardVisual")
	var bar = player.get_node("GuardVisual/GuardBar")
	var dragged := Vector2(3, 14)
	bar.position = dragged
	await _tick()
	var ok := true

	var hidden_full: bool = not bar.visible and is_equal_approx(bar.value, 1.0)
	print("full + idle -> hidden: %s (value %.2f)" % [hidden_full, bar.value])
	ok = ok and hidden_full

	guard.try_guard()
	await _tick()
	var shown_guarding: bool = bar.visible
	print("guarding -> shown: %s" % shown_guarding)
	ok = ok and shown_guarding

	await create_timer(guard.parry_window + 0.05).timeout    # into BLOCK
	health.take_damage(20.0, dummy, true)
	await _tick()
	var follows: bool = is_equal_approx(bar.value, guard.tank_fraction()) and bar.value < 1.0
	print("blocked 20 -> bar %.2f, tank %.2f: %s" % [bar.value, guard.tank_fraction(), follows])
	ok = ok and follows

	guard.release()
	await _tick()
	var shown_refilling: bool = bar.visible and guard.state == Guard.State.READY
	print("released, not full -> still shown while refilling: %s" % shown_refilling)
	ok = ok and shown_refilling

	guard.try_guard()
	await create_timer(guard.parry_window + 0.05).timeout
	health.take_damage(500.0, dummy, true)                   # more than the bar -> breaks
	await _tick()
	var red: bool = bar.visible and bar.modulate.is_equal_approx(gv.broken_bar_color) and is_zero_approx(bar.value)
	print("broken -> shown, empty, red: %s (value %.2f)" % [red, bar.value])
	ok = ok and red
	guard.release()

	var kept: bool = bar.position.is_equal_approx(dragged)
	print("dragged bar position kept: %s (%s)" % [kept, bar.position])
	ok = ok and kept

	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _tick() -> void:
	await physics_frame
	await process_frame
