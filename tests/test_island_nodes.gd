extends SceneTree
const SmallMap = preload("res://tests/support/small_map.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func a_rest(res: MapGen.Result, style: MapStyle) -> Array:
	var out := []
	for o in res.obstacles:
		if o["node"] < 0 or not String(style.resource_nodes[o["node"]].id).begins_with("treepp_"):
			out.append(o)
	return out

## What stands farther than `margin` cells from every cell of `biome`: obstacles and deco as "pos,node/set,region" keys. Used to prove a slider of one biome moves nothing elsewhere.
func _outside(res: MapGen.Result, p: MapGen.Params, biome: int, margin: int) -> Dictionary:
	var near := PackedByteArray()
	near.resize(res.land.size())
	for i in res.land.size():
		if res.land[i] == 1 and res.biome[i] == biome:
			var cx := i % p.cols
			var cy := i / p.cols
			for dy in range(maxi(cy - margin, 0), mini(cy + margin + 1, p.rows)):
				for dx in range(maxi(cx - margin, 0), mini(cx + margin + 1, p.cols)):
					near[dy * p.cols + dx] = 1
	var out := {}
	for o in res.obstacles:
		if near[MapGen.cell_index(p, Vector2i(o["pos"] / p.cell))] == 0:
			out["o%s,%s,%s" % [o["pos"], o["node"], o["region"]]] = true
	for d in res.deco:
		if near[MapGen.cell_index(p, Vector2i(d["pos"] / p.cell))] == 0:
			out["d%s,%s,%s" % [d["pos"], d["set"], d["region"]]] = true
	return out


func forest_bd_set(style: MapStyle, prop: String, v: float) -> void:
	var bd: BiomeData = style.biomes[MapGen.Biome.FOREST]
	bd.set_block_signals(true)   # the map is not to rebuild for this
	bd.set(prop, v)
	bd.set_block_signals(false)


func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").map_seed = 3   # 0038 step 4: seed 3 has every biome on the 200 x 120 island, Plains and rocky hills included
	arena.get_node("ArenaMap").map_cols = 200   # 0038 step 2: the default island is 512 x 512 now; these counts were tuned at 200 x 120
	arena.get_node("ArenaMap").map_rows = 120
	SmallMap.apply(arena.get_node("ArenaMap"))   # v3 sized biomes + water for the 512 island; these counts need the 200 x 120 sizes
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var m: ArenaMap = arena.get_node("ArenaMap")
	var style := m.style
	var by_kind := {}
	var by_area := {}
	for o in m.result.obstacles:   # the WORLD DATA: every placement, loaded as a node or not
		if o["node"] < 0:
			continue
		var k: StringName = style.resource_nodes[o["node"]].id
		by_kind[k] = by_kind.get(k, 0) + 1
		var key := "%s@%d" % [k, m.area_at(o["pos"])]
		by_area[key] = by_area.get(key, 0) + 1
	print("  nodes: %s" % [by_area])
	var aged := 0
	var ages := {}
	for k in by_kind:
		if String(k).begins_with("treepp_"):
			aged += by_kind[k]
			ages[String(k).rsplit("_", true, 1)[1]] = true   # treepp_oak_green_old: the age is the last part
	_check(aged > 100 and by_kind.get(&"rock", 0) > 30 and by_kind.get(&"copper_rock", 0) >= 3, "aged trees, rocks and copper on the island (%d trees, %d rocks, %d copper)" % [aged, by_kind.get(&"rock", 0), by_kind.get(&"copper_rock", 0)])
	_check(ages.size() == 4, "all 4 Pixel Plains tree ages appear %s" % [ages.keys()])
	# 0037 / 0038: biomes. Aged trees per 100 land cells of Plains and Forest (all climate biomes of the map); trunks never closer than a cell diagonal.
	var r: MapGen.Result = m.result
	var p0 := m.make_params()
	var cells := {}
	var trees := {}
	for i in r.land.size():
		if r.land[i] == 1:
			cells[r.biome[i]] = cells.get(r.biome[i], 0) + 1
	var circles: Array[Dictionary] = []
	var mix_rocks := 0
	for o in r.obstacles:
		if String(style.resource_nodes[o["node"]].id).begins_with("treepp_") if o["node"] >= 0 else false:
			var ci := MapGen.cell_index(p0, Vector2i(o["pos"] / p0.cell))
			trees[r.biome[ci]] = trees.get(r.biome[ci], 0) + 1
			circles.append(o)
	for sd in [3, 11, 7, 21, 42]:
		var rm := r if sd == 3 else MapGen.generate(style, p0, sd)
		for o in rm.obstacles:
			var id := String(style.resource_nodes[o["node"]].id)
			var ci2 := MapGen.cell_index(p0, Vector2i(o["pos"] / p0.cell))
			if id == "rock" and rm.biome[ci2] == MapGen.Biome.ROCKY:
				mix_rocks += 1
	var dens := {}
	for b in MapGen.Biome.size():
		dens[b] = 100.0 * trees.get(b, 0) / maxi(cells.get(b, 0), 1)
	print("  trees per 100 cells by biome: %s" % [dens])
	_check(dens[MapGen.Biome.FOREST] > dens[MapGen.Biome.PLAINS] * 4.0, "forest biome trees per 100 cells >> plains (forest %.2f, plains %.2f)" % [dens[MapGen.Biome.FOREST], dens[MapGen.Biome.PLAINS]])
	_check(dens[MapGen.Biome.AUTUMN] > 2.0, "autumn has a forest (%.1f per 100 cells; the Pixel Plains pack has no taiga tree)" % dens[MapGen.Biome.AUTUMN])
	_check(trees.get(MapGen.Biome.BEACH_SAND, 0) + trees.get(MapGen.Biome.BEACH_GRAVEL, 0) <= 3, "(almost) no tree on a beach: a trunk may lean over its cell edge (%d)" % [trees.get(MapGen.Biome.BEACH_SAND, 0) + trees.get(MapGen.Biome.BEACH_GRAVEL, 0)])
	# 0038 step 4: the deco of each biome (what each pass drew, by sprite group)
	var flowers := 0   # the live island draws only the Pixel Plains sets (pp_flowers / pp_tufts)
	var tufts := 0
	for d in r.deco:
		flowers += 1 if style.deco[d["set"]].id == &"pp_flowers" else 0
		tufts += 1 if style.deco[d["set"]].id == &"pp_tufts" else 0
	_check(flowers > 0 and tufts > 0, "the island has Pixel Plains flowers and tufts (%d, %d)" % [flowers, tufts])
	_check(mix_rocks > 30, "rocky biome has rock groups you can mine (%d rocks over 5 seeds)" % mix_rocks)
	var stone := 0
	var dirt := 0
	for i in r.land.size():
		if r.land[i] == 1 and r.biome[i] == MapGen.Biome.ROCKY:
			stone += 1 if r.ground[i] == MapGen.Ground.COBBLE else 0
			dirt += 1 if r.ground[i] == MapGen.Ground.DIRT else 0
	_check(stone > 30 and dirt > 30, "rocky ground is stone with dirt mixed in by noise (%d stone, %d dirt cells)" % [stone, dirt])
	var water_deco := 0
	for d in r.deco:
		water_deco += 0 if MapGen.is_land(r, p0, Vector2i(d["pos"] / p0.cell)) else 1
	_check(water_deco == 0, "nothing decorative on water (%d)" % water_deco)
	var overlap := 0
	var nearest := INF
	for i in circles.size():
		for j in range(i + 1, circles.size()):
			var gap: float = circles[i]["pos"].distance_to(circles[j]["pos"]) - circles[i]["radius"] - circles[j]["radius"]
			nearest = minf(nearest, gap)
			overlap += 1 if gap < 0.0 else 0
	# a slider of ONE biome moves nothing in the others (beyond the cells its own trees / patches can reach)
	var rocky_bd: BiomeData = style.biomes[MapGen.Biome.ROCKY]
	var base_f := _outside(r, p0, MapGen.Biome.FOREST, 9)
	var base_r := _outside(r, p0, MapGen.Biome.ROCKY, 9)
	var old_tt: float = style.biomes[MapGen.Biome.FOREST].tree_tries
	forest_bd_set(style, "tree_tries", old_tt - 1.0)
	var fr_b := MapGen.generate(style, p0, 3)
	forest_bd_set(style, "tree_tries", old_tt)
	var old_rpb := rocky_bd.rock_per_block
	rocky_bd.set_block_signals(true)
	rocky_bd.rock_per_block = old_rpb * 0.5
	var ro_b := MapGen.generate(style, p0, 3)
	rocky_bd.rock_per_block = old_rpb
	rocky_bd.set_block_signals(false)
	var out_f := _outside(fr_b, p0, MapGen.Biome.FOREST, 9)
	var out_r := _outside(ro_b, p0, MapGen.Biome.ROCKY, 9)
	_check(base_f.size() > 150 and out_f == base_f and r.obstacles.size() != fr_b.obstacles.size(), "forest tree_tries -1: trees, rocks and deco farther than 9 cells from forest are identical (%d things)" % base_f.size())
	_check(base_r.size() > 300 and out_r == base_r and r.obstacles.size() != ro_b.obstacles.size(), "rocky rock_per_block x0.5: everything farther than 9 cells from rocky land is identical (%d things)" % base_r.size())
	var forest_bd: BiomeData = style.biomes[MapGen.Biome.FOREST]
	var rest_a := a_rest(MapGen.generate(style, p0, 11), style)
	forest_bd.set_block_signals(true)   # the map is not to rebuild for this
	forest_bd.tree_tries = 13.0
	var rest_b := a_rest(MapGen.generate(style, p0, 11), style)
	forest_bd.tree_tries = 14.0
	forest_bd.set_block_signals(false)
	_check(rest_a == rest_b and not rest_a.is_empty(), "forest tree_tries 14 -> 13 moves no rock, copper, boss tree (%d kept)" % rest_a.size())
	_check(overlap == 0, "no two trunk circles overlap (closest gap %.1f px)" % nearest)
	# boss land = the zone grown by boss_land_cells: every land cell inside is BOSS, and none far outside
	var bc := MapGen.boss_cells(p0)
	var boss_ok := true
	for i in r.land.size():
		if r.land[i] == 1:
			boss_ok = boss_ok and ((r.area[i] == MapGen.Area.BOSS) == bc.has_point(Vector2i(i % r.cols, i / r.cols)))
	_check(boss_ok and not m.in_boss_area(m.home_point()) and m.in_boss_area(m.layout()["zone"].get_center()), "boss land = fight zone + boss_land_cells (%d)" % p0.boss_land_cells)
	var copper_ok := true
	for o in r.obstacles:
		if style.resource_nodes[o["node"]].id == &"copper_rock":
			var cb: int = r.biome[MapGen.cell_index(p0, Vector2i(o["pos"] / p0.cell))]
			copper_ok = copper_ok and (cb == MapGen.Biome.ROCKY or cb == MapGen.Biome.SNOWY)
	_check(copper_ok and by_area.get("copper_rock@2", 0) == 0, "copper only in the rocky and snowy biomes (BiomeData.copper_per_100)")
	var rock_looks_ok := true
	for o in r.obstacles:
		if style.resource_nodes[o["node"]].id == &"rock" and int(o["region"]) < 2:
			rock_looks_ok = false
	_check(rock_looks_ok, "no plain rock shows a copper (orange-brown) look")
	# 0038 step 4: Area is boss land or not
	var area_ok := true
	for i in r.land.size():
		if r.land[i] == 1 and r.area[i] != MapGen.Area.BOSS:
			area_ok = area_ok and r.area[i] == MapGen.Area.FOREST
	_check(area_ok and m.area_at(m.home_point()) == MapGen.Area.FOREST, "area is BOSS on the boss land and FOREST everywhere else, home is FOREST")
	# 0038: cold and warm never touch; home is Plains / Forest; beaches are on the water; every seed gives several biomes
	var seeds_ok := true
	var clashes := 0
	var kinds_seen := {}
	for sd in [11, 7, 3, 21, 42]:
		var rs := MapGen.generate(style, p0, sd)
		clashes += MapGen.climate_clashes(rs)
		var hc := MapGen.cell_index(p0, Vector2i(p0.player_spawn / p0.cell))
		seeds_ok = seeds_ok and (rs.biome[hc] == MapGen.Biome.PLAINS or rs.biome[hc] == MapGen.Biome.FOREST)
		for i in rs.land.size():
			if rs.land[i] == 1:
				kinds_seen[rs.biome[i]] = true
	_check(clashes == 0, "cold / warm biomes never touch (snow | forest, taiga | autumn): %d clashes over 5 seeds" % clashes)
	_check(seeds_ok, "home is Plains or Forest on 5 seeds")
	_check(kinds_seen.size() == MapGen.Biome.size(), "all %d biomes appear over 5 seeds (%d seen)" % [MapGen.Biome.size(), kinds_seen.size()])
	var clash := MapGen.Result.new()   # the check itself: a hand-made clash is counted
	clash.cols = 2
	clash.rows = 1
	clash.land = PackedByteArray([1, 1])
	clash.biomes = style.biomes
	clash.biome = PackedByteArray([MapGen.Biome.SNOWY, MapGen.Biome.FOREST])
	_check(MapGen.climate_clashes(clash) == 1, "climate_clashes counts a snow | forest pair")
	var beach_far := 0
	for i in r.land.size():
		if r.land[i] == 1 and (r.biome[i] == MapGen.Biome.BEACH_SAND or r.biome[i] == MapGen.Biome.BEACH_GRAVEL):
			var c := Vector2i(i % r.cols, i / r.cols)
			var near_water := false
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					near_water = near_water or not MapGen.is_land(r, p0, c + Vector2i(dx, dy))
			beach_far += 0 if near_water else 1
	_check(beach_far == 0, "every beach cell is within 4 cells of water")
	m.load_all_chunks()
	_check(get_nodes_in_group("map_obstacle").size() == get_nodes_in_group("resource_node").size(), "no plain cover rocks left on the island")
	_check(get_nodes_in_group("resource_node").size() == m.node_count, "every placement is a node once all chunks are loaded (%d)" % m.node_count)
	var zone: Rect2 = m.layout()["zone"]
	var in_zone := 0
	for o in m.result.obstacles:
		if zone.has_point(o["pos"]):
			in_zone += 1
	_check(in_zone == 0, "nothing in the fight zone")
	var p := m.make_params()
	_check(MapGen.floor_reachable(p, m.result.obstacles, m.result.walk_land), "all walkable ground (land + shallow water) still reachable from home")
	var a := MapGen.generate(style, p, 11)
	var b := MapGen.generate(style, p, 11)
	_check(a.obstacles == b.obstacles and a.f == b.f and a.biome == b.biome and a.deco == b.deco, "same seed = same trees, rocks, deco and biomes")
	_check(m.build_ms < 2000, "build with nodes under budget (%d ms)" % m.build_ms)
	var flat := MapGen.Params.new()
	var fr := MapGen.generate(style, flat, 11)
	var plain := true
	for o in fr.obstacles:
		plain = plain and o["node"] == -1
	_check(plain and not fr.obstacles.is_empty(), "flat map keeps its plain rocks")
	# 0038 step 4: the first tools need copper: one copper rock within copper_near_home_cells of home on 512 x 512 islands, and Plains has trees there
	m.map_cols = 512
	m.map_rows = 512
	m._rebuild_queued = false
	var big := m.make_params()
	var copper_ok_all := true
	var plains_trees := 0
	for sd in [11, 4, 9]:
		var rb := MapGen.generate(style, big, sd)
		var near_copper := 0
		for o in rb.obstacles:
			if style.resource_nodes[o["node"]].id == &"copper_rock" and (o["pos"] as Vector2).distance_to(big.player_spawn) <= big.copper_near_home_cells * big.cell:
				near_copper += 1
			elif String(style.resource_nodes[o["node"]].id).begins_with("treepp_") and rb.biome[MapGen.cell_index(big, Vector2i(o["pos"] / big.cell))] == MapGen.Biome.PLAINS:
				plains_trees += 1
		print("  seed %d: %d copper rocks within %d cells of home" % [sd, near_copper, int(big.copper_near_home_cells)])
		copper_ok_all = copper_ok_all and near_copper > 0
	_check(copper_ok_all, "512 x 512 seeds 11 / 4 / 9: a copper rock within copper_near_home_cells of home")
	_check(plains_trees > 0, "512 x 512 seeds 11 / 4 / 9: Plains has trees (%d)" % plains_trees)
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
