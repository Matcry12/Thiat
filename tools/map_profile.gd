extends SceneTree
## Profile the global map data (MapGen.generate alone, 0038 step 2): total ms, ms per stage (Result.timings), and a digest of the whole
## result (a change that should only be faster must not change it). Usage:
##   BOSSFIGHT_TEST_SEED=11 godot --headless --script tools/map_profile.gd -- [cols] [rows] [seed]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	var m: ArenaMap = arena.get_node("ArenaMap")
	m.map_cols = int(args[0]) if args.size() > 0 else 512
	m.map_rows = int(args[1]) if args.size() > 1 else 512
	m._rebuild_queued = false
	m._place_actors()
	var t := Time.get_ticks_msec()
	var r := MapGen.generate(m.style, m.make_params(), int(args[2]) if args.size() > 2 else 11)
	print("generate ms ", Time.get_ticks_msec() - t)
	var keys := r.timings.keys()
	for k in keys:
		print("  %-14s %8.1f" % [k, r.timings[k]])
	print("digest ", _digest(r))
	print("obstacles ", r.obstacles.size(), " deco ", r.deco.size())
	quit(0)


## One number for the whole Result: any optimisation that changes the map changes this.
func _digest(r: MapGen.Result) -> String:
	var parts: PackedStringArray = []
	parts.append(str(hash(r.land)) + "," + str(hash(r.biome)) + "," + str(hash(r.area)) + "," + str(hash(r.ground)) + "," + str(hash(r.f)) + "," + str(hash(r.temp)) + "," + str(hash(r.shallow)) + "," + str(hash(r.fresh)) + "," + str(hash(r.walk_land)))
	var s := ""
	for o in r.obstacles:
		s += "%s,%s,%s,%s;" % [o["pos"], o["radius"], o["node"], o["region"]]
	parts.append(str(s.hash()))
	s = ""
	for d in r.deco:
		s += "%s,%s,%s;" % [d["pos"], d["set"], d["region"]]
	parts.append(str(s.hash()))
	parts.append(str(hash(r.dirt_stamps)) + "," + str(str(r.dirt_cells.keys()).hash()) + "," + str(str(r.bridge.keys()).hash()) + "," + str(str(r.clearings).hash()) + "," + str(hash(r.kind)))
	return " | ".join(parts)
