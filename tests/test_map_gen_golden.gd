extends SceneTree
# Golden hashes of the WHOLE MapGen.Result (every field except timings and the biome data objects) for fixed seeds, taken before
# map_gen.gd was split into one file per stage. A real change of the map re-pins them on purpose (run it, copy the printed lines).
var _ok := true

func _params(n: int, pp: bool) -> MapGen.Params:
	var p := MapGen.Params.new()
	p.cols = n
	p.rows = n
	p.cell = 32.0
	p.world = Vector2(n, n) * 32.0
	p.island_on = true
	p.player_spawn = Vector2(0.12 * p.world.x, 0.5 * p.world.y)
	p.zone = Rect2(Vector2(0.86 * p.world.x, 0.5 * p.world.y) - Vector2(440, 230), Vector2(880, 460))
	p.spawns = PackedVector2Array([p.player_spawn])
	p.obstacle_count = 190
	p.patch_count = 120
	if pp:
		p.pp = load("res://data/maps/grass.tres").pixel_plains
	return p

func _digest(r: MapGen.Result) -> int:
	var h := 0
	for prop in r.get_property_list():
		if not (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n: String = prop["name"]
		if n == "timings" or n == "biomes":
			continue
		h = hash([h, n, hash(var_to_bytes(r.get(n)))])
	return h

func _init() -> void:
	var style: MapStyle = load("res://data/maps/grass.tres")
	var pins := {"192_11": 3702684118, "192_7": 1259275694, "192_23": 2401112555, "512_11": 2863854119, "512_7": 3422073125, "512_23": 3729544517, "192flat_5": 3976740156}
	for key in pins:
		var parts: PackedStringArray = key.split("_")
		var p := _params(192 if parts[0].begins_with("192") else 512, true)
		if parts[0] == "192flat":
			p.island_on = false
			p.pp = null
		var got := _digest(MapGen.generate(style, p, int(parts[1])))
		print("golden %s = %d" % [key, got])
		var ok: bool = got == pins[key]
		print(("ok   " if ok else "FAIL ") + "map %s unchanged" % key)
		if not ok:
			_ok = false
	quit(0 if _ok else 1)
