extends SceneTree
# The in-water state follows the DRAWN shore, not the cell grid: the dual-grid picture draws the shore's sand a few pixels into its
# water cells, and a player standing on that sand is dry (no water look, no slowdown, F3 "in water: no").
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

var _m: ArenaMap

## Is the picture water at art pixel a? Read from the baked corner tile itself (water = transparent or the water fill).
func _drawn_water(a: Vector2i) -> bool:
	var pp := _m.style.pixel_plains
	var t := pp.tile_size
	var h := t / 2
	var tile := Vector2i(floori(float(a.x + h) / t), floori(float(a.y + h) / t))
	var img: Image = GroundBaker.bake_region(_m.result, _m.style, tile.x, tile.y, 1, 1)["ground"]
	var c := img.get_pixelv(a + Vector2i(h, h) - tile * t)
	var wf := pp.fill_of(PixelPlainsGround.Mat.WATER)
	var same := func(x: Color, y: Color) -> bool: return x.r8 == y.r8 and x.g8 == y.g8 and x.b8 == y.b8
	return c.a8 == 0 or same.call(c, wf)

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	_m = arena.get_node("ArenaMap")
	_m.map_seed = 11
	_m.map_cols = 200
	_m.map_rows = 120
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var res := _m.result
	var ps := float(_m.style.pixel_scale)
	var t := _m.style.pixel_plains.tile_size
	# a shallow cell with dry land west of it, whose drawn sand reaches >= 2 art px into it on the cell's middle row
	var sand_pt := Vector2.ZERO
	var wet_pt := Vector2.ZERO
	for i in res.land.size():
		var c := Vector2i(i % res.cols, i / res.cols)
		if c.x < 4 or c.y < 4 or c.x > res.cols - 5 or c.y > res.rows - 5 or res.shallow[i] != 1 or res.land[i - 1] != 1 or res.shallow[i + 1] != 1:
			continue
		var ay := c.y * t + t / 2
		var edge := -1   # last drawn-land art px of the run that starts at the cell's west edge
		for ax in range(c.x * t, (c.x + 2) * t):
			if _drawn_water(Vector2i(ax, ay)):
				break
			edge = ax
		if edge < c.x * t + 1 or edge >= (c.x + 1) * t - 4:
			continue
		var s := Vector2((edge + 1) * ps - 2.0, (ay + 0.5) * ps)   # on the sand, 2 world px from the drawn water line
		var w := Vector2((edge + 3) * ps + 0.5 * ps, s.y)          # 3 art px past the line, in the water
		if not _drawn_water(Vector2i((w / ps).floor())) or res.shallow[Vector2i((w / _m.cell_px()).floor()).y * res.cols + Vector2i((w / _m.cell_px()).floor()).x] != 1:
			continue
		var clear := true
		for o in res.obstacles:
			if s.distance_to(o["pos"]) < 120.0:
				clear = false
				break
		if clear:
			sand_pt = s
			wet_pt = w
			break
	_check(sand_pt != Vector2.ZERO, "found a shore where the drawn sand reaches into a shallow cell (sand %s, water %s)" % [sand_pt, wet_pt])
	var sc := Vector2i((sand_pt / _m.cell_px()).floor())
	_check(res.land[sc.y * res.cols + sc.x] == 0, "the sand point lies in a water cell (the old cell rule called it water)")
	_check(not _drawn_water(Vector2i((sand_pt / ps).floor())), "the picture shows sand under the sand point")
	_check(_m.water_kind_at(sand_pt) == MapGen.WaterKind.NONE, "water_kind_at: drawn sand 2 px from the water line is dry")
	_check(_m.water_kind_at(wet_pt) == MapGen.WaterKind.SHALLOW, "water_kind_at: drawn shallow water is shallow")
	# every drawn pixel of this shore agrees with water_kind_at (a 3 x 3 cell window around it)
	var agree := true
	for ay in range(sc.y * t - t, sc.y * t + 2 * t):
		for ax in range(sc.x * t - t, sc.x * t + 2 * t):
			var pos := (Vector2(ax, ay) + Vector2(0.5, 0.5)) * ps
			agree = agree and (_m.water_kind_at(pos) != MapGen.WaterKind.NONE) == _drawn_water(Vector2i(ax, ay))
	_check(agree, "water_kind_at matches the picture on every pixel around the shore")
	# the Swimmer (speed, WaterFx, F3 status) follows
	var player: CharacterBody2D = arena.get_node("Player")
	var sw: Swimmer = player.get_node("Swimmer")
	var fx: WaterFx = player.get_node("Visual/WaterFx")
	for spot in [[wet_pt, true], [sand_pt, false], [wet_pt, true]]:
		player.global_position = spot[0]
		player.velocity = Vector2.ZERO
		await physics_frame
		await physics_frame
		await process_frame
		var want: bool = spot[1]
		_check(sw.in_water == want and fx.in_water == want and sw.status_text().begins_with("in water: " + ("yes" if want else "no")) and is_equal_approx(sw.speed_scale(), sw.water_speed_scale if want else 1.0),
			"Swimmer + WaterFx + F3 status on the %s point: in water %s (%s)" % ["water" if want else "sand", want, sw.status_text()])
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
