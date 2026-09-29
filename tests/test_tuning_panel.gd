extends SceneTree
# Headless: the F3 panel discovers tunable properties by REFLECTION (not a
# hardcoded list) and its apply path actually changes the target.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame
	var panel = arena.get_node("TuningPanel")

	var count: int = panel._controls.size()
	print("discovered properties: ", count)
	var ok: bool = count > 8

	# Apply through the panel's own path (the same one Save/Load/sliders use),
	# not by poking the target object directly.
	var any_key: String = panel._controls.keys()[0]
	var entry: Dictionary = panel._controls[any_key]
	var target: Object = entry["obj"]
	var prop: String = entry["prop"]
	var before = target.get(prop)
	var new_value
	if entry["is_bool"]:
		new_value = not bool(before)
	elif entry["is_int"]:
		new_value = int(before) + 1
	else:
		new_value = float(before) + 1.0
	panel._apply_value(any_key, new_value)
	var after = target.get(prop)
	var changed: bool = after != before
	print("%s: %s -> %s (changed=%s)" % [any_key, before, after, changed])
	ok = ok and changed

	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
