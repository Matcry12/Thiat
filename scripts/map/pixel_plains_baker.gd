class_name PixelPlainsBaker
extends RefCounted
## The Pixel Plains ground picture (GroundBaker.bake_region calls this when MapStyle.pixel_plains is set). Same dual grid as the
## old baker (tile (i, j) sits on the corner of cells (i-1,j-1) (i,j-1) (i-1,j) (i,j); the picture is one tile bigger than the map),
## but every tile is built from the pack's 8x8 quarters by the case tables in PixelPlainsGround, and it is the python reference
## tools/asset_viewer/pixel_plains_tiles.py `render()` pixel for pixel (tests/test_pixel_plains_ground.gd checks it).
## Rules, like the reference: 4 cells of one material = a fill tile (hash of the corner picks it, so chunks match);
## 2 materials with a table = the table's quarters; water in the corner or any other mix = each quarter shows its own cell's plain quarter.
## Map rule on top: a dark cell with dirt within `dark_dirt_gap` cells becomes light grass.
## Slice 2 (decision 0046): a corner that holds sand, snow or water is built by _compose(): the grounds of the corner sorted by (level, priority),
## the lowest one flat, every higher one drawn with the light_on_dirt shape in the ground's own sheet colours (step or flat border, see
## PixelPlainsGround Levels); water is not painted (the flat water sprite shows through) except bank band / shadow pixels. The picture
## "foam" is now the ANIMATION MASK (RGBA8, R = kind: 1 beach foam, 2 foam dash, 3 shore water (flat water over the marks), G = j * 8 + length, B = phase) that terrain_anim.gdshader
## lights frame by frame; marks on open water come from terrain_water_flat.gdshader.
## All flat (decision 0047, the default): every mixed corner goes through _compose(), so dark / light grass and grass / dirt get the same quiet
## flat border as the rest (the pack's own raised-edge pairs are only used with all_flat off). Everything is tile local: a chunk baked alone equals the whole map.

class Cache:
	var pp: PixelPlainsGround
	var sheet: Image
	var quarters := {}   ## Vector3i -> 8x8 Image
	var fills := {}      ## Vector2i -> 16x16 Image
	var tiles := {}      ## pair * 16 + mask -> composed 16x16 Image
	var composed := {}   ## Vector4i of 4 x (material * 16 + level) -> {img, anim, has_anim, cands, ok}
	var roles := {}      ## mask -> PackedByteArray of the role of every pixel of the pack's light_on_dirt tile
	var skins := {}      ## Skin -> that ground's sheet Image (assets/game/map/pixel_plains/ground/)
	var pal := {}        ## material -> PackedColorArray [fill, highlight, outline, shade] read from its sheet

static var _caches := {}


static func clear_cache() -> void:
	_caches.clear()


static func _cache(pp: PixelPlainsGround) -> Cache:
	var key := pp.get_instance_id()
	if _caches.has(key):
		return _caches[key]
	var c := Cache.new()
	c.pp = pp
	c.sheet = pp.texture.get_image()
	c.sheet.convert(Image.FORMAT_RGBA8)
	_caches[key] = c
	return c


static func _quarter(c: Cache, e: Vector3i) -> Image:
	if not c.quarters.has(e):
		var h := c.pp.tile_size / 2
		c.quarters[e] = c.sheet.get_region(Rect2i(e.x * c.pp.tile_size + (e.z & 1) * h, e.y * c.pp.tile_size + (e.z >> 1) * h, h, h))
	return c.quarters[e]


static func _skin_sheet(c: Cache, skin: int) -> Image:
	if not c.skins.has(skin):
		var tex := c.pp.sheet_of(skin)
		if tex == null:
			push_warning("PixelPlainsGround: sheet %d is not set, using the dirt sheet (or tiles.png)" % skin)
			tex = c.pp.sheet_dirt if c.pp.sheet_dirt != null else c.pp.texture
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		c.skins[skin] = img
	return c.skins[skin]


## A whole 16 px fill tile from the sheet of a ground (skin).
static func _fill(c: Cache, skin: int, v: Vector2i) -> Image:
	var key := Vector3i(skin, v.x, v.y)
	if not c.fills.has(key):
		var t := c.pp.tile_size
		c.fills[key] = _skin_sheet(c, skin).get_region(Rect2i(v.x * t, v.y * t, t, t))
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


# ---- Slice 2: levels ----------------------------------------------------------------------------------------------------------

## Level of one map cell (off the map = water). Rules in PixelPlainsGround "Levels".
static func level_at(res: MapGen.Result, pp: PixelPlainsGround, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= res.cols or y >= res.rows:
		return pp.level_water
	if pp.all_flat:
		return pp.level_water
	var i := y * res.cols + x
	if not res.level_override.is_empty():
		return res.level_override[i]
	var has_biome := not res.biome.is_empty()
	match int(res.ground[i]):
		MapGen.Ground.WATER:
			return pp.level_water
		MapGen.Ground.SAND:
			if not res.shore.is_empty() and res.shore[i] == 1:
				return pp.level_bank_sand
			if has_biome and res.biome[i] == MapGen.Biome.BEACH_SAND:
				return pp.level_beach_sand
			return pp.level_inland_sand
		MapGen.Ground.SNOW:
			if has_biome:
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nx := x + dx
						var ny := y + dy
						if nx < 0 or ny < 0 or nx >= res.cols or ny >= res.rows:
							continue
						var ni := ny * res.cols + nx
						if res.ground[ni] != MapGen.Ground.WATER and res.biome[ni] != MapGen.Biome.SNOWY:
							return pp.level_snow_edge
			return pp.level_snow
		MapGen.Ground.GRASS:
			return maxi(pp.level_grass, pp.level_snow_edge) if has_biome and res.biome[i] == MapGen.Biome.SNOWY else pp.level_grass
	if has_biome and res.biome[i] == MapGen.Biome.SNOWY:   # other land inside the snowy biome stands with the snow edge: no step against it
		return maxi(pp.level_dirt, pp.level_snow_edge)
	return pp.level_dirt   # dirt, cobble, boss


## Levels of the same cells as cell_materials (same window, same order).
static func cell_levels(res: MapGen.Result, pp: PixelPlainsGround, ci0: int, cj0: int, tiles_w: int, tiles_h: int) -> PackedByteArray:
	var pw := tiles_w + 1
	var out := PackedByteArray()
	out.resize(pw * (tiles_h + 1))
	for ly in tiles_h + 1:
		for lx in pw:
			out[ly * pw + lx] = level_at(res, pp, ci0 - 1 + lx, cj0 - 1 + ly)
	return out


## What is drawn between two grounds: "" (same ground), "step", "flat" or "foam" (flat beach: sand level with water).
static func border_kind(pp: PixelPlainsGround, ma: int, la: int, mb: int, lb: int) -> String:
	if PixelPlainsGround.mi(ma) == PixelPlainsGround.mi(mb):
		return ""
	if la != lb:
		return "step"
	var up := ma if pp.prio_of(ma) > pp.prio_of(mb) else mb
	var lo := mb if up == ma else ma
	if up == PixelPlainsGround.Mat.SAND and PixelPlainsGround.mi(lo) == PixelPlainsGround.Mat.WATER:
		return "foam"
	return "flat"


## F3: the cell, its level and the border to each of its 4 neighbours.
static func report(res: MapGen.Result, pp: PixelPlainsGround, x: int, y: int) -> String:
	var here := _cell_mat(res, pp, x, y)
	var lh := level_at(res, pp, x, y)
	var parts: Array[String] = []
	for d in [["N", Vector2i(0, -1)], ["E", Vector2i(1, 0)], ["S", Vector2i(0, 1)], ["W", Vector2i(-1, 0)]]:
		var n: Vector2i = Vector2i(x, y) + d[1]
		var m := _cell_mat(res, pp, n.x, n.y)
		var k := border_kind(pp, here, lh, m, level_at(res, pp, n.x, n.y))
		if k != "":
			parts.append("%s %s (%s L%d)" % [d[0], k, pp.name_of(m), level_at(res, pp, n.x, n.y)])
	return "%s level %d  borders: %s" % [pp.name_of(here), lh, ", ".join(parts) if not parts.is_empty() else "none"]


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


## One tile of a corner with sand / snow / water in it. key = Vector4i of 4 x (material * 16 + level), NW NE SW SE (material 5 = water).
## Returns {img: RGBA8 (water pixels transparent), anim: RGBA8 mask, has_anim, cands: PackedInt32Array (x, y, dir) of foam dash anchors, ok: PackedByteArray}.
static func _compose(c: Cache, key: Vector4i) -> Dictionary:
	if c.composed.has(key):
		return c.composed[key]
	var pp := c.pp
	var t := pp.tile_size
	var ms: Array[int] = []
	var lvs: Array[int] = []
	var top := {}   # material -> its highest level in this corner
	for qd in 4:
		ms.append(key[qd] >> 4)
		lvs.append(key[qd] & 15)
		top[ms[qd]] = maxi(top.get(ms[qd], -1), lvs[qd])
	var rank := func(m: int) -> int: return int(top[m]) * 16 + pp.prio_of(m)
	var layers: Array = top.keys()
	layers.sort_custom(func(a: int, b: int) -> bool: return rank.call(a) < rank.call(b))
	var buf := PackedByteArray()
	buf.resize(t * t * 4)
	var land := PackedByteArray()   # 1 = ground that is not water (band and dashes look at it)
	land.resize(t * t)
	var foam := PackedByteArray()
	foam.resize(t * t)
	var water_step := false
	if layers[0] != PixelPlainsGround.Mat.WATER:
		var f := pp.fill_of(layers[0])
		for p in t * t:
			_put(buf, p, f)
			land[p] = 1
	for k in range(1, layers.size()):
		var lo: int = layers[k - 1]
		var up: int = layers[k]
		var mask := 0
		for qd in 4:
			if rank.call(ms[qd]) >= rank.call(up):
				mask |= 1 << qd
		var step: bool = top[up] != top[lo]
		var fill := pp.fill_of(up)
		var hl := pp.hl_of(up) if step else fill
		var outline := pp.outline_of(up) if step else Color8(int(fill.r8 * (1.0 - pp.quiet_darken)), int(fill.g8 * (1.0 - pp.quiet_darken)), int(fill.b8 * (1.0 - pp.quiet_darken)))
		var has_shadow := step
		var shadow := pp.shade_of(lo)
		var beach := not step and lo == PixelPlainsGround.Mat.WATER and up == PixelPlainsGround.Mat.SAND   # flat beach: foam outline, water shadow
		if beach:
			has_shadow = true
			shadow = pp.fill_of(PixelPlainsGround.Mat.WATER)
		water_step = water_step or (step and lo == PixelPlainsGround.Mat.WATER)
		var rm := _roles(c, mask)
		for p in t * t:
			match rm[p]:
				R_FILL:
					_put(buf, p, fill)
					land[p] = 1
					foam[p] = 0
				R_HL:
					_put(buf, p, hl)
					land[p] = 1
					foam[p] = 0
				R_OUTLINE:
					_put(buf, p, fill if beach else outline)
					land[p] = 1
					foam[p] = 1 if beach else 0
				R_SHADOW:
					if has_shadow:
						_put(buf, p, shadow)
						foam[p] = 0
	if water_step:   # bank band: water just below / right of land
		for y in t:
			for x in t:
				var p := y * t + x
				if land[p] == 1 or buf[p * 4 + 3] != 0:
					continue
				var hit := false
				for d in range(1, pp.band_up + 1):
					if y - d >= 0 and land[(y - d) * t + x] == 1:
						hit = true
				for d in range(1, pp.band_left + 1):
					if x - d >= 0 and land[y * t + x - d] == 1:
						hit = true
				if hit:
					_put(buf, p, pp.band_colour)
	var cands := PackedInt32Array()
	var ok := PackedByteArray()
	if water_step:   # dash anchors: free water 2..4 px (chessboard) off ground / band, may run out to 8
		ok.resize(t * t)
		var dist := PackedInt32Array()
		dist.resize(t * t)
		for p in t * t:
			dist[p] = 99 if buf[p * 4 + 3] == 0 else 0
		for y in t:
			for x in t:
				var p := y * t + x
				var v := dist[p]
				if v == 0:
					continue
				if x > 0:
					v = mini(v, dist[p - 1] + 1)
				if y > 0:
					v = mini(v, dist[p - t] + 1)
					if x > 0:
						v = mini(v, dist[p - t - 1] + 1)
					if x < t - 1:
						v = mini(v, dist[p - t + 1] + 1)
				dist[p] = v
		for y in range(t - 1, -1, -1):
			for x in range(t - 1, -1, -1):
				var p := y * t + x
				var v := dist[p]
				if v == 0:
					continue
				if x < t - 1:
					v = mini(v, dist[p + 1] + 1)
				if y < t - 1:
					v = mini(v, dist[p + t] + 1)
					if x < t - 1:
						v = mini(v, dist[p + t + 1] + 1)
					if x > 0:
						v = mini(v, dist[p + t - 1] + 1)
				dist[p] = v
		for y in t:
			for x in t:
				var p := y * t + x
				if dist[p] < pp.dash_near or dist[p] > pp.dash_reach:
					continue
				ok[p] = 1
				if dist[p] <= pp.dash_far:
					var gx := (dist[p + 1] if x < t - 1 else dist[p]) - (dist[p - 1] if x > 0 else dist[p])
					cands.append_array(PackedInt32Array([x, y, 1 if gx >= 0 else -1]))
	var abuf := PackedByteArray()
	abuf.resize(t * t * 4)
	var has_anim := false
	for p in t * t:
		abuf[p * 4 + 3] = 255
		if foam[p] == 1:
			abuf[p * 4] = 1
			has_anim = true
		elif buf[p * 4 + 3] == 0:   # kind 3 = shore water: the anim shader paints flat water over it, so the open-water marks stay off the shore
			abuf[p * 4] = 3
			has_anim = true
	var out := {"img": Image.create_from_data(t, t, false, Image.FORMAT_RGBA8, buf), "anim": Image.create_from_data(t, t, false, Image.FORMAT_RGBA8, abuf),
		"has_anim": has_anim, "cands": cands, "ok": ok, "land": land}
	c.composed[key] = out
	return out


## Is pixel j (0..length) of a foam dash lit in frame f? Mirror of terrain_anim.gdshader (tests). States of the loop: (shift, cut) per (f+1)/2 + phase.
static func dash_lit(j: int, length: int, phase: int, f: int) -> bool:
	var q := (((f + 1) / 2) + phase) % 4
	var sft := 1 if q == 1 or q == 2 else 0
	var cut := 1 if q == 2 or q == 3 else 0
	return j >= sft and j - sft < length - cut


## Is pixel x + y of a beach foam lit in frame f? Mirror of the shader.
static func beach_lit(px: int, py: int, f: int, lit: int, frames: int) -> bool:
	return posmod(px + py - f, 8) < lit


## One foam dash on a shore tile (the tile's own anchor, picked by a hash of the tile): written into the animation mask.
static func _dash(res: MapGen.Result, pp: PixelPlainsGround, comp: Dictionary, anim: Image, tx: int, ty: int, dst: Vector2i) -> void:
	var cands: PackedInt32Array = comp["cands"]
	if cands.is_empty():
		return
	var t := pp.tile_size
	var h := GroundBaker._hash(tx, ty, res.seed + 300)
	if (h % 1000) >= int(pp.dash_keep * 1000.0):
		return
	var best := 0
	var best_h := -1
	for n in cands.size() / 3:
		var hh := GroundBaker._hash(tx * t + cands[n * 3], ty * t + cands[n * 3 + 1], res.seed + 17)
		if hh > best_h:
			best_h = hh
			best = n
	var length := pp.dash_len_min + ((h >> 10) % (pp.dash_len_max - pp.dash_len_min + 1))
	var phase := (h >> 20) & 3
	var ok: PackedByteArray = comp["ok"]
	for j in length + 1:
		var x := cands[best * 3] + cands[best * 3 + 2] * j
		var y := cands[best * 3 + 1]
		if x < 0 or x >= t or ok[y * t + x] == 0:
			continue
		if anim.get_pixel(dst.x + x, dst.y + y).r8 == 1:
			continue
		anim.set_pixel(dst.x + x, dst.y + y, Color8(2, j * 8 + length, phase, 255))


static func bake_region(res: MapGen.Result, pp: PixelPlainsGround, ci0: int, cj0: int, tiles_w: int, tiles_h: int) -> Dictionary:
	var c := _cache(pp)
	var t := pp.tile_size
	var h := t / 2
	var img := Image.create_empty(tiles_w * t, tiles_h * t, false, Image.FORMAT_RGBA8)
	var anim := Image.create_empty(tiles_w * t, tiles_h * t, false, Image.FORMAT_RGBA8)
	anim.fill(Color8(0, 0, 0, 255))
	var cells := cell_materials(res, pp, ci0, cj0, tiles_w, tiles_h)
	var skins := cell_skins(res, pp, ci0, cj0, tiles_w, tiles_h)
	var lvls := cell_levels(res, pp, ci0, cj0, tiles_w, tiles_h)
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
				img.blit_rect(_fill(c, skin, v), tile_rect, dst)
				continue
			var native := true
			for qd in 4:
				native = native and m4[qd] >= 1 and m4[qd] <= PixelPlainsGround.Mat.DARK + 1
			if not native or pp.all_flat:   # sand, snow or water in the corner (or all flat: every border, grass / dirt too): levels decide step / flat
				var key := Vector4i(0, 0, 0, 0)
				for qd in 4:
					key[qd] = (PixelPlainsGround.mi(m4[qd] - 1) << 4) | lvls[p0 + (qd & 1) + (qd >> 1) * pw]
				var comp := _compose(c, key)
				img.blit_rect(comp["img"], tile_rect, dst)
				if comp["has_anim"]:
					anim.blit_rect(comp["anim"], tile_rect, dst)
				_dash(res, pp, comp, anim, ci0 + i, cj0 + j, dst)
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
	var lvls := cell_levels(res, pp, tile.x, tile.y, 1, 1)
	var key := Vector4i(0, 0, 0, 0)
	for qd in 4:
		key[qd] = (PixelPlainsGround.mi(cells[qd] - 1) << 4) | lvls[qd]
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
