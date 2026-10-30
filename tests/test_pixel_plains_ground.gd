extends SceneTree
## Pixel Plains ground (GroundBaker -> PixelPlainsBaker): (1) a fixed grid baked with plain-only fills equals the python reference
## render() pixel for pixel (tests/support/pixel_plains/ref.png, made by tools/asset_viewer/pixel_plains_test_ref.py);
## (2) pieces baked alone equal the same pixels of the whole picture (picture + foam), with the real fills (variants on);
## (3) pixel_plains = null still takes the old path; (4) pack pixels reach the screen: tint / shade maps are neutral;
## (5) slice 2 (0046): level rules + border kinds, forced step / flat / beach cases pixel by pixel, chunk seams with sand, snow, water, foam masks.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		print("FAIL " + msg)
		_ok = false

func _result(rows: Array, rng_seed: int) -> MapGen.Result:
	var res := MapGen.Result.new()
	res.seed = rng_seed
	res.rows = rows.size()
	res.cols = String(rows[0]).length()
	res.ground.resize(res.cols * res.rows)
	res.biome.resize(res.cols * res.rows)
	res.shore.resize(res.cols * res.rows)
	for y in res.rows:
		for x in res.cols:
			var c := String(rows[y])[x]
			var i := y * res.cols + x
			res.ground[i] = {".": MapGen.Ground.WATER, "d": MapGen.Ground.DIRT, "l": MapGen.Ground.GRASS, "D": MapGen.Ground.GRASS, "s": MapGen.Ground.SAND, "S": MapGen.Ground.SAND, "n": MapGen.Ground.SNOW}[c]
			res.biome[i] = {"D": MapGen.Biome.FOREST, "s": MapGen.Biome.BEACH_SAND, "n": MapGen.Biome.SNOWY}.get(c, MapGen.Biome.PLAINS)   # forest grass is dark, plains grass is light
			res.shore[i] = 1 if c == "S" else 0
	return res

func _style(pp: PixelPlainsGround) -> MapStyle:
	var s := MapStyle.new()
	s.pixel_plains = pp
	return s

func _same(a: Image, b: Image) -> bool:
	return a.get_size() == b.get_size() and a.get_data() == b.get_data()

func _init() -> void:
	var real: PixelPlainsGround = load("res://data/maps/grass.tres").pixel_plains
	_check(real != null, "grass.tres has pixel_plains")
	# (1) python reference
	var plain := real.duplicate() as PixelPlainsGround
	plain.plain_weight = 1.0
	plain.plain_light = [Vector2i(10, 7)] as Array[Vector2i]
	plain.all_flat = false   # the reference is the pack's own raised-edge pairs
	plain.dark_dirt_gap = 1   # the reference applies the dark-next-to-dirt rule
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/support/pixel_plains/grid.json"))["rows"]
	var res := _result(rows, 3)
	var out := GroundBaker.bake_region(res, _style(plain), 0, 0, res.cols + 1, res.rows + 1)
	var ref := Image.load_from_file(ProjectSettings.globalize_path("res://tests/support/pixel_plains/ref.png"))
	ref.convert(Image.FORMAT_RGBA8)
	var got: Image = out["ground"]
	_check(got.get_size() == ref.get_size(), "size %s vs reference %s" % [got.get_size(), ref.get_size()])
	if got.get_size() == ref.get_size():
		var bad := 0
		var compared := 0
		for ty in res.rows + 1:   # tiles with water in the corner changed in slice 2 (new water look): the reference is only for the pack's own pairs
			for tx in res.cols + 1:
				var wet := false
				for c in [Vector2i(tx - 1, ty - 1), Vector2i(tx, ty - 1), Vector2i(tx - 1, ty), Vector2i(tx, ty)]:
					wet = wet or c.x < 0 or c.y < 0 or c.x >= res.cols or c.y >= res.rows or res.ground[c.y * res.cols + c.x] == MapGen.Ground.WATER
				if wet:
					continue
				compared += 1
				for y in 16:
					for x in 16:
						if got.get_pixel(tx * 16 + x, ty * 16 + y) != ref.get_pixel(tx * 16 + x, ty * 16 + y):
							bad += 1
		_check(compared > 20, "reference compares %d dry tiles" % compared)
		_check(bad == 0, "%d pixels differ from the python reference" % bad)
	_check(out["foam"].get_format() == Image.FORMAT_RGBA8 and out["anim"], "foam is the RGBA animation mask")
	# all flat (0047): grass / dirt and dark / light grass corners lose the pack's outline, highlight and shadow
	var flat := real.duplicate() as PixelPlainsGround
	flat.plain_weight = 1.0
	var fc := _colours(GroundBaker.bake_region(res, _style(flat), 0, 0, res.cols + 1, res.rows + 1)["ground"])
	_check(not fc.has(_k(Color8(42, 89, 79))) and not fc.has(_k(Color8(189, 106, 98))) and not fc.has(_k(Color8(164, 196, 67))), "all flat: no pack outline / shadow / highlight left")
	# (2) chunk seams, real fills (variants), a bigger random grid with all materials
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var big: Array = []
	for y in 40:
		var r := ""
		for x in 44:
			var v := rng.randf()
			var blob := sin(x * 0.35) + cos(y * 0.3)
			var k := sin(x * 0.9 + y * 0.4) + cos(x * 0.2 - y * 0.7)
			r += "." if blob < -1.2 else ("d" if blob < -0.3 else ("s" if k > 1.2 else ("S" if k < -1.3 else ("n" if k > 0.7 and blob > 0.3 else ("l" if blob < 0.6 else "D")))))
		big.append(r)
	var res2 := _result(big, 11)
	var stepped := real.duplicate() as PixelPlainsGround
	stepped.all_flat = false   # levels on: steps + dashes are the harder seam case
	var style2 := _style(stepped)
	var tw := res2.cols + 1
	var th := res2.rows + 1
	var whole := GroundBaker.bake_region(res2, style2, 0, 0, tw, th)
	var t: int = whole["tile"]
	var pic := Image.create_empty(tw * t, th * t, false, Image.FORMAT_RGBA8)
	var fm := Image.create_empty(tw * t, th * t, false, Image.FORMAT_RGBA8)
	for cut in [[0, 0, 17, 13], [17, 0, tw - 17, 13], [0, 13, 17, th - 13], [17, 13, tw - 17, th - 13]]:
		var part := GroundBaker.bake_region(res2, style2, cut[0], cut[1], cut[2], cut[3])
		pic.blit_rect(part["ground"], Rect2i(Vector2i.ZERO, part["ground"].get_size()), Vector2i(cut[0], cut[1]) * t)
		fm.blit_rect(part["foam"], Rect2i(Vector2i.ZERO, part["foam"].get_size()), Vector2i(cut[0], cut[1]) * t)
	_check(_same(pic, whole["ground"]), "four pieces equal the whole ground picture")
	_check(_same(fm, whole["foam"]), "four pieces equal the whole animation mask (beach foam + dashes)")
	var kinds := [0, 0, 0]
	var wd: PackedByteArray = whole["foam"].get_data()
	for o in range(0, wd.size(), 4):
		kinds[mini(wd[o], 2) if wd[o] != 3 else 0] += 1
	_check(kinds[1] > 0 and kinds[2] > 0, "the seam grid has beach foam (%d px) and foam dashes (%d px)" % [kinds[1], kinds[2]])
	var shares := PixelPlainsBaker.shares(res2, real)
	_check(shares[3] > 0 and shares[4] > 0, "the seam grid has sand and snow %s" % [shares])
	# the map rule: a dark cell touching dirt is light grass
	var gap_pp := real.duplicate() as PixelPlainsGround
	gap_pp.dark_dirt_gap = 1   # the rule itself (off in the data since 0047: flat edges handle dark next to dirt)
	var mats := PixelPlainsBaker.cell_materials(_result(["...", "dD.", "..."], 1), gap_pp, 0, 0, 2, 2)
	_check(mats.count(PixelPlainsGround.Mat.DARK + 1) == 0, "dark next to dirt became light")
	# F3 edits must reach the map: a changed export emits `changed`
	var hits := [0]
	var probe := real.duplicate() as PixelPlainsGround
	probe.changed.connect(func(): hits[0] += 1)
	probe.dark_dirt_gap = 2
	probe.hide_trees = not probe.hide_trees
	_check(hits[0] == 2, "setting dark_dirt_gap / hide_trees emits changed (%d)" % hits[0])
	# (3) pixel_plains = null: the old baker still runs
	var old := load("res://data/maps/grass.tres").duplicate() as MapStyle
	old.pixel_plains = null
	var o := GroundBaker.bake_region(_result(["..", ".."], 1), old, 0, 0, 3, 3)
	_check(o["ground"].get_size() == Vector2i(48, 48), "old path still bakes")
	# (4) neutral look
	var tint := GroundBaker.tint_image_region(res2, {"neutral": true}, 0, 0, 4, 4)
	_check(tint.get_pixel(1, 1) == Color8(128, 128, 128, 128), "tint map neutral")
	_slice2(real)
	print("pixel plains ground: ", "PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)


## Every opaque colour of a baked case, as a Dictionary rgb-int -> pixel count.
func _colours(img: Image) -> Dictionary:   # the inner part: the ring of tiles at the grid edge borders the water off the map
	var out := {}
	var d := img.get_region(Rect2i(16, 16, img.get_width() - 32, img.get_height() - 32)).get_data()
	for o in range(0, d.size(), 4):
		if d[o + 3] != 0:
			var k := (d[o] << 16) | (d[o + 1] << 8) | d[o + 2]
			out[k] = out.get(k, 0) + 1
	return out


func _k(c: Color) -> int:
	return (c.r8 << 16) | (c.g8 << 8) | c.b8


func _kind_count(anim: Image, kind: int) -> int:
	var n := 0
	var d := anim.get_data()
	for o in range(0, d.size(), 4):
		if d[o] == kind:
			n += 1
	return n


func _slice2(flat_pp: PixelPlainsGround) -> void:
	# all flat (the default): every cell on one level, sand meets water with foam
	_check(flat_pp.all_flat, "all_flat is the default")
	var flat_res := _result(["..SSs", "l.snn", "dDlll"], 1)
	for y in flat_res.rows:
		for x in flat_res.cols:
			_check(PixelPlainsBaker.level_at(flat_res, flat_pp, x, y) == flat_pp.level_water, "all flat: one level everywhere")
	var pp := flat_pp.duplicate() as PixelPlainsGround
	pp.all_flat = false   # the level rules below
	# level -> border kind decisions
	var M := PixelPlainsGround.Mat
	_check(PixelPlainsBaker.border_kind(pp, M.LIGHT, 2, M.SAND, 1) == "step", "grass 2 over sand 1 = step")
	_check(PixelPlainsBaker.border_kind(pp, M.LIGHT, 2, M.SAND, 2) == "flat", "grass 2 next to sand 2 = flat")
	_check(PixelPlainsBaker.border_kind(pp, M.SAND, 0, M.NONE, 0) == "foam", "sand 0 next to water 0 = foam (flat beach)")
	_check(PixelPlainsBaker.border_kind(pp, M.SAND, 1, M.NONE, 0) == "step", "sand 1 over water 0 = step (bank)")
	_check(PixelPlainsBaker.border_kind(pp, M.SNOW, 3, M.LIGHT, 2) == "step" and PixelPlainsBaker.border_kind(pp, M.SNOW, 2, M.LIGHT, 2) == "flat", "snow: step at an edge, flat inside")
	_check(PixelPlainsBaker.border_kind(pp, M.LIGHT, 2, M.LIGHT, 3) == "", "same ground = no border")
	# level rules (the table of PixelPlainsGround "Levels") on a small real result
	var res := _result(["..SSs", "l.snn", "dDlll"], 1)   # row 1: grass, water, snow (edge), snow, snow ; row 2: dirt, dark, grass
	_check(PixelPlainsBaker.level_at(res, pp, 4, 0) == pp.level_beach_sand, "beach sand level")
	_check(PixelPlainsBaker.level_at(res, pp, 2, 0) == pp.level_bank_sand, "river-shore sand = bank level")
	res.biome[0 * 5 + 2] = MapGen.Biome.PLAINS
	_check(PixelPlainsBaker.level_at(res, pp, 0, 2) == pp.level_dirt and PixelPlainsBaker.level_at(res, pp, 2, 2) == pp.level_grass, "dirt and grass levels")
	_check(PixelPlainsBaker.level_at(res, pp, 3, 1) == pp.level_snow_edge, "snow next to a plains cell = edge level")
	_check(PixelPlainsBaker.level_at(res, pp, 4, 1) == pp.level_snow_edge or PixelPlainsBaker.level_at(res, pp, 4, 1) == pp.level_snow, "snow level is one of the two")
	_check(PixelPlainsBaker.level_at(res, pp, -1, 0) == pp.level_water, "off the map = water level")
	var inland := _result(["ll", "ls"], 1)
	inland.biome[3] = MapGen.Biome.PLAINS
	_check(PixelPlainsBaker.level_at(inland, pp, 1, 1) == pp.level_inland_sand, "sand outside the beach and shore = inland level")
	# forced cases, pixel by pixel
	var sand_fill := _k(pp.sand_fill)
	var sand_shade := _k(pp.sand_shade)
	var grass_outline := _k(pp.light_outline)
	var grass_fill := _k(pp.light_fill)
	var dim_grass := _k(Color8(int(pp.light_fill.r8 * (1.0 - pp.quiet_darken)), int(pp.light_fill.g8 * (1.0 - pp.quiet_darken)), int(pp.light_fill.b8 * (1.0 - pp.quiet_darken))))
	var step := GroundCase.bake(GroundCase.CASES["step_beach"], pp)
	var cs := _colours(step["ground"])
	_check(cs.has(grass_outline) and cs.has(sand_shade) and cs.has(sand_fill) and cs.has(grass_fill), "step beach: grass outline + shadow in the sand's shade")
	var flat := GroundCase.bake(GroundCase.CASES["flat_desert"], pp)
	var cf := _colours(flat["ground"])
	_check(not cf.has(grass_outline) and not cf.has(sand_shade) and cf.has(dim_grass), "flat desert: no outline, no shadow, quiet 8%% darker edge (%s)" % [cf.keys().size()])
	_check(cf.keys().size() == 3, "flat desert: only grass, sand and the quiet edge colour (got %d)" % cf.keys().size())
	var beach := GroundCase.bake(GroundCase.CASES["flat_beach"], pp)
	var cb := _colours(beach["ground"])
	_check(_kind_count(beach["foam"], 1) > 20 and _kind_count(beach["foam"], 2) == 0, "flat beach: foam px %d, no dashes" % _kind_count(beach["foam"], 1))
	_check(not cb.has(_k(pp.band_colour)) and not cb.has(_k(pp.sand_outline)) and not cb.has(_k(pp.water_shade)), "flat beach: no band, no sand outline, no water shadow")
	var bank := GroundCase.bake(GroundCase.CASES["sand_bank"], pp)
	var cbk := _colours(bank["ground"])
	_check(cbk.has(_k(pp.band_colour)) and cbk.has(_k(pp.water_shade)) and cbk.has(_k(pp.sand_outline)), "sand bank: band, water shadow, sand outline")
	_check(_kind_count(bank["foam"], 1) == 0 and _kind_count(bank["foam"], 2) > 0, "sand bank: no beach foam, foam dashes %d" % _kind_count(bank["foam"], 2))
	var snow := GroundCase.bake(GroundCase.CASES["snow_on_grass"], pp)
	var snow_flat := GroundCase.bake(GroundCase.CASES["snow_flat"], pp)
	_check(_colours(snow["ground"]).has(_k(pp.snow_outline)) and not _colours(snow_flat["ground"]).has(_k(pp.snow_outline)), "snow: outline only on the step")
	# the same case twice = same pixels (nothing random per call), and a baked tile is never half transparent
	var again := GroundCase.bake(GroundCase.CASES["mixed_coast"], pp)
	_check(_same(again["ground"], GroundCase.bake(GroundCase.CASES["mixed_coast"], pp)["ground"]), "a case bakes the same twice")
	# animation mirrors: beach foam moves 1 px per frame, 6 of 8 lit; a dash loop has 4 distinct states
	var lit := 0
	for x in 8:
		lit += 1 if PixelPlainsBaker.beach_lit(x, 0, 3, pp.beach_foam_lit, 8) else 0
	_check(lit == pp.beach_foam_lit, "beach foam: %d of 8 lit" % lit)
	_check(PixelPlainsBaker.beach_lit(5, 0, 0, 6, 8) == PixelPlainsBaker.beach_lit(6, 0, 1, 6, 8), "beach foam moves 1 px per frame")
	var states := {}
	for f in 8:
		var s := ""
		for j in 6:
			s += "1" if PixelPlainsBaker.dash_lit(j, 5, 0, f) else "0"
		states[s] = true
	_check(states.size() == 4, "a foam dash cycles through 4 shapes (%d)" % states.size())
