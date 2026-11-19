class_name MapGenNodes
extends RefCounted
## MapGen stage "nodes": moved out of map_gen.gd unchanged (static helpers; MapGen keeps the public API and the shared consts / Params / Result).


## Vegetation scratch (0038 step 4): the dry non-boss land cells grouped by block (16 x 16) and biome, the cell occupancy and the clearing mask.
## Made once per generate (first caller wins); the passes draw their random spots from these lists, so "N tries per block" is spread over
## exactly the cells of that biome in the block (a block that is half Plains gets half the Plains tries).
static func make_veg_lists(res: MapGen.Result, p: MapGen.Params) -> void:
	if res.veg_nblocks > 0:
		return
	var bs := int(MapGen.TREE_BLOCK)
	var cols := p.cols
	res.veg_bcols = (cols + bs - 1) / bs
	var brows := (p.rows + bs - 1) / bs
	res.veg_nblocks = res.veg_bcols * brows
	var nb := res.biomes.size()
	res.veg_blocks.clear()
	res.veg_by_biome.clear()
	for _k in nb * res.veg_nblocks:
		res.veg_blocks.append(PackedInt32Array())
	for _k in nb:
		res.veg_by_biome.append(PackedInt32Array())
	res.veg_all = PackedInt32Array()
	var land := res.land
	var areas := res.area
	var biome := res.biome
	for y in p.rows:
		var brow := (y / bs) * res.veg_bcols
		for x in cols:
			var i := y * cols + x
			if land[i] == 1 and areas[i] != MapGen.Area.BOSS:
				var b: int = biome[i]
				res.veg_blocks[b * res.veg_nblocks + brow + x / bs].append(i)
				res.veg_by_biome[b].append(i)
				res.veg_all.append(i)
	res.veg_occ.resize(cols * p.rows)
	res.veg_occ.fill(0)
	res.veg_clear.resize(cols * p.rows)
	res.veg_clear.fill(0)


## The smooth noise behind the local density d (0..1 before BiomeData.dens_lo / dens_hi).
static func veg_noise(res_seed: int, p: MapGen.Params) -> FastNoiseLite:
	return MapGen._noise(res_seed + MapGen.SEED_VEG_NOISE, 1.0 / maxf(p.veg_density_period, 1.0))


## Local density d at a spot of biome `bd`: noise between its dens_lo..dens_hi; a wooded biome is capped by f (young, thin trees where it meets Plains).
static func veg_density(res: MapGen.Result, bd: BiomeData, noise: FastNoiseLite, x: float, y: float, ci: int) -> float:
	var d := lerpf(bd.dens_lo, bd.dens_hi, MapGen._n01(noise, x, y))
	if bd.forest_role == BiomeData.Role.WOODED:
		d = minf(d, res.f[ci])
	return d


## Number of tries for an expected `v`: the whole part plus one more with the chance of the rest.
static func veg_count(rng: RandomNumberGenerator, v: float) -> int:
	return int(v) + (1 if rng.randf() < v - int(v) else 0)


## Aged tree nodes of the style: model * 100 + season * 10 + age index -> index into style.resource_nodes. Empty when the style has none.
static func _tree_kinds(style: MapStyle, pp := false) -> Dictionary:
	var out := {}
	var prefix := "treepp" if pp else "tree"   # Pixel Plains oaks have their own nodes (data/resource_nodes/treepp_*)
	for ki in style.resource_nodes.size():
		var parts := String((style.resource_nodes[ki] as ResourceNodeData).id).split("_")   # tree_oak_old / tree_oak_yellow_old
		if parts.size() < 3 or parts.size() > 4 or parts[0] != prefix:
			continue
		var model := BiomeData.MODELS.find(StringName(parts[1]))
		var age := MapGen.AGES.find(StringName(parts[parts.size() - 1]))
		var season := 0 if parts.size() == 3 else BiomeData.SEASONS.find(StringName(parts[2]))
		if model > 0 and age >= 0 and season >= 0:
			out[model * 100 + season * 10 + age] = ki
	return out


## The node for (model, season, age); when the tree has no such age (dead firs have no saplings) the nearest age that exists. -1 = none.
static func _tree_node(kinds: Dictionary, model: int, season: int, age: int) -> int:
	for d in 5:
		for a in [age - d, age + d]:
			if a >= 0 and a < 5 and kinds.has(model * 100 + season * 10 + a):
				return kinds[model * 100 + season * 10 + a]
	return -1


## Age index (0 sapling .. 4 old) of a new tree in biome `bd` at local density d, capped by BiomeData.max_stage.
static func _tree_age(p: MapGen.Params, bd: BiomeData, d: float, rng: RandomNumberGenerator) -> int:
	var u := rng.randf()
	var age := 3
	if bd.age_rule == 1:   # fixed weights
		var w := [bd.age_w_sapling, bd.age_w_young, bd.age_w_small, bd.age_w_mature, bd.age_w_old]
		var tot := 0.0
		for x in w:
			tot += x
		var acc := 0.0
		u *= tot
		age = 4
		for k in 5:
			acc += w[k]
			if u <= acc:
				age = k
				break
	elif d > p.age_core:
		age = 4 if u < p.core_old else 3
	elif d > p.age_mid:
		age = 2 if u < p.mid_small else 3
	else:
		age = 1 if u < p.edge_young else (0 if u < p.edge_young + p.edge_sapling else 2)
	return mini(age, bd.max_stage)


## One tree on cell `c` (which must belong to `biome`) if every check passes (land, not boss land, not near home, not in a clearing, not on a shore cell, the trunk cell and its
## 4 neighbours free of trunks, `ring` cells free around it, the circle legal). True = placed.
static func _put_tree(res: MapGen.Result, style: MapStyle, p: MapGen.Params, rng: RandomNumberGenerator, c: Vector2i, biome: int, node: int, ring: int, home: Vector2) -> bool:
	# every random number of the try is drawn first: a check that fails (because another biome's tree stands there) must not shift this biome's stream
	var v_draw := rng.randi()
	var jit := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * p.tree_jitter * p.cell
	if node < 0 or c.x < 0 or c.y < 0 or c.x >= p.cols or c.y >= p.rows:
		return false
	var ci := c.y * p.cols + c.x
	if res.land[ci] == 0 or res.area[ci] == MapGen.Area.BOSS or res.biome[ci] != biome or res.veg_clear[ci] == 1:
		return false   # a group member that would land in another biome is dropped: each biome only grows its own table
	if Vector2(c.x + 0.5, c.y + 0.5).distance_to(home) < p.tree_home_clear:
		return false
	var occ := res.veg_occ
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _trunk_at(occ, p, c + d):
			return false
	if ring > 0:
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if dx * dx + dy * dy <= ring * ring and _trunk_at(occ, p, c + Vector2i(dx, dy)):
					return false
	var kind: ResourceNodeData = style.resource_nodes[node]
	var v := v_draw % kind.regions.size()
	# trunk foot near the bottom of its cell (jittered, so no rows); the collision circle sits on the foot
	var pos := Vector2((c.x + 0.5) * p.cell, (c.y + 1.0) * p.cell - 2.0 - kind.radius) + jit
	if not res.shore.is_empty():   # the drawn tree, not its cell: the jitter can move the foot or the circle onto a shore cell
		for q in [pos, pos + Vector2(0.0, kind.radius)]:
			var sc := MapGen.cell_index(p, Vector2i((q / p.cell).floor()))
			if sc >= 0 and res.shore[sc] == 1:
				return false
	# spacing 0: only trunks that would overlap (or overlap a rock) are dropped
	if not MapGenWalk._obstacle_legal(res, p, pos, kind.radius, kind.regions[v].size * float(kind.pixel_scale), 0.0):
		return false
	MapGenWalk._add_obstacle(res, {"region": v, "pos": pos, "radius": kind.radius, "node": node})
	occ[ci] = 1
	return true


static func _trunk_at(occ: PackedByteArray, p: MapGen.Params, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < p.cols and c.y < p.rows and occ[c.y * p.cols + c.x] == 1


## Trees of every biome (rules: vegetation-rules.md, numbers: BiomeData). Per biome and 16x16-cell block, random tries over that biome's cells;
## a try that fails a check is dropped, never moved. Chance fades with f where an open (Plains) biome meets a wooded one and, for a biome that
## asks for it, with the local density d. Age follows d (forest rule or fixed weights), colour and model come from the biome's tree table.
## One random stream per biome. `kinds` = _tree_kinds().
static func _place_trees(res: MapGen.Result, style: MapStyle, p: MapGen.Params, kinds: Dictionary) -> void:
	make_veg_lists(res, p)
	var home := Vector2(p.player_spawn / p.cell)
	var cols := p.cols
	var nb := res.biomes.size()
	# 1. clearings (own stream) in the biomes that have them; the mask makes the per-try test one lookup
	var crng := MapGen._rng(res.seed + MapGen.SEED_CLEARINGS)
	res.clearings.clear()
	var wooded := PackedInt32Array()
	for b in nb:
		if res.biomes[b].has_clearings:
			wooded.append_array(res.veg_by_biome[b])
	if not wooded.is_empty():
		for _i in roundi(wooded.size() / maxf(p.clearing_per_cells, 1.0)):
			var fc := wooded[crng.randi() % wooded.size()]
			res.clearings.append(Vector3(fc % cols + 0.5, fc / cols + 0.5, crng.randf_range(p.clearing_r_min, p.clearing_r_max)))
	for cl in res.clearings:
		for cy in range(maxi(int(cl.y - cl.z) - 1, 0), mini(int(cl.y + cl.z) + 2, p.rows)):
			for cx in range(maxi(int(cl.x - cl.z) - 1, 0), mini(int(cl.x + cl.z) + 2, cols)):
				if Vector2(cx + 0.5, cy + 0.5).distance_to(Vector2(cl.x, cl.y)) <= cl.z:
					res.veg_clear[cy * cols + cx] = 1
	# 2. trees
	var dn := veg_noise(res.seed, p)
	var bcells := MapGen.TREE_BLOCK * MapGen.TREE_BLOCK
	for b in nb:
		var bd := res.biomes[b]
		var rows := bd.tree_rows()
		if bd.tree_tries <= 0.0 or rows.is_empty() or (p.pp != null and not p.pp.shows(&"trees", b)):
			continue
		var total := 0.0
		for r in rows:
			total += r.z
		var rng := MapGen._rng(res.seed + MapGen.SEED_TREE_BIOME + b)
		var role := bd.forest_role
		for blk in res.veg_nblocks:
			var cells := res.veg_blocks[b * res.veg_nblocks + blk]
			if cells.is_empty():
				continue
			for _t in veg_count(rng, bd.tree_tries * cells.size() / bcells):
				var ci := cells[rng.randi() % cells.size()]
				var x := ci % cols + rng.randf()
				var y := ci / cols + rng.randf()
				var f: float = res.f[ci]
				if role == BiomeData.Role.WOODED:
					if rng.randf() >= MapGenBiomes._smooth(p.band_lo, p.band_hi, f):
						continue
				elif role == BiomeData.Role.OPEN:
					if rng.randf() >= 1.0 - MapGenBiomes._smooth(p.band_lo, p.band_hi, f):
						continue
				var d := veg_density(res, bd, dn, x, y, ci)
				if bd.fade_by_density and rng.randf() >= MapGenBiomes._smooth(p.tree_fade_lo, p.tree_fade_hi, d):
					continue
				var u := rng.randf() * total
				var row: Vector3 = rows[rows.size() - 1]
				for r in rows:
					u -= r.z
					if u <= 0.0:
						row = r
						break
				var spots: Array[Vector2] = [Vector2(x, y)]
				if bd.group_model > 0 and int(row.x) == bd.group_model:
					for _g in rng.randi_range(mini(bd.group_min, bd.group_max), maxi(bd.group_min, bd.group_max)) - 1:
						spots.append(Vector2(x, y) + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * p.fir_group_radius)
				for sp in spots:
					var sc := Vector2i(sp.floor())
					var sci := sc.y * cols + sc.x if sc.x >= 0 and sc.y >= 0 and sc.x < cols and sc.y < p.rows else -1
					var sd := d if sci < 0 else veg_density(res, bd, dn, sp.x, sp.y, sci)
					var age := _tree_age(p, bd, sd, rng)
					var node := _tree_node(kinds, int(row.x), int(row.y), age)
					if node < 0 and p.pp != null and int(row.x) == 1 and b < p.pp.tree_fallback_season.size() and p.pp.tree_fallback_season[b] >= 0:
						node = _tree_node(kinds, 1, p.pp.tree_fallback_season[b], age)   # Pixel Plains has no dead / teal oak: the biome's own colour stands there
					_put_tree(res, style, p, rng, sc, b, node, bd.tree_ring, home)


## Trees, rocks and copper. Boss land: each kind at its `density_boss`. Elsewhere (0038 step 4) per biome: lone rocks and copper by
## BiomeData.rock_nodes_per_100 / copper_per_100, rock groups (their middle pieces are mineable rocks), then the aged trees.
static func _place_nodes(res: MapGen.Result, style: MapStyle, p: MapGen.Params) -> void:
	if p.yard:
		_place_yard_nodes(res, style, p)
		return
	var t := Time.get_ticks_usec()
	make_veg_lists(res, p)
	var boss_cells := PackedInt32Array()
	for i in res.land.size():
		if res.land[i] == 1 and res.area[i] == MapGen.Area.BOSS:
			boss_cells.append(i)
	var spacing := maxf(p.obstacle_min_spacing, MapGenWalk.rock_clearance(p))
	var widest := 0.0
	for k in style.resource_nodes:
		widest = maxf(widest, k.radius)
	res.obstacle_bucket = 2.0 * widest + spacing
	t = MapGen._lap(res, "nodes.cells", t)
	var tree_kinds := _tree_kinds(style, p.pp != null) if p.trees_on else {}   # aged trees fill the land (below); the old tree then keeps to the boss land
	var ki_rock := -1
	var ki_copper := -1
	for ki in style.resource_nodes.size():
		var kind: ResourceNodeData = style.resource_nodes[ki]
		if String(kind.id).begins_with("tree") and (String(kind.id).begins_with("treepp") != (p.pp != null)):
			continue   # the old trees in Pixel Plains mode (boss land stays treeless) and the Pixel Plains oaks in the old look: not scattered
		if kind.id == &"rock":
			ki_rock = ki
		elif kind.id == &"copper_rock":
			ki_copper = ki
		_scatter(res, p, kind, ki, boss_cells, roundi(kind.density_boss * boss_cells.size() / 100.0), MapGen._rng(res.seed + MapGen.SEED_KIND + ki * 3 + MapGen.Area.BOSS), spacing)
		if kind.id == &"tree":
			if tree_kinds.is_empty():
				_scatter(res, p, kind, ki, res.veg_all, roundi(kind.density_forest * res.veg_all.size() / 100.0), MapGen._rng(res.seed + MapGen.SEED_KIND + ki * 3), spacing)
			continue
		if kind.id != &"rock" and kind.id != &"copper_rock":
			continue
		for b in res.biomes.size():
			var per100 := res.biomes[b].rock_nodes_per_100 if kind.id == &"rock" else res.biomes[b].copper_per_100
			if per100 > 0.0:
				var list := res.veg_by_biome[b]
				_scatter(res, p, kind, ki, list, roundi(per100 * list.size() / 100.0), MapGen._rng(res.seed + MapGen.SEED_KIND_BIOME + ki * 16 + b), spacing)
	t = MapGen._lap(res, "nodes.rocks", t)
	if ki_rock >= 0:
		_place_rock_groups(res, style, p, ki_rock)
	if ki_copper >= 0 and ki_rock >= 0:
		_ensure_copper(res, style, p, ki_copper, ki_rock, spacing)
	t = MapGen._lap(res, "nodes.groups", t)
	MapGenWalk._repair_reach(res, p)
	t = MapGen._lap(res, "nodes.repair1", t)
	if not tree_kinds.is_empty():   # trees go last and see the rocks, so a tree slider never moves a rock; the second repair may only drop trees
		_place_trees(res, style, p, tree_kinds)
		t = MapGen._lap(res, "nodes.trees", t)
		MapGenWalk._repair_reach(res, p, tree_kinds.values())
		t = MapGen._lap(res, "nodes.repair2", t)
	_assign_looks(res, style, p)


## Test yard: exactly the listed nodes, nothing random. Same obstacle dicts as the island, so chunks/chop/mine are the real code.
static func _place_yard_nodes(res: MapGen.Result, style: MapStyle, p: MapGen.Params) -> void:
	var widest := 0.0
	for k in style.resource_nodes:
		widest = maxf(widest, k.radius)
	res.obstacle_bucket = 2.0 * widest + p.obstacle_min_spacing
	for n in p.yard_nodes:
		for ki in style.resource_nodes.size():
			if style.resource_nodes[ki].id == n["id"]:
				MapGenWalk._add_obstacle(res, {"region": 0, "pos": n["pos"], "radius": style.resource_nodes[ki].radius, "node": ki})
				break
	_assign_looks(res, style, p)


## The first tools need copper: if no copper rock stands within `copper_near_home_cells` of home, put a small outcrop (one copper rock and two rocks
## beside it) on dry non-boss land 40% to 100% of that distance from home. Own stream; nothing else moves. Skipped when no legal spot exists.
static func _ensure_copper(res: MapGen.Result, style: MapStyle, p: MapGen.Params, ki_copper: int, ki_rock: int, spacing: float) -> void:
	if p.copper_near_home_cells <= 0.0:
		return
	var home := Vector2(p.player_spawn / p.cell)
	var reach := p.copper_near_home_cells * p.cell
	for o in res.obstacles:
		if o["node"] == ki_copper and (o["pos"] as Vector2).distance_to(p.player_spawn) <= reach:
			return
	var cells := PackedInt32Array()
	for ci in res.veg_all:
		var d := Vector2(ci % p.cols + 0.5, ci / p.cols + 0.5).distance_to(home)
		if d >= p.copper_near_home_cells * 0.4 and d <= p.copper_near_home_cells:
			cells.append(ci)
	if cells.is_empty():
		return
	var rng := MapGen._rng(res.seed + MapGen.SEED_ROCKS + 20)
	var kc: ResourceNodeData = style.resource_nodes[ki_copper]
	var kr: ResourceNodeData = style.resource_nodes[ki_rock]
	for _attempt in 600:
		var ci := cells[rng.randi() % cells.size()]
		var pos := (Vector2(ci % p.cols, ci / p.cols) + Vector2(rng.randf(), rng.randf())) * p.cell
		if not MapGenWalk._obstacle_legal(res, p, pos, kc.radius, Vector2(kc.regions[0].size) * float(kc.pixel_scale) if not kc.regions.is_empty() else Vector2.ZERO, spacing):
			continue
		MapGenWalk._add_obstacle(res, {"region": 0, "pos": pos, "radius": kc.radius, "node": ki_copper})
		for _k in 2:   # the two rocks beside it, if they fit
			var rpos := pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 3.0) * kr.radius * 1.2
			var v := rng.randi() % maxi(kr.regions.size(), 1)
			var sprite := kr.regions[v].size * float(kr.pixel_scale) if v < kr.regions.size() else Vector2.ZERO
			if MapGenWalk._obstacle_legal(res, p, rpos, kr.radius, sprite, 4.0):
				MapGenWalk._add_obstacle(res, {"region": v, "pos": rpos, "radius": kr.radius, "node": ki_rock})
		return


## `target` lone nodes of `kind`, each at a random spot of a random cell of `cells` (cell indices), when the spot is legal.
static func _scatter(res: MapGen.Result, p: MapGen.Params, kind: ResourceNodeData, ki: int, cells: PackedInt32Array, target: int, rng: RandomNumberGenerator, spacing: float) -> void:
	if cells.is_empty():
		return
	var made := 0
	for _attempt in target * 60:
		if made >= target:
			break
		var ci := cells[rng.randi() % cells.size()]
		var pos := (Vector2(ci % p.cols, ci / p.cols) + Vector2(rng.randf(), rng.randf())) * p.cell
		var v := rng.randi() % maxi(kind.regions.size(), 1)
		var sprite := kind.regions[v].size * float(kind.pixel_scale) if v < kind.regions.size() else Vector2.ZERO
		if MapGenWalk._obstacle_legal(res, p, pos, kind.radius, sprite, spacing):
			MapGenWalk._add_obstacle(res, {"region": v, "pos": pos, "radius": kind.radius, "node": ki})
			made += 1


## Rock groups of every biome: per block `rock_per_block` groups, each = rock_mid_min..max middle pieces + rock_small_min..max small stones.
## Boulders and the small stones are decoration (res.rock_pieces, BiomeVeg draws them); medium and big pieces are `rock` nodes you can mine
## (region 0 / 1 brown big / medium, 2 / 3 grey). A piece that fails a check is dropped. Own stream per biome.
static func _place_rock_groups(res: MapGen.Result, style: MapStyle, p: MapGen.Params, ki_rock: int) -> void:
	var kind: ResourceNodeData = style.resource_nodes[ki_rock]
	var cols := p.cols
	var bcells := MapGen.TREE_BLOCK * MapGen.TREE_BLOCK
	for b in res.biomes.size():
		var bd := res.biomes[b]
		var wsum := bd.rock_w_boulder + bd.rock_w_med + bd.rock_w_big
		if bd.rock_per_block <= 0.0 or wsum <= 0.0:
			continue
		var rng := MapGen._rng(res.seed + MapGen.SEED_ROCKS + b)
		for blk in res.veg_nblocks:
			var cells := res.veg_blocks[b * res.veg_nblocks + blk]
			if cells.is_empty():
				continue
			for _t in veg_count(rng, bd.rock_per_block * cells.size() / bcells):
				var ci := cells[rng.randi() % cells.size()]
				var x := ci % cols + rng.randf()
				var y := ci / cols + rng.randf()
				if res.veg_clear[ci] == 1:
					continue
				var grey := rng.randf() >= bd.rock_brown_share
				for i in rng.randi_range(mini(bd.rock_mid_min, bd.rock_mid_max), maxi(bd.rock_mid_min, bd.rock_mid_max)):
					var at := Vector2(x, y)
					if i > 0:
						at += Vector2.from_angle(rng.randf() * TAU) * p.rock_group_radius * sqrt(rng.randf())
					var u := rng.randf() * wsum
					var pick := 0   # 0 boulder, 1 medium, 2 big
					if u > bd.rock_w_boulder:
						pick = 1 if u <= bd.rock_w_boulder + bd.rock_w_med else 2
					if pick == 0:
						res.rock_pieces.append(Vector3(at.x, at.y, 1.0 if grey else 0.0))
						continue
					var c := Vector2i(at.floor())
					var cj := MapGen.cell_index(p, c)
					if cj < 0 or res.land[cj] == 0 or res.area[cj] == MapGen.Area.BOSS:
						continue
					var v := (2 if grey else 0) + (0 if pick == 2 else 1)
					if v >= kind.regions.size():
						continue
					var pos := at * p.cell
					if MapGenWalk._obstacle_legal(res, p, pos, kind.radius, kind.regions[v].size * float(kind.pixel_scale), 4.0):
						MapGenWalk._add_obstacle(res, {"region": v, "pos": pos, "radius": kind.radius, "node": ki_rock})
						res.veg_occ[cj] = 2
				for _k in rng.randi_range(mini(bd.rock_small_min, bd.rock_small_max), maxi(bd.rock_small_min, bd.rock_small_max)):
					var a := rng.randf() * TAU
					var dd := bd.rock_spread * sqrt(rng.randf())
					res.rock_pieces.append(Vector3(x + cos(a) * dd, y + sin(a) * dd * 0.7, 3.0 if grey else 2.0))


## Which picture each node shows, by the area it stands in (forest: green trees, rocky: autumn / dead, boss: dead).
## Runs AFTER placement and draws no random numbers, so a seed still gives the same nodes in the same places.
static func _assign_looks(res: MapGen.Result, style: MapStyle, p: MapGen.Params) -> void:
	for i in res.obstacles.size():
		var o := res.obstacles[i]
		if o["node"] < 0:
			continue
		var c := Vector2i(o["pos"] / p.cell)
		var ci := MapGen.cell_index(p, c)
		if ci < 0:
			continue
		var look := (style.resource_nodes[o["node"]] as ResourceNodeData).look_for(res.area[ci], c.x * 7 + c.y * 13 + i)
		if look >= 0:
			o["region"] = look
