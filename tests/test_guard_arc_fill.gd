extends SceneTree
# The guard arc's FILL (decision 0015, merged): hidden when full and idle, shown
# while guarding and while refilling, fill follows the guard exactly, the full
# width stays drawn as a track, turns red when broken, keeps a dragged position.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame
	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	dummy.get_node("Attacker").set_physics_process(false)   # no surprise hits
	player.aim_override = dummy.global_position - player.global_position
	var guard = player.get_node("Guard")
	var health = player.get_node("Health")
	var gv = player.get_node("GuardVisual")
	var bar = player.get_node("GuardVisual/CoverArc")
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

	await _until_block(guard)    # wait for the STATE: physics can lag the clock (godot-gotchas)
	health.take_damage(20.0, dummy, true)
	await _tick()
	var follows: bool = is_equal_approx(bar.value, guard.tank_fraction()) and bar.value < 1.0
	# The protected WIDTH must not shrink with the guard — only the fill does.
	var width_kept: bool = is_equal_approx(bar.arc_degrees, guard.parry_arc_degrees)
	print("blocked 20 -> fill %.2f, guard %.2f: %s | full width still %.0f deg: %s" % [
		bar.value, guard.tank_fraction(), follows, bar.arc_degrees, width_kept])
	follows = follows and width_kept
	ok = ok and follows

	guard.release()
	await _tick()
	var shown_refilling: bool = bar.visible and guard.state == Guard.State.READY
	print("released, not full -> still shown while refilling: %s" % shown_refilling)
	ok = ok and shown_refilling

	guard.try_guard()
	await _until_block(guard)
	health.take_damage(500.0, dummy, true)                   # more than the bar -> breaks
	await _tick()
	var red: bool = bar.visible and bar.modulate.is_equal_approx(gv.broken_color) and is_zero_approx(bar.value)
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

## Steps physics until the guard is in BLOCK (or 2s of game time pass).
func _until_block(guard) -> void:
	var left := 2.0
	while guard.state != Guard.State.BLOCK and left > 0.0:
		await physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second
