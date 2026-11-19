class_name MapGenDeco
extends RefCounted
## MapGen stage "deco": moved out of map_gen.gd unchanged (static helpers; MapGen keeps the public API and the shared consts / Params / Result).


static func _place_deco(res: MapGen.Result, style: MapStyle, p: MapGen.Params, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var sets := style.deco
	var any := false
	for s in sets:
		any = any or not s.regions.is_empty()
	if not any:
		return
	var size := p.size_px()
	var target := int(p.deco_density * p.cols * p.rows)
	var bucket := maxf(p.deco_min_spacing, 1.0)
	var grid := {}   # bucket key (by * 100000 + bx) -> PackedVector2Array of positions; bucket size = deco_min_spacing
	# obstacles in a flat bucket grid (bucket >= radius + 8): the old code scanned every obstacle per candidate
	var wmax := 8.0
	for o in res.obstacles:
		wmax = maxf(wmax, o["radius"] + 8.0)
	var ogrid := {}   # bucket key -> PackedInt32Array of obstacle indices
	var opos := PackedVector2Array()
	var orad := PackedFloat64Array()
	for k in res.obstacles.size():
		var o := res.obstacles[k]
		opos.append(o["pos"])
		orad.append(o["radius"])
		var ob := Vector2i(o["pos"] / wmax)
		var key := ob.y * 100000 + ob.x
		if not ogrid.has(key):
			ogrid[key] = PackedInt32Array()
		ogrid[key].append(k)
	var wtab: Array[PackedFloat64Array] = []   # [area][set] weight, and its running total
	var wtot := PackedFloat64Array()
	for area in 3:
		var row := PackedFloat64Array()
		var tot := 0.0
		for st in sets:
			var w := _deco_weight(st, area)
			row.append(w)
			tot += w
		wtab.append(row)
		wtot.append(tot)
	var empty_v := PackedVector2Array()
	var empty_i := PackedInt32Array()
	var has_ground := not res.ground.is_empty()
	for _attempt in target * 25:
		if res.deco.size() >= target:
			break
		var pos := Vector2(rng.randf_range(p.cell * 1.5, size.x - p.cell * 1.5), rng.randf_range(p.cell * 1.5, size.y - p.cell))
		var pick_r := rng.randf()
		var cell := Vector2i(pos / p.cell)
		var ci := cell.y * p.cols + cell.x
		if res.land[ci] == 0:
			continue
		# which set: by weight, and by the island area (flowers only in the forest, dry stuff in rocky / boss ...)
		var area: int = res.area[ci]
		var total_w: float = wtot[area]
		if total_w <= 0.0:
			continue
		var pick := pick_r * total_w
		var si := 0
		for i in sets.size():
			var w: float = wtab[area][i]
			if pick < w:
				si = i
				break
			pick -= w
		var set: PropSet = sets[si]
		if has_ground:
			var gd := res.ground[ci]
			if (gd == MapGen.Ground.DIRT or gd == MapGen.Ground.COBBLE or gd == MapGen.Ground.SAND or gd == MapGen.Ground.SNOW or res.dirt_cells.has(cell)) and not set.on_dirt:
				continue                  # plants only on grass
		elif res.kind[ci] != MapGen.FILL and not set.on_dirt:
			continue                      # plants only on full grass
		if rng.randf() > MapGen._n01(noise, pos.x / p.cell, pos.y / p.cell):
			continue                      # likelier where the noise is high
		var ok := true
		var b := Vector2i(pos / bucket)
		for by in range(maxi(b.y - 1, 0), b.y + 2):
			for bx in range(maxi(b.x - 1, 0), b.x + 2):
				for other: Vector2 in grid.get(by * 100000 + bx, empty_v):
					if pos.distance_to(other) < p.deco_min_spacing:
						ok = false
		if ok:
			var ob := Vector2i(pos / wmax)
			for by in range(maxi(ob.y - 1, 0), ob.y + 2):
				for bx in range(maxi(ob.x - 1, 0), ob.x + 2):
					for k in ogrid.get(by * 100000 + bx, empty_i):
						if pos.distance_to(opos[k]) < orad[k] + 8.0:
							ok = false
		if ok:
			res.deco.append({"set": si, "region": rng.randi() % set.regions.size(), "pos": pos})
			var key := b.y * 100000 + b.x
			if not grid.has(key):
				grid[key] = PackedVector2Array()
			grid[key].append(pos)


static func _deco_weight(set: PropSet, area: int) -> float:
	if set.regions.is_empty():
		return 0.0
	return set.weight * [set.area_weights.x, set.area_weights.y, set.area_weights.z][area]


# ------------------------------------------------------------------- border ---

## Bushes laid along the four walls, each overlapping the one before. Sorted by y so lower ones
## cover upper ones.
static func _place_border(res: MapGen.Result, style: MapStyle, p: MapGen.Params, rng: RandomNumberGenerator) -> void:
	var set := style.border
	if set == null or set.regions.is_empty():
		return
	var s := float(style.pixel_scale)
	var size := p.size_px()
	var inner := p.cell - 6.0         # how far a bush reaches in from the screen edge
	var dens := maxf(p.border_density, 0.05)
	for edge in 4:                    # 0 top, 1 bottom, 2 left, 3 right
		var t := -16.0
		var limit := size.x if edge < 2 else size.y
		while t < limit:
			var idx := rng.randi() % set.regions.size()
			var sz: Vector2 = set.regions[idx].size * s
			var pos := Vector2.ZERO
			var along := sz.x if edge < 2 else sz.y
			match edge:
				0: pos = Vector2(t + sz.x * 0.5, inner + rng.randf_range(-4.0, 8.0))
				1: pos = Vector2(t + sz.x * 0.5, size.y - inner + sz.y + rng.randf_range(-8.0, 4.0))
				2: pos = Vector2(inner - sz.x * 0.5 + rng.randf_range(-4.0, 8.0), t + sz.y)
				3: pos = Vector2(size.x - inner + sz.x * 0.5 + rng.randf_range(-8.0, 4.0), t + sz.y)
			res.border.append({"region": idx, "pos": pos, "flip": rng.randf() < 0.5})
			t += along * rng.randf_range(0.5, 0.75) / dens
	res.border.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
