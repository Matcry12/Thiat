extends SceneTree
## Writes one picture per ground into assets/game/map/pixel_plains/ground/ (dirt, grass_light, grass_dark, sand, snow, cobble, boss, gravel).
## Same size and cell layout as tiles.png (the pack's sheet, which stays in the game: pack pairs, quarters and edge shapes still come from it).
## Each sheet holds, in the ground's own colours: its fill tiles (plain_* / variants_* cells) and a 4-colour swatch (fill, highlight, outline,
## shade; PixelPlainsBaker.SWATCH_CELL). The game reads these files (PixelPlainsBaker.palette, _fill); redraw one and the map changes.
## Re-running rebuilds all seven files, so a hand-drawn change is lost: draw in the file, do not re-run unless the layout changes.
##   timeout 300 godot --headless --script tools/bake_ground_art.gd
## The test only checks the sheets exist, load and are readable (a redrawn sheet must keep passing); it does not compare them with build().
const SRC := "res://assets/game/map/pixel_plains/tiles.png"
const OUT := "res://assets/game/map/pixel_plains/ground/"
const PP := "res://data/maps/ground_pixel_plains.tres"
## The pack's dirt colours that sand / snow replace: fill, darker patch, shadow.
const DIRT_SRC: Array[Color] = [Color8(240, 181, 65), Color8(235, 150, 61), Color8(189, 106, 98)]
## Authoring colours of every ground: [fill, highlight, outline, shade] of its edge (shade = shadow cast ONTO it), patch (recolour only).
const SPECS := [
	{"file": "dirt", "src": 0, "edge": [Color8(240, 181, 65), Color8(250, 208, 112), Color8(150, 100, 60), Color8(189, 106, 98)]},
	{"file": "grass_light", "src": 1, "edge": [Color8(99, 171, 63), Color8(164, 196, 67), Color8(42, 89, 79), Color8(59, 125, 79)]},
	{"file": "grass_dark", "src": 2, "edge": [Color8(59, 125, 79), Color8(99, 171, 63), Color8(42, 89, 79), Color8(42, 89, 79)]},
	{"file": "sand", "src": 0, "edge": [Color8(236, 214, 150), Color8(248, 232, 182), Color8(150, 112, 84), Color8(170, 134, 100)], "patch": Color8(222, 192, 125)},
	{"file": "snow", "src": 0, "edge": [Color8(240, 246, 252), Color8(255, 255, 255), Color8(150, 170, 204), Color8(214, 228, 242)], "patch": Color8(214, 228, 242)},
	# cobble starts as dirt, gravel as sand: redraw them to tell them apart (borders of both still use the dirt / sand swatch)
	{"file": "cobble", "src": 0, "edge": [Color8(240, 181, 65), Color8(250, 208, 112), Color8(150, 100, 60), Color8(189, 106, 98)]},
	{"file": "gravel", "src": 0, "edge": [Color8(236, 214, 150), Color8(248, 232, 182), Color8(150, 112, 84), Color8(170, 134, 100)], "patch": Color8(222, 192, 125)},
]


func _init() -> void:
	var made := build()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for f in made:
		(made[f] as Image).save_png(ProjectSettings.globalize_path(OUT + f + ".png"))
	print("bake_ground_art: wrote %d sheets to %s" % [made.size(), OUT])
	quit()


static func _same(px: Color, c: Color) -> bool:
	return px.r8 == c.r8 and px.g8 == c.g8 and px.b8 == c.b8


static func _rgb(c: Color, a: int) -> Color:
	return Color8(c.r8, c.g8, c.b8, a)


## file name (no extension) -> Image, every sheet of SPECS.
static func build() -> Dictionary:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	sheet.convert(Image.FORMAT_RGBA8)
	var pp: PixelPlainsGround = load(PP)
	var t := pp.tile_size
	var out := {}
	for spec in SPECS:
		var img := Image.create_empty(sheet.get_width(), sheet.get_height(), false, Image.FORMAT_RGBA8)
		var src: int = spec["src"]
		var fills: Array[Vector2i] = []
		fills.append_array(pp.plain_of(src))
		fills.append_array(pp.variants_of(src))
		var dst: Array[Color] = [spec["edge"][0], spec.get("patch", spec["edge"][0]), spec["edge"][3]]
		for v in fills:
			var r := Rect2i(v.x * t, v.y * t, t, t)
			img.blit_rect(sheet, r, r.position)
			if spec.has("patch"):   # dirt art with its 3 colours swapped (sand, snow)
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						var px := img.get_pixel(x, y)
						for k in 3:
							if _same(px, DIRT_SRC[k]):
								img.set_pixel(x, y, _rgb(dst[k], px.a8))
								break
		var edge: Array = spec["edge"]
		for k in 4:   # swatch: fill, highlight, outline, shade
			var o := PixelPlainsBaker.SWATCH_CELL * t + Vector2i(k * PixelPlainsBaker.SWATCH_PX, 0)
			for y in PixelPlainsBaker.SWATCH_PX:
				for x in PixelPlainsBaker.SWATCH_PX:
					img.set_pixel(o.x + x, o.y + y, _rgb(edge[k], 255))
		out[spec["file"]] = img
	return out
