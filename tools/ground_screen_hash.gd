extends SceneTree
## What the ground looks like on screen, as one hash per seed and animation frame (ground-tileset-algorithm.md "Test plan"):
## per 64 tile page: flat water colour, the ground picture over it, then the lit foam of frame f. The open-water wave marks are NOT
## decoded (every pixel the ground leaves free stays the flat water colour), so the hash does not change when marks move.
## The decoder reads foam.png (the old one, before the pictures, read R = 1 beach foam lit by (x + y - f) mod 8 < 6 and R = 3 shore water).
## Run it on the old code and on the new code: the lines must be equal.
##   timeout 900 godot --headless --script tools/ground_screen_hash.gd -- <out.txt>


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var lines: PackedStringArray = []
	for s in [1, 11, 42]:
		var arena = load("res://scenes/arena.tscn").instantiate()
		root.add_child(arena)
		var m: ArenaMap = arena.get_node("ArenaMap")
		m.map_seed = s
		m._rebuild_queued = false
		var r := MapGen.generate(m.style, m.make_params(), s)
		var pp: PixelPlainsGround = m.style.pixel_plains
		var water := pp.fill_of(PixelPlainsGround.Mat.WATER)
		var pic := pp.foam_texture.get_image()
		pic.convert(Image.FORMAT_RGBA8)
		var ctx: Array[HashingContext] = []
		for f in 8:
			var h := HashingContext.new()
			h.start(HashingContext.HASH_MD5)
			ctx.append(h)
		var step := 64
		for cj in range(0, r.rows, step):
			for ci in range(0, r.cols, step):
				var d: Dictionary = GroundBaker.bake_region(r, m.style, ci, cj, mini(step, r.cols - ci), mini(step, r.rows - cj))
				var g: Image = d["ground"]
				var base := Image.create_empty(g.get_width(), g.get_height(), false, Image.FORMAT_RGBA8)
				base.fill(water)
				base.blend_rect(g, Rect2i(Vector2i.ZERO, g.get_size()), Vector2i.ZERO)
				var marks := _foam_pixels(d["foam"])
				for f in 8:
					var screen := base.duplicate() as Image
					_foam(screen, marks, f, pic)
					ctx[f].update(screen.get_data())
		for f in 8:
			lines.append("seed %d frame %d screen %s" % [s, f, ctx[f].finish().hex_encode()])
		arena.queue_free()
		await process_frame
	var fh := FileAccess.open(out, FileAccess.WRITE)
	fh.store_string("\n".join(lines) + "\n")
	print("\n".join(lines))
	quit()


## Pixels the animation mask marks: {x, y, picture x, picture y} flattened. R = 1 foam; G / B = where its colour sits in frame 0 of foam.png.
func _foam_pixels(anim: Image) -> PackedInt32Array:
	var out := PackedInt32Array()
	var d := anim.get_data()
	var w := anim.get_width()
	var o := d.find(1)
	while o >= 0:
		if o % 4 == 0:
			var p := o / 4
			out.append_array(PackedInt32Array([p % w, p / w, d[o + 1], d[o + 2]]))
		o = d.find(1, o + 1)
	return out


## Frame f: where foam.png has a pixel in that frame, its colour goes on screen (what terrain_anim.gdshader does).
func _foam(screen: Image, marks: PackedInt32Array, f: int, pic: Image) -> void:
	for n in marks.size() / 4:
		var c := pic.get_pixel(marks[n * 4 + 2] + f * 64, marks[n * 4 + 3])
		if c.a > 0.0:
			screen.set_pixel(marks[n * 4], marks[n * 4 + 1], c)
