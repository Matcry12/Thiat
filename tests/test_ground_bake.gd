extends SceneTree
## Island ground bake (decision 0033) and seed stability.
##  1. No water cell shows land pixels at its centre, no land cell shows water at its centre (the picture follows the
##     collision grid at the waterline; looks must never promise land that is a wall).
##  2. A seed gives a pinned obstacle hash: any random draw added before _place_nodes changes it (and so the trees,
##     rocks and everything tests rely on).
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
	p.spawns = PackedVector2Array([p.player_spawn, p.zone.get_center(), p.player_spawn, p.player_spawn])
	p.obstacle_count = 190
	p.patch_count = 120
	return p

func _obstacle_hash(res: MapGen.Result) -> int:
	var s := ""
	for o in res.obstacles:
		s += "%d,%d,%d;" % [roundi(o["pos"].x), roundi(o["pos"].y), o["node"]]
	return s.hash()

func _init() -> void:
	var look := {"tint": [Color.WHITE, Color.WHITE, Color.WHITE] as Array[Color], "sat": [1.0, 1.0, 1.0], "shade_variation": 0.0, "shade_scale": 0.05}
	for path in ["res://data/maps/grass.tres"]:
		var style: MapStyle = load(path)
		for seed_v in [11, 7, 3]:
			var p := _params()
			var res := MapGen.generate(style, p, seed_v)
			var img: Image = GroundBaker.bake(res, style, look)["ground"]
			var bad_water := 0
			var bad_land := 0
			for y in p.rows:
				for x in p.cols:
					var a := img.get_pixel(x * 16 + 16, y * 16 + 16).a   # cell centre; the picture starts half a tile up and left
					if res.land[y * p.cols + x] == 0 and a > 0.0:
						bad_water += 1
					elif res.land[y * p.cols + x] == 1 and a == 0.0:
						bad_land += 1
			_check(bad_water == 0 and bad_land == 0, "%s seed %d: ground picture matches land / water at every cell centre (water showing land %d, land showing water %d)" % [path, seed_v, bad_water, bad_land])
	var style: MapStyle = load("res://data/maps/grass.tres")
	# saturation above 1 survives the tint map (alpha = sat * 127.5): autumn grass is 1.1 x the area's 1.0 -> 140, not clamped to 255 / 2
	var pr := _params()
	var tres := MapGen.generate(style, pr, 11)
	var timg := GroundBaker.tint_image(tres, look)
	var alpha := {}
	for i in tres.land.size():
		var inside := i % pr.cols > 0 and i % pr.cols < pr.cols - 1 and i / pr.cols > 0 and i / pr.cols < pr.rows - 1   # the tint map is blurred 3 x 3: read only cells whose neighbours are the same
		for d in [-pr.cols - 1, -pr.cols, -pr.cols + 1, -1, 1, pr.cols - 1, pr.cols, pr.cols + 1]:
			inside = inside and i + d >= 0 and i + d < tres.land.size() and tres.land[i + d] == 1 and tres.biome[i + d] == tres.biome[i] and tres.ground[i + d] == MapGen.Ground.GRASS and tres.area[i + d] != MapGen.Area.BOSS
		if inside and tres.land[i] == 1 and tres.area[i] != MapGen.Area.BOSS and tres.ground[i] == MapGen.Ground.GRASS:
			alpha[tres.biome[i]] = roundi(timg.get_pixel(i % pr.cols, i / pr.cols).a * 255.0)
	_check(alpha.has(MapGen.Biome.FOREST) and alpha.has(MapGen.Biome.AUTUMN) and absi(alpha[MapGen.Biome.FOREST] - 128) <= 1 and absi(alpha[MapGen.Biome.AUTUMN] - 140) <= 1, "tint saturation 0..2 is stored (forest %s, autumn %s)" % [alpha.get(MapGen.Biome.FOREST), alpha.get(MapGen.Biome.AUTUMN)])
	var pins := {11: 2304434224, 7: 335026835}   # re-pinned for 2x tree_tries; before: v5 (copper off); earlier pin: v3 water in MapGen.Params; earlier pin: v4 (rocks off in the data); earlier pin: 0038 step 4 (per-biome trees, rock groups); earlier pin: 0038 water v2 (big rivers / lakes, ponds); earlier pin: step 3 (continent shape, rivers, lakes, shallows); earlier pin for 0038 step 1
	for seed_v in pins:
		var h := _obstacle_hash(MapGen.generate(style, _params(), seed_v))
		print("obstacle hash seed %d = %d" % [seed_v, h])
		_check(h == pins[seed_v], "seed %d keeps its trees and rocks (hash %d)" % [seed_v, h])
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
