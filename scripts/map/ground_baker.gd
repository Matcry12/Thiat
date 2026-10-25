class_name GroundBaker
extends RefCounted
## Bakes the island ground (MapGen.Result.ground) into ONE picture, so the map is a few big sprites instead of
## 20 000 tiles (decision 0033). Method: DUAL GRID / marching squares.
##   - Display tiles sit on the cell CORNERS: tile (i, j) covers the corner shared by cells (i-1,j-1) (i,j-1) (i-1,j) (i,j),
##     so the picture is one tile bigger than the map and is drawn half a tile up and left.
##   - Ground is in layers (GroundData.layer: dirt 1, sand 2, cobble 3, snow 4, grass 5). For a layer, each of the 4 cells is "in" if its
##     ground has layer >= this one. The 4 bits (NW 1, NE 2, SW 4, SE 8) pick one of 16 pieces.
##   - The 16 pieces are built from ONE straight edge picture of the pack (GroundData.edge_window), made mirror
##     symmetric so its left and right borders match; half planes are rotations of it, one quadrant = AND of two
##     half planes, three quadrants = OR of two, the two diagonal cases = OR of two ANDs. Seams match by construction
##     (tests/test_ground_seams.gd checks it on the pixels).
## Water is layer 0 (transparent): the lowest ground's edge is the shoreline; a foam mask is baked from it.
## Nothing here knows a tile coordinate: it all comes from GroundData resources.

## Cached per GroundData (instance id).
static var _layers := {}

const NW := 1
const NE := 2
const SW := 4
const SE := 8
const TOP := 3
const BOTTOM := 12
const LEFT := 5
const RIGHT := 10


class Layer:
	var data: GroundData
	var tile := 16
	var fills: Array[Image] = []   ## fill index * 4 + flip (none, x, y, xy)
	var halves := {}               ## TOP / RIGHT / BOTTOM / LEFT -> Image: this ground in that half
	var cases := {}                ## q (1..14) -> {tile: Image, foam: Image}, built on first use


static func _layer(data: GroundData) -> Layer:
	var key := data.get_instance_id()
	if _layers.has(key):
		return _layers[key]
	var l := Layer.new()
	l.data = data
	l.tile = data.tile_size
	var t := l.tile
	var sheet := data.texture.get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	for f in data.fills:
		var img := sheet.get_region(Rect2i(f.x * t, f.y * t, t, t))
		if data.fill_scrub_green:
			img = _scrub_green(img, t)
		l.fills.append(img)
		var fx := img.duplicate() as Image
		fx.flip_x()
		l.fills.append(fx)
		var fy := img.duplicate() as Image
		fy.flip_y()
		l.fills.append(fy)
		var fxy := fx.duplicate() as Image
		fxy.flip_y()
		l.fills.append(fxy)
	var top := _edge_picture(data, l.fills)
	if data.bright != 1.0 or data.warm != 0.0 or data.sat != 1.0:
		for k in l.fills.size():
			l.fills[k] = _tint_pixels(l.fills[k], data, t)
		top = _tint_pixels(top, data, t)
	var right := top.duplicate() as Image
	right.rotate_90(CLOCKWISE)
	var bottom := top.duplicate() as Image
	bottom.flip_y()
	var left := top.duplicate() as Image
	left.rotate_90(COUNTERCLOCKWISE)
	l.halves = {TOP: top, RIGHT: right, BOTTOM: bottom, LEFT: left}
	_layers[key] = l
	return l


## Brightness / warm / saturation of a ground's own pixels (GroundData.bright, warm, sat). Alpha is kept.
static func _tint_pixels(img: Image, data: GroundData, t: int) -> Image:
	var d := img.get_data()
	var mul := Vector3(data.bright * (1.0 + data.warm), data.bright, data.bright * (1.0 - data.warm))
	for i in t * t:
		var o := i * 4
		var lum := 0.299 * d[o] + 0.587 * d[o + 1] + 0.114 * d[o + 2]
		d[o] = clampi(roundi(lerpf(lum, d[o], data.sat) * mul.x), 0, 255)
		d[o + 1] = clampi(roundi(lerpf(lum, d[o + 1], data.sat) * mul.y), 0, 255)
		d[o + 2] = clampi(roundi(lerpf(lum, d[o + 2], data.sat) * mul.z), 0, 255)
	return Image.create_from_data(t, t, false, Image.FORMAT_RGBA8, d)


static func _scrub_green(img: Image, t: int) -> Image:
	var d := img.get_data()
	var counts := {}
	for i in t * t:
		var c := Color8(d[i * 4], d[i * 4 + 1], d[i * 4 + 2])
		counts[c] = counts.get(c, 0) + 1
	var best := Color.BLACK
	var n := 0
	for c in counts:
		if counts[c] > n:
			n = counts[c]
			best = c
	for i in t * t:
		if int(d[i * 4 + 1]) > int(d[i * 4]) + 8:
			d[i * 4] = best.r8
			d[i * 4 + 1] = best.g8
			d[i * 4 + 2] = best.b8
	return Image.create_from_data(t, t, false, Image.FORMAT_RGBA8, d)


## The straight edge: this ground above, something else below, border at row 8, mirror symmetric (column x = column 15 - x).
static func _edge_picture(data: GroundData, fills: Array[Image]) -> Image:
	var t := data.tile_size
	var sheet := (data.edge_texture if data.edge_texture else data.texture).get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	var w := sheet.get_region(data.edge_window)
	var d := w.get_data()
	if data.edge_key == 1:
		for i in t * t:
			d[i * 4 + 3] = 255 if int(d[i * 4 + 1]) > int(d[i * 4]) + 8 else 0
	for y in t:
		for x in t / 2:
			var a := (y * t + x) * 4
			var b := (y * t + t - 1 - x) * 4
			for c in 4:
				d[b + c] = d[a + c]
	var out := Image.create_from_data(t, t, false, Image.FORMAT_RGBA8, d)
	if data.edge_from_fills and not fills.is_empty():
		out = _recolor(out, fills[0], data.rim_darken, t)
	return out


## One of the 16 pieces (q = 1..14) for a layer. q 15 = a full fill, 0 = nothing (the caller handles both).
static func piece(l: Layer, q: int) -> Dictionary:
	if l.cases.has(q):
		return l.cases[q]
	var h: Dictionary = l.halves
	var t: Image
	match q:
		TOP, BOTTOM, LEFT, RIGHT:
			t = h[q]
		NW:
			t = _and(h[TOP], h[LEFT])
			_cut(t, 7, 7, l.data.corner_cut)
		NE:
			t = _and(h[TOP], h[RIGHT])
			_cut(t, 8, 7, l.data.corner_cut)
		SW:
			t = _and(h[BOTTOM], h[LEFT])
			_cut(t, 7, 8, l.data.corner_cut)
		SE:
			t = _and(h[BOTTOM], h[RIGHT])
			_cut(t, 8, 8, l.data.corner_cut)
		14:   # all but NW
			t = _or(h[BOTTOM], h[RIGHT])
		13:   # all but NE
			t = _or(h[BOTTOM], h[LEFT])
		11:   # all but SW
			t = _or(h[TOP], h[RIGHT])
		7:    # all but SE
			t = _or(h[TOP], h[LEFT])
		9:    # NW + SE
			t = _or(_and(h[TOP], h[LEFT]), _and(h[BOTTOM], h[RIGHT]))
		6:    # NE + SW
			t = _or(_and(h[TOP], h[RIGHT]), _and(h[BOTTOM], h[LEFT]))
	var out := {"tile": t, "foam": _foam(t, l.tile)}
	l.cases[q] = out
	return out


## The fill tile images of a ground (tests: a dirt fill must hold no grass).
static func fill_images(data: GroundData) -> Array[Image]:
	return _layer(data).fills


## The pixels of a layer's piece for tests: 15 is fully opaque, 0 fully transparent.
static func config_tile(data: GroundData, q: int) -> Image:
	var l := _layer(data)
	if q == 0:
		return Image.create_empty(l.tile, l.tile, false, Image.FORMAT_RGBA8)
	if q == 15:
		var full := Image.create_empty(l.tile, l.tile, false, Image.FORMAT_RGBA8)
		full.fill(Color.WHITE)
		return full
	return piece(l, q)["tile"]


## Alpha AND: opaque only where both are; the smaller alpha wins (rims survive), colour from the more transparent one.
static func _and(a: Image, b: Image) -> Image:
	var da := a.get_data()
	var db := b.get_data()
	var out := PackedByteArray()
	out.resize(da.size())
	for o in range(0, da.size(), 4):
		var aa := da[o + 3]
		var ab := db[o + 3]
		if aa == 0 or ab == 0:
			continue
		var from := da if aa <= ab else db
		out[o] = from[o]
		out[o + 1] = from[o + 1]
		out[o + 2] = from[o + 2]
		out[o + 3] = mini(aa, ab)
	return Image.create_from_data(a.get_width(), a.get_height(), false, Image.FORMAT_RGBA8, out)


## Alpha OR: the larger alpha wins, colour from that one.
static func _or(a: Image, b: Image) -> Image:
	var da := a.get_data()
	var db := b.get_data()
	var out := PackedByteArray()
	out.resize(da.size())
	for o in range(0, da.size(), 4):
		var from := da if da[o + 3] >= db[o + 3] else db
		out[o] = from[o]
		out[o + 1] = from[o + 1]
		out[o + 2] = from[o + 2]
		out[o + 3] = from[o + 3]
	return Image.create_from_data(a.get_width(), a.get_height(), false, Image.FORMAT_RGBA8, out)


## Rounds the sharp corner of a one-quadrant piece: clears pixels within `cut` (diamond) of the corner point, and the
## stray semi-transparent rim specks the AND leaves around it.
static func _cut(img: Image, cx: int, cy: int, cut: int) -> void:
	for y in range(maxi(cy - cut - 2, 0), mini(cy + cut + 3, img.get_height())):
		for x in range(maxi(cx - cut - 2, 0), mini(cx + cut + 3, img.get_width())):
			var d := absi(x - cx) + absi(y - cy)
			var a := img.get_pixel(x, y).a
			if d < cut or (a < 0.99 and d < cut + 4):
				img.set_pixel(x, y, Color(0, 0, 0, 0))


## Art pixels per tile (cell) of the island grounds.
static func tile_of(style: MapStyle) -> int:
	return style.grounds[MapGen.Ground.GRASS].tile_size


## Forget the cached pieces (a style changed).
static func clear_cache() -> void:
	_layers.clear()
	_discs.clear()


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
	var cols := res.cols
	var rows := res.rows
	var by_ground: Array[Layer] = []
	var by_layer := {}
	var layer_of := PackedByteArray()
	for gi in style.grounds.size():
		var d := style.grounds[gi]
		if d == null:
			by_ground.append(null)
			layer_of.append(0)
			continue
		var l := _layer(d)
		by_ground.append(l)
		layer_of.append(d.layer)
		if not by_layer.has(d.layer):
			by_layer[d.layer] = l
	var t := by_ground[MapGen.Ground.GRASS].tile
	var img := Image.create_empty(tiles_w * t, tiles_h * t, false, Image.FORMAT_RGBA8)
	var foam := Image.create_empty(tiles_w * t, tiles_h * t, false, Image.FORMAT_L8)
	var tile_rect := Rect2i(0, 0, t, t)
	# the cells this piece looks at: x in [ci0 - 1, ci0 + tiles_w - 1], y likewise; water outside the map
	var L := PackedByteArray()   # layer per cell
	var G := PackedByteArray()   # ground id per cell, same window
	var pw := tiles_w + 1
	L.resize(pw * (tiles_h + 1))
	G.resize(pw * (tiles_h + 1))
	for ly in tiles_h + 1:
		var y := cj0 - 1 + ly
		if y < 0 or y >= rows:
			continue
		for lx in range(maxi(1 - ci0, 0), mini(cols - ci0 + 1, pw)):   # cells x = ci0 - 1 + lx inside [0, cols)
			var gid := res.ground[y * cols + ci0 - 1 + lx]
			G[ly * pw + lx] = gid
			L[ly * pw + lx] = layer_of[gid]
	for j in tiles_h:
		for i in tiles_w:
			var p0 := j * pw + i   # the cell up-left of this corner
			var l0 := L[p0]
			var l1 := L[p0 + 1]
			var l2 := L[p0 + pw]
			var l3 := L[p0 + pw + 1]
			if l0 == l1 and l1 == l2 and l2 == l3:   # all four cells on one layer (most corners): one fill tile, no edge pieces
				if l0 != 0:
					var fl: Layer = by_ground[G[p0]]
					var fh := _hash(ci0 + i, cj0 + j, res.seed + l0)
					img.blit_rect(fl.fills[(fh % (fl.fills.size() / 4)) * 4 + ((fh >> 8) & 3)], tile_rect, Vector2i(i * t, j * t))
				continue
			var cells := [p0, p0 + 1, p0 + pw, p0 + pw + 1]   # NW NE SW SE
			var mx := maxi(maxi(l0, l1), maxi(l2, l3))
			if mx == 0:
				continue
			var mn := mini(mini(l0, l1), mini(l2, l3))
			var present := (1 << l0) | (1 << l1) | (1 << l2) | (1 << l3)
			# lowest real ground here; everything under a full higher layer is hidden, so start there
			var lo := 1
			while not (present >> lo) & 1:
				lo += 1
			var start := lo
			for lay in range(mx, lo - 1, -1):
				if mn >= lay and (present >> lay) & 1:
					start = lay
					break
			var dst := Vector2i(i * t, j * t)
			var gi := ci0 + i   # the corner in the whole map: the fill picks and flips depend on it, not on the piece
			var gj := cj0 + j
			for lay in range(start, mx + 1):
				if not (present >> lay) & 1:
					continue
				var layer: Layer = by_layer.get(lay)
				for c in cells:   # a cell that stands on this layer decides whose picture (forest vs boss grass)
					if L[c] == lay:
						layer = by_ground[G[c]]
						break
				var q := int(l0 >= lay) | (int(l1 >= lay) << 1) | (int(l2 >= lay) << 2) | (int(l3 >= lay) << 3)
				if q == 15:
					var h := _hash(gi, gj, res.seed + lay)
					img.blit_rect(layer.fills[(h % (layer.fills.size() / 4)) * 4 + ((h >> 8) & 3)], tile_rect, dst)
				else:
					var pc := piece(layer, q)
					img.blend_rect(pc["tile"], tile_rect, dst)
					if lay == lo and mn == 0:
						foam.blit_rect(pc["foam"], tile_rect, dst)
	_paint_stamps(img, res, by_ground[MapGen.Ground.DIRT], Vector2i(ci0 * t, cj0 * t))
	return {"ground": img, "foam": foam, "tile": t}


## Dirt stamps (patches, camp, paths) painted as smooth discs over the tiles. Three passes over ALL stamps so the
## outline only shows around the union, never inside it: a wide light rim, a narrow dark rim, then the dirt.
static func _paint_stamps(img: Image, res: MapGen.Result, layer: Layer, origin := Vector2i.ZERO) -> void:
	if res.dirt_stamps.is_empty() or layer == null or layer.fills.is_empty():
		return
	var k := float(layer.tile) / res.cell   # art px per world px
	var half := layer.tile / 2               # the dual-grid picture starts half a tile up and left
	var bounds := Rect2i(origin, img.get_size())
	var mine: Array[Vector3] = []            # only the stamps that reach this picture (a chunk sees a few of them)
	for st in res.dirt_stamps:
		var reach := roundi(st.z * k) + 3
		if bounds.grow(reach).has_point(Vector2i(roundi(st.x * k) + half, roundi(st.y * k) + half)):
			mine.append(st)
	for pass_i in 3:
		for st in mine:
			var r := roundi(st.z * k)
			var grow := 2 - pass_i             # 2, 1, 0 px beyond the dirt
			var d := _disc(layer, r + grow, [0.82, 0.62, 1.0][pass_i])
			img.blend_rect(d, Rect2i(0, 0, d.get_width(), d.get_height()), Vector2i(roundi(st.x * k) + half - r - grow, roundi(st.y * k) + half - r - grow) - origin)


## Discs by (ground, radius, shade): a disc is the same wherever it is drawn.
static var _discs := {}


static func _disc(layer: Layer, radius: int, shade: float) -> Image:
	var key := Vector3i(layer.data.get_instance_id() & 0x7fffffff, radius, int(shade * 1000.0))
	if _discs.has(key):
		return _discs[key]
	var made := _make_disc(layer, radius, shade)
	_discs[key] = made
	return made


static func _make_disc(layer: Layer, radius: int, shade: float) -> Image:
	var size := radius * 2 + 1
	var t := layer.tile
	var fill := layer.fills[0].get_data()
	var out := PackedByteArray()
	out.resize(size * size * 4)
	for y in size:
		for x in size:
			var dx := x - radius
			var dy := y - radius
			var jitter := (float(_hash(x, y, radius) % 100) / 100.0 - 0.5) * 0.9
			if sqrt(float(dx * dx + dy * dy)) > radius + jitter:
				continue
			var o := (y * size + x) * 4
			var f := ((y % t) * t + (x % t)) * 4
			out[o] = int(fill[f] * shade)
			out[o + 1] = int(fill[f + 1] * shade)
			out[o + 2] = int(fill[f + 2] * shade)
			out[o + 3] = 255
	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, out)


## A frame piece's SHAPE with another tile's colours: opaque pixels take `fill`, the ones beside the edge are
## darkened (an outline), the frame's own semi-transparent rim pixels stay as they are.
static func _recolor(frame: Image, fill: Image, darken: float, t: int) -> Image:
	var f := frame.get_data()
	var c := fill.get_data()
	var out := f.duplicate()
	for py in t:
		for px in t:
			var o := (py * t + px) * 4
			if f[o + 3] != 255:
				continue
			var edge := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var qx: int = px + d.x
				var qy: int = py + d.y
				if qx >= 0 and qy >= 0 and qx < t and qy < t and f[(qy * t + qx) * 4 + 3] != 255:
					edge = true
			var k := darken if edge else 1.0
			out[o] = int(c[o] * k)
			out[o + 1] = int(c[o + 1] * k)
			out[o + 2] = int(c[o + 2] * k)
	return Image.create_from_data(t, t, false, Image.FORMAT_RGBA8, out)


## Foam: the transparent pixels touching the piece (full strength) and the ring beyond them (about 40%).
static func _foam(tile: Image, t: int) -> Image:
	var a := tile.get_data()
	var out := PackedByteArray()
	out.resize(t * t)
	for py in t:
		for px in t:
			var o := py * t + px
			if a[o * 4 + 3] != 0:
				continue
			var near := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var qx: int = px + d.x
				var qy: int = py + d.y
				if qx >= 0 and qy >= 0 and qx < t and qy < t and a[(qy * t + qx) * 4 + 3] != 0:
					near = 1
					break
			if near == 1:
				out[o] = 255
	var ring := out.duplicate()
	for py in t:
		for px in t:
			var o := py * t + px
			if out[o] == 255 or a[o * 4 + 3] != 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var qx: int = px + d.x
				var qy: int = py + d.y
				if qx >= 0 and qy >= 0 and qx < t and qy < t and out[qy * t + qx] == 255:
					ring[o] = 100
					break
	return Image.create_from_data(t, t, false, Image.FORMAT_L8, ring)


## One pixel per cell, NEAREST filtered: the area tint x the biome's own tint (x2 encoded, so brighter than 1 fits) and in alpha its saturation (x2 too: 0..2).
## Crisp on purpose: a tint must not smear over the border into the next area.
static func tint_image(res: MapGen.Result, look: Dictionary) -> Image:
	return tint_image_region(res, look, 0, 0, res.cols, res.rows)


## The same for the cells [cx, cx + w) x [cy, cy + h); a cell outside the map takes its nearest cell (a chunk's maps reach one cell out).
static func tint_image_region(res: MapGen.Result, look: Dictionary, cx: int, cy: int, w: int, h: int) -> Image:
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


## A small repeating water picture (tiles x tiles of style.water_fills, mirrored at random) for the water shader.
static func water_image(style: MapStyle, tiles: int, rng_seed: int) -> Image:
	var t := style.tile_size
	var sheet := style.water_texture.get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	var out := Image.create_empty(tiles * t, tiles * t, false, Image.FORMAT_RGBA8)
	for y in tiles:
		for x in tiles:
			var h := _hash(x, y, rng_seed)
			var f: Vector2i = style.water_fills[h % style.water_fills.size()]
			var tile := sheet.get_region(Rect2i(f.x * t, f.y * t, t, t))
			if h & 256:
				tile.flip_x()
			if h & 512:
				tile.flip_y()
			out.blit_rect(tile, Rect2i(0, 0, t, t), Vector2i(x * t, y * t))
	return out
