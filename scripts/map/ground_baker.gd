class_name GroundBaker
extends RefCounted
## Entry point for the island ground pictures (decision 0033): the pictures come from PixelPlainsBaker (the pack's own tiles, dual grid:
## one display tile per cell CORNER), per chunk through bake_region(); this file also makes the per-cell tint / shade / biome / world-map pictures.
## The old GroundData baker (its seam test is in assets/retired/tests/) was retired with its art.

## Art pixels per tile (cell) of the island grounds.
static func tile_of(style: MapStyle) -> int:
	return style.pixel_plains.tile_size


## Forget the cached pieces (a style changed).
static func clear_cache() -> void:
	PixelPlainsBaker.clear_cache()


static func _hash(x: int, y: int, s: int) -> int:
	return ((x * 73856093) ^ (y * 19349663) ^ (s * 83492791)) & 0x7fffffff


## look: {tint: Array[Color] per Area (brightness already applied), sat: Array[float] per Area, shade_variation, shade_scale}
## Returns {ground: Image (RGBA8, (cols+1) x (rows+1) tiles: draw it half a tile up and left), foam: Image (L8, same),
## tint: Image (RGBA8, cols x rows), shade: Image (RGB8, cols x rows), tile: int}
static func bake(res: MapGen.Result, style: MapStyle, look: Dictionary) -> Dictionary:
	var out := bake_region(res, style, 0, 0, res.cols + 1, res.rows + 1)
	out["tint"] = tint_image(res, look)
	out["shade"] = shade_image(res, look)
	return out


## One piece of the ground picture (0038 step 2, chunks): the corner tiles i in [ci0, ci0 + tiles_w), j in [cj0, cj0 + tiles_h).
## The whole map is ci0 = cj0 = 0, tiles (cols + 1, rows + 1). Returns {ground, foam, tile}: pictures of tiles_w * tile x tiles_h * tile
## pixels. Tile (i, j) is drawn at (i * tile - tile / 2, j * tile - tile / 2) art pixels. A corner looks at the four cells around it,
## so the piece needs the cells one step out (the ground array outside the map counts as water): neighbours join up pixel for pixel,
## and a piece baked alone equals the same pixels of the whole picture.
static func bake_region(res: MapGen.Result, style: MapStyle, ci0: int, cj0: int, tiles_w: int, tiles_h: int) -> Dictionary:
	return PixelPlainsBaker.bake_region(res, style.pixel_plains, ci0, cj0, tiles_w, tiles_h)


## One pixel per cell, NEAREST filtered: the area tint x the biome's own tint (x2 encoded, so brighter than 1 fits) and in alpha its saturation (x2 too: 0..2).
## Crisp on purpose: a tint must not smear over the border into the next area.
static func tint_image(res: MapGen.Result, look: Dictionary) -> Image:
	return tint_image_region(res, look, 0, 0, res.cols, res.rows)


## The same for the cells [cx, cx + w) x [cy, cy + h); a cell outside the map takes its nearest cell (a chunk's maps reach one cell out).
static func tint_image_region(res: MapGen.Result, look: Dictionary, cx: int, cy: int, w: int, h: int) -> Image:
	if look.get("neutral", false):   # Pixel Plains: the pack's pixels as they are (the shader skips the maps too)
		var one := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		one.fill(Color8(128, 128, 128, 128))
		return one
	var tints: Array = look["tint"]
	var sats: Array = look["sat"]
	var biome_tint: Array[Color] = []   # per biome id: its own tint and saturation, looked up once
	var biome_sat: Array[float] = []
	for b in res.biomes:
		biome_tint.append(b.tint_color())
		biome_sat.append(b.tint_sat)
	# per cell (the region plus one cell all round): colour x2 and saturation x2; then a 3 x 3 average, so a biome change (swamp | forest) fades over ~3 cells
	# instead of one hard step. It reads the global cells, so a chunk picture equals the same pixels of the whole-map picture.
	var vw := w + 2
	var vals := PackedFloat32Array()
	vals.resize(vw * (h + 2) * 4)
	var o := 0
	for y in h + 2:
		var row := clampi(cy + y - 1, 0, res.rows - 1) * res.cols
		for x in vw:
			var i := row + clampi(cx + x - 1, 0, res.cols - 1)
			# the tint follows the SMOOTHED ground (same cells the tiles use), so a stray gameplay-area cell does not show
			var a: int = res.area[i]
			match res.ground[i]:
				MapGen.Ground.GRASS:
					a = MapGen.Area.FOREST
				MapGen.Ground.COBBLE:
					a = MapGen.Area.ROCKY
				MapGen.Ground.BOSS:
					a = MapGen.Area.BOSS
				MapGen.Ground.SAND, MapGen.Ground.SNOW:
					a = -1   # their own pictures: no area colour, only the biome's own tint
			var base := Color.WHITE
			var sat := 1.0
			if a >= 0:
				base = tints[a]
				sat = sats[a]
			if not res.biomes.is_empty() and a != MapGen.Area.BOSS:   # the biome's own tint (BiomeData), on top
				var bi: int = res.biome[i]
				if res.ground[i] == MapGen.Ground.SAND and not res.shore.is_empty() and res.shore[i] == 1:
					bi = MapGen.Biome.BEACH_SAND   # shore sand around a river / lake looks like the beach sand, not like the biome's tint
				base *= biome_tint[bi]
				sat *= biome_sat[bi]
			vals[o] = base.r
			vals[o + 1] = base.g
			vals[o + 2] = base.b
			vals[o + 3] = sat
			o += 4
	var data := PackedByteArray()
	data.resize(w * h * 4)
	o = 0
	for y in h:
		for x in w:
			var acc := Vector4.ZERO
			for dy in 3:
				for dx in 3:
					var k := ((y + dy) * vw + x + dx) * 4
					acc += Vector4(vals[k], vals[k + 1], vals[k + 2], vals[k + 3])
			acc /= 9.0
			data[o] = clampi(roundi(acc.x * 127.5), 0, 255)
			data[o + 1] = clampi(roundi(acc.y * 127.5), 0, 255)
			data[o + 2] = clampi(roundi(acc.z * 127.5), 0, 255)
			data[o + 3] = clampi(roundi(acc.w * 127.5), 0, 255)   # saturation x2 encoded like the colour: 0..2
			o += 4
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)


## One pixel per cell: the biome colour (BiomeData.map_color), opaque; water clear. Shown by ArenaMap as the F3 biome map, with its own alpha.
static func biome_image(res: MapGen.Result) -> Image:
	var data := PackedByteArray()
	data.resize(res.cols * res.rows * 4)
	for i in res.cols * res.rows:
		if res.land[i] == 1:
			var c: Color = res.biomes[res.biome[i]].map_color
			data[i * 4] = c.r8
			data[i * 4 + 1] = c.g8
			data[i * 4 + 2] = c.b8
			data[i * 4 + 3] = 255
	return Image.create_from_data(res.cols, res.rows, false, Image.FORMAT_RGBA8, data)


## F3 World map (debug): one pixel per cell, the whole island. Land = BiomeData.map_color, river / lake / coast shallows / deep ocean in blues.
const MAP_OCEAN := Color(0.11, 0.24, 0.51)
const MAP_SHALLOW := Color(0.22, 0.45, 0.72)
const MAP_RIVER := Color(0.29, 0.59, 0.88)
const MAP_LAKE := Color(0.38, 0.75, 0.93)

static func world_map_image(res: MapGen.Result) -> Image:
	var data := PackedByteArray()
	var n := res.cols * res.rows
	data.resize(n * 4)
	var has_shallow := not res.shallow.is_empty()
	for i in n:
		var c := MAP_OCEAN
		if res.land[i] == 1:
			c = res.biomes[res.biome[i]].map_color if not res.biome.is_empty() else Color(0.5, 0.7, 0.4)
		elif has_shallow and res.shallow[i] == 1:
			c = MAP_RIVER if res.fresh[i] == 1 else (MAP_LAKE if res.fresh[i] == 2 else MAP_SHALLOW)
		data[i * 4] = c.r8
		data[i * 4 + 1] = c.g8
		data[i * 4 + 2] = c.b8
		data[i * 4 + 3] = 255
	return Image.create_from_data(res.cols, res.rows, false, Image.FORMAT_RGBA8, data)


## One pixel per cell, LINEAR filtered: soft light and dark patches (x2 encoded grey).
static func shade_image(res: MapGen.Result, look: Dictionary) -> Image:
	return shade_image_region(res, look, 0, 0, res.cols, res.rows)


## The same for the cells [cx, cx + w) x [cy, cy + h). The noise is a function of the cell, so a piece matches the whole map's pixels.
static func shade_image_region(res: MapGen.Result, look: Dictionary, cx: int, cy: int, w: int, h: int) -> Image:
	if look.get("neutral", false):
		var one := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
		one.fill(Color8(128, 128, 128))
		return one
	var var_amount: float = look["shade_variation"]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = res.seed + 77
	noise.frequency = look["shade_scale"]
	var fine := FastNoiseLite.new()
	fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fine.seed = res.seed + 78
	fine.frequency = look["shade_scale"] * 3.1
	var data := PackedByteArray()
	data.resize(w * h * 3)
	var i := 0
	for y in h:
		var gy := clampi(cy + y, 0, res.rows - 1)
		for x in w:
			var gx := clampi(cx + x, 0, res.cols - 1)
			var v := clampi(roundi((1.0 + var_amount * (noise.get_noise_2d(gx, gy) * 0.75 + fine.get_noise_2d(gx, gy) * 0.45)) * 127.5), 0, 255)
			data[i] = v
			data[i + 1] = v
			data[i + 2] = v
			i += 3
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, data)
