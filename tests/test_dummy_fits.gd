extends SceneTree
# The training dummy always stands where a walker fits (seeds 10, 20, 21 put the layout spot in water / on a rock).
func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var m: ArenaMap = arena.get_node("ArenaMap")
	var ok := true
	for sd in [10, 20, 21, 11]:
		m.generate_seed(sd)
		await process_frame
		var fits: bool = m._walker_fits(arena.get_node("Dummy").global_position)
		print(("ok   " if fits else "FAIL ") + "seed %d: dummy fits at %s" % [sd, arena.get_node("Dummy").global_position])
		ok = ok and fits
	quit(0 if ok else 1)
