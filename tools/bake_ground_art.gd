extends SceneTree
## Writes one picture per ground into assets/game/map/pixel_plains/ground/ (dirt, grass_light, grass_dark, sand, snow, cobble, boss, gravel).
## Same size and cell layout as tiles.png (the pack's sheet, which stays in the game: pack pairs, quarters and edge shapes still come from it).
## Each sheet holds, in the ground's own colours: its fill tiles (plain_* / variants_* cells) and a 4-colour swatch (fill, highlight, outline,
## shade; PixelPlainsBaker.SWATCH_CELL). The game reads these files (PixelPlainsBaker.palette, _fill); redraw one and the map changes.
## Re-running rebuilds all seven files, so a hand-drawn change is lost: draw in the file, do not re-run unless the layout changes.
##   timeout 300 godot --headless --script tools/bake_ground_art.gd
## `-- tiles`: writes ONLY the edge tiles (free cells 0..3 of rows 1..4 of the five ground sheets, slot s = cell (s % 4, 1 + s / 4)), `ground/foam.png`
## and `ground/water.png` from the look the code used to draw (decision 0069, docs/wiki/ground-tileset-algorithm.md). Fill cells and the swatch are not touched.
##   timeout 300 godot --headless --script tools/bake_ground_art.gd -- tiles
## Re-running it overwrites hand-drawn edge slots / foam / water.
## `-- biomes` (after `tiles`, also combinable: `-- tiles biomes`): one copy of the 7 sheets + foam + water per biome in
## assets/game/map/pixel_plains/biomes/<biome>/ground/ (BiomeArt reads them). Only MISSING files are written, `--force` overwrites. Then `godot --headless --import`.
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


## The numbers the game used to read from exports; now only this tool knows them (the pictures hold the result).
const QUIET_DARKEN := 0.08                      ## flat border: outline = fill this much darker
const FOAM_COLOUR := Color8(218, 246, 252)
const FOAM_LIT := 6                             ## lit pixels of every 8 along the shore, the lit part moves 1 px per frame
const WATER_FILL := Color8(112, 210, 228)
const MARK_LIGHT_A := 34                        ## wave mark lightness in the first / second half of its 8 frame loop
const MARK_LIGHT_B := 14
const MARK_VARIANTS := 16
const MARK_BLOCK := 32
const MARK_LEN_MIN := 3
const MARK_LEN_MAX := 5
const EDGE_FILES: Array[String] = ["dirt", "grass_light", "grass_dark", "sand", "snow"]   ## index = PixelPlainsGround.Mat


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if "tiles" in args or "biomes" in args:
		if "tiles" in args:
			bake_tiles()
		if "biomes" in args:
			bake_biomes("--force" in args)
		quit()
		return
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


static func _png(img: Image, file: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT + file + ".png"))


static func _cell_image(rgba: PackedByteArray, t: int) -> Image:
	return Image.create_from_data(t, t, false, Image.FORMAT_RGBA8, rgba)


## Edge slots + foam.png + water.png (see the header).
static func bake_tiles() -> void:
	var pp: PixelPlainsGround = load(PP)
	var t := pp.tile_size
	var c := PixelPlainsBaker._cache(pp)
	var none := Color(0, 0, 0, 0)
	for mat in EDGE_FILES.size():
		var img := Image.load_from_file(ProjectSettings.globalize_path(OUT + EDGE_FILES[mat] + ".png"))
		img.convert(Image.FORMAT_RGBA8)
		var fill := PixelPlainsBaker.palette(pp, mat)[0]
		var outline := Color8(int(fill.r8 * (1.0 - QUIET_DARKEN)), int(fill.g8 * (1.0 - QUIET_DARKEN)), int(fill.b8 * (1.0 - QUIET_DARKEN)))
		img.fill_rect(Rect2i(0, t, 4 * t, 4 * t), none)
		for s in range(1, 15):
			var ly := PixelPlainsBaker._layer(c, s, fill, fill, outline, none, mat == PixelPlainsGround.Mat.SAND)
			img.blit_rect(_cell_image(ly["rgba"], t), Rect2i(0, 0, t, t), Vector2i((s % 4) * t, (1 + s / 4) * t))
		img.fill_rect(Rect2i(3 * t, 4 * t, t, t), fill)   # slot 15: the flat base
		_png(img, EDGE_FILES[mat])
	# foam.png: 8 frames of 4x4 slots (a slot = a sand mask)
	var foam := Image.create_empty(8 * 4 * t, 4 * t, false, Image.FORMAT_RGBA8)
	var sand := PixelPlainsBaker.palette(pp, PixelPlainsGround.Mat.SAND)[0]
	for s in range(1, 15):
		var flags: PackedByteArray = PixelPlainsBaker._layer(c, s, sand, sand, sand, none, true)["foam"]
		for f in 8:
			for y in t:
				for x in t:
					if flags[y * t + x] == 1 and posmod(x + y - f, 8) < FOAM_LIT:
						foam.set_pixel(f * 4 * t + (s % 4) * t + x, (s / 4) * t + y, FOAM_COLOUR)
	_png(foam, "foam")
	# water.png: cell (0, 0) = flat water; then one row of 8 frames (MARK_BLOCK px each) per wave mark variant
	var water := Image.create_empty(8 * MARK_BLOCK, t + MARK_VARIANTS * MARK_BLOCK, false, Image.FORMAT_RGBA8)
	water.fill_rect(Rect2i(0, 0, t, t), WATER_FILL)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260101
	for v in MARK_VARIANTS:
		var mx := rng.randi_range(2, MARK_BLOCK - 10)
		var my := rng.randi_range(2, MARK_BLOCK - 4)
		var ln := rng.randi_range(MARK_LEN_MIN, MARK_LEN_MAX)
		for f in 8:
			var o := Vector2i(f * MARK_BLOCK, t + v * MARK_BLOCK)
			water.fill_rect(Rect2i(o, Vector2i(MARK_BLOCK, MARK_BLOCK)), WATER_FILL)
			var shift := 1 if f >= 2 and f < 6 else 0
			var add := MARK_LIGHT_A if f < 4 else MARK_LIGHT_B
			var col := Color8(mini(WATER_FILL.r8 + add, 255), mini(WATER_FILL.g8 + add, 255), mini(WATER_FILL.b8 + add, 255))
			for x in ln:
				water.set_pixel(o.x + mx + shift + x, o.y + my, col)
	_png(water, "water")
	print("bake_ground_art tiles: edge slots in %d sheets, foam.png, water.png" % EDGE_FILES.size())


## Byte copies of the base ground files into biomes/<biome>/ground/ (missing ones only, or all with force).
static func bake_biomes(force: bool) -> void:
	var wrote := 0
	var kept := 0
	for b in BiomeArt.NAMES:
		var dir := "%s/%s/ground" % ["res://assets/game/map/pixel_plains/biomes", b]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		for f in BiomeArt.GROUND_FILES:
			var dst := "%s/%s.png" % [dir, f]
			if FileAccess.file_exists(dst) and not force:
				kept += 1
				continue
			var out := FileAccess.open(dst, FileAccess.WRITE)
			out.store_buffer(FileAccess.get_file_as_bytes(OUT + f + ".png"))
			out.close()
			wrote += 1
	print("bake_ground_art biomes: wrote %d, kept %d (force %s)" % [wrote, kept, force])
