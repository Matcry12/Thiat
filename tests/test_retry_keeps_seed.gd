extends SceneTree
# R / F3 Restart reload the arena; the reloaded map must be the same island (map_seed 0 = random, so the rolled seed is carried over once).
func _init() -> void:
	var a1 = load("res://scenes/arena.tscn").instantiate()
	root.add_child(a1)
	await process_frame
	var m1: ArenaMap = a1.get_node("ArenaMap")
	m1.new_map()
	while m1.current_seed == int(OS.get_environment("BOSSFIGHT_TEST_SEED")):   # a seed the test env would not give anyway
		m1.new_map()
	var s := m1.current_seed
	ArenaMap.reload_keeping_seed(self)   # no current scene in a test: only the carry-over is checked
	root.remove_child(a1)
	a1.free()
	var a2 = load("res://scenes/arena.tscn").instantiate()
	root.add_child(a2)
	await process_frame
	var m2: ArenaMap = a2.get_node("ArenaMap")
	var ok := m2.current_seed == s and ArenaMap.retry_seed == 0
	print(("ok   " if ok else "FAIL ") + "retry keeps seed %d (got %d)" % [s, m2.current_seed])
	m2.new_map()
	ok = ok and m2.current_seed != 0
	quit(0 if ok else 1)
