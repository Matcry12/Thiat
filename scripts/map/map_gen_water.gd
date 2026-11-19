class_name MapGenWater
extends RefCounted
## MapGen stage "water": moved out of map_gen.gd unchanged (static helpers; MapGen keeps the public API and the shared consts / Params / Result).


## Water (0038 step 3; port of tools/asset_viewer_retired/world_preview.py). Cut out of the land mass the continent and the biomes made:
##  - rivers: the zero line of a ridge noise (|n| < width), only inland, wider towards the sea; a piece that does not reach the sea is dropped.
##  - lakes: pockets of a separate noise on wet, inland, not-too-rough land.
##  - shallows: the first 1-2 ocean cells along the coast. Rivers, lakes and shallows are SHALLOW water: not land (nothing is placed there)
##    but walkable. The ocean beyond is OCEAN: deep, it blocks walking.
##  - shore: the 1-2 land cells around a river / lake (res.shore; the ground pass gives them BiomeData.shore_ground).
##  - BiomeData.fresh_pull_cells: a biome (swamp) takes wet lowland near fresh water.
## `res.land` ends up as DRY land only; `res.walk_land` = dry + shallow, what walking and the walk grid use.
static func _make_water(res: MapGen.Result, p: MapGen.Params, home: Vector2i, zc: Rect2i) -> void:
	var cols := p.cols
	var rows := p.rows
	var n := cols * rows
	var land := res.land
	var ws := MapGenIsland._world_scale(p)
	var shallow := PackedByteArray()
	var fresh := PackedByteArray()
	var shore := PackedByteArray()
	shallow.resize(n)
	fresh.resize(n)
	shore.resize(n)
	res.shallow = shallow
	res.fresh = fresh
	res.shore = shore
	var wx := res.warp_x
	var wy := res.warp_y
	var t := Time.get_ticks_usec()
	var wet := PackedInt32Array()   # every shallow cell
	var fresh_cells := PackedInt32Array()
	if p.water_on:
		# distance to the sea on a grid 4 times coarser (chamfer, in coarse cells): the river width and the lake inland rule only need it roughly
		var cw := (cols + 3) / 4
		var ch := (rows + 3) / 4
		var dc := PackedFloat32Array()
		dc.resize(cw * ch)
		for cy in ch:
			for cx in cw:
				dc[cy * cw + cx] = 1.0e6 if land[mini(cy * 4 + 2, rows - 1) * cols + mini(cx * 4 + 2, cols - 1)] == 1 else 0.0
		for cy in ch:
			for cx in cw:
				var k := cy * cw + cx
				var d := dc[k]
				if d == 0.0:
					continue
				if cx > 0:
					d = minf(d, dc[k - 1] + 1.0)
				if cy > 0:
					d = minf(d, dc[k - cw] + 1.0)
					if cx > 0:
						d = minf(d, dc[k - cw - 1] + 1.414)
					if cx < cw - 1:
						d = minf(d, dc[k - cw + 1] + 1.414)
				dc[k] = d
		for cy in range(ch - 1, -1, -1):
			for cx in range(cw - 1, -1, -1):
				var k := cy * cw + cx
				var d := dc[k]
				if d == 0.0:
					continue
				if cx < cw - 1:
					d = minf(d, dc[k + 1] + 1.0)
				if cy < ch - 1:
					d = minf(d, dc[k + cw] + 1.0)
					if cx < cw - 1:
						d = minf(d, dc[k + cw + 1] + 1.414)
					if cx > 0:
						d = minf(d, dc[k + cw - 1] + 1.414)
				dc[k] = d
		t = MapGen._lap(res, "water.seadist", t)
		# --- rivers
		var rn := MapGenBiomes._climate_noise(res.seed + MapGen.SEED_WATER + 1, p.river_period * ws, p.river_octaves)
		var nr := PackedFloat32Array()
		nr.resize(n)
		for y in rows:
			for x in cols:
				var i := y * cols + x
				nr[i] = rn.get_noise_2d(x + 0.5 + wx[i], y + 0.5 + wy[i])
		t = MapGen._lap(res, "water.ridge", t)
		var rough := res.rough
		var humid := res.humid
		var hp2 := (p.home_clear_cells + 3) * (p.home_clear_cells + 3)
		var grow := maxf(p.river_grow_dist * ws, 1.0)
		var rscale := maxf(ws, 0.4)   # river widths shrink on a small map too, but not below 0.4 x
		var river := PackedByteArray()
		river.resize(n)
		var rdist := PackedFloat32Array()   # |n| / |grad n| = the distance to the zero line in cells; 1e9 = not a candidate cell
		rdist.resize(n)
		rdist.fill(1.0e9)
		var rcells := PackedInt32Array()
		for y in range(1, rows - 1):
			var dy2 := (y - home.y) * (y - home.y)
			var zone_y := y >= zc.position.y and y < zc.end.y
			for x in range(1, cols - 1):
				var i := y * cols + x
				if land[i] == 0:
					continue
				var a := absf(nr[i])
				if a > 0.25 or rough[i] >= p.river_rough_max:
					continue
				if (x - home.x) * (x - home.x) + dy2 <= hp2 or (zone_y and x >= zc.position.x and x < zc.end.x):
					continue   # home and the fight zone stay dry
				var gx := (nr[i + 1] - nr[i - 1]) * 0.5
				var gy := (nr[i + cols] - nr[i - cols]) * 0.5
				var dd := a / maxf(sqrt(gx * gx + gy * gy), 1.0e-6)
				rdist[i] = dd
				var w := lerpf(p.river_w_inland, p.river_w_sea, clampf(1.0 - dc[(y >> 2) * cw + (x >> 2)] * 4.0 / grow, 0.0, 1.0)) * rscale
				if dd < w:
					river[i] = 1
					rcells.append(i)
		var rseen := PackedByteArray()
		rseen.resize(n)
		var stack := PackedInt32Array()
		var spans := PackedInt32Array()
		var pieces: Array[PackedInt32Array] = []   # the kept river pieces
		for i in rcells:
			if rseen[i] == 1:
				continue
			spans.clear()
			if MapGenWalk._span_fill(river, rseen, cols, rows, i, 1, spans, stack) < p.river_min_cells:
				continue
			var reaches_sea := false
			var inland_max := 0.0   # how far from the sea the piece gets: a river that only runs along the coast is a ditch, not a river
			for k in range(0, spans.size(), 2):
				for c in range(spans[k], spans[k] + spans[k + 1]):
					if land[c - 1] == 0 or land[c + 1] == 0 or land[c - cols] == 0 or land[c + cols] == 0:
						reaches_sea = true
					inland_max = maxf(inland_max, dc[(c / cols >> 2) * cw + (c % cols >> 2)])
			if reaches_sea and inland_max * 4.0 >= p.river_inland_min * ws:
				var cells := PackedInt32Array()
				for k2 in range(0, spans.size(), 2):
					for c in range(spans[k2], spans[k2] + spans[k2 + 1]):
						fresh[c] = 1
						fresh_cells.append(c)
						cells.append(c)
				pieces.append(cells)
		# the longest rivers (most cells) are widened: cells within `river_big_reach` of the thin river that are closer than the big half width to its zero line
		var order: Array = range(pieces.size())
		order.sort_custom(func(a: int, b: int) -> bool: return pieces[a].size() > pieces[b].size() or (pieces[a].size() == pieces[b].size() and a < b))
		var offs4 := PackedInt32Array([-cols, cols, -1, 1])
		for bk in mini(p.river_big_n, order.size()):
			var front: PackedInt32Array = pieces[order[bk]].duplicate()
			for step in p.river_big_reach:   # grow outwards from the thin river, only through cells inside the big half width (no loose specks)
				var nxt := PackedInt32Array()
				for c in front:
					for o in offs4:
						var j: int = c + o
						if j < 0 or j >= n or land[j] == 0 or fresh[j] != 0 or rdist[j] >= 1.0e8:
							continue
						var gr := clampf(1.0 - dc[(j / cols >> 2) * cw + (j % cols >> 2)] * 4.0 / grow, 0.0, 1.0)
						if rdist[j] < lerpf(p.river_big_w_inland, p.river_big_w_sea, gr) * rscale:
							fresh[j] = 1
							fresh_cells.append(j)
							nxt.append(j)
				front = nxt
		t = MapGen._lap(res, "water.rivers", t)
		_make_lakes(res, p, home, zc, dc, cw, fresh, fresh_cells)
		t = MapGen._lap(res, "water.lakes", t)
		_drop_small_water(p, fresh, fresh_cells)
		# --- cut the fresh water out of the land; the land around it is the shore
		for i in fresh_cells:
			land[i] = 0
			shallow[i] = 1
		wet.append_array(fresh_cells)
		var offs8 := PackedInt32Array([-cols - 1, -cols, -cols + 1, -1, 1, cols - 1, cols, cols + 1])
		var ring1 := PackedInt32Array()
		for i in fresh_cells:
			for o in offs8:
				var j := i + o
				if land[j] == 1 and shore[j] == 0:
					shore[j] = 1
					ring1.append(j)
		if p.shore_cells > 1.0:   # a ragged second ring: `shore_cells` 1.5 = half of its cells
			for j in ring1:
				for o in [-cols, cols, -1, 1]:
					var k: int = j + o
					if k >= 0 and k < n and land[k] == 1 and shore[k] == 0 and float(MapGenGround._hash_int(k % cols, k / cols, res.seed + 7) % 100) < (p.shore_cells - 1.0) * 100.0:
						shore[k] = 1
		# --- swamp (any biome with BiomeData.fresh_pull_cells): wet lowland near fresh water, on a 2x coarser distance
		var pulls: Array[int] = []
		var pull_max := 0.0
		for bi in res.biomes.size():
			if res.biomes[bi].fresh_pull_cells > 0.0:
				pulls.append(bi)
				pull_max = maxf(pull_max, res.biomes[bi].fresh_pull_cells)
		if not pulls.is_empty() and not fresh_cells.is_empty():
			var cap2 := int(ceilf(pull_max / 2.0)) + 3
			var w2 := (cols + 1) / 2
			var h2 := (rows + 1) / 2
			var d2 := PackedByteArray()
			d2.resize(w2 * h2)
			d2.fill(255)
			var front := PackedInt32Array()
			for i in fresh_cells:
				var k := (i / cols / 2) * w2 + (i % cols) / 2
				if d2[k] != 0:
					d2[k] = 0
					front.append(k)
			var offs2 := PackedInt32Array([-w2 - 1, -w2, -w2 + 1, -1, 1, w2 - 1, w2, w2 + 1])
			for step in cap2:
				var nxt := PackedInt32Array()
				for k in front:
					var kx := k % w2
					var ky := k / w2
					if kx < 1 or ky < 1 or kx >= w2 - 1 or ky >= h2 - 1:
						continue
					for o in offs2:
						if d2[k + o] > step + 1:
							d2[k + o] = step + 1
							nxt.append(k + o)
				front = nxt
			var wob := MapGenBiomes._climate_noise(res.seed + MapGen.SEED_WATER + 3, 12.0, 2)
			var temp := res.temp
			for i in n:
				if land[i] == 0:
					continue
				var dd := d2[((i / cols) / 2) * w2 + (i % cols) / 2]
				if dd > cap2 or res.biome[i] >= MapGen.Biome.BEACH_SAND:
					continue
				var near_cells := dd * 2.0 + (MapGen._n01(wob, i % cols, i / cols) - 0.5) * 6.0
				for bi in pulls:
					var bd := res.biomes[bi]
					if near_cells < bd.fresh_pull_cells and humid[i] > bd.fresh_humid_min and rough[i] < bd.fresh_rough_max and temp[i] > bd.fresh_temp_min and temp[i] < bd.fresh_temp_max:
						res.biome[i] = bi
						break
		t = MapGen._lap(res, "water.shore+swamp", t)
		# --- shallows along the ocean coast: ocean cells within 1-2 cells of the land (ragged)
		var ring := PackedByteArray()
		ring.resize(n)
		var frontier := PackedInt32Array()
		var cd := res.coast_dist
		var at := cd.find(1)
		while at >= 0:
			for o in offs8:
				var j := at + o
				if j >= 0 and j < n and land[j] == 0 and ring[j] == 0 and shallow[j] == 0:
					ring[j] = 1
					frontier.append(j)
			at = cd.find(1, at + 1)
		var second := PackedInt32Array()
		for i in frontier:
			for o in offs8:
				var j := i + o
				if j >= 0 and j < n and land[j] == 0 and ring[j] == 0 and shallow[j] == 0:
					ring[j] = 2
					second.append(j)
		var sn := MapGenBiomes._climate_noise(res.seed + MapGen.SEED_WATER + 4, 20.0, 2)
		for lst in [frontier, second]:
			for i in lst:
				if float(ring[i]) <= lerpf(p.shallow_min, p.shallow_max, MapGen._n01(sn, i % cols, i / cols)):
					shallow[i] = 1
					wet.append(i)
		t = MapGen._lap(res, "water.shallows", t)
	res.land = land
	var walk := land.duplicate()
	for i in wet:
		walk[i] = 1
	res.walk_land = walk
	res.warp_x = PackedFloat32Array()
	res.warp_y = PackedFloat32Array()
	res.coast_dist = PackedByteArray()


## Lakes (0038 water v2; port of tools/asset_viewer_retired/world_preview.py): `lake_big_n` landmark lakes (`lake_big_on_river` of them on a river path) and
## `lake_pond_n` small ponds that cluster where a wetness noise is high (or sit next to a river). A lake is one or a few merged blobs, each
## an ellipse whose edge is wobbled by noise. Lake cells become fresh = 2 (a lake over a river cell wins). Home and the fight zone stay dry.
## Radii and counts shrink on a map smaller than 512 x 512 (counts by the area), never below 0.4 x.
static func _make_lakes(res: MapGen.Result, p: MapGen.Params, home: Vector2i, zc: Rect2i, dc: PackedFloat32Array, cw: int, fresh: PackedByteArray, fresh_cells: PackedInt32Array) -> void:
	var cols := p.cols
	var rows := p.rows
	var n := cols * rows
	var land := res.land
	var humid := res.humid
	var rough := res.rough
	var wx := res.warp_x
	var wy := res.warp_y
	var ws := MapGenIsland._world_scale(p)
	var ls := maxf(ws, 0.4)
	var hp2 := (p.home_clear_cells + 3) * (p.home_clear_cells + 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = res.seed + MapGen.SEED_WATER + 5
	var shape_n := MapGenBiomes._climate_noise(res.seed + MapGen.SEED_WATER + 2, p.lake_shape_period * ls, 3)
	var wet_n := MapGenBiomes._climate_noise(res.seed + MapGen.SEED_WATER + 6, p.lake_pond_wet_period * ws, 2)
	# wetness threshold = the `lake_pond_wet_min` quantile over a coarse sample of the land
	var samp := PackedFloat32Array()
	for y in range(0, rows, 4):
		for x in range(0, cols, 4):
			var i := y * cols + x
			if land[i] == 1:
				samp.append(wet_n.get_noise_2d(x + 0.5 + wx[i], y + 0.5 + wy[i]))
	samp.sort()
	var wet_thr := -2.0 if samp.is_empty() else samp[clampi(int(samp.size() * p.lake_pond_wet_min), 0, samp.size() - 1)]
	var rpts := PackedInt32Array()   # river cells away from the sea: where "on a river" lakes are centred
	for c in fresh_cells:
		if dc[(c / cols >> 2) * cw + (c % cols >> 2)] * 4.0 > 14.0:
			rpts.append(c)
	var n_big := ceili(p.lake_big_n * ls * ls) if p.lake_big_n > 0 else 0
	var n_pond := ceili(p.lake_pond_n * ls * ls) if p.lake_pond_n > 0 else 0
	var placed: Array[Vector3] = []   # x, y, radius
	var lake := PackedByteArray()
	lake.resize(n)
	var lake_cells := PackedInt32Array()
	var inland := p.lake_inland_min * ws
	for k in n_big + n_pond:
		var big := k < n_big
		var rad := (rng.randf_range(p.lake_big_r_min, p.lake_big_r_max) if big else rng.randf_range(p.lake_pond_r_min, p.lake_pond_r_max)) * ls
		var on_river := (k < p.lake_big_on_river) if big else (rng.randf() < p.lake_pond_on_river)
		var cx := 0.0
		var cy := 0.0
		var found := false
		for _try in 120:
			if on_river and not rpts.is_empty():
				var c := rpts[rng.randi() % rpts.size()]
				var jit := 0.3 if big else 1.2
				cx = c % cols + rng.randf_range(-rad, rad) * jit
				cy = c / cols + rng.randf_range(-rad, rad) * jit
			else:
				cx = rng.randf_range(0.0, cols)
				cy = rng.randf_range(0.0, rows)
			var ix := clampi(int(cx), 1, cols - 2)
			var iy := clampi(int(cy), 1, rows - 2)
			var ci := iy * cols + ix
			if land[ci] == 0 or humid[ci] <= p.lake_humid_min or rough[ci] >= p.lake_rough_max:
				continue
			if dc[(iy >> 2) * cw + (ix >> 2)] * 4.0 < rad * 1.4 + inland:
				continue
			if not big and not on_river and wet_n.get_noise_2d(ix + 0.5 + wx[ci], iy + 0.5 + wy[ci]) <= wet_thr:
				continue   # a free pond only where it is wet: ponds cluster
			var gap := 1.0 if not big else float(p.lake_gap)
			var clash := false
			for q in placed:
				if Vector2(cx - q.x, cy - q.y).length() < rad + q.z + gap:
					clash = true
					break
			if not clash:
				found = true
				break
		if not found:
			continue
		var blobs: Array = []   # [x, y, radius, edge-wobble k, angle, stretch]
		if big:
			blobs.append([cx, cy, rad, 0.25, 0.0, 1.0])
		else:
			var ang := rng.randf_range(0.0, PI)
			var sgn := float((placed.size() % 2) * 2 - 1)
			for _b in rng.randi_range(p.lake_pond_blobs_min, maxi(p.lake_pond_blobs_min, p.lake_pond_blobs_max)):
				var off := rng.randf_range(0.6, 1.4) * rad
				var a2 := ang + rng.randf_range(-0.5, 0.5)
				blobs.append([cx + cos(a2) * off * sgn, cy + sin(a2) * off, rad * rng.randf_range(0.6, 1.0), 0.22, ang, rng.randf_range(p.lake_pond_stretch_min, p.lake_pond_stretch_max)])
		placed.append(Vector3(cx, cy, rad))
		for bl in blobs:
			var bx: float = bl[0]
			var by: float = bl[1]
			var br: float = bl[2]
			var ca := cos(float(bl[4]))
			var sa := sin(float(bl[4]))
			var stretch := maxf(float(bl[5]), 0.1)
			var wob: float = p.lake_warp * float(bl[3])
			for y in range(maxi(int(by - br * 3.0), 1), mini(int(by + br * 3.0) + 1, rows - 1)):
				var dy2 := (y - home.y) * (y - home.y)
				var zone_y := y >= zc.position.y and y < zc.end.y
				for x in range(maxi(int(bx - br * 3.0), 1), mini(int(bx + br * 3.0) + 1, cols - 1)):
					var i := y * cols + x
					if land[i] == 0 or lake[i] == 1 or dc[(y >> 2) * cw + (x >> 2)] * 4.0 <= 2.0:
						continue
					if (x - home.x) * (x - home.x) + dy2 <= hp2 or (zone_y and x >= zc.position.x and x < zc.end.x):
						continue
					var gx := x + 0.5 - bx
					var gy := y + 0.5 - by
					var u := (gx * ca + gy * sa) / stretch
					var v := -gx * sa + gy * ca
					if sqrt(u * u + v * v) / br + shape_n.get_noise_2d(x + 0.5 + wx[i], y + 0.5 + wy[i]) * wob < 1.0:
						lake[i] = 1
						lake_cells.append(i)
	var seen := PackedByteArray()
	seen.resize(n)
	var spans := PackedInt32Array()
	var stack := PackedInt32Array()
	for i in lake_cells:
		if seen[i] == 1:
			continue
		spans.clear()
		if MapGenWalk._span_fill(lake, seen, cols, rows, i, 1, spans, stack) < p.lake_min_cells:
			continue
		for k2 in range(0, spans.size(), 2):
			for c in range(spans[k2], spans[k2] + spans[k2 + 1]):
				if fresh[c] == 0:
					fresh_cells.append(c)
				fresh[c] = 2


## Fresh-water bodies (river + lake cells, 4-connected) below `water_min_cells` become land again; fresh_cells keeps only the kept ones.
static func _drop_small_water(p: MapGen.Params, fresh: PackedByteArray, fresh_cells: PackedInt32Array) -> void:
	if p.water_min_cells <= 1 or fresh_cells.is_empty():
		return
	var n := p.cols * p.rows
	var wm := PackedByteArray()
	wm.resize(n)
	for i in fresh_cells:
		wm[i] = 1
	var seen := PackedByteArray()
	seen.resize(n)
	var spans := PackedInt32Array()
	var stack := PackedInt32Array()
	for i in fresh_cells:
		if seen[i] == 1:
			continue
		spans.clear()
		if MapGenWalk._span_fill(wm, seen, p.cols, p.rows, i, 1, spans, stack) >= p.water_min_cells:
			continue
		for k in range(0, spans.size(), 2):
			for c in range(spans[k], spans[k] + spans[k + 1]):
				fresh[c] = 0
	var kept := PackedInt32Array()
	var dup := PackedByteArray()
	dup.resize(n)
	for i in fresh_cells:
		if fresh[i] != 0 and dup[i] == 0:
			dup[i] = 1
			kept.append(i)
	fresh_cells.clear()
	fresh_cells.append_array(kept)
