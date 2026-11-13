extends SceneTree
## Dual-grid edge pieces (decision 0033): two pieces that sit side by side must agree on the pixels of the shared
## border (alpha), for every ground of every style and every compatible pair of the 16 cases. Also checks the
## full / empty cases and that every ground has a real edge (not all-opaque, not empty).
var _ok := true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		print("FAIL " + msg)
		_ok = false

func _distinct(a: Array) -> bool:
	var seen := {}
	for v in a:
		if seen.has(v):
			return false
		seen[v] = true
	return true

func _init() -> void:
	var n_pairs := 0
	for path in ["res://data/maps/grass.tres"]:
		var style: MapStyle = load(path)
		var ids := {}
		for g in style.grounds:
			if g != null:
				ids[g.id] = g.layer
		# 0038: sand and snow are real grounds with their own layer (an edge over every ground below them), all layers distinct
		_check(ids.has(&"sand") and ids.has(&"snow") and style.grounds.size() == MapGen.Ground.SNOW + 1, "%s: sand and snow grounds are in the style" % path)
		_check(style.grounds[MapGen.Ground.SAND].id == &"sand" and style.grounds[MapGen.Ground.SNOW].id == &"snow", "%s: MapGen.Ground.SAND / SNOW index the right grounds" % path)
		var layers := []
		for id in ids:
			if id != &"boss_grass":
				layers.append(ids[id])
		_check(_distinct(layers), "%s: every ground has its own layer (boss grass shares grass's)" % path)
		for g in style.grounds:
			if g == null:
				continue
			for img in GroundBaker.fill_images(g):   # a fill is a full tile: no see-through pixel (sand / snow too)
				for y in 16:
					for x in 16:
						if img.get_pixel(x, y).a != 1.0:
							_check(false, "%s %s: fill pixel (%d, %d) is see-through" % [path, g.id, x, y])
			var tiles := []
			for q in 16:
				tiles.append(GroundBaker.config_tile(g, q))
			if g.layer == 1:   # a dirt fill must hold no grass (Serene Village dirt tiles have tufts: fill_scrub_green)
				for img in GroundBaker.fill_images(g):
					for y in 16:
						for x in 16:
							var c := img.get_pixel(x, y)
							_check(not (c.g > c.r + 0.03), "%s %s: dirt fill has a green pixel" % [path, g.id])
			_check(tiles[3].get_pixel(8, 0).a == 1.0 and tiles[3].get_pixel(8, 15).a == 0.0, "%s %s: top half is ground, bottom half is not" % [path, g.id])
			for q1 in 16:
				for q2 in 16:
					# q bits: NW 1, NE 2, SW 4, SE 8. Side by side (q2 right of q1): q1's NE/SE = q2's NW/SW.
					if ((q1 >> 1) & 1) == (q2 & 1) and ((q1 >> 3) & 1) == ((q2 >> 2) & 1):
						n_pairs += 1
						for y in 16:
							_check(is_equal_approx(tiles[q1].get_pixel(15, y).a, tiles[q2].get_pixel(0, y).a),
								"%s %s: seam left %d | right %d at row %d" % [path, g.id, q1, q2, y])
					# q2 below q1: q1's SW/SE = q2's NW/NE.
					if ((q1 >> 2) & 1) == (q2 & 1) and ((q1 >> 3) & 1) == ((q2 >> 1) & 1):
						n_pairs += 1
						for x in 16:
							_check(is_equal_approx(tiles[q1].get_pixel(x, 15).a, tiles[q2].get_pixel(x, 0).a),
								"%s %s: seam top %d / bottom %d at column %d" % [path, g.id, q1, q2, x])
	print("seam pairs checked: %d" % n_pairs)
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
