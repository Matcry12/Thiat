extends SceneTree
## Pixel Plains ground (GroundBaker -> PixelPlainsBaker): (1) a fixed grid baked with plain-only fills equals the python reference
## render() pixel for pixel (tests/support/pixel_plains/ref.png, made by tools/asset_viewer/pixel_plains_test_ref.py);
## (2) pieces baked alone equal the same pixels of the whole picture (picture + foam), with the real fills (variants on);
## (3) pixel_plains = null still takes the old path; (4) pack pixels reach the screen: tint / shade maps are neutral;
## (5) ground tile set (0069): every border pixel comes from the pictures (edge slots, foam.png, water.png), chunk seams with sand, snow, water, foam masks.
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
	stepped.all_flat = false   # the pack's own pairs next to the stacked pictures: the harder seam case
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
	_check(_same(fm, whole["foam"]), "four pieces equal the whole animation mask (beach foam)")
	var foam_px := 0
	var wd: PackedByteArray = whole["foam"].get_data()
	for o in range(0, wd.size(), 4):
		foam_px += 1 if wd[o] == 1 else 0
	_check(foam_px > 0, "the seam grid has beach foam (%d px)" % foam_px)
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


func _slice2(pp: PixelPlainsGround) -> void:
	var M := PixelPlainsGround.Mat
	BiomeArt.get_default().enabled = false   # the base ground/ files are what the next checks redraw; the biome files come back below
	_check(pp.all_flat, "all_flat is the default")
	# ground sheets + foam / water pictures: set, right size (a redrawn picture must keep passing)
	var tsize := pp.texture.get_size()
	for sk in 7:
		var tex := pp.sheet_of(sk)
		_check(tex != null and tex.get_size() == tsize, "ground sheet %d is set and the size of tiles.png" % sk)
	var t := pp.tile_size
	_check(pp.foam_texture != null and pp.foam_texture.get_size() == Vector2(8 * 4 * t, 4 * t), "foam.png: 8 frames of 4x4 slots")
	_check(pp.water_texture != null and int(pp.water_texture.get_width()) == 8 * PixelPlainsBaker.MARK_BLOCK and (int(pp.water_texture.get_height()) - PixelPlainsBaker.WATER_TOP) % PixelPlainsBaker.MARK_BLOCK == 0, "water.png: flat strip + mark rows of 8 frames")
	var pal := PixelPlainsBaker.palette(pp, M.SAND)
	_check(pal.size() == 4 and pp.fill_of(M.SAND) != pp.outline_of(M.SAND) and pp.hl_of(M.SNOW).a > 0.0, "palette readable from the sheets' swatch")
	_check(pp.fill_of(M.WATER) == PixelPlainsBaker.water_colour(pp) and pp.fill_of(M.WATER) != Color(1, 0, 1), "water colour is pixel (0, 0) of water.png")
	# a redraw reaches the game: change one fill pixel of the sand sheet in memory, the baked sand cell changes
	var sand_res := _result(["ss", "ss"], 1)
	var before: Image = GroundBaker.bake_region(sand_res, _style(pp), 0, 0, 3, 3)["ground"]
	var red := pp.duplicate() as PixelPlainsGround
	var simg: Image = pp.sheet_sand.get_image().duplicate()
	simg.convert(Image.FORMAT_RGBA8)
	var cell: Vector2i = pp.plain_dirt[0]
	simg.set_pixel(cell.x * t + 3, cell.y * t + 3, Color8(1, 2, 3))
	red.sheet_sand = ImageTexture.create_from_image(simg)
	var after: Image = GroundBaker.bake_region(sand_res, _style(red), 0, 0, 3, 3)["ground"]
	_check(not _same(before, after), "a redrawn sand sheet changes the baked sand ground")
	# pixels come from the picture: paint one pixel of light slot 6 (NE + SW light) and of dirt slot 15 (the base) in memory
	var mixed := _result(["dl", "ld"], 1)   # corner tile (1, 1): NW dirt, NE light, SW light, SE dirt
	var plain_img: Image = GroundBaker.bake_region(mixed, _style(pp), 0, 0, 3, 3)["ground"].get_region(Rect2i(t, t, t, t))
	var limg: Image = pp.sheet_grass_light.get_image().duplicate()
	limg.convert(Image.FORMAT_RGBA8)
	var dimg: Image = pp.sheet_dirt.get_image().duplicate()
	dimg.convert(Image.FORMAT_RGBA8)
	var slot6 := Vector2i(2 * t, 2 * t)    # slot 6 = cell (2, 1 + 1)
	var base15 := Vector2i(3 * t, 4 * t)   # slot 15 = cell (3, 1 + 3)
	var on := Vector2i(-1, -1)
	var off := Vector2i(-1, -1)
	for y in t:
		for x in t:
			if limg.get_pixel(slot6.x + x, slot6.y + y).a8 > 0 and on.x < 0:
				on = Vector2i(x, y)
			if limg.get_pixel(slot6.x + x, slot6.y + y).a8 == 0 and off.x < 0:
				off = Vector2i(x, y)
	_check(on.x >= 0 and off.x >= 0, "light slot 6 has drawn and empty pixels")
	limg.set_pixelv(slot6 + on, Color8(1, 2, 3))
	dimg.set_pixelv(base15 + off, Color8(4, 5, 6))
	var edit := pp.duplicate() as PixelPlainsGround
	edit.sheet_grass_light = ImageTexture.create_from_image(limg)
	edit.sheet_dirt = ImageTexture.create_from_image(dimg)
	var painted: Image = GroundBaker.bake_region(mixed, _style(edit), 0, 0, 3, 3)["ground"].get_region(Rect2i(t, t, t, t))
	_check(painted.get_pixelv(on) == Color8(1, 2, 3), "a pixel painted in light slot 6 shows in the mask 6 corner")
	_check(painted.get_pixelv(off) == Color8(4, 5, 6), "a pixel painted in dirt slot 15 shows where the light edge is empty")
	_check(plain_img.get_pixelv(on) != Color8(1, 2, 3), "(the unpainted corner differs)")
	PixelPlainsBaker.clear_cache()   # the cache is keyed by instance id: forget the throwaway copies
	# beach corner: sand over water. land = sand slot alpha; drawn_land_at agrees; foam marks point at foam.png pixels
	var beach := _result(["ss", ".."], 1)   # corner tile (1, 1): sand NW + NE, water SW + SE = sand slot 3
	var c := PixelPlainsBaker._cache(pp)
	var key := Vector4i(M.SAND, M.SAND, M.WATER, M.WATER)
	var comp := PixelPlainsBaker._compose(c, key)
	var slot: PackedByteArray = PixelPlainsBaker._slot(c, M.SAND, 3).get_data()
	var land: PackedByteArray = comp["land"]
	var agree := true
	for p in t * t:
		agree = agree and (land[p] == 1) == (slot[p * 4 + 3] > 0)
		agree = agree and PixelPlainsBaker.drawn_land_at(beach, pp, Vector2i(t / 2 + p % t, t / 2 + p / t)) == (slot[p * 4 + 3] > 0)
	_check(agree, "beach corner: land and drawn_land_at agree with the alpha of the sand slot")
	var anim: PackedByteArray = (comp["anim"] as Image).get_data()
	var marks := 0
	var lit := 0
	for p in t * t:
		if anim[p * 4] != 1:
			continue
		marks += 1
		var any := false
		for f in 8:
			any = any or c.foam_pic.get_pixel(f * 64 + anim[p * 4 + 1], anim[p * 4 + 2]).a8 > 0
		lit += 1 if any else 0
		_check(slot[p * 4 + 3] > 0, "a foam pixel lies on a drawn sand pixel")
	_check(marks > 5 and lit == marks, "beach corner: %d foam pixels, all lit in some frame of foam.png" % marks)
	# a later layer clears the foam under it: dirt over the sand takes the foam pixels it draws
	var cd := PixelPlainsBaker._compose(c, Vector4i(M.SAND, M.DIRT, M.WATER, M.WATER))
	var dirt_slot: PackedByteArray = PixelPlainsBaker._slot(c, M.DIRT, 2).get_data()
	var anim2: PackedByteArray = (cd["anim"] as Image).get_data()
	var cleared := true
	for p in t * t:
		cleared = cleared and not (dirt_slot[p * 4 + 3] > 0 and anim2[p * 4] == 1)
	_check(cleared, "dirt over sand: no foam on a pixel the dirt edge draws")
	# per-biome ground: painting one pixel of FOREST's sand slot changes only corners whose sand cell is forest (the first cell holding sand)
	BiomeArt.get_default().enabled = true
	PixelPlainsBaker.clear_cache()
	var forest := MapGen.Biome.FOREST
	var spic := BiomeArt.ground_texture("sand", forest)
	_check(spic != null, "forest has its own sand sheet")
	var simg2: Image = spic.get_image().duplicate()
	simg2.convert(Image.FORMAT_RGBA8)
	var sp := Vector2i(-1, -1)   # a drawn pixel of sand slot 3
	for y in t:
		for x in t:
			if sp.x < 0 and simg2.get_pixel(3 * t + x, (1 + 0) * t + y).a8 > 0:
				sp = Vector2i(x, y)
	simg2.set_pixel(3 * t + sp.x, t + sp.y, Color8(7, 8, 9))   # slot 3 = cell (3, 1)
	BiomeArt.override(&"ground/sand", forest, ImageTexture.create_from_image(simg2))
	PixelPlainsBaker.clear_cache()
	var wet := _result(["ss", ".."], 1)
	wet.biome.fill(MapGen.Biome.PLAINS)
	var wet_forest := _result(["ss", ".."], 1)
	wet_forest.biome.fill(MapGen.Biome.FOREST)
	var px_plains: Image = GroundBaker.bake_region(wet, _style(pp), 0, 0, 3, 3)["ground"]
	var px_forest: Image = GroundBaker.bake_region(wet_forest, _style(pp), 0, 0, 3, 3)["ground"]
	_check(px_forest.get_pixel(t + sp.x, t + sp.y) == Color8(7, 8, 9), "a pixel painted in forest's sand slot 3 shows in a forest corner")
	_check(px_plains.get_pixel(t + sp.x, t + sp.y) != Color8(7, 8, 9), "the same corner in plains is unchanged")
	_check(not _same(px_plains, px_forest) and _same(px_plains.get_region(Rect2i(0, 0, t, t)), px_forest.get_region(Rect2i(0, 0, t, t))), "only the forest corner changed")
	BiomeArt.override(&"ground/sand", forest, null)
	BiomeArt.clear_cache()
	PixelPlainsBaker.clear_cache()
	_check(BiomeArt.get_default().status_text().contains("ground files loaded (of 9)"), "F3 status lists the biome ground files")
	# the F3 layers line
	_check(PixelPlainsBaker.corner_layers(pp, Vector4i(M.WATER, M.SAND, M.LIGHT, M.LIGHT)) == "water base | sand slot 14 + foam | light grass slot 12", "layers line: " + PixelPlainsBaker.corner_layers(pp, Vector4i(M.WATER, M.SAND, M.LIGHT, M.LIGHT)))
	_check(PixelPlainsBaker.corner_layers(pp, Vector4i(M.DIRT, M.DIRT, M.DIRT, M.DIRT)) == "dirt fill", "layers line of a single ground")
	# a missing foam / water picture warns and does not crash
	var nopic := pp.duplicate() as PixelPlainsGround
	nopic.foam_texture = null
	nopic.water_texture = null
	var np: Image = GroundBaker.bake_region(beach, _style(nopic), 0, 0, 3, 3)["ground"]
	_check(np.get_width() == 3 * t, "no foam / water picture: bake still runs")
	PixelPlainsBaker.clear_cache()
	# a baked case twice = same pixels (nothing random per call)
	var again := GroundCase.bake(GroundCase.CASES["mixed_coast"], pp)
	_check(_same(again["ground"], GroundCase.bake(GroundCase.CASES["mixed_coast"], pp)["ground"]), "a case bakes the same twice")
	# every mixed corner of the 6 grounds can be stacked, none half transparent
	var bad := 0
	for k in 1296:
		var kk := Vector4i(k % 6, (k / 6) % 6, (k / 36) % 6, (k / 216) % 6)
		var img: Image = PixelPlainsBaker._compose(c, kk)["img"]
		var d := img.get_data()
		for p in t * t:
			bad += 1 if d[p * 4 + 3] != 255 and not (kk.x == M.WATER and kk.y == M.WATER and kk.z == M.WATER and kk.w == M.WATER) else 0
	_check(bad == 0, "all mixed corners are opaque (%d pixels not)" % bad)
