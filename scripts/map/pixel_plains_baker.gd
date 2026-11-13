class_name PixelPlainsBaker
extends RefCounted
## The Pixel Plains ground picture (GroundBaker.bake_region calls this when MapStyle.pixel_plains is set). Same dual grid as the
## old baker (tile (i, j) sits on the corner of cells (i-1,j-1) (i,j-1) (i-1,j) (i,j); the picture is one tile bigger than the map),
## but every tile is built from the pack's 8x8 quarters by the case tables in PixelPlainsGround, and it is the python reference
## tools/asset_viewer/pixel_plains_tiles.py `render()` pixel for pixel (tests/test_pixel_plains_ground.gd checks it).
## Rules, like the reference: 4 cells of one material = a fill tile (hash of the corner picks it, so chunks match);
## 2 materials with a table = the table's quarters; water in the corner or any other mix = each quarter shows its own cell's plain quarter.
## Map rule on top: a dark cell with dirt within `dark_dirt_gap` cells becomes light grass.
## Ground tile set (decision 0069): a corner that holds sand, snow or water (or any mix, all_flat) is stacked by _compose() from PICTURES: the grounds
## of the corner sorted by priority, the lowest one is its base slot (water: the flat cell of ground/water.png), every higher one is its edge slot of
## its sheet drawn over it. The picture "foam" is the ANIMATION MASK (RGBA8, R = 1 foam pixel, G / B = x / y of its colour in frame 0 of ground/foam.png)
## that terrain_anim.gdshader reads per frame; the open-water wave marks are rows of water.png chosen by terrain_water_flat.gdshader.
## tools/bake_ground_art.gd -- tiles draws the pictures once from _layer() (the old code look). Everything is tile local: a chunk baked alone equals the whole map.

class Cache:
	var pp: PixelPlainsGround
	var sheet: Image
	var quarters := {}   ## Vector3i -> 8x8 Image
	var fills := {}      ## Vector2i -> 16x16 Image
	var tiles := {}      ## pair * 16 + mask -> composed 16x16 Image
	var composed := {}   ## Vector4i of the 4 materials -> {img, anim, has_anim, land}
	var roles := {}      ## mask -> PackedByteArray of the role of every pixel of the pack's light_on_dirt tile
	var skins := {}      ## Skin -> that ground's sheet Image (assets/game/map/pixel_plains/ground/)
	var pal := {}        ## material -> PackedColorArray [fill, highlight, outline, shade] read from its sheet
	var foam_pic: Image  ## ground/foam.png: 8 frames of 4x4 slots (slot = sand mask), foam colour where lit
	var water_pic: Image ## ground/water.png: cell (0,0) = flat water, below it one row of 8 frames per wave mark variant
	var slots := {}      ## (biome + 1) * 256 + material * 16 + slot -> 16x16 Image of the edge block of that ground's sheet
	var foam_any := {}   ## (biome + 1) * 16 + mask -> PackedByteArray, 1 = lit in some frame of that biome's foam.png
	var grounds := {}    ## "file/biome" -> Image of a ground file of a biome (or the base file)

static var _caches := {}
static var _from_files := false   ## after reload_pictures(): read the PNGs from disk (no editor re-import needed)
## Layout of the ground pictures (art facts, not tuning): slot s of a ground sheet = cell (s % 4, 1 + s / 4); foam.png frames are 4 x 4 slots wide;
## water.png has the flat water cell on top, then wave mark variants of MARK_BLOCK px.
const EDGE_ROW := 1
const FOAM_FRAMES := 8
const WATER_TOP := 16
const MARK_BLOCK := 32


static func clear_cache() -> void:
	_caches.clear()


## F3 "Reload ground pictures": forget everything and read the PNGs from disk again.
static func reload_pictures() -> void:
	_from_files = true
	_caches.clear()
	BiomeArt.clear_cache()


static func _pic(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var img: Image = null
	if _from_files and tex.resource_path.begins_with("res://"):
		img = Image.load_from_file(ProjectSettings.globalize_path(tex.resource_path))
	if img == null:
		img = tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


## Colour of flat water: pixel (0, 0) of water.png.
static func water_colour(pp: PixelPlainsGround) -> Color:
	var w := _cache(pp).water_pic
	return Color(1, 0, 1) if w == null else Color8(w.get_pixel(0, 0).r8, w.get_pixel(0, 0).g8, w.get_pixel(0, 0).b8)


## The two pictures the shaders sample (TerrainVisual.begin_island).
static func shader_pictures(pp: PixelPlainsGround) -> Dictionary:
	var c := _cache(pp)
	var none := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)   # a missing picture: nothing (warned in _cache)
	return {"foam_pic": ImageTexture.create_from_image(c.foam_pic if c.foam_pic != null else none), "water_pic": ImageTexture.create_from_image(c.water_pic if c.water_pic != null else none)}


static func _cache(pp: PixelPlainsGround) -> Cache:
	var key := pp.get_instance_id()
	if _caches.has(key):
		return _caches[key]
	var c := Cache.new()
	c.pp = pp
	c.sheet = pp.texture.get_image()
	c.sheet.convert(Image.FORMAT_RGBA8)
	c.foam_pic = _pic(pp.foam_texture)
	c.water_pic = _pic(pp.water_texture)
	if c.foam_pic == null or c.water_pic == null:
		push_warning("PixelPlainsGround: foam_texture / water_texture is not set: no beach foam, no water base (run tools/bake_ground_art.gd -- tiles)")
	_caches[key] = c
	return c


static func _quarter(c: Cache, e: Vector3i) -> Image:
	if not c.quarters.has(e):
		var h := c.pp.tile_size / 2
		c.quarters[e] = c.sheet.get_region(Rect2i(e.x * c.pp.tile_size + (e.z & 1) * h, e.y * c.pp.tile_size + (e.z >> 1) * h, h, h))
	return c.quarters[e]


## The picture of a ground file in a biome (biome -1 or a missing biome file = the base file). file: BiomeArt.GROUND_FILES name, base: its texture in the resource.
static func _ground_img(c: Cache, file: String, base: Texture2D, biome: int) -> Image:
	var key := "%s/%d" % [file, biome]
	if not c.grounds.has(key):
		var tex := BiomeArt.ground_texture(file, biome)
		c.grounds[key] = _pic(tex if tex != null else base)
	return c.grounds[key]


static func _skin_sheet(c: Cache, skin: int, biome := -1) -> Image:
	var base := c.pp.sheet_of(skin)
	if base == null:
		push_warning("PixelPlainsGround: sheet %d is not set, using the dirt sheet (or tiles.png)" % skin)
		base = c.pp.sheet_dirt if c.pp.sheet_dirt != null else c.pp.texture
	return _ground_img(c, BiomeArt.GROUND_FILES[skin], base, biome)


## A whole 16 px fill tile from the sheet of a ground (skin).
static func _fill(c: Cache, skin: int, v: Vector2i, biome := -1) -> Image:
	var key := Vector4i(skin, v.x, v.y, biome)
	if not c.fills.has(key):
		var t := c.pp.tile_size
		c.fills[key] = _skin_sheet(c, skin, biome).get_region(Rect2i(v.x * t, v.y * t, t, t))
	return c.fills[key]


## pair 0 = light on dirt, 1 = dark on light; -1 = not in the pack.
static func _pair(pp: PixelPlainsGround, a: int, b: int) -> int:
	var up := a if pp.layer_of(a) > pp.layer_of(b) else b
	var lo := b if up == a else a
	if up == PixelPlainsGround.Mat.LIGHT and lo == PixelPlainsGround.Mat.DIRT:
		return 0
	if up == PixelPlainsGround.Mat.DARK and lo == PixelPlainsGround.Mat.LIGHT:
		return 1
	return -1


## The composed tile of a pair and mask (NW 1, NE 2, SW 4, SE 8, set = the upper material).
static func _case_tile(c: Cache, pair: int, up: int, lo: int, mask: int) -> Image:
	var key := pair * 16 + mask
	if c.tiles.has(key):
		return c.tiles[key]
	c.tiles[key] = build_case(c, c.sheet, pair, up, lo, mask)
	return c.tiles[key]


## The tile of a pair and mask built from the quarters of `sheet` (the pack's tiles.png, or a ground sheet to read its colours).
## edges_only: the plain upper / lower quarters stay empty (palette reads only the edge cells).
static func build_case(c: Cache, sheet: Image, pair: int, up: int, lo: int, mask: int, edges_only := false) -> Image:
	var pp := c.pp
	var table: Array[Vector3i] = pp.table_light_on_dirt if pair == 0 else pp.table_dark_on_light
	var t := pp.tile_size
	var h := t / 2
	var img := Image.create_empty(t, t, false, Image.FORMAT_RGBA8)
	for qd in 4:
		var e := table[mask * 4 + qd]
		if edges_only and e.x < 0:
			continue
		if e.x == PixelPlainsGround.UPPER:
			e = pp.quarter_of(up)
		elif e.x == PixelPlainsGround.LOWER:
			e = pp.quarter_of(lo)
		var q := sheet.get_region(Rect2i(e.x * t + (e.z & 1) * h, e.y * t + (e.z >> 1) * h, h, h))
		img.blit_rect(q, Rect2i(0, 0, h, h), Vector2i((qd & 1) * h, (qd >> 1) * h))
	return img


## Material per cell (-1 water) of the window x in [x0, x0 + w), y in [y0, y0 + h), before the map rule. Off the map = water.
static func _raw(res: MapGen.Result, pp: PixelPlainsGround, x0: int, y0: int, w: int, h: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(w * h)   # value = material + 1 (0 = water)
	var has_biome := not res.biome.is_empty()
	for ly in h:
		var y := y0 + ly
		if y < 0 or y >= res.rows:
			continue
		for lx in w:
			var x := x0 + lx
			if x < 0 or x >= res.cols:
				continue
			var i := y * res.cols + x
			out[ly * w + lx] = pp.material_of(res.ground[i], res.biome[i] if has_biome else 0) + 1
	return out


## The cells the pieces look at: x in [ci0 - 1, ci0 + tiles_w - 1] (tiles_w + 1 cells), y likewise, with the map rule applied.
static func cell_materials(res: MapGen.Result, pp: PixelPlainsGround, ci0: int, cj0: int, tiles_w: int, tiles_h: int) -> PackedByteArray:
	var gap := pp.dark_dirt_gap
	var pw := tiles_w + 1
	var ph := tiles_h + 1
	var rw := pw + 2 * gap
	var raw := _raw(res, pp, ci0 - 1 - gap, cj0 - 1 - gap, rw, ph + 2 * gap)
	var dark := PixelPlainsGround.Mat.DARK + 1
	var dirt := PixelPlainsGround.Mat.DIRT + 1
	var out := PackedByteArray()
	out.resize(pw * ph)
	for ly in ph:
		for lx in pw:
			var m := raw[(ly + gap) * rw + lx + gap]
			if m == dark:
				for dy in range(-gap, gap + 1):
					for dx in range(-gap, gap + 1):
						if raw[(ly + gap + dy) * rw + lx + gap + dx] == dirt:
							m = PixelPlainsGround.Mat.LIGHT + 1
			out[ly * pw + lx] = m
	return out


## Sheet of each cell of the same window as cell_materials: Skin + 1 for cobble / gravel, 0 = the default sheet of its material.
static func cell_skins(res: MapGen.Result, pp: PixelPlainsGround, ci0: int, cj0: int, tiles_w: int, tiles_h: int) -> PackedByteArray:
	var pw := tiles_w + 1
	var out := PackedByteArray()
	out.resize(pw * (tiles_h + 1))
	var has_biome := not res.biome.is_empty()
	for ly in tiles_h + 1:
		var y := cj0 - 1 + ly
		if y < 0 or y >= res.rows:
			continue
		for lx in pw:
			var x := ci0 - 1 + lx
			if x < 0 or x >= res.cols:
				continue
			var i := y * res.cols + x
			out[ly * pw + lx] = PixelPlainsGround.special_skin(res.ground[i], res.biome[i] if has_biome else 0) + 1
	return out


## Biome + 1 of each cell of the same window as cell_materials (0 = no biome / off the map).
static func cell_biomes(res: MapGen.Result, ci0: int, cj0: int, tiles_w: int, tiles_h: int) -> PackedByteArray:
	var pw := tiles_w + 1
	var out := PackedByteArray()
	out.resize(pw * (tiles_h + 1))
	if res.biome.is_empty():
		return out
	for ly in tiles_h + 1:
		var y := cj0 - 1 + ly
		if y < 0 or y >= res.rows:
			continue
		for lx in pw:
			var x := ci0 - 1 + lx
			if x >= 0 and x < res.cols:
				out[ly * pw + lx] = res.biome[y * res.cols + x] + 1
	return out


## F3: the cell and the layers stacked at the corner on its south-east: e.g. `water base | sand slot 6 + foam | light slot 4`.
static func report(res: MapGen.Result, pp: PixelPlainsGround, x: int, y: int) -> String:
	var here := _cell_mat(res, pp, x, y)
	var m4: Array[int] = []
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		m4.append(PixelPlainsGround.mi(_cell_mat(res, pp, x + d.x, y + d.y)))
	return "%s  corner at its south-east: %s" % [pp.name_of(here), corner_layers(pp, Vector4i(m4[0], m4[1], m4[2], m4[3]))]


## The layers of a corner (key = 4 materials NW NE SW SE) as text: lowest ground = base, each higher one with its slot (sand: + foam).
static func corner_layers(pp: PixelPlainsGround, key: Vector4i) -> String:
	var present := {}
	for qd in 4:
		present[key[qd]] = true
	var layers: Array = present.keys()
	layers.sort_custom(func(a: int, b: int) -> bool: return pp.prio_of(a) < pp.prio_of(b))
	if layers.size() == 1:
		return "%s fill" % pp.name_of(layers[0])
	var parts: Array[String] = ["%s base" % pp.name_of(layers[0])]
	for k in range(1, layers.size()):
		var mask := 0
		for qd in 4:
			if pp.prio_of(key[qd]) >= pp.prio_of(layers[k]):
				mask |= 1 << qd
		parts.append("%s slot %d%s" % [pp.name_of(layers[k]), mask, " + foam" if layers[k] == PixelPlainsGround.Mat.SAND else ""])
	return " | ".join(parts)


static func _cell_mat(res: MapGen.Result, pp: PixelPlainsGround, x: int, y: int) -> int:   # with the dark-near-dirt rule, like what is drawn
	if x < 0 or y < 0 or x >= res.cols or y >= res.rows:
		return int(PixelPlainsGround.Mat.NONE)
	return cell_materials(res, pp, x + 1, y + 1, 1, 1)[0] - 1


# ---- Slice 2: step / flat tiles -----------------------------------------------------------------------------------------------

const R_FILL := 0
const R_HL := 1
const R_OUTLINE := 2
const R_SHADOW := 3
const R_LOWER := 4
## The pack's light_on_dirt pixels (art facts of the sheet, not tuning): everything of the tile that is not one of these is "fill".
const PX_HL := [164, 196, 67]
const PX_OUTLINE := [42, 89, 79]
const PX_SHADOW := [189, 106, 98]
const PX_LOWER := [[240, 181, 65], [235, 150, 61]]


static func _is(d: PackedByteArray, o: int, c: Array) -> bool:
	return d[o] == c[0] and d[o + 1] == c[1] and d[o + 2] == c[2]


## Role of every pixel of the pack's light_on_dirt tile of a mask (the shapes every step / flat border is made from).
static func _roles(c: Cache, mask: int) -> PackedByteArray:
	if c.roles.has(mask):
		return c.roles[mask]
	var d := _case_tile(c, 0, PixelPlainsGround.Mat.LIGHT, PixelPlainsGround.Mat.DIRT, mask).get_data()
	var out := PackedByteArray()
	out.resize(d.size() / 4)
	for p in out.size():
		var o := p * 4
		var r := R_FILL
		if _is(d, o, PX_HL):
			r = R_HL
		elif _is(d, o, PX_OUTLINE):
			r = R_OUTLINE
		elif _is(d, o, PX_SHADOW):
			r = R_SHADOW
		elif _is(d, o, PX_LOWER[0]) or _is(d, o, PX_LOWER[1]):
			r = R_LOWER
		out[p] = r
	c.roles[mask] = out
	return out


static func _put(buf: PackedByteArray, p: int, col: Color) -> void:
	buf[p * 4] = col.r8
	buf[p * 4 + 1] = col.g8
	buf[p * 4 + 2] = col.b8
	buf[p * 4 + 3] = 255


## The 4-colour swatch of every ground sheet: 4 squares of SWATCH_PX side by side from the top-left of cell SWATCH_CELL, in the order
## fill, highlight, outline, shade (shade = shadow cast ONTO this ground). tools/bake_ground_art.gd draws it; redraw a square to recolour that role.
const SWATCH_CELL := Vector2i(0, 12)
const SWATCH_PX := 4


## Fill, highlight, outline and shade of a material, read from the swatch of its ground sheet.
static func palette(pp: PixelPlainsGround, mat: int) -> PackedColorArray:
	var c := _cache(pp)
	if c.pal.has(mat):
		return c.pal[mat]
	var sheet := _skin_sheet(c, mat)
	var out := PackedColorArray()
	for k in 4:
		var col := sheet.get_pixel(SWATCH_CELL.x * pp.tile_size + k * SWATCH_PX + SWATCH_PX / 2, SWATCH_CELL.y * pp.tile_size + SWATCH_PX / 2)
		out.append(Color8(col.r8, col.g8, col.b8))
	c.pal[mat] = out
	return out


## One ground's layer of one corner shape (mask: NW 1, NE 2, SW 4, SE 8, set = this ground or a higher one): the pack's light_on_dirt shape
## painted in the colours given. shadow.a == 0 = no shadow pixels. beach: the outline pixels carry foam.
## Returns {rgba: RGBA8 bytes (alpha 0 = untouched, the ground below shows), foam: 1 where beach foam, land: 1 where this layer is ground}.
static func _layer(c: Cache, mask: int, fill: Color, hl: Color, outline: Color, shadow: Color, beach: bool) -> Dictionary:
	var t := c.pp.tile_size
	var rgba := PackedByteArray()
	rgba.resize(t * t * 4)
	var foam := PackedByteArray()
	foam.resize(t * t)
	var land := PackedByteArray()
	land.resize(t * t)
	var rm := _roles(c, mask)
	for p in t * t:
		match rm[p]:
			R_FILL:
				_put(rgba, p, fill)
				land[p] = 1
			R_HL:
				_put(rgba, p, hl)
				land[p] = 1
			R_OUTLINE:
				_put(rgba, p, fill if beach else outline)
				land[p] = 1
				foam[p] = 1 if beach else 0
			R_SHADOW:
				if shadow.a > 0.0:
					_put(rgba, p, shadow)
	return {"rgba": rgba, "foam": foam, "land": land}


## One tile of a corner with sand / snow / water in it, stacked from the pictures (docs/wiki/ground-tileset-algorithm.md rule 3).
## key = Vector4i of the 4 cells (NW NE SW SE): material (5 = water) | (biome + 1) << 4 (0 = no biome = the base pictures). The lowest ground is its base
## (slot 15; water: the flat cell of water.png), every higher ground (by priority) is drawn over it with its slot of the mask "cells that are this ground
## or higher". Each layer reads the pictures of the biome of the FIRST cell (NW NE SW SE) that holds that ground.
## Returns {img: RGBA8, anim: RGBA8 mask (R 1 = foam, G / B = x / y of the pixel in frame 0 of that biome's foam.png), has_anim, land: 1 where ground is drawn}.
static func _compose(c: Cache, key: Vector4i) -> Dictionary:
	if c.composed.has(key):
		return c.composed[key]
	var pp := c.pp
	var t := pp.tile_size
	var rect := Rect2i(0, 0, t, t)
	var ms: Array[int] = []
	var bs: Array[int] = []
	var present := {}
	for qd in 4:
		ms.append(key[qd] & 15)
		bs.append((key[qd] >> 4) - 1)
		if not present.has(ms[qd]):
			present[ms[qd]] = bs[qd]   # the first cell holding it
	var layers: Array = present.keys()
	layers.sort_custom(func(a: int, b: int) -> bool: return pp.prio_of(a) < pp.prio_of(b))
	var img := Image.create_empty(t, t, false, Image.FORMAT_RGBA8)
	var land := PackedByteArray()
	land.resize(t * t)
	var foam := PackedByteArray()   # the sand mask whose foam picture marks this pixel, 0 = none
	foam.resize(t * t)
	if layers[0] == PixelPlainsGround.Mat.WATER:
		var w := _ground_img(c, "water", pp.water_texture, present[layers[0]])
		if w != null:
			img.blit_rect(w, rect, Vector2i.ZERO)
	else:
		img.blit_rect(_slot(c, layers[0], 15, present[layers[0]]), rect, Vector2i.ZERO)
		land.fill(1)
	for k in range(1, layers.size()):
		var up: int = layers[k]
		if up == PixelPlainsGround.Mat.WATER:
			continue
		var mask := 0
		for qd in 4:
			if pp.prio_of(ms[qd]) >= pp.prio_of(up):
				mask |= 1 << qd
		var slot := _slot(c, up, mask, present[up])
		img.blend_rect(slot, rect, Vector2i.ZERO)
		var sd := slot.get_data()
		var fa := _foam_any(c, mask, present[up]) if up == PixelPlainsGround.Mat.SAND else PackedByteArray()
		for p in t * t:
			if sd[p * 4 + 3] == 0:
				continue
			land[p] = 1
			foam[p] = mask if not fa.is_empty() and fa[p] == 1 else 0
	var abuf := PackedByteArray()
	abuf.resize(t * t * 4)
	var has_anim := false
	for p in t * t:
		abuf[p * 4 + 3] = 255
		if foam[p] != 0:
			abuf[p * 4] = 1
			abuf[p * 4 + 1] = (foam[p] % 4) * t + p % t
			abuf[p * 4 + 2] = (foam[p] / 4) * t + p / t
			has_anim = true
	var out := {"img": img, "anim": Image.create_from_data(t, t, false, Image.FORMAT_RGBA8, abuf), "has_anim": has_anim, "land": land}
	c.composed[key] = out
	return out


## The edge tile of ground `mat` (0..4) for slot s (1..15) from its sheet in `biome` (-1 = base).
static func _slot(c: Cache, mat: int, s: int, biome := -1) -> Image:
	var key := (biome + 1) * 256 + mat * 16 + s
	if not c.slots.has(key):
		var t := c.pp.tile_size
		c.slots[key] = _skin_sheet(c, mat, biome).get_region(Rect2i((s % 4) * t, (EDGE_ROW + s / 4) * t, t, t))
	return c.slots[key]


## 1 where the foam picture (of `biome`) of sand mask `mask` has a pixel in any of its 8 frames.
static func _foam_any(c: Cache, mask: int, biome := -1) -> PackedByteArray:
	var key := (biome + 1) * 16 + mask
	if not c.foam_any.has(key):
		var t := c.pp.tile_size
		var out := PackedByteArray()
		out.resize(t * t)
		var pic := _ground_img(c, "foam", c.pp.foam_texture, biome)
		if pic != null:
			for f in FOAM_FRAMES:
				var d := pic.get_region(Rect2i(f * 4 * t + (mask % 4) * t, (mask / 4) * t, t, t)).get_data()
				for p in t * t:
					if d[p * 4 + 3] > 0:
						out[p] = 1
		c.foam_any[key] = out
	return c.foam_any[key]


static func bake_region(res: MapGen.Result, pp: PixelPlainsGround, ci0: int, cj0: int, tiles_w: int, tiles_h: int) -> Dictionary:
	var c := _cache(pp)
	var t := pp.tile_size
	var h := t / 2
	var img := Image.create_empty(tiles_w * t, tiles_h * t, false, Image.FORMAT_RGBA8)
	var anim := Image.create_empty(tiles_w * t, tiles_h * t, false, Image.FORMAT_RGBA8)
	anim.fill(Color8(0, 0, 0, 255))
	var cells := cell_materials(res, pp, ci0, cj0, tiles_w, tiles_h)
	var skins := cell_skins(res, pp, ci0, cj0, tiles_w, tiles_h)
	var biomes := cell_biomes(res, ci0, cj0, tiles_w, tiles_h)
	var pw := tiles_w + 1
	var tile_rect := Rect2i(0, 0, t, t)
	var q_rect := Rect2i(0, 0, h, h)
	var weight := int(round(pp.plain_weight * 1000.0))
	for j in tiles_h:
		for i in tiles_w:
			var p0 := j * pw + i
			var m4 := PackedByteArray([cells[p0], cells[p0 + 1], cells[p0 + pw], cells[p0 + pw + 1]])   # NW NE SW SE, material + 1 (0 = water)
			var dst := Vector2i(i * t, j * t)
			var a := m4[0]
			var other := -1  # the second material of the corner (0 = water), if there is exactly one
			var kinds := 1
			for qd in range(1, 4):
				if m4[qd] != a:
					if other < 0 or m4[qd] == other:
						other = m4[qd]
					else:
						kinds = 3
			if other >= 0 and kinds == 1:
				kinds = 2
			if kinds == 1:
				if a == 0:
					continue   # open water: the water sprite shows
				var mat := a - 1   # one material: a fill tile picked by the corner, from the sheet of its ground
				var src := mat if mat <= PixelPlainsGround.Mat.DARK else int(PixelPlainsGround.Mat.DIRT)
				var hs := GroundBaker._hash(ci0 + i, cj0 + j, res.seed + 100 + mat)
				var plain_only: bool = (mat == PixelPlainsGround.Mat.SAND and pp.sand_plain_only) or (mat == PixelPlainsGround.Mat.SNOW and pp.snow_plain_only)
				var list := pp.plain_of(src) if plain_only or (hs % 1000) < weight or pp.variants_of(src).is_empty() else pp.variants_of(src)
				var v: Vector2i = list[(hs >> 10) % list.size()]
				var skin := mat   # a corner of one special ground (cobble, gravel) uses its own sheet
				if skins[p0] > 0 and skins[p0] == skins[p0 + 1] and skins[p0] == skins[p0 + pw] and skins[p0] == skins[p0 + pw + 1]:
					skin = skins[p0] - 1
				img.blit_rect(_fill(c, skin, v, biomes[p0] - 1), tile_rect, dst)
				continue
			var native := true
			for qd in 4:
				native = native and m4[qd] >= 1 and m4[qd] <= PixelPlainsGround.Mat.DARK + 1
			if not native or pp.all_flat:   # sand, snow or water in the corner (or all flat: every border, grass / dirt too):
				var key := Vector4i(0, 0, 0, 0)
				for qd in 4:
					key[qd] = PixelPlainsGround.mi(m4[qd] - 1) | (biomes[p0 + (qd & 1) + (qd >> 1) * pw] << 4)
				var comp := _compose(c, key)
				img.blit_rect(comp["img"], tile_rect, dst)
				if comp["has_anim"]:
					anim.blit_rect(comp["anim"], tile_rect, dst)
				continue
			if kinds == 2:   # the pack's own pairs, pixel for pixel like the python reference
				var pair := _pair(pp, a - 1, other - 1)
				if pair >= 0:
					var up := a - 1 if pp.layer_of(a - 1) > pp.layer_of(other - 1) else other - 1
					var lo := other - 1 if up == a - 1 else a - 1
					var mask := 0
					for qd in 4:
						if m4[qd] - 1 == up:
							mask |= 1 << qd
					img.blit_rect(_case_tile(c, pair, up, lo, mask), tile_rect, dst)
					continue
			for qd in 4:   # a pair the pack lacks, or 3 materials: each quarter = its own cell's plain quarter
				img.blit_rect(_quarter(c, pp.quarter_of(m4[qd] - 1)), q_rect, dst + Vector2i((qd & 1) * h, (qd >> 1) * h))
	return {"ground": img, "foam": anim, "anim": true, "tile": t}


## True where the picture shows ground (not water) at art pixel `a` (world px / pixel_scale; the dual grid starts half a tile up-left).
## The pack's shapes draw the upper ground a few pixels over the lower cell, so a shore's sand reaches into its water cells:
## this asks the same corner tile bake_region() draws, pixel for pixel (ArenaMap.water_kind_at uses it).
static func drawn_land_at(res: MapGen.Result, pp: PixelPlainsGround, a: Vector2i) -> bool:
	var t := pp.tile_size
	var h := t / 2
	var tile := Vector2i(floori(float(a.x + h) / t), floori(float(a.y + h) / t))   # corner of cells tile - 1 .. tile
	var cells := cell_materials(res, pp, tile.x, tile.y, 1, 1)   # NW NE SW SE, material + 1 (0 = water)
	var wet := 0
	for qd in 4:
		wet += 1 if cells[qd] == 0 else 0
	if wet == 0 or wet == 4:
		return wet == 0
	var bio := cell_biomes(res, tile.x, tile.y, 1, 1)
	var key := Vector4i(0, 0, 0, 0)
	for qd in 4:
		key[qd] = PixelPlainsGround.mi(cells[qd] - 1) | (bio[qd] << 4)
	var land: PackedByteArray = _compose(_cache(pp), key)["land"]
	var l := a + Vector2i(h, h) - tile * t
	return land[l.y * t + l.x] == 1


## Share of dirt / light / dark / sand / snow among the land cells (F3 status), in percent.
static func shares(res: MapGen.Result, pp: PixelPlainsGround) -> Array[int]:
	var n := [0, 0, 0, 0, 0]
	var land := 0
	var has_biome := not res.biome.is_empty()
	for i in res.ground.size():
		var m := pp.material_of(res.ground[i], res.biome[i] if has_biome else 0)
		if m >= 0:
			n[m] += 1
			land += 1
	var out: Array[int] = []
	for k in 5:
		out.append(100 * n[k] / maxi(land, 1))
	return out
