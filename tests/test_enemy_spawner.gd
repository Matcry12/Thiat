extends SceneTree
# W5 (0052 + 0053): EnemySpawner. Biome rates, seeded slime spots, cap lowers chance, residents on chunk load,
# soft despawn, plus the placement rules (land, safe radius, off screen, boss land, y-sort chain, nothing while dead).
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _type(sp: EnemySpawner, id: StringName) -> EnemyData:
	for d in sp.enemy_types:
		if d.id == id:
			return d
	return null

func _clear() -> void:
	for e in get_nodes_in_group("enemy"):
		e.free()

func _init() -> void:
	var arena = await World.make(self)
	var player: Node2D = arena.get_node("Player")
	var map: ArenaMap = arena.get_node("ArenaMap")
	var sp: EnemySpawner = arena.get_node("EnemySpawner")
	sp.enabled = false   # the test drives the rolls by hand
	_check(OS.get_environment("BOSSFIGHT_TEST_SEED") == "" or not EnemySpawner.new().enabled, "default off in test runs")
	sp.cap_near_player = 6
	sp.spot_tries = 40
	map.load_chunks_around(player.global_position, 3)
	await process_frame
	var home := map.home_point()
	_check(sp.enemy_types.size() == 5, "all 5 slime types listed (%d)" % sp.enemy_types.size())
	var green := _type(sp, &"slime")
	var swamp := _type(sp, &"swamp_slime")

	# --- biome rates: chance scales with the rate at the spot (a spot-free point is used)
	var pos := home
	var sd := 0
	while sp.is_spot(pos) or sp.rate_at(green, pos) <= 0.0:
		pos += Vector2(sp.spot_cell_size, 0)
		sd += 1
		if sd > 200:
			break
	var rate := sp.rate_at(green, pos)
	_check(is_equal_approx(sp.chance_for(green, pos, 0), sp.base_chance * rate), "chance = base x rate")
	_check(sp.chance_for(swamp, pos, 0) == 0.0 or sp.rate_at(swamp, pos) > 0.0, "a type with rate 0 here never rolls")
	# the spawner itself: count packs over seeded ticks vs expected (cap off, stations / spots as they are)
	sp.cap_near_player = 1000
	sp.base_chance = 0.1
	sp.spot_chance = 0.0
	seed(7)
	var packs := 0
	for i in 600:
		_clear()
		var res_s := sp.roll_tick()
		if res_s.begins_with("ok"):
			packs += 1
	_clear()
	_check(packs >= 20 and packs <= 80, "600 ticks at base 0.1: %d packs (expect ~8%% of ticks, never the full 10%%x types)" % packs)
	sp.base_chance = 0.0
	var none := 0
	for i in 100:
		_clear()
		none += 1 if sp.roll_tick().begins_with("ok") else 0
	_check(none == 0, "base_chance 0 = no spawns")
	sp.base_chance = 0.015
	sp.spot_chance = 0.1
	sp.cap_near_player = 6
	_clear()

	# --- spots: deterministic per seed, share ~ spot_chance, boost the rate
	var n_spot := 0
	var first: Array[bool] = []
	for i in 2000:
		var is_s := sp.cell_is_spot(Vector2i(i % 50, i / 50))
		first.append(is_s)
		n_spot += 1 if is_s else 0
	var same := true
	for i in 2000:
		same = same and first[i] == sp.cell_is_spot(Vector2i(i % 50, i / 50))
	_check(same, "spots are the same on a second ask")
	_check(absf(n_spot / 2000.0 - sp.spot_chance) < 0.03, "spot share %.3f ~ %.2f" % [n_spot / 2000.0, sp.spot_chance])
	var sp_pos := Vector2.ZERO
	for i in 2000:
		if first[i]:
			sp_pos = (Vector2(i % 50, i / 50) + Vector2(0.5, 0.5)) * sp.spot_cell_size
			break
	_check(sp.is_spot(sp_pos), "is_spot true at a spot centre")
	var old_seed := map.current_seed
	map.current_seed = old_seed + 1
	var other := 0
	for i in 2000:
		other += 1 if sp.cell_is_spot(Vector2i(i % 50, i / 50)) != first[i] else 0
	_check(other > 0, "another seed gives other spots")
	map.current_seed = old_seed
	var sc := sp.spot_chance
	sp.spot_chance = 1.0
	var all_spot := sp.chance_for(green, pos, 0)
	sp.spot_chance = 0.0
	var no_spot := sp.chance_for(green, pos, 0)
	sp.spot_chance = sc
	_check(is_equal_approx(all_spot, no_spot * sp.spot_rate_mult), "spot raises the chance x%.1f" % sp.spot_rate_mult)

	# --- cap lowers the chance, and refuses when full
	_check(sp.chance_for(green, pos, 3) < sp.chance_for(green, pos, 0) and is_equal_approx(sp.chance_for(green, pos, 3), sp.chance_for(green, pos, 0) * 0.5), "half full = half the chance")
	_check(sp.chance_for(green, pos, 6) == 0.0, "full = 0")

	# --- placement rules over many ticks (high chance so packs appear)
	sp.base_chance = 1.0
	sp.cap_near_player = 100
	var spawned := 0
	for i in 40:
		_clear()
		if sp.roll_tick().begins_with("ok"):
			spawned += 1
		for e: Enemy in get_nodes_in_group("enemy"):
			var p := e.global_position
			_check(map.water_kind_at(p) == MapGen.WaterKind.NONE, "on land")
			_check(sp.rate_at(e.data, p) > 0.0, "%s rate > 0 in %s" % [e.data.id, map._biome_name(p)])
			_check(p.distance_to(home) >= sp.safe_radius - 0.1, "outside safe radius")
			_check(not sp._on_screen(p, player.global_position) and p.distance_to(player.global_position) > 600.0, "off a 1152x648 screen")
			_check(p.distance_to(map.boss_point()) >= sp.boss_zone_radius, "outside boss land")
	_check(spawned > 0, "ticks spawned packs (%d/40)" % spawned)
	_clear()

	# --- cap respected
	sp.cap_near_player = 6
	for i in 60:
		sp.roll_tick()
	_check(sp.count_near(player.global_position) <= sp.cap_near_player, "cap respected (%d)" % sp.count_near(player.global_position))
	_clear()

	# --- residents: a (re)loaded chunk puts packs on spots only
	sp.cap_near_player = 100
	sp.resident_chance = 1.0
	sp.spot_chance = 0.5   # plenty of spots
	sp._seen.clear()
	sp.residents_placed = 0
	sp.place_residents()
	var res := get_nodes_in_group("enemy")
	_check(sp.residents_placed > 0 and res.size() == sp.residents_placed, "residents placed (%d)" % res.size())
	var on_spot := true
	for e: Enemy in res:
		var near_spot := false
		var c := sp._spot_cell(e.global_position)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				near_spot = near_spot or sp.cell_is_spot(c + Vector2i(dx, dy))
		on_spot = on_spot and near_spot
	_check(on_spot, "every resident stands in or next to a spot cell")
	var cam := player.global_position
	for e: Enemy in res:
		_check(map.water_kind_at(e.global_position) == MapGen.WaterKind.NONE and e.global_position.distance_to(home) >= sp.safe_radius - 0.1 and not sp._on_screen(e.global_position, cam), "resident on land, outside safe radius, off screen")
		_check(e.has_meta(&"resident_chunk"), "resident is marked")
	# residents stay while their chunk is loaded, even far away; they leave when it unloads
	player.global_position += Vector2(0, 0)
	for e: Enemy in res:
		e.global_position = player.global_position + Vector2(sp.hard_despawn_dist + 500.0, 0)   # far
	var keep_chunk: int = res[0].get_meta(&"resident_chunk")
	for i in 30:
		sp._despawn_far(1.0)
	await process_frame
	var kept := 0
	for e: Enemy in res:
		if is_instance_valid(e) and not e.is_queued_for_deletion() and map.streamer().is_loaded(int(e.get_meta(&"resident_chunk"))):
			kept += 1
	var loaded_res := res.filter(func(e): return map.streamer().is_loaded(int(e.get_meta(&"resident_chunk")))).size()
	_check(kept == loaded_res and loaded_res > 0, "residents survive 30 s of despawn ticks while their chunk is loaded (%d/%d)" % [kept, loaded_res])
	var victim: Enemy = res[0]
	map.streamer().loaded.erase(keep_chunk)   # pretend the chunk unloaded
	sp._despawn_far(1.0)
	await process_frame
	_check(not is_instance_valid(victim) or victim.is_queued_for_deletion(), "resident leaves when its chunk unloads")
	map.load_chunks_around(player.global_position, 3)
	await process_frame
	var before := get_nodes_in_group("enemy").size()
	sp.place_residents()
	_check(get_nodes_in_group("enemy").size() >= before - 5, "second call: only the reloaded chunk may add")
	sp.spot_chance = 0.0
	_clear()
	sp._seen.clear()
	sp.place_residents()
	_check(get_nodes_in_group("enemy").is_empty(), "no spots, no residents")
	sp.spot_chance = sc

	# --- new map: spawner enemies are freed and residents can be placed again
	sp.spawn(green, home + Vector2(0, 3000))
	map.rebuilt.emit()
	await process_frame
	_check(sp._seen.is_empty() and sp._holder.get_child_count() == 0, "rebuild frees the spawner's enemies and clears the chunk marks")
	_clear()

	# --- soft despawn: far idle leave eventually; hand-placed and busy stay; hard distance = at once
	_clear()
	var far := sp.spawn(green, player.global_position + Vector2(sp.despawn_dist + 100.0, 0))
	var busy := sp.spawn(green, player.global_position + Vector2(sp.despawn_dist + 100.0, 50))
	var hard := sp.spawn(green, player.global_position + Vector2(sp.hard_despawn_dist + 100.0, 0))
	var hand_e: Enemy = green.scene.instantiate()
	hand_e.data = green
	arena.add_child(hand_e)
	hand_e.global_position = player.global_position + Vector2(sp.hard_despawn_dist + 200.0, 0)
	await physics_frame
	busy.state = Enemy.State.WINDUP
	sp._despawn_far(1.0)
	await process_frame
	_check(not is_instance_valid(hard) or hard.is_queued_for_deletion(), "past hard distance: gone at once")
	sp.despawn_chance = 0.3
	for i in 60:
		sp._despawn_far(1.0)
	await process_frame
	_check(not is_instance_valid(far) or far.is_queued_for_deletion(), "far idle: soft despawn removed it")
	_check(is_instance_valid(busy) and not busy.is_queued_for_deletion(), "far winding-up enemy stays")
	_check(is_instance_valid(hand_e) and not hand_e.is_queued_for_deletion(), "hand-placed far enemy stays")
	_clear()

	# --- y-sort chain
	var e0 := sp.spawn(green, home + Vector2(0, 2000))
	var n: Node = e0
	var chain_ok := true
	while n != arena:
		n = n.get_parent()
		if not (n is CanvasItem and (n as CanvasItem).y_sort_enabled):
			chain_ok = false
	_check(chain_ok and e0.z_index == 0 and e0.visual.z_index == 0, "enemy -> arena is all y-sorted, no z_index")
	e0.free()

	# --- dead player: nothing
	player.dead = true
	_check(sp.roll_tick() == "refused: player dead", "no spawn while dead")
	player.dead = false

	print("ALL PASS" if _ok else "SOME FAILED")
	quit(0 if _ok else 1)
