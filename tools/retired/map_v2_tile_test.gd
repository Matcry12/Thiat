extends SceneTree
## Edge test picture (decision 0033): every ground pair drawn with a square, a plus, a staircase, a 1-cell hole,
## a 1-cell island, a 2-wide path with turns and a 1-wide strip. Works headless (no GPU, no tint).
##   godot --headless --script tools/retired/map_v2_tile_test.gd -- <out.png> <style.tres> [scale]
const W := 38
const H := 30

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var style: MapStyle = load(args[1])
	var scale := int(args[2]) if args.size() > 2 else 3
	# pair: [label, top ground, base ground, water background?]
	var pairs := [
		["grass over dirt", MapGen.Ground.GRASS, MapGen.Ground.DIRT, false],
		["grass over cobble", MapGen.Ground.GRASS, MapGen.Ground.COBBLE, false],
		["grass over water", MapGen.Ground.GRASS, MapGen.Ground.WATER, true],
		["dirt over water", MapGen.Ground.DIRT, MapGen.Ground.WATER, true],
	]
	var t := 16
	var bw := (W + 1) * t
	var bh := (H + 1) * t
	var sheet := Image.create_empty(bw * 2 + 8, bh * 2 + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.85, 0.2, 0.85))
	for k in pairs.size():
		var pr: Array = pairs[k]
		var res := MapGen.Result.new()
		res.cols = W
		res.rows = H
		res.seed = 5
		res.ground.resize(W * H)
		res.area.resize(W * H)
		res.ground.fill(pr[2])
		_shapes(res.ground, pr[1], pr[2])
		var look := {"tint": [Color.WHITE, Color.WHITE, Color.WHITE] as Array[Color], "sat": [1.0, 1.0, 1.0], "shade_variation": 0.0, "shade_scale": 0.05}
		var img: Image = GroundBaker.bake(res, style, look)["ground"]
		var cell := Image.create_empty(bw, bh, false, Image.FORMAT_RGBA8)
		cell.fill(Color(0.2, 0.5, 0.85) if pr[3] else Color(0.85, 0.2, 0.85))
		cell.blend_rect(img, Rect2i(0, 0, bw, bh), Vector2i.ZERO)
		sheet.blit_rect(cell, Rect2i(0, 0, bw, bh), Vector2i((k % 2) * (bw + 8), (k / 2) * (bh + 8)))
	sheet.resize(sheet.get_width() * scale, sheet.get_height() * scale, Image.INTERPOLATE_NEAREST)
	sheet.save_png(args[0])
	quit(0)


func _put(g: PackedByteArray, x: int, y: int, v: int) -> void:
	if x >= 1 and y >= 1 and x < W - 1 and y < H - 1:
		g[y * W + x] = v


func _rect(g: PackedByteArray, x: int, y: int, w: int, h: int, v: int) -> void:
	for yy in h:
		for xx in w:
			_put(g, x + xx, y + yy, v)


func _shapes(g: PackedByteArray, top: int, base: int) -> void:
	_rect(g, 2, 2, 8, 8, top)                       # big square
	_rect(g, 14, 2, 3, 9, top)                      # plus: vertical arm
	_rect(g, 11, 5, 9, 3, top)                      # plus: horizontal arm
	for k in 8:                                     # diagonal staircase (filled below-left)
		_rect(g, 24, 2 + k, k + 1, 1, top)
	_rect(g, 2, 14, 9, 9, top)                      # 1-cell hole
	_put(g, 6, 18, base)
	_put(g, 14, 18, top)                            # 1-cell island
	_rect(g, 17, 14, 15, 11, top)                   # 2-wide path with turns (base ground through top)
	_rect(g, 18, 16, 8, 2, base)
	_rect(g, 24, 16, 2, 6, base)
	_rect(g, 24, 20, 7, 2, base)
	_rect(g, 2, 26, 20, 1, top)                     # thin 1-wide strip
