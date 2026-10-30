extends SceneTree
## The ground tiles the game really bakes (PixelPlainsBaker, all_flat): for each pair of grounds, the 16 corner masks
## (bit set = first ground: NW 1, NE 2, SW 4, SE 8). One strip PNG per pair; tools/pixel_plains_flat_tileset.py labels them.
##   godot --headless --script tools/pixel_plains_flat_tileset.gd -- <out_dir>
const PAIRS := [["D", "l"], ["l", "d"], ["l", "s"], ["l", "."], ["s", "."], ["n", "l"], ["n", "s"], ["n", "."], ["d", "s"], ["d", "."], ["D", "s"], ["D", "."]]

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var pp: PixelPlainsGround = (load("res://data/maps/grass.tres").pixel_plains as PixelPlainsGround).duplicate()
	pp.plain_weight = 1.0   # plain fills, so only the border shapes vary
	var style := MapStyle.new()
	style.pixel_plains = pp
	for p in PAIRS:
		var strip: Image = null
		for mask in 16:
			var rows := ["", ""]
			for k in 4:   # NW NE SW SE
				rows[k / 2] += p[0] if mask & (1 << k) else p[1]
			var b := GroundBaker.bake_region(_result(rows), style, 0, 0, 3, 3)
			var t: int = b["tile"]
			if strip == null:
				strip = Image.create_empty(16 * t, t, false, Image.FORMAT_RGBA8)
			strip.blit_rect(b["ground"], Rect2i(t, t, t, t), Vector2i(mask * t, 0))
		strip.save_png("%s/pair_%s_%s.png" % [out, _n(p[0]), _n(p[1])])
	print("done")
	quit()

func _n(c: String) -> String:
	return {"D": "darkgrass", "l": "grass", "d": "dirt", "s": "sand", ".": "water", "n": "snow"}[c]

func _result(rows: Array) -> MapGen.Result:
	var res := MapGen.Result.new()
	res.seed = 1
	res.rows = 2
	res.cols = 2
	for a in [res.ground, res.biome, res.shore]:
		a.resize(4)
	for i in 4:
		var c: String = rows[i / 2][i % 2]
		res.ground[i] = {".": MapGen.Ground.WATER, "d": MapGen.Ground.DIRT, "l": MapGen.Ground.GRASS, "D": MapGen.Ground.GRASS, "s": MapGen.Ground.SAND, "n": MapGen.Ground.SNOW}[c]
		res.biome[i] = {"D": MapGen.Biome.FOREST, "s": MapGen.Biome.BEACH_SAND, "n": MapGen.Biome.SNOWY}.get(c, MapGen.Biome.PLAINS)
		res.shore[i] = 0
	return res
