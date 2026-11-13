class_name BiomeVeg
extends RefCounted
## The island's floor decoration, one pass per kind, every number from BiomeData (decision 0038 step 4; port of tools/asset_viewer/biome_looks.py).
## Runs after the trees, rock nodes and the ground, so it sees them: rock pieces (the small stones of the rock groups), bushes, flower patches,
## foxglove, mushrooms (in tree shade), snow stumps, reeds (along water), grass tufts and ferns (more near trunks and rocks). Each pass has its own
## random stream (MapGen.SEED_VEG + pass). A try that fails a check is dropped, never moved. Nothing grows on water, a shore cell, a path / camp
## stamp or boss land; plants also keep to their biome's ground. The result is Result.deco ({set, region, pos = bottom centre in px}) drawn by ChunkDeco.
## The sprites come from the PropSets ids `rocks` and `pp_flowers / pp_tufts / pp_hedges` (data/maps/prop_*.tres). The old `veg` / `stump_*` sets (Vegetation.png, old tree sheets) are retired: with no such set their passes add nothing.

const FLOWER := [&"flower_0", &"flower_1", &"flower_2", &"flower_3"]   ## orange, white, blue, yellow
const BUSH := [&"bush_green", &"bush_yellow", &"bush_orange", &"bush_red"]
const TUFT := [&"tuft_green", &"tuft_yellow", &"tuft_brown", &"fern_green", &"fern_yellow", &"fern_brown"]
const ROCK_PIECE := [&"boulder_brown", &"boulder_grey", &"stone_brown", &"stone_grey"]
const STUMP_MODELS := [1, 1, 2, 3]   ## oak twice as likely

var res: MapGen.Result
var p: MapGen.Params
var sets: Array[PropSet]
var cols := 0
var rows := 0
var cell := 32.0
var veg := -1
var rocks := -1
var veg_g: Dictionary
var rocks_g: Dictionary
var stumps := {}            ## model number -> Array of set indices
var pp_sets := {}           ## Pixel Plains mode: kind (flowers tufts hedges) -> set index of pp_<kind> (data/maps/prop_pp_*.tres; groups "<role>@<biome label>")
var occ: PackedByteArray
var stamp := PackedByteArray()
var dn: FastNoiseLite
var rng: RandomNumberGenerator


static func has_sets(style: MapStyle) -> bool:
	for s in style.deco:
		if s.id == &"rocks":
			return true
	return false


static func place(result: MapGen.Result, style: MapStyle, params: MapGen.Params) -> void:
	var pass_ := BiomeVeg.new()
	pass_.run(result, style, params)


func run(result: MapGen.Result, style: MapStyle, params: MapGen.Params) -> void:
	res = result
	p = params
	sets = style.deco
	cols = p.cols
	rows = p.rows
	cell = p.cell
	for i in sets.size():
		match sets[i].id:
			&"veg":
				veg = i
				veg_g = sets[i].groups
			&"rocks":
				rocks = i
				rocks_g = sets[i].groups
			&"pp_flowers", &"pp_tufts", &"pp_hedges":
				pp_sets[StringName(String(sets[i].id).substr(3))] = i
			_:
				var parts := String(sets[i].id).split("_")   # stump_oak_s3
				if parts.size() == 3 and parts[0] == "stump":
					var m := BiomeData.MODELS.find(StringName(parts[1]))
					if m > 0:
						if not stumps.has(m):
							stumps[m] = []
						stumps[m].append(i)
	MapGen.make_veg_lists(res, p)
	occ = res.veg_occ
	stamp.resize(cols * rows)
	stamp.fill(0)
	for c: Vector2i in res.dirt_cells:
		if c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows:
			stamp[c.y * cols + c.x] = 1
	dn = MapGen.veg_noise(res.seed, p)
	_rock_pieces()
	_bushes()
	_flowers()
	_foxglove()
	_mushrooms()
	_stumps()
	_reeds()
	_tufts()


# ------------------------------------------------------------------ helpers ---

## Pixel Plains switch (PixelPlainsGround.show_*): is this kind of plant drawn in biome `b`? Always true with the old art.
func _on(kind: StringName, b: int) -> bool:
	return p.pp == null or p.pp.shows(kind, b)


## A flower / tuft / bush: in Pixel Plains mode from the pack's own set (group "<role>@<biome label>", no group = nothing), else from the old sheet.
func _addk(kind: StringName, bd: BiomeData, name: StringName, x: float, y: float) -> void:
	if p.pp == null:
		_add(veg, veg_g, name, x, y)
	elif pp_sets.has(kind):
		_add(pp_sets[kind], sets[pp_sets[kind]].groups, StringName("%s@%s" % [name, bd.label]), x, y)

func _stream(k: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = res.seed + MapGen.SEED_VEG + k
	return r


## Random spots (x, y in cells; z = cell index) of biome `b`: `rate` tries per 16x16 block, scaled by how much of the block is that biome.
func _spots(b: int, rate: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var bcells := MapGen.TREE_BLOCK * MapGen.TREE_BLOCK
	for blk in res.veg_nblocks:
		var cells := res.veg_blocks[b * res.veg_nblocks + blk]
		if cells.is_empty():
			continue
		for _t in MapGen.veg_count(rng, rate * cells.size() / bcells):
			var ci := cells[rng.randi() % cells.size()]
			out.append(Vector3(ci % cols + rng.randf(), ci / cols + rng.randf(), ci))
	return out


func _cell(x: float, y: float) -> int:
	var cx := int(floorf(x))
	var cy := int(floorf(y))
	if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
		return -1
	return cy * cols + cx


## Dry, free, not boss land, not on a shore cell or a path / camp stamp.
func _free_any(ci: int) -> bool:
	if ci < 0 or res.land[ci] == 0 or res.area[ci] == MapGen.Area.BOSS or occ[ci] != 0 or stamp[ci] == 1:
		return false
	return res.shore.is_empty() or res.shore[ci] == 0


## A plant of biome `b` may grow here: free_any, the cell belongs to b, and its ground is b's own (or its second ground).
func _free(ci: int, b: int) -> bool:
	if not _free_any(ci) or res.biome[ci] != b:
		return false
	if res.ground.is_empty():
		return true
	var bd := res.biomes[b]
	var g := res.ground[ci]
	return g == bd.ground or (bd.ground_alt > 0 and g == bd.ground_alt)


func _peaked(r: float) -> float:
	return rng.randf_range(-r * 0.5, r * 0.5) + rng.randf_range(-r * 0.5, r * 0.5)


func _add(set_i: int, groups: Dictionary, name: StringName, x: float, y: float) -> void:
	if not groups.has(name):
		return
	var list: PackedInt32Array = groups[name]
	if list.is_empty():
		return
	# the sprite comes from the position, not from the stream: a try that fails elsewhere never shifts the draws of this biome; seeded by the set id, not its list index, so adding or removing a set never reshuffles the pictures
	res.deco.append({"set": set_i, "region": list[absi(hash([x, y, sets[set_i].id])) % list.size()], "pos": Vector2(x, y) * cell})


## True if a trunk stands within `r` cells of (x, y).
func _trunk_within(x: float, y: float, r: float) -> bool:
	var reach := int(ceilf(r))
	var cx := int(floorf(x))
	var cy := int(floorf(y))
	for dy in range(-reach, reach + 1):
		var yy := cy + dy
		if yy < 0 or yy >= rows:
			continue
		for dx in range(-reach, reach + 1):
			var xx := cx + dx
			if xx >= 0 and xx < cols and occ[yy * cols + xx] == 1 and Vector2(x - (xx + 0.5), y - (yy + 0.5)).length() <= r:
				return true
	return false


## Weighted index into `w`, or -1 when all weights are 0.
func _wpick(w: Array) -> int:
	var tot := 0.0
	for x in w:
		tot += x
	if tot <= 0.0:
		return -1
	var u := rng.randf() * tot
	for k in w.size():
		u -= w[k]
		if u <= 0.0:
			return k
	return w.size() - 1


# ------------------------------------------------------------------- passes ---

func _rock_pieces() -> void:
	for pc in res.rock_pieces:
		var ci := _cell(pc.x, pc.y)
		if not _free_any(ci) or not _on(&"other", res.biome[ci]) or res.veg_clear[ci] == 1 or _trunk_within(pc.x, pc.y, 1.5):
			continue
		occ[ci] = 2
		_add(rocks, rocks_g, ROCK_PIECE[int(pc.z)], pc.x, pc.y)


func _bushes() -> void:
	for b in res.biomes.size():
		rng = _stream(0 * 16 + b)   # one stream per pass and biome
		var bd := res.biomes[b]
		var w := [bd.bush_w_green, bd.bush_w_yellow, bd.bush_w_orange, bd.bush_w_red]
		if bd.bush_per_block <= 0.0 or (not bd.bush_dead and _wpick(w) < 0) or not _on(&"hedges", b):
			continue
		var gated := bd.bush_d_lo > 0.0 or bd.bush_d_hi < 1.0
		for s in _spots(b, bd.bush_per_block):
			if gated:
				var d := MapGen.veg_density(res, bd, dn, s.x, s.y, int(s.z))
				if d < bd.bush_d_lo or d > bd.bush_d_hi:
					continue
			if bd.bush_tries > 1:
				for _k in bd.bush_tries:
					_bush(b, bd, w, s.x + _peaked(bd.bush_spread * 2.0), s.y + _peaked(bd.bush_spread * 2.0))
			else:
				var pair := rng.randf() < bd.bush_pair   # drawn whether or not the first bush stood
				var a := rng.randf() * TAU
				if _bush(b, bd, w, s.x, s.y) and pair:
					_bush(b, bd, w, s.x + cos(a) * 1.6, s.y + sin(a) * 1.6)


func _bush(b: int, bd: BiomeData, w: Array, x: float, y: float) -> bool:
	var ci := _cell(x, y)
	if not _free(ci, b) or res.veg_clear[ci] == 1:
		return false
	var name: StringName = &"deadbush" if bd.bush_dead else BUSH[maxi(_wpick(w), 0)]
	occ[ci] = 3
	_addk(&"hedges", bd, name, x, y)
	return true


func _flowers() -> void:
	for b in res.biomes.size():
		rng = _stream(1 * 16 + b)   # one stream per pass and biome
		var bd := res.biomes[b]
		var w := [bd.flower_w_orange, bd.flower_w_white, bd.flower_w_blue, bd.flower_w_yellow]
		if bd.flower_per_block <= 0.0 or _wpick(w) < 0 or not _on(&"flowers", b):
			continue
		for s in _spots(b, bd.flower_per_block):
			if bd.flower_in_clear and res.veg_clear[int(s.z)] == 0:
				continue
			var row := _wpick(w)
			var pts := PackedVector2Array()
			for _k in bd.flower_tries:
				var q := Vector2(s.x + _peaked(bd.flower_spread), s.y + _peaked(bd.flower_spread))
				if not _free(_cell(q.x, q.y), b):
					continue
				var apart := true
				for o in pts:
					if o.distance_to(q) < 1.0:
						apart = false
						break
				if apart:
					pts.append(q)
					_addk(&"flowers", bd, FLOWER[row], q.x, q.y)
			if rng.randf() < bd.flower_fox and _on(&"other", b):   # a few foxgloves at the rim
				for _k in rng.randi_range(2, 3):
					var a := rng.randf() * TAU
					var qx: float = s.x + cos(a) * bd.flower_spread
					var qy: float = s.y + sin(a) * bd.flower_spread
					if _free(_cell(qx, qy), b):
						_add(veg, veg_g, &"foxglove", qx, qy)


func _foxglove() -> void:
	for b in res.biomes.size():
		rng = _stream(2 * 16 + b)   # one stream per pass and biome
		var bd := res.biomes[b]
		if bd.fox_per_block <= 0.0 or not _on(&"other", b):
			continue
		for s in _spots(b, bd.fox_per_block):
			for _k in rng.randi_range(mini(bd.fox_min, bd.fox_max), maxi(bd.fox_min, bd.fox_max)):
				var qx: float = s.x + _peaked(3.0)
				var qy: float = s.y + _peaked(3.0)
				if _free(_cell(qx, qy), b):
					_add(veg, veg_g, &"foxglove", qx, qy)


func _mushrooms() -> void:
	for b in res.biomes.size():
		rng = _stream(3 * 16 + b)   # one stream per pass and biome
		var bd := res.biomes[b]
		if bd.mush_tries <= 0.0 or not _on(&"other", b):
			continue
		for s in _spots(b, bd.mush_tries):
			for _k in rng.randi_range(mini(bd.mush_group_min, bd.mush_group_max), maxi(bd.mush_group_min, bd.mush_group_max)):
				var qx: float = s.x + rng.randf_range(-1.0, 1.0)
				var qy: float = s.y + rng.randf_range(-1.0, 1.0)
				if _free(_cell(qx, qy), b) and _trunk_within(qx, qy, bd.mush_shade):
					_add(veg, veg_g, &"mushroom", qx, qy)


func _stumps() -> void:
	for b in res.biomes.size():
		rng = _stream(4 * 16 + b)   # one stream per pass and biome
		var bd := res.biomes[b]
		if bd.stump_per_block <= 0.0 or not _on(&"other", b):
			continue
		for s in _spots(b, bd.stump_per_block):
			var ci := int(s.z)
			var list: Array = stumps.get(STUMP_MODELS[rng.randi() % STUMP_MODELS.size()], [])
			var pick := rng.randi()
			if not _free_any(ci) or list.is_empty():
				continue
			var si: int = list[pick % list.size()]
			occ[ci] = 1
			_add(si, sets[si].groups, &"snow_stump", ci % cols + 0.5, ci / cols + 1.0 - 2.0 / cell)


## Reeds: along fresh water and the coast, on the land cells next to it. A patch = reed_tries spots within a peaked +-spread of the shore cell,
## each only if some water lies within 3.2 cells.
func _reeds() -> void:
	if res.shore.is_empty():
		return
	var streams: Array[RandomNumberGenerator] = []
	for b in res.biomes.size():
		streams.append(_stream(5 * 16 + b))
	var i := res.shore.find(1)
	while i >= 0:
		rng = streams[res.biome[i]]
		var bd := res.biomes[res.biome[i]]
		if bd.reed_per_shore > 0.0 and _on(&"other", res.biome[i]) and res.land[i] == 1 and res.area[i] != MapGen.Area.BOSS and rng.randf() < bd.reed_per_shore:
			var name: StringName = &"reed_green" if rng.randf() * (bd.reed_w_green + bd.reed_w_brown) < bd.reed_w_green else &"reed_brown"
			var x := i % cols
			var y := i / cols
			for _k in bd.reed_tries:
				var qx: float = x + 0.5 + _peaked(bd.reed_spread * 2.0)
				var qy: float = y + 0.5 + _peaked(bd.reed_spread * 2.0)
				var c := _cell(qx, qy)
				if c >= 0 and res.land[c] == 1 and res.area[c] != MapGen.Area.BOSS and occ[c] == 0 and stamp[c] == 0 and _water_near(int(floorf(qx)), int(floorf(qy))):
					occ[c] = 4
					_add(veg, veg_g, name, qx, qy)
		i = res.shore.find(1, i + 1)


## Water (not dry land) within 3.2 cells of cell (cx, cy), looked for on a 3-cell grid like the preview.
func _water_near(cx: int, cy: int) -> bool:
	for dy in [-3, 0, 3]:
		for dx in [-3, 0, 3]:
			var xx: int = cx + dx
			var yy: int = cy + dy
			if (xx < 0 or yy < 0 or xx >= cols or yy >= rows or res.land[yy * cols + xx] == 0) and Vector2(dx, dy).length() <= 3.2:
				return true
	return false


## Tufts and ferns: each land cell of the biome has chance tuft_p, double within 2 cells of a trunk or 1 of a rock. Drawn as 2p random tries
## that always count near a trunk / rock and half the time elsewhere.
func _tufts() -> void:
	for b in res.biomes.size():
		rng = _stream(6 * 16 + b)   # one stream per pass and biome
		var bd := res.biomes[b]
		var w := [bd.tuft_w_green, bd.tuft_w_yellow, bd.tuft_w_brown, bd.fern_w_green, bd.fern_w_yellow, bd.fern_w_brown]
		if bd.tuft_p <= 0.0 or _wpick(w) < 0 or not _on(&"tufts", b):
			continue
		for s in _spots(b, bd.tuft_p * 2.0 * MapGen.TREE_BLOCK * MapGen.TREE_BLOCK):
			var ci := int(s.z)
			var far_chance := rng.randf()
			var which := _wpick(w)
			if not _free(ci, b):
				continue
			if far_chance >= 0.5 and not _near_trunk_or_rock(ci):
				continue
			occ[ci] = 5
			var cy := ci / cols
			_addk(&"tufts", bd, TUFT[which], s.x, cy + 0.6 + 0.4 * (s.y - cy))


func _near_trunk_or_rock(ci: int) -> bool:
	var cx := ci % cols
	var cy := ci / cols
	for dy in range(-2, 3):
		var yy := cy + dy
		if yy < 0 or yy >= rows:
			continue
		for dx in range(-2, 3):
			var xx := cx + dx
			if xx < 0 or xx >= cols:
				continue
			var o := occ[yy * cols + xx]
			if o == 1 or (o == 2 and absi(dx) <= 1 and absi(dy) <= 1):
				return true
	return false
