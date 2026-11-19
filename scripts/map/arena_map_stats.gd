class_name ArenaMapStats
extends RefCounted
## ArenaMap helper: counts of the built map (compute) and the F3 [Map] status text. Moved out of arena_map.gd unchanged.


## Fills the cached numbers on `m` (node / tree / deco counts, biome shares, water text) from m.result.
static func compute(m: ArenaMap) -> void:
	var counts: Array[int] = []
	counts.resize(MapGen.Biome.size())
	var land := 0
	var land_a := m.result.land
	var biome_a := m.result.biome
	var has_biome := not biome_a.is_empty()
	for i in land_a.size():
		if land_a[i] == 1:
			land += 1
			if has_biome:
				counts[biome_a[i]] += 1
	m.water_text = "none"
	if not m.result.shallow.is_empty():
		var river := 0
		var lake := 0
		var shallow := 0
		for i in land_a.size():
			shallow += m.result.shallow[i]
			river += int(m.result.fresh[i] == 1)
			lake += int(m.result.fresh[i] == 2)
		m.water_text = "river %d  lake %d  shallow %d cells (walkable); deep ocean blocks" % [river, lake, shallow]
	m.land_pct = 100 * land / maxi(land_a.size(), 1)
	m.node_count = 0
	m.stone_count = 0
	m.copper_count = 0
	m.tree_counts.clear()
	m.tree_colours.clear()
	m.deco_counts.clear()
	for age in MapGen.AGES:
		m.tree_counts[age] = 0
	var is_tree := PackedByteArray()   # per node kind: 1 = an aged tree
	for k in m.style.resource_nodes:
		is_tree.append(1 if String(k.id).begins_with("tree") else 0)
	for o in m.result.obstacles:
		m.node_count += 1 if o["node"] >= 0 else 0
		if o["node"] >= 0:
			var nid: StringName = m.style.resource_nodes[o["node"]].id
			m.stone_count += int(nid == &"rock")
			m.copper_count += int(nid == &"copper_rock")
		if o["node"] >= 0 and is_tree[o["node"]] == 1:
			var parts := String(m.style.resource_nodes[o["node"]].id).split("_")   # tree_oak_old / tree_oak_yellow_old: the age is the last part
			m.tree_counts[StringName(parts[parts.size() - 1])] += 1
			var colour: String = parts[2] if parts.size() == 4 else "green"
			m.tree_colours[colour] = m.tree_colours.get(colour, 0) + 1
	var family: Array[Dictionary] = []   # per deco set: region index -> kind (flower_0 -> flower, tuft_green -> tuft, snow_stump -> stump)
	for set in m.style.deco:
		var fam := {}
		for g in set.groups:
			var name := String(g)
			for r in set.groups[g]:
				fam[r] = "stump" if name.ends_with("_stump") else (name if name in ["deadbush", "mushroom", "foxglove"] else name.rsplit("_", true, 1)[0])
		family.append(fam)
	for d in m.result.deco:
		var kind: String = family[d["set"]].get(d["region"], "other")
		m.deco_counts[kind] = m.deco_counts.get(kind, 0) + 1
	m.biome_pct.clear()
	m.biome_pct.resize(MapGen.Biome.size())
	var given := 0
	var order: Array[int] = []   # largest remainder: the shares sum to 100
	for b in counts.size():
		m.biome_pct[b] = 100 * counts[b] / maxi(land, 1)
		given += m.biome_pct[b]
		order.append(b)
	order.sort_custom(func(x: int, y: int) -> bool: return (100 * counts[x]) % maxi(land, 1) > (100 * counts[y]) % maxi(land, 1))
	for k in range(mini(100 - given, order.size()) if land > 0 else 0):
		m.biome_pct[order[k]] += 1


static func status_text(m: ArenaMap) -> String:
	if m.result == null:
		return "n/a"
	var player := m.get_node_or_null(m.player_path) as Node2D
	var here: Vector2 = player.global_position if player else Vector2.ZERO
	var ai := m.area_at(here) if player else -1
	var shares: Array[String] = []
	for b in m.result.biomes.size():
		if not m.biome_pct.is_empty() and m.biome_pct[b] > 0:
			shares.append("%s %d" % [m.result.biomes[b].label, m.biome_pct[b]])
	return "zoom: %.2f (target %.2f)\nseed: %d  size: %dx%d cells (%dx%d px)\ndirt patches: %d  rocks: %d  deco: %d  bushes: %d\narea %s  land %d%%  nodes %d (stone %d, copper %d)  dirt cells %d\nbiome %s  temperature %.2f  humidity %.2f  roughness %.2f  f %.2f\nground: %s\nwater: %s\nbiome %% of land: %s\ntrees by age: %s\ntrees by colour: %s\ndeco by kind: %s\nbuild %d ms (world data %d ms, first chunks %d ms)\n%s" % [
		m._camera.zoom.x if m._camera else 1.0, m.camera_zoom, m.current_seed, m.map_cols, m.map_rows, m.map_size().x, m.map_size().y,
		m.result.patches.size(), m.result.obstacles.size(), m.result.deco.size(), m.result.border.size(),
		["forest", "rocky", "boss"][ai] if ai >= 0 else "water", m.land_pct, m.node_count, m.stone_count, m.copper_count, m.result.dirt_cells.size(),
		m._biome_name(here), m._climate_here(m.result.temp, here), m._climate_here(m.result.humid, here), m._climate_here(m.result.rough, here), m._climate_here(m.result.f, here),
		m._ground_text(here), m.water_text, ", ".join(shares),
		" ".join(MapGen.AGES.map(func(a): return "%s %d" % [a, m.tree_counts.get(a, 0)])), m._counts_text(m.tree_colours), m._counts_text(m.deco_counts), m.build_ms, m.gen_ms, m.bake_ms, m._streamer.status_text() if m._streamer else ""]


static func _ground_text(m: ArenaMap, here_pos: Vector2) -> String:
	if m.style == null or m.style.pixel_plains == null:
		return "old tinted tiles"
	if m._pp_shares_of != m.result:   # counted once per map
		m._pp_shares = PixelPlainsBaker.shares(m.result, m.style.pixel_plains)
		m._pp_shares_of = m.result
	var hi := m._cell_i(here_pos)
	var cell_text := "" if hi < 0 else "\n  here: " + PixelPlainsBaker.report(m.result, m.style.pixel_plains, hi % m.result.cols, hi / m.result.cols)
	var shown := ""
	if hi >= 0:   # which plants the pack art draws in the biome under the player (PixelPlainsGround.show_*)
		var bi: int = m.result.biome[hi]
		shown = "\n  plants here (biome %d): %s" % [bi, " ".join(["trees", "flowers", "tufts", "hedges", "other"].map(func(k): return "%s %s" % [k, "on" if m.style.pixel_plains.shows(StringName(k), bi) else "hidden"]))]
	return "pixel plains, no tint (land: dirt %d%% light %d%% dark %d%% sand %d%% snow %d%%, before the dark-near-dirt rule)  all trees hidden %s  all plants hidden %s%s%s" % [m._pp_shares[0], m._pp_shares[1], m._pp_shares[2], m._pp_shares[3], m._pp_shares[4], m.style.pixel_plains.hide_trees, m.style.pixel_plains.hide_veg, shown, cell_text] + "\n" + BiomeArt.get_default().status_text()


static func _biome_name(m: ArenaMap, pos: Vector2) -> String:
	var i := m._cell_i(pos)
	if i >= 0 and not m.result.shallow.is_empty() and m.result.shallow[i] == 1:
		return ["", "river", "lake", "coast shallows"][m.result.fresh[i] if m.result.fresh[i] != 0 else 3]
	if i < 0 or m.result.biome.is_empty() or m.result.land[i] == 0:
		return "n/a"
	return m.result.biomes[m.result.biome[i]].label


static func _counts_text(m: ArenaMap, counts: Dictionary) -> String:
	var parts: Array[String] = []
	for k in counts:
		parts.append("%s %d" % [k, counts[k]])
	return " ".join(parts) if not parts.is_empty() else "none"


static func _climate_here(m: ArenaMap, values: PackedFloat32Array, pos: Vector2) -> float:
	var i := m._cell_i(pos)
	return values[i] if i >= 0 and not values.is_empty() else 0.0
