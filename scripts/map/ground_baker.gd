class_name GroundBaker
extends RefCounted
## Bakes the island ground (MapGen.Result.ground) into ONE picture, so the map is a few big sprites instead of
## 20 000 tiles (decision 0033). Method: DUAL GRID / marching squares.
##   - Display tiles sit on the cell CORNERS: tile (i, j) covers the corner shared by cells (i-1,j-1) (i,j-1) (i-1,j) (i,j),
##     so the picture is one tile bigger than the map and is drawn half a tile up and left.
##   - Ground is in layers (GroundData.layer: dirt 1, cobble 2, grass 3). For a layer, each of the 4 cells is "in" if its
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


## Forget the cached pieces (a style changed).
static func clear_cache() -> void:
	_layers.clear()


static func _hash(x: int, y: int, s: int) -> int:
	return ((x * 73856093) ^ (y * 19349663) ^ (s * 83492791)) & 0x7fffffff


## look: {tint: Array[Color] per Area (brightness already applied), sat: Array[float] per Area, shade_variation, shade_scale}
## Returns {ground: Image (RGBA8, (cols+1) x (rows+1) tiles: draw it half a tile up and left), foam: Image (L8, same),
## tint: Image (RGBA8, cols x rows), shade: Image (RGB8, cols x rows), tile: int}
static func bake(res: MapGen.Result, style: MapStyle, look: Dictionary) -> Dictionary:
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
	var img := Image.create_empty((cols + 1) * t, (rows + 1) * t, false, Image.FORMAT_RGBA8)
	var foam := Image.create_empty((cols + 1) * t, (rows + 1) * t, false, Image.FORMAT_L8)
	var tile_rect := Rect2i(0, 0, t, t)
	var L := PackedByteArray()   # layer per cell, one cell of water around the map
	var G := PackedByteArray()   # ground id per cell, same padding
	var pw := cols + 2
	L.resize(pw * (rows + 2))
	G.resize(pw * (rows + 2))
	for y in rows:
		for x in cols:
			G[(y + 1) * pw + x + 1] = res.ground[y * cols + x]
			L[(y + 1) * pw + x + 1] = layer_of[res.ground[y * cols + x]]
	for j in rows + 1:
		for i in cols + 1:
			var p0 := j * pw + i   # the cell up-left of this corner
			var cells := [p0, p0 + 1, p0 + pw, p0 + pw + 1]   # NW NE SW SE
			var l0 := L[cells[0]]
			var l1 := L[cells[1]]
			var l2 := L[cells[2]]
			var l3 := L[cells[3]]
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
					var h := _hash(i, j, res.seed + lay)
					img.blit_rect(layer.fills[(h % (layer.fills.size() / 4)) * 4 + ((h >> 8) & 3)], tile_rect, dst)
				else:
					var pc := piece(layer, q)
					img.blend_rect(pc["tile"], tile_rect, dst)
					if lay == lo and mn == 0:
						foam.blit_rect(pc["foam"], tile_rect, dst)
	_paint_stamps(img, res, by_ground[MapGen.Ground.DIRT])
	return {"ground": img, "foam": foam, "tint": tint_image(res, look), "shade": shade_image(res, look), "tile": t}


## Dirt stamps (patches, camp, paths) painted as smooth discs over the tiles. Three passes over ALL stamps so the
## outline only shows around the union, never inside it: a wide light rim, a narrow dark rim, then the dirt.
static func _paint_stamps(img: Image, res: MapGen.Result, layer: Layer) -> void:
	if res.dirt_stamps.is_empty() or layer == null or layer.fills.is_empty():
		return
	var k := float(layer.tile) / res.cell   # art px per world px
	var half := layer.tile / 2               # the dual-grid picture starts half a tile up and left
	var discs := {}
	for pass_i in 3:
		for st in res.dirt_stamps:
			var r := roundi(st.z * k)
			var grow := 2 - pass_i             # 2, 1, 0 px beyond the dirt
			var key := r * 10 + pass_i
			if not discs.has(key):
				discs[key] = _disc(layer, r + grow, [0.82, 0.62, 1.0][pass_i])
			var d: Image = discs[key]
			img.blend_rect(d, Rect2i(0, 0, d.get_width(), d.get_height()), Vector2i(roundi(st.x * k) + half - r - grow, roundi(st.y * k) + half - r - grow))


static func _disc(layer: Layer, radius: int, shade: float) -> Image:
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


## One pixel per cell, NEAREST filtered: the area tint (x2 encoded, so brighter than 1 fits) and in alpha its saturation.
## Crisp on purpose: a tint must not smear over the border into the next area.
static func tint_image(res: MapGen.Result, look: Dictionary) -> Image:
	var tints: Array = look["tint"]
	var sats: Array = look["sat"]
	var data := PackedByteArray()
	data.resize(res.cols * res.rows * 4)
	for i in res.cols * res.rows:
		# the tint follows the SMOOTHED ground (same cells the tiles use), so a stray gameplay-area cell does not show
		var a: int = res.area[i]
		match res.ground[i]:
			MapGen.Ground.GRASS:
				a = MapGen.Area.FOREST
			MapGen.Ground.COBBLE:
				a = MapGen.Area.ROCKY
			MapGen.Ground.BOSS:
				a = MapGen.Area.BOSS
		var base: Color = tints[a]
		data[i * 4] = clampi(roundi(base.r * 127.5), 0, 255)
		data[i * 4 + 1] = clampi(roundi(base.g * 127.5), 0, 255)
		data[i * 4 + 2] = clampi(roundi(base.b * 127.5), 0, 255)
		data[i * 4 + 3] = clampi(roundi(float(sats[a]) * 255.0), 0, 255)
	return Image.create_from_data(res.cols, res.rows, false, Image.FORMAT_RGBA8, data)


## One pixel per cell, LINEAR filtered: soft light and dark patches (x2 encoded grey).
static func shade_image(res: MapGen.Result, look: Dictionary) -> Image:
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
	data.resize(res.cols * res.rows * 3)
	for y in res.rows:
		for x in res.cols:
			var v := clampi(roundi((1.0 + var_amount * (noise.get_noise_2d(x, y) * 0.75 + fine.get_noise_2d(x, y) * 0.45)) * 127.5), 0, 255)
			var i := (y * res.cols + x) * 3
			data[i] = v
			data[i + 1] = v
			data[i + 2] = v
	return Image.create_from_data(res.cols, res.rows, false, Image.FORMAT_RGB8, data)


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
