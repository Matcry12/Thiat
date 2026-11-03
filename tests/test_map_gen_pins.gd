extends SceneTree
# 0038 step 2 made MapGen.generate ~12x faster at 512 x 512 (flat arrays, span floods, incremental walk grid). The map for a seed must not
# change by it: these digests were taken from the code BEFORE the rewrite (200 x 120, the params of test_island_gen). A real change of the
# map (a new rule) re-pins them on purpose.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _params() -> MapGen.Params:
	var p := MapGen.Params.new()
	p.cols = 200
	p.rows = 120
	p.cell = 32.0
	p.world = Vector2(200, 120) * 32.0
	p.island_on = true
	p.player_spawn = Vector2(0.12 * p.world.x, 0.5 * p.world.y)
	p.zone = Rect2(Vector2(0.86 * p.world.x, 0.5 * p.world.y) - Vector2(440, 230), Vector2(880, 460))
	p.spawns = PackedVector2Array([p.player_spawn])
	p.obstacle_count = 190
	p.patch_count = 120
	return p

func _digest(r: MapGen.Result) -> Array:
	var o := ""
	for e in r.obstacles:
		o += "%s,%s,%s,%s;" % [e["pos"], e["radius"], e["node"], e["region"]]
	var d := ""
	for e in r.deco:
		d += "%s,%s,%s;" % [e["pos"], e["set"], e["region"]]
	return [hash(r.land), hash(r.biome), hash(r.area), hash(r.ground), hash(r.f), hash(o), hash(d)]

func _init() -> void:
	var style: MapStyle = load("res://data/maps/grass.tres")
	# re-pinned for 2x tree_tries (trees + props digests); before: v5: copper off (copper_per_100 0, copper_near_home_cells 0): rocks + props digests; before: v3 water in MapGen.Params (fewer / bigger lakes + rivers, no ponds, water_min_cells): land, biome, area, ground, nodes, props;
	# before: v4 rocks off in the data (rock_per_block / rock_nodes_per_100 0, rock density_boss 0): rocks + props digests; before: one ground per colour (0047: every river / lake shore = sand, rocky without dirt clumps, gravel beach = sand: ground + props digests);
	# before: the copper rock look + fewer swamp reeds (rocks digest: copper has regions, plain rocks show grey looks; props digest: reeds); before: 0038 step 4 (per-biome trees, rock groups, deco passes, stone / dirt ground: the area, ground, rocks, trees and props changed on purpose);
	# earlier pin: water v2 (big rivers, big lakes + ponds, snow shore), before that step 3
	var pins := {11: [158471966, 2511943546, 616593949, 2941611565, 3903971691, 154562740, 548033731], 7: [3474702120, 3702374245, 3299497395, 4129484834, 3969305605, 257603024, 1415754846]}
	for sd in pins:
		var got := _digest(MapGen.generate(style, _params(), sd))
		print("digest seed %d = %s" % [sd, got])
		_check(got == pins[sd], "seed %d gives the same map as the pin (land, biome, area, ground, f, rocks + trees, props)" % sd)
	# the incremental walk grid (after land is dropped) equals a full recompute
	var p := _params()
	var res := MapGen.generate(style, p, 11)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var land := res.land.duplicate()
	var free := MapGen._walk_free(p, land)
	var changed := PackedInt32Array()
	while changed.size() < 200:
		var ci := rng.randi() % land.size()
		if land[ci] == 1:
			land[ci] = 0
			changed.append(ci)
	var delta := MapGen._walk_free_patch(p, land, free, changed)
	var full_n := PackedInt32Array([0])
	var full := MapGen._walk_free(p, land, full_n)
	_check(free == full, "walk grid patched after dropping land = recomputed from scratch")
	_check(MapGen._walk_free(p, res.land).size() == full.size() and delta <= 0, "patching only ever removes free samples (%d)" % delta)
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
