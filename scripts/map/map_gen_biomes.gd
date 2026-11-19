class_name MapGenBiomes
extends RefCounted
## MapGen stage "biomes": moved out of map_gen.gd unchanged (static helpers; MapGen keeps the public API and the shared consts / Params / Result).


## Climate -> biome per land cell (decision 0038; port of tools/asset_viewer_retired/world_preview.py). Temperature, humidity and roughness are
## domain-warped noise, stretched to an even 0..1 over the land, pulled to a mild climate around home; each cell then takes the nearest
## point of the biomes (BiomeData). The map is smoothed, small patches absorbed, warm / cold clashes repaired, and land close to water becomes beach.
## Own seeds (SEED_CLIMATE + n): draws nothing from the main stream.
static func _make_biomes(res: MapGen.Result, p: MapGen.Params, home: Vector2i) -> void:
	var cols := p.cols
	var rows := p.rows
	var n := cols * rows
	res.biome.resize(n)
	res.biome.fill(MapGen.Biome.PLAINS)
	res.f.resize(n)
	res.f.fill(0.0)
	var t := Time.get_ticks_usec()
	var warp_x := res.warp_x   # the domain warp, made once for the continent (_make_continent): the climate bends the same way
	var warp_y := res.warp_y
	var noises: Array[FastNoiseLite] = [
		_climate_noise(res.seed + MapGen.SEED_CLIMATE, p.climate_temp_period, p.climate_octaves),
		_climate_noise(res.seed + MapGen.SEED_CLIMATE + 1, p.climate_humid_period, p.climate_octaves),
		_climate_noise(res.seed + MapGen.SEED_CLIMATE + 2, p.climate_rough_period, p.climate_octaves)]
	var raw: Array[PackedFloat32Array] = []
	for _k in 3:
		var a := PackedFloat32Array()
		a.resize(n)
		raw.append(a)
	for y in rows:
		for x in cols:
			var i := y * cols + x
			if res.land[i] == 0:
				continue
			var sx := x + 0.5 + warp_x[i]
			var sy := y + 0.5 + warp_y[i]
			for k in 3:
				raw[k][i] = noises[k].get_noise_2d(sx, sy)
	t = MapGen._lap(res, "bio.noise", t)
	var temp := _rank01(raw[0], res.land)
	var humid := _rank01(raw[1], res.land)
	var rough := _rank01(raw[2], res.land)
	t = MapGen._lap(res, "bio.rank", t)
	var calm := [p.calm_temp, p.calm_humid, p.calm_rough]
	var calm_far := p.home_calm_cells + maxf(p.home_calm_fade, 0.01) + 1.0
	for i in n:   # home calm: smooth, so no border is created
		if res.land[i] == 1:
			var cdx := i % cols - home.x
			var cdy := i / cols - home.y
			if cdx * cdx + cdy * cdy > calm_far * calm_far:
				continue   # far from home: the pull is exactly 0
			var w := 1.0 - smoothstep(p.home_calm_cells, p.home_calm_cells + maxf(p.home_calm_fade, 0.01), Vector2(i % cols + 0.5, i / cols + 0.5).distance_to(Vector2(home) + Vector2(0.5, 0.5)))
			temp[i] = lerpf(temp[i], calm[0], w)
			humid[i] = lerpf(humid[i], calm[1], w)
			rough[i] = lerpf(rough[i], calm[2], w)
	t = MapGen._lap(res, "bio.calm", t)
	res.temp = temp
	res.humid = humid
	res.rough = rough
	# nearest point of the table; f = how much nearer a tree-biome point is than a Plains point (0.5 = equally near, 0 / 1 = `forest_margin` or more apart)
	var rows_n := 0
	var tt := PackedFloat32Array()   # the table flat, one array per axis: array-of-arrays reads are slow in the per-cell loop
	var th := PackedFloat32Array()
	var tr := PackedFloat32Array()
	var tb_biome := PackedInt32Array()
	var tb_mode := PackedInt32Array()   # BiomeData.forest_role of the point's biome: 1 = open (Plains) point, 2 = wooded point, 0 = other
	for bi in res.biomes.size():
		for pt in res.biomes[bi].points():
			tt.append(pt.x)
			th.append(pt.y)
			tr.append(pt.z)
			tb_biome.append(bi)
			tb_mode.append(res.biomes[bi].forest_role)   # BiomeData.Role: 1 OPEN (Plains), 2 WOODED
			rows_n += 1
	var w_t := p.climate_w_temp
	var w_h := p.climate_w_humid
	var w_r := p.climate_w_rough
	var margin := maxf(p.forest_margin, 0.0001)
	var biome := res.biome
	var fmap := res.f
	var land := res.land
	for i in n:
		if land[i] == 0:
			continue
		var ti: float = temp[i]
		var hi: float = humid[i]
		var ri: float = rough[i]
		var best := INF
		var d_plains := INF
		var d_trees := INF
		var best_k := 0
		for k in rows_n:
			var dt: float = (ti - tt[k]) * w_t
			var dh: float = (hi - th[k]) * w_h
			var dr: float = (ri - tr[k]) * w_r
			var dd := dt * dt + dh * dh + dr * dr
			if dd < best:
				best = dd
				best_k = k
			var m := tb_mode[k]
			if m == 1:
				if dd < d_plains:
					d_plains = dd
			elif m == 2:
				if dd < d_trees:
					d_trees = dd
		biome[i] = tb_biome[best_k]
		fmap[i] = clampf(0.5 + 0.5 * (sqrt(d_plains) - sqrt(d_trees)) / margin, 0.0, 1.0)
	res.biome = biome
	res.f = fmap
	t = MapGen._lap(res, "bio.nearest", t)
	_biome_majority(res, cols, rows, p.biome_smooth_passes, p.biome_smooth_half)
	t = MapGen._lap(res, "bio.majority", t)
	_biome_absorb_small(res, cols, rows, p.biome_min_blob)
	t = MapGen._lap(res, "bio.absorb", t)
	_biome_repair_clashes(res, cols, rows)
	t = MapGen._lap(res, "bio.clashes", t)
	# beach: land within a ragged band of the water; sand when warm, gravel when cold
	var cap := int(ceilf(maxf(p.beach_min, p.beach_max)))
	var dist := MapGenGround._water_dist(res, p, cap)
	res.coast_dist = dist   # kept for the shallows (_make_water)
	t = MapGen._lap(res, "bio.waterdist", t)
	var edge := _climate_noise(res.seed + MapGen.SEED_CLIMATE + 5, p.beach_noise_period, p.beach_noise_octaves)
	for i in n:
		if res.land[i] == 1 and dist[i] <= cap:
			var width := lerpf(p.beach_min, p.beach_max, MapGen._n01(edge, i % cols, i / cols))
			if dist[i] <= width:
				res.biome[i] = MapGen.Biome.BEACH_SAND if temp[i] >= p.cold_beach_t else MapGen.Biome.BEACH_GRAVEL


static func _climate_noise(noise_seed: int, period: float, octaves: int) -> FastNoiseLite:
	var nz := MapGen._noise(noise_seed, 1.0 / maxf(period, 1.0))
	nz.fractal_type = FastNoiseLite.FRACTAL_FBM
	nz.fractal_octaves = octaves
	return nz


## Values -> 0..1 evenly spread over the LAND cells (percentile; keeps the order, so the map stays smooth).
static func _rank01(vals: PackedFloat32Array, land: PackedByteArray) -> PackedFloat32Array:
	var sorted := PackedFloat32Array()
	for i in vals.size():
		if land[i] == 1:
			sorted.append(vals[i])
	sorted.sort()
	var out := PackedFloat32Array()
	out.resize(vals.size())
	var count := maxf(sorted.size(), 1.0)
	for i in vals.size():
		if land[i] == 1:
			out[i] = float(sorted.bsearch(vals[i])) / count
	return out


## Each land cell takes the commonest biome of the land cells around it (a window of 2 * half + 1), `passes` times. Ties keep the cell's own
## biome. Sliding histogram: one count per biome per column, moved along the row, so the cost does not grow with the window.
static func _biome_majority(res: MapGen.Result, cols: int, rows: int, passes: int, half: int) -> void:
	# The whole histogram of a window in ONE int: `bits` per biome (enough for the biggest window count). Falls back to the
	# per-biome version when that does not fit in 63 bits (a bigger window or more biomes).
	var kinds := res.biomes.size()
	var bits := 1
	while (1 << bits) <= (2 * half + 1) * (2 * half + 1):
		bits += 1
	if kinds * bits > 62:
		_biome_majority_wide(res, cols, rows, passes, half)
		return
	var land := res.land
	var mask := (1 << bits) - 1
	var x0s := PackedInt32Array()   # per row: first and last land cell (-1 = none): water-only stretches are skipped
	var x1s := PackedInt32Array()
	x0s.resize(rows)
	x1s.resize(rows)
	for y in rows:
		var lo := -1
		var hi := -1
		for x in cols:
			if land[y * cols + x] == 1:
				if lo < 0:
					lo = x
				hi = x
		x0s[y] = lo
		x1s[y] = hi
	for _pass in passes:
		var src := res.biome.duplicate()
		var colw := PackedInt64Array()   # per column: the biome counts over the window's rows, one packed word
		colw.resize(cols)
		for yy in mini(half, rows):
			_majority_row_packed(land, src, colw, cols, yy, 1, x0s[yy], x1s[yy], bits)
		for y in rows:
			if y + half < rows:
				_majority_row_packed(land, src, colw, cols, y + half, 1, x0s[y + half], x1s[y + half], bits)
			if y - half - 1 >= 0:
				_majority_row_packed(land, src, colw, cols, y - half - 1, -1, x0s[y - half - 1], x1s[y - half - 1], bits)
			var xa := x0s[y]
			if xa < 0:
				continue
			var h := 0
			for xx in range(maxi(xa - half, 0), mini(xa + half, cols - 1) + 1):
				h += colw[xx]
			var row := y * cols
			for x in range(xa, x1s[y] + 1):
				if x > xa:
					if x + half < cols:
						h += colw[x + half]
					if x - half - 1 >= 0:
						h -= colw[x - half - 1]
				var i := row + x
				if land[i] == 0:
					continue
				var own := src[i]
				var sh := bits * own
				if (h & ~(mask << sh)) == 0:   # only its own biome around: nothing can change (the common case)
					continue
				var best := own
				var hb := (h >> sh) & mask
				for k in kinds:
					var v := (h >> (bits * k)) & mask
					if v > hb:
						best = k
						hb = v
				res.biome[i] = best


static func _majority_row_packed(land: PackedByteArray, src: PackedByteArray, colw: PackedInt64Array, cols: int, y: int, sign: int, x0: int, x1: int, bits: int) -> void:
	if x0 < 0:
		return
	for i in range(y * cols + x0, y * cols + x1 + 1):
		if land[i] == 1:
			colw[i - y * cols] += sign << (bits * src[i])


static func _biome_majority_wide(res: MapGen.Result, cols: int, rows: int, passes: int, half: int) -> void:
	var kinds := res.biomes.size()
	var land := res.land
	var x0s := PackedInt32Array()   # per row: first and last land cell (-1 = none): water-only stretches are skipped
	var x1s := PackedInt32Array()
	x0s.resize(rows)
	x1s.resize(rows)
	for y in rows:
		var lo := -1
		var hi := -1
		for x in cols:
			if land[y * cols + x] == 1:
				if lo < 0:
					lo = x
				hi = x
		x0s[y] = lo
		x1s[y] = hi
	for _pass in passes:
		var src := res.biome.duplicate()
		var colc := PackedInt32Array()   # per column: biome counts over the window's rows
		colc.resize(cols * kinds)
		var hist := PackedInt32Array()
		hist.resize(kinds)
		for yy in mini(half, rows):
			_majority_row(land, src, colc, cols, kinds, yy, 1, x0s[yy], x1s[yy])
		for y in rows:
			if y + half < rows:
				_majority_row(land, src, colc, cols, kinds, y + half, 1, x0s[y + half], x1s[y + half])
			if y - half - 1 >= 0:
				_majority_row(land, src, colc, cols, kinds, y - half - 1, -1, x0s[y - half - 1], x1s[y - half - 1])
			var xa := x0s[y]
			if xa < 0:
				continue
			hist.fill(0)
			for xx in range(maxi(xa - half, 0), mini(xa + half, cols - 1) + 1):
				for k in kinds:
					hist[k] += colc[xx * kinds + k]
			var row := y * cols
			for x in range(xa, x1s[y] + 1):
				if x > xa:
					if x + half < cols:
						for k in kinds:
							hist[k] += colc[(x + half) * kinds + k]
					if x - half - 1 >= 0:
						for k in kinds:
							hist[k] -= colc[(x - half - 1) * kinds + k]
				var i := row + x
				if land[i] == 0:
					continue
				var best := src[i]
				for k in kinds:
					if hist[k] > hist[best]:
						best = k
				res.biome[i] = best


static func _majority_row(land: PackedByteArray, src: PackedByteArray, colc: PackedInt32Array, cols: int, kinds: int, y: int, sign: int, x0: int, x1: int) -> void:
	if x0 < 0:
		return
	for x in range(x0, x1 + 1):
		if land[y * cols + x] == 1:
			colc[x * kinds + src[y * cols + x]] += sign


## Biome patches (4-neighbour) smaller than `min_blob` cells take the nearest big biome. Not a patch that sits BETWEEN a warm and a cold
## biome (a 1-step buffer such as a thin taiga strip): that would let them touch. Two rounds.
static func _biome_absorb_small(res: MapGen.Result, cols: int, rows: int, min_blob: int) -> void:
	var n := cols * rows
	var land := res.land
	var biome := res.biome
	var tc := _temp_classes(res)
	for _round in 2:
		var lb := biome.duplicate()   # biome per cell, 255 on water: one compare says "land of this biome"
		for i in n:
			if land[i] == 0:
				lb[i] = 255
		var seen := PackedByteArray()
		seen.resize(n)
		var small := PackedByteArray()
		small.resize(n)
		var any := false
		var spans := PackedInt32Array()   # the patch as runs: (first cell, length) pairs
		var stack := PackedInt32Array()   # shared flood stack
		for start in n:
			if lb[start] == 255 or seen[start] == 1:
				continue
			var kind := lb[start]
			spans.clear()
			var size := MapGenWalk._span_fill(lb, seen, cols, rows, start, kind, spans, stack)
			if size >= min_blob:
				continue
			var lo := 9
			var hi := -9
			for k in range(0, spans.size(), 2):
				for i in range(spans[k], spans[k] + spans[k + 1]):
					var x := i - (i / cols) * cols
					for j in [i + 1 if x < cols - 1 else -1, i - 1 if x > 0 else -1, i + cols, i - cols]:
						if j < 0 or j >= n or lb[j] == 255 or lb[j] == kind:
							continue
						var t := tc[lb[j]]
						if t >= 0:
							lo = mini(lo, t)
							hi = maxi(hi, t)
			if hi - lo < 2:
				any = true
				for k in range(0, spans.size(), 2):
					for i in range(spans[k], spans[k] + spans[k + 1]):
						small[i] = 1
		if not any:
			break
		# grow the big biomes into the small cells, one ring at a time (nearest wins)
		var frontier := PackedInt32Array()   # land cells that touch a small patch, in cell order (the rest could not claim anything)
		for i in n:
			if land[i] == 1 and small[i] == 0:
				var x := i % cols
				if (x < cols - 1 and small[i + 1] == 1) or (x > 0 and small[i - 1] == 1) or (i + cols < n and small[i + cols] == 1) or (i >= cols and small[i - cols] == 1):
					frontier.append(i)
		while not frontier.is_empty():
			var next := PackedInt32Array()
			for i in frontier:
				var x := i % cols
				for dir in 4:
					var j := i + 1 if dir == 0 else (i - 1 if dir == 1 else (i + cols if dir == 2 else i - cols))
					if (dir == 0 and x == cols - 1) or (dir == 1 and x == 0) or j < 0 or j >= n:
						continue
					if small[j] == 1:
						small[j] = 0
						biome[j] = biome[i]
						next.append(j)
			frontier = next
	res.biome = biome


## BiomeData.temp_class per biome id, as an array (the per-cell loops must not touch Resources).
static func _temp_classes(res: MapGen.Result) -> PackedInt32Array:
	var tc := PackedInt32Array()
	for b in res.biomes:
		tc.append(b.temp_class)
	return tc


## Last guard: two neighbours whose temperature classes differ by 2+ (snow | forest, taiga | autumn) -> the warmer cell becomes the
## biome in between (taiga / forest). Repeats until none is left (each step shrinks the gap, so it ends).
static func _biome_repair_clashes(res: MapGen.Result, cols: int, rows: int) -> void:
	var n := cols * rows
	var land := res.land
	var biome := res.biome
	var tc := _temp_classes(res)
	for _guard in 12:
		var fixed := false
		for i in n:
			if land[i] == 0 or tc[biome[i]] < 0:
				continue
			for o in 2:   # right neighbour, then the one below
				var j := i + 1 if o == 0 else i + cols
				if (o == 0 and i % cols == cols - 1) or j >= n or land[j] == 0 or tc[biome[j]] < 0:
					continue
				var a := tc[biome[i]]
				var b := tc[biome[j]]
				if absi(a - b) >= 2:
					biome[i if a > b else j] = MapGen.Biome.TAIGA if mini(a, b) == 0 else MapGen.Biome.FOREST
					fixed = true
		if not fixed:
			break
	res.biome = biome


## Neighbouring land cells (4-neighbour) whose temperature classes differ by 2 or more. 0 = the cold / warm guarantee holds. Tests call it.
static func climate_clashes(res: MapGen.Result) -> int:
	var bad := 0
	for i in res.land.size():
		if res.land[i] == 0 or res.biome.is_empty() or res.biomes[res.biome[i]].temp_class < 0:
			continue
		for o in [1, res.cols]:
			if (i % res.cols == res.cols - 1 and o == 1) or i + o >= res.land.size() or res.land[i + o] == 0 or res.biomes[res.biome[i + o]].temp_class < 0:
				continue
			bad += 1 if absi(res.biomes[res.biome[i]].temp_class - res.biomes[res.biome[i + o]].temp_class) >= 2 else 0
	return bad


static func _smooth(a: float, b: float, v: float) -> float:
	return clampf((v - a) / maxf(b - a, 0.0001), 0.0, 1.0)
