class_name EnemySpawner
extends Node2D
## Spawns packs of world enemies (decision 0052, survival-ideas §2): off-screen, inside loaded chunks, on land, in a listed biome,
## never near home or a station, capped near the player; far idle enemies are removed. Enemies are not saved.

## Off in test runs (BOSSFIGHT_TEST_SEED set, like SaveGame) so tests are not disturbed; tests that want it set it true.
@export var enabled := OS.get_environment("BOSSFIGHT_TEST_SEED") == ""
@export var enemy_types: Array[EnemyData] = []
@export_range(0.1, 10.0, 0.1, "or_greater") var tick_interval := 1.0   ## s between rolls (0053: chance per tick, no fixed pack timer)
@export_range(0.0, 1.0, 0.005) var base_chance := 0.015   ## per type per tick, before biome rate / spot bonus / cap. ~1 roaming pack/min outside spots, x spot_rate_mult in one
@export_range(0.0, 600.0, 1.0, "or_greater") var screen_margin := 80.0   ## extra px beyond the screen edge
@export_range(100.0, 4000.0, 10.0, "or_greater") var spawn_max_dist := 900.0
@export_range(0, 50, 1, "or_greater") var cap_near_player := 4
@export_range(100.0, 4000.0, 10.0, "or_greater") var cap_radius := 1000.0
@export_range(0.0, 1500.0, 1.0, "or_greater") var safe_radius := 260.0   ## round home and every placed station
@export_range(0.0, 200.0, 1.0, "or_greater") var clear_gap := 6.0   ## extra px between the enemy body and any rock / node / station collision circle
@export_range(0.0, 3000.0, 1.0, "or_greater") var boss_zone_radius := 450.0   ## no spawns this close to the boss point
@export var min_screen := Vector2(1152, 648)   ## screen size floor (design resolution), so the ring is the same headless
@export_range(0.0, 400.0, 1.0, "or_greater") var pack_spread := 70.0
@export_range(100.0, 6000.0, 10.0, "or_greater") var despawn_dist := 1400.0   ## far + idle: leaves by chance
@export_range(0.0, 1.0, 0.005) var despawn_chance := 0.1   ## per second while far
@export_range(100.0, 9000.0, 10.0, "or_greater") var hard_despawn_dist := 2600.0   ## idle past this: gone at once
@export_group("Slime spots")
@export_range(64.0, 2000.0, 8.0, "or_greater") var spot_cell_size := 320.0
@export_range(0.0, 1.0, 0.01) var spot_chance := 0.1   ## share of squares that are spots (same seed = same spots)
@export_range(1.0, 20.0, 0.1, "or_greater") var spot_rate_mult := 4.0
@export_range(0.0, 1.0, 0.01) var resident_chance := 0.6   ## per spot, once per chunk load
@export_group("")
@export_range(1, 40, 1, "or_greater") var spot_tries := 12   ## random points tried per pack

@onready var _map: ArenaMap = get_tree().get_first_node_in_group("arena_map") as ArenaMap
var _holder: Node2D
var _ring: Node2D
var _timer := 0.0
var last_result := "none yet"
var residents_placed := 0
var _seen := {}   ## chunk ids already given their residents (cleared when the chunk unloads)

func _ready() -> void:
	add_to_group("debug")
	y_sort_enabled = true   # enemies sort by their feet with the player, trees and stations (a plain Node here would break it)
	_holder = Node2D.new()
	_holder.y_sort_enabled = true
	_holder.name = "Enemies"
	add_child(_holder)
	_ring = Node2D.new()   # F1 shapes only; follows the DebugOverlay switch
	_ring.name = "SpawnRingDebug"
	_ring.z_index = 100
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_timer = tick_interval
	if _map != null:
		_map.rebuilt.connect(_on_map_rebuilt)

## New map / new seed: the old enemies belong to the old world, the new chunks get their residents.
func _on_map_rebuilt() -> void:
	for e in _holder.get_children():
		e.queue_free()
	_seen.clear()
	residents_placed = 0

func _process(delta: float) -> void:
	var ov := get_node_or_null("../DebugOverlay")
	_ring.visible = ov != null and ov.get("enabled") == true
	if _ring.visible:
		_ring.queue_redraw()
	if not enabled:
		return
	_timer -= delta
	if _timer <= 0.0:
		var dt := tick_interval - _timer
		_timer = tick_interval
		_despawn_far(dt)
		place_residents()
		last_result = roll_tick()

# ---- rules

func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

func _blocked_now() -> String:
	var p := _player()
	if p == null or p.get("dead"):
		return "player dead"
	var b := get_tree().get_first_node_in_group("boss") as Boss
	if b != null and b.aggro == Boss.Aggro.ENGAGED:
		return "boss engaged"
	return ""

func _screen_half() -> Vector2:   # half the visible world size (zoom included)
	var vp := get_viewport()
	var size := vp.get_visible_rect().size.max(min_screen)
	return size / vp.get_canvas_transform().get_scale().x * 0.5

func _screen_center(fallback: Vector2) -> Vector2:
	var cam := get_viewport().get_camera_2d()
	return cam.get_screen_center_position() if cam != null else fallback

## Collision circle radius of a node/station/rock (its CollisionShape2D), else a guess.
func _radius(n: Node2D) -> float:
	var cs := n.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs != null and cs.shape is CircleShape2D:
		return (cs.shape as CircleShape2D).radius
	return 20.0

func min_dist() -> float:
	return _screen_half().length() + screen_margin

func _on_screen(pos: Vector2, center: Vector2) -> bool:
	var h := _screen_half() + Vector2(screen_margin, screen_margin)
	var d := (pos - center).abs()
	return d.x < h.x and d.y < h.y

func _near_safe(pos: Vector2) -> bool:
	if _map != null and pos.distance_to(_map.home_point()) < safe_radius:
		return true
	for s: Node2D in get_tree().get_nodes_in_group("station"):
		if pos.distance_to(s.global_position) < safe_radius:
			return true
	return false

## "" = the spot is fine for a body of `body_r`, else why not. Chunk + land + safe + boss + props (no biome rule here).
func spot_problem(pos: Vector2, body_r := 10.0) -> String:
	if _map == null or _map.streamer() == null:
		return "no map"
	var st := _map.streamer()
	var id := st.chunk_id_at(pos)
	if id < 0 or not st.is_loaded(id):
		return "chunk not loaded"
	if _map.water_kind_at(pos) != MapGen.WaterKind.NONE:
		return "water"
	if _near_safe(pos):
		return "safe zone"
	if pos.distance_to(_map.boss_point()) < boss_zone_radius or _map.in_boss_area(pos):
		return "boss land"
	for g in [&"resource_node", &"station", &"map_obstacle"]:
		for n: Node2D in get_tree().get_nodes_in_group(g):
			if pos.distance_to(n.global_position) < _radius(n) + body_r + clear_gap:
				return "blocked by a node"
	return ""

## Biome rate of a type at a position (0 = never there), from EnemyData.rate_for.
func rate_at(data: EnemyData, pos: Vector2) -> float:
	return data.rate_for(_map._biome_name(pos))

# ---- slime spots (seeded grid: same seed = same spots)

func _spot_cell(pos: Vector2) -> Vector2i:
	return Vector2i((pos / spot_cell_size).floor())

func cell_is_spot(c: Vector2i) -> bool:
	var seed_v := _map.current_seed if _map != null else 0
	return float(hash(Vector3i(c.x, c.y, seed_v)) & 0xFFFF) / 65536.0 < spot_chance

func is_spot(pos: Vector2) -> bool:
	return cell_is_spot(_spot_cell(pos))

func spots_near(center: Vector2, radius: float) -> int:
	var n := 0
	var c0 := _spot_cell(center - Vector2(radius, radius))
	var c1 := _spot_cell(center + Vector2(radius, radius))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			if cell_is_spot(Vector2i(cx, cy)):
				n += 1
	return n

# ---- when

func count_near(center: Vector2) -> int:
	var n := 0
	for e: Enemy in get_tree().get_nodes_in_group("enemy"):
		if e.state != Enemy.State.DIE and e.global_position.distance_to(center) <= cap_radius:
			n += 1
	return n

## Chance this type spawns at `pos` in one tick: base x biome rate x spot bonus x (1 - near / cap).
func chance_for(data: EnemyData, pos: Vector2, near: int) -> float:
	if cap_near_player <= 0:
		return 0.0
	var c: float = base_chance * rate_at(data, pos) * (spot_rate_mult if is_spot(pos) else 1.0)
	return clampf(c * (1.0 - float(near) / cap_near_player), 0.0, 1.0)

## One tick: pick a spot in the ring, then roll each type by its chance there. Returns what happened.
func roll_tick() -> String:
	var why := _blocked_now()
	if why != "":
		return "refused: " + why
	var p := _player()
	var c := _screen_center(p.global_position)
	var near := count_near(p.global_position)
	if near >= cap_near_player:
		return "refused: cap"
	var lo := min_dist()
	for i in spot_tries:
		var at := c + Vector2.from_angle(randf() * TAU) * randf_range(lo, maxf(spawn_max_dist, lo + 1.0))
		if _on_screen(at, c) or spot_problem(at) != "":
			continue
		var types := enemy_types.duplicate()
		types.shuffle()
		var best := 0.0
		for d: EnemyData in types:
			var ch := chance_for(d, at, near)
			best = maxf(best, ch)
			if randf() < ch:
				var n := mini(randi_range(d.pack_min, d.pack_max), cap_near_player - near)
				return "ok %d %s%s" % [_spread(d, at, n, c), d.id, " (spot)" if is_spot(at) else ""]
		return "no roll (best %.1f%%%s)" % [best * 100.0, ", spot" if is_spot(at) else ""]
	return "refused: no valid spot"

## Residents: a chunk that just loaded gives each slime spot inside it one chance at a pack.
func place_residents() -> void:
	if _map == null or _map.streamer() == null or _blocked_now() != "":
		return
	var st := _map.streamer()
	for id in _seen.keys():
		if not st.loaded.has(id):
			_seen.erase(id)
	var px := _map.cell_px()
	var p := _player()
	var cam := _screen_center(p.global_position)
	for id in st.loaded:
		if _seen.has(id):
			continue
		_seen[id] = true
		var cells: Rect2i = st._cells_of(id)
		var r := Rect2(Vector2(cells.position) * px, Vector2(cells.size) * px)
		var c0 := _spot_cell(r.position)
		var c1 := _spot_cell(r.end)
		for cy in range(c0.y, c1.y + 1):
			for cx in range(c0.x, c1.x + 1):
				var mid := (Vector2(cx, cy) + Vector2(0.5, 0.5)) * spot_cell_size
				if not r.has_point(mid) or not cell_is_spot(Vector2i(cx, cy)) or randf() >= resident_chance:
					continue
				var d := _pick_by_rate(mid)
				if d == null:
					continue
				residents_placed += _spread(d, mid, randi_range(d.pack_min, d.pack_max), cam, id)

func _pick_by_rate(pos: Vector2) -> EnemyData:
	var total := 0.0
	for d in enemy_types:
		total += rate_at(d, pos)
	if total <= 0.0:
		return null
	var r := randf() * total
	for d in enemy_types:
		r -= rate_at(d, pos)
		if r <= 0.0:
			return d
	return null

## Spawns up to `n` around `at`; each spot is re-checked (land, rules, rate > 0, off-screen from `c`). Returns how many.
func _spread(data: EnemyData, at: Vector2, n: int, c: Vector2, resident_chunk := -1) -> int:
	var made := 0
	for i in n * 4:
		if made >= n:
			break
		var pos := at if i == 0 else at + Vector2.from_angle(randf() * TAU) * pack_spread * sqrt(randf())
		if _on_screen(pos, c) or spot_problem(pos, data.body_radius) != "" or rate_at(data, pos) <= 0.0:
			continue
		var e := spawn(data, pos)
		if resident_chunk >= 0:
			e.set_meta(&"resident_chunk", resident_chunk)
		made += 1
	return made

func spawn(data: EnemyData, pos: Vector2) -> Enemy:
	var e: Enemy = data.scene.instantiate()
	e.data = data
	_holder.add_child(e)
	e.global_position = pos
	return e

## Far + idle leave by chance per second; past hard_despawn_dist at once. Only our own enemies.
func _despawn_far(dt: float) -> void:
	var p := _player()
	if p == null:
		return
	for c in _holder.get_children():   # slime drops (Pickup) land here too: Enemy._drop spawns into its parent
		var e := c as Enemy
		if e == null:
			continue
		if e.state != Enemy.State.IDLE or e.returning:
			continue
		if e.has_meta(&"resident_chunk"):   # a resident stays while its chunk is loaded, leaves when it unloads
			if _map == null or _map.streamer() == null or not _map.streamer().is_loaded(int(e.get_meta(&"resident_chunk"))):
				e.queue_free()
			continue
		var d := e.global_position.distance_to(p.global_position)
		if d > hard_despawn_dist or (d > despawn_dist and randf() < despawn_chance * dt):
			e.queue_free()

# ---- F3 / F1

func _draw_ring() -> void:
	var p := _player()
	if p == null:
		return
	var c := _ring.to_local(_screen_center(p.global_position))
	_ring.draw_circle(c, min_dist(), Color(1.0, 0.5, 0.1, 0.6), false, 1.5)
	_ring.draw_circle(c, spawn_max_dist, Color(1.0, 0.5, 0.1, 0.9), false, 2.0)
	_ring.draw_circle(c, cap_radius, Color(0.6, 0.6, 1.0, 0.5), false, 1.0)
	if _map != null:
		_ring.draw_circle(_ring.to_local(_map.boss_point()), boss_zone_radius, Color(1.0, 0.2, 0.2, 0.6), false, 1.5)
	var cs := spot_cell_size   # faint squares on slime spots near the player
	var pc := _player().global_position
	var c0 := _spot_cell(pc - Vector2(1, 1) * cs * 3.0)
	for cy in range(c0.y, c0.y + 7):
		for cx in range(c0.x, c0.x + 7):
			if cell_is_spot(Vector2i(cx, cy)):
				_ring.draw_rect(Rect2(_ring.to_local(Vector2(cx, cy) * cs), Vector2(cs, cs)), Color(0.5, 1.0, 0.3, 0.12))
				_ring.draw_rect(Rect2(_ring.to_local(Vector2(cx, cy) * cs), Vector2(cs, cs)), Color(0.5, 1.0, 0.3, 0.4), false, 1.0)
	var centers: Array[Vector2] = []
	if _map != null:
		centers.append(_map.home_point())
	for s: Node2D in get_tree().get_nodes_in_group("station"):
		centers.append(s.global_position)
	for h in centers:
		_ring.draw_circle(_ring.to_local(h), safe_radius, Color(0.2, 1.0, 0.4, 0.6), false, 1.5)

func debug_name() -> String:
	return "EnemySpawner"

func debug_category() -> String:
	return "World"

func debug_actions() -> Array:
	return [
		{"label": "Spawn slime pack here", "run": _debug_pack_here},
		{"label": "Kill all enemies", "run": func():
			for e: Enemy in get_tree().get_nodes_in_group("enemy"):
				e.health.take_damage(99999.0)},
		{"label": "Spawner on/off", "run": func(): enabled = not enabled},
	]

## Near the player; ignores ring, cap, screen, biome, chunk and safe zone; checks only water.
func _debug_pack_here() -> void:
	var p := _player()
	if p == null or enemy_types.is_empty():
		return
	var data := enemy_types[0]
	var n := 0
	for i in 40:
		if n >= data.pack_max:
			break
		var pos := p.global_position + Vector2.from_angle(randf() * TAU) * randf_range(60.0, 140.0)
		if _map != null and _map.water_kind_at(pos) != MapGen.WaterKind.NONE:
			continue
		spawn(data, pos)
		n += 1
	last_result = "debug pack: %d %s" % [n, data.id]

func status_text() -> String:
	var parts: Array[String] = []
	var p := _player()
	var near := count_near(p.global_position) if p else 0
	for d in enemy_types:
		var k := 0
		for e: Enemy in get_tree().get_nodes_in_group("enemy"):
			if e.data == d and e.state != Enemy.State.DIE:
				k += 1
		parts.append("%s %d" % [d.id, k])
	var sp := spots_near(p.global_position, spawn_max_dist) if p else 0
	var here := "  (standing in a spot)" if p and is_spot(p.global_position) else ""
	return "%s  alive: %s\nnear player %d / cap %d\nspots within ring: %d%s\nresidents placed: %d\nlast: %s\nnext roll in %.1f s" % [
		"on" if enabled else "OFF", ", ".join(parts), near, cap_near_player, sp, here, residents_placed, last_result, maxf(_timer, 0.0)]
