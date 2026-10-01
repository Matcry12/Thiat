extends SceneTree
# Pure map logic, no scene: deterministic from the seed; every dirt patch is a rectangle the tile set
# can draw; no missing tile; rocks stay out of the fight zone and the spawns and never wall floor off.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		print("FAIL: ", msg)
		_ok = false

func _params(patches := 5) -> MapGen.Params:
	var p := MapGen.Params.new()
	p.patch_count = patches
	p.obstacle_count = 8
	p.zone = Rect2(136, 94, 880, 460)
	p.spawns = PackedVector2Array([Vector2(409, 321), Vector2(960, 324), Vector2(700, 130)])
	p.player_spawn = Vector2(409, 321)
	p.patch_noise_threshold = 0.3    # easy acceptance: stress the spacing rule, not the noise
	p.dark_grass_chance = 0.3
	return p

func _init() -> void:
	var style: MapStyle = load("res://data/maps/grass.tres")
	var p := _params()

	# same seed -> identical, different seed -> different
	var a := MapGen.generate(style, p, 7)
	var b := MapGen.generate(style, p, 7)
	var c := MapGen.generate(style, p, 8)
	_check(a.patches == b.patches and a.grass == b.grass and a.dirt == b.dirt, "same seed, same ground")
	_check(a.deco == b.deco and a.obstacles == b.obstacles and a.border == b.border, "same seed, same props")
	_check(a.patches != c.patches or a.grass != c.grass, "different seed, different map")

	var patch_total := 0
	var rock_total := 0
	for sd in range(1, 41):
		var r := MapGen.generate(style, _params(2 + sd % 6), sd)
		patch_total += r.patches.size()
		rock_total += r.obstacles.size()
		_legal_ground(style, p, r)
		_fair_rocks(p, r)
	_check(patch_total > 40, "patches are actually produced (%d)" % patch_total)
	_check(rock_total > 40, "rocks are actually produced (%d)" % rock_total)

	# The big map (72x40): same rules, rocks anywhere outside the zone and the spawns.
	var big := _params(15)
	big.cols = 72
	big.rows = 40
	big.world = Vector2(2304, 1280)
	big.obstacle_count = 23
	big.zone = Rect2(1219, 410, 880, 460)
	big.spawns = PackedVector2Array([Vector2(323, 640), Vector2(1879, 640), Vector2(613, 450)])
	big.player_spawn = Vector2(323, 640)
	var big_rocks := 0
	var left_rocks := 0
	for sd in range(1, 11):
		var r := MapGen.generate(style, big, sd)
		big_rocks += r.obstacles.size()
		for o in r.obstacles:
			left_rocks += 1 if o["pos"].x < 1152 else 0
		_legal_ground(style, big, r)
		_fair_rocks(big, r)
	_check(big_rocks > 150 and left_rocks > 50, "big map: rocks placed all over (%d, %d on the left half)" % [big_rocks, left_rocks])

	# The reachability check itself: a ring of rocks around the player must be refused.
	var ring: Array[Dictionary] = []
	for i in 12:
		ring.append({"pos": p.player_spawn + Vector2.RIGHT.rotated(TAU * i / 12.0) * 60.0, "radius": 24.0})
	_check(not MapGen.floor_reachable(p, ring), "a ring of rocks around the spawn is caught")
	_check(MapGen.floor_reachable(p, []), "empty arena is fully reachable")

	print("patches %d, rocks %d over 40 seeds" % [patch_total, rock_total])
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)

func _legal_ground(style: MapStyle, p: MapGen.Params, r: MapGen.Result) -> void:
	var grass_ok := {}
	for v in style.grass_fills + style.grass_dark_fills:
		grass_ok[v] = true
	for i in r.patches.size():
		var x := r.patches[i]
		_check(x.size.x >= 2 and x.size.y >= 2, "patch >= 2x2")
		_check(x.position.x >= 1 and x.position.y >= 1 and x.end.x <= p.cols - 1 and x.end.y <= p.rows - 1, "patch keeps its ring on the grid")
		for j in range(i + 1, r.patches.size()):
			var y := r.patches[j]
			var gap_x := maxi(y.position.x - (x.end.x - 1) - 1, x.position.x - (y.end.x - 1) - 1)
			var gap_y := maxi(y.position.y - (x.end.y - 1) - 1, x.position.y - (y.end.y - 1) - 1)
			_check(maxi(gap_x, gap_y) >= 2, "patches %s and %s have >= 2 grass cells between" % [x, y])
	for y in p.rows:
		for x in p.cols:
			var cell := Vector2i(x, y)
			_check(r.dirt.has(cell), "dirt under every cell")
			var k := r.kind[y * p.cols + x]
			if k == MapGen.FILL:
				_check(r.grass.has(cell) and grass_ok.has(r.grass[cell]), "full grass cell has a fill tile")
			elif k == MapGen.RING:
				_check(r.grass.has(cell) and not grass_ok.has(r.grass[cell]), "ring cell has an edge tile")
			else:
				var inside := false
				for pt in r.patches:
					if pt.has_point(cell):
						inside = true
						var corner := (x == pt.position.x or x == pt.end.x - 1) and (y == pt.position.y or y == pt.end.y - 1)
						_check(r.grass.has(cell) == corner, "only hole corners carry a grass tile")
				_check(inside, "hole cell belongs to a patch")
	# every edge tile used must be one the style defines (variant A or B)
	var defined := {}
	for role in style.edge_tiles:
		for v in style.variant_count():
			defined[style.edge(role, v)] = true
	for cell in r.grass:
		var t: Vector2i = r.grass[cell]
		_check(grass_ok.has(t) or defined.has(t), "tile %s exists in the table" % t)

func _fair_rocks(p: MapGen.Params, r: MapGen.Result) -> void:
	var size := p.size_px()
	for o in r.obstacles:
		var pos: Vector2 = o["pos"]
		var rad: float = o["radius"]
		var closest := Vector2(clampf(pos.x, p.zone.position.x, p.zone.end.x), clampf(pos.y, p.zone.position.y, p.zone.end.y))
		_check(pos.distance_to(closest) >= rad, "rock outside the FightZone")
		for s in p.spawns:
			_check(pos.distance_to(s) >= p.spawn_clear_radius + rad, "rock clear of a spawn")
		_check(pos.x - rad >= p.cell and pos.y - rad >= p.cell and pos.x + rad <= size.x - p.cell and pos.y + rad <= size.y - p.cell, "rock inside the walls")
	_check(MapGen.floor_reachable(p, r.obstacles), "all floor reachable")
