class_name ArenaMap
extends Node2D
## Builds the arena floor from MapGen's plan: dirt layer, grass layer (with dirt-showing holes),
## deco, rocks (the only part that collides) and bushes along the walls. All of it sits BELOW the
## characters. Every number is an @export, so the F3 panel lists it; changing one rebuilds the map
## with the SAME seed ("New map" in F3 rolls a new one).
##
## Fair fight: rocks never touch the FightZone or the spawns, and never wall off any floor
## (see MapGen). Dirt patches are looks only.
##
## ArenaMap is the ONE owner of: the outer walls (built from map_cols x map_rows), the player's
## Camera2D (child of the player, limits = the map), the Background size, and where the FightZone,
## Boss, Player and Dummy start. Layout is a pure function of the exports below (no seed, no live
## node positions), so the same exports always give the same layout. Moving those nodes in the
## editor has no effect: change the numbers here (a size/layout change in F3 moves them again).

## patch_count and obstacle_count are "per screen-sized area" (36 x 21 cells) and scale with the
## map, so density stays the same on a bigger map.
const RESOURCE_NODE := preload("res://scenes/world/resource_node.tscn")
const REF_CELLS := 36 * 21

## Map size in cells (1 cell = tile_size * pixel_scale px = 32). 72 x 40 = 2304 x 1280 px = 2x the screen.
@export var map_cols := 200:
	set(v):
		map_cols = v
		_changed(false, true)
@export var map_rows := 120:
	set(v):
		map_rows = v
		_changed(false, true)
## The boss zone (= the aggro zone). Its centre is a fraction of the map, so it follows the size.
@export var zone_width := 880.0:
	set(v):
		zone_width = v
		_changed(false, true)
@export var zone_height := 460.0:
	set(v):
		zone_height = v
		_changed(false, true)
@export var zone_x := 0.86:
	set(v):
		zone_x = v
		_changed(false, true)
@export var zone_y := 0.5:
	set(v):
		zone_y = v
		_changed(false, true)
## The boss waits this many px to the right of the zone centre.
@export var boss_offset_x := 220.0:
	set(v):
		boss_offset_x = v
		_changed(false, true)
## The player starts here (fraction of the map): far left, outside the zone.
@export var player_spawn_x := 0.12:
	set(v):
		player_spawn_x = v
		_changed(false, true)
@export var player_spawn_y := 0.5:
	set(v):
		player_spawn_y = v
		_changed(false, true)
## The training dummy stands this far from the player's spawn.
@export var dummy_offset_x := 290.0:
	set(v):
		dummy_offset_x = v
		_changed(false, true)
@export var dummy_offset_y := -190.0:
	set(v):
		dummy_offset_y = v
		_changed(false, true)
@export var camera_smoothing := true:
	set(v):
		camera_smoothing = v
		_apply_camera()
## Higher = snappier. 7 is mild.
@export var camera_smoothing_speed := 7.0:
	set(v):
		camera_smoothing_speed = v
		_apply_camera()

@export var style: MapStyle
## 0 = a new random seed every run.
@export var map_seed := 0:
	set(v):
		map_seed = v
		_changed(true)
@export var patch_count := 4:
	set(v):
		patch_count = v
		_changed()
@export var patch_min_size := 3:
	set(v):
		patch_min_size = v
		_changed()
@export var patch_max_size := 7:
	set(v):
		patch_max_size = v
		_changed()
## Patch centres are only accepted where the noise is above this (0..1), so patches cluster.
@export var noise_frequency := 0.1:
	set(v):
		noise_frequency = v
		_changed()
@export var patch_noise_threshold := 0.5:
	set(v):
		patch_noise_threshold = v
		_changed()
## Deco items per floor cell.
@export var deco_density := 0.1:
	set(v):
		deco_density = v
		_changed()
@export var deco_min_spacing := 30.0:
	set(v):
		deco_min_spacing = v
		_changed()
@export var obstacle_count := 6:
	set(v):
		obstacle_count = v
		_changed()
@export var obstacle_min_spacing := 40.0:
	set(v):
		obstacle_min_spacing = v
		_changed()
@export var spawn_clear_radius := 110.0:
	set(v):
		spawn_clear_radius = v
		_changed()
@export var border_density := 0.9:
	set(v):
		border_density = v
		_changed()
## Share of the grass that is the darker kind (smooth noise, so it forms meadows).
@export var dark_grass_chance := 0.0:
	set(v):
		dark_grass_chance = v
		_changed()
## Widest walker that must still be able to reach all the floor around the rocks.
@export var agent_radius := 14.0:
	set(v):
		agent_radius = v
		_changed()

## Island (W1): shape of the land, the areas along home -> boss. Water is everything else.
@export var island_on := true:
	set(v):
		island_on = v
		_changed(false, true)
@export var island_noise_frequency := 0.035:
	set(v):
		island_noise_frequency = v
		_changed()
@export var island_noise := 0.3:
	set(v):
		island_noise = v
		_changed()
@export var island_falloff := 2.0:
	set(v):
		island_falloff = v
		_changed()
@export var island_threshold := 0.15:
	set(v):
		island_threshold = v
		_changed()
@export var coast_cells := 3:
	set(v):
		coast_cells = v
		_changed()
@export var home_clear_cells := 6:
	set(v):
		home_clear_cells = v
		_changed()
@export var corridor_half := 2:
	set(v):
		corridor_half = v
		_changed()
@export var forest_end := 0.45:
	set(v):
		forest_end = v
		_changed()
@export var rocky_end := 0.8:
	set(v):
		rocky_end = v
		_changed()
@export var area_wobble := 0.12:
	set(v):
		area_wobble = v
		_changed()

@export var player_path: NodePath
@export var home_path: NodePath = ^"../HomePoint"
## The campfire sits this far from the player start.
@export var home_offset_x := -70.0:
	set(v):
		home_offset_x = v
		_changed(false, true)
@export var home_offset_y := -50.0:
	set(v):
		home_offset_y = v
		_changed(false, true)
@export var boss_path: NodePath
@export var dummy_path: NodePath
@export var fight_zone_path: NodePath
## A ColorRect behind everything; resized to the map.
@export var background_path: NodePath

var current_seed := 0
var build_ms := 0   ## last rebuild, in ms
var node_count := 0   ## resource nodes in the current result, cached at build time
var land_pct := 0   ## share of land cells in the current result, cached at build time
var result: MapGen.Result

var _spawns := PackedVector2Array()
var _player_spawn := Vector2.ZERO
var _zone := Rect2()
var _ready_done := false
var _rebuild_queued := false
var _want_new_seed := false
var _want_relayout := false
var _walls: Node2D
var _camera: Camera2D
var _water: TileMapLayer
var _water_body: StaticBody2D
var _dirt: TileMapLayer
var _grass: TileMapLayer
var _deco: Node2D
var _obstacles: Node2D
var _border: Node2D


func _ready() -> void:
	add_to_group("arena_map")
	# The layers live in arena.tscn: Ground (z -10: under every character and shadow) holds the flat
	# stuff; Obstacles is Y-sorted with the characters, so a rock hides whoever stands behind it.
	_water = $Ground/Water
	_dirt = $Ground/Dirt
	_grass = $Ground/Grass
	_deco = $Ground/Deco
	_border = $Ground/Border
	_obstacles = $Obstacles
	for layer in [_water, _dirt, _grass]:
		layer.scale = Vector2.ONE * style.pixel_scale
	_water_body = StaticBody2D.new()
	_water_body.name = "Water"
	_water_body.collision_mask = 0
	add_child(_water_body)
	_walls = Node2D.new()
	_walls.name = "Walls"
	add_child(_walls)
	_ready_done = true
	_want_new_seed = false
	_want_relayout = false
	_place_actors()
	var player := get_node_or_null(player_path) as Node2D
	if player:
		_camera = Camera2D.new()
		_camera.name = "Camera"
		player.add_child(_camera)
		_apply_camera()
		_camera.reset_smoothing()
	rebuild(true)


func status_text() -> String:
	if result == null:
		return "n/a"
	var player := get_node_or_null(player_path) as Node2D
	var ai := area_at(player.global_position) if player else -1
	return "seed: %d  size: %dx%d cells (%dx%d px)\ndirt patches: %d  rocks: %d  deco: %d  bushes: %d\narea %s  land %d%%  nodes %d  build %d ms" % [
		current_seed, map_cols, map_rows, map_size().x, map_size().y,
		result.patches.size(), result.obstacles.size(), result.deco.size(), result.border.size(),
		["forest", "rocky", "boss"][ai] if ai >= 0 else "water", land_pct, node_count, build_ms]


## F3 Save asks this instead of reading the export: map_seed 0 means "random", but a saved file
## should bring back the map that is showing.
func save_value(prop: String) -> Variant:
	return current_seed if prop == "map_seed" else get(prop)


## "New map" button: same settings, new random seed.
func new_map() -> void:
	current_seed = _fresh_seed()
	rebuild(false)


## F3 "Generate": rebuild with exactly this seed (1..9999, the same range as New map and the slider).
## Goes through map_seed so the F3 slider and a later Save show it too.
func generate_seed(s: int) -> void:
	var v := clampi(s, 1, 9999)
	if v == map_seed:
		rebuild(true)   # the setter would not fire for an unchanged value
	else:
		map_seed = v
		_apply_pending_now()


## new_seed: roll map_seed (or a random one if it is 0); otherwise rebuild the current seed.
## relayout: also move the zone / boss / player / dummy to the layout.
func rebuild(new_seed: bool, relayout := false) -> void:
	if not _ready_done:
		return
	var t0 := Time.get_ticks_msec()
	if relayout:
		_place_actors()
		if _camera:
			_camera.reset_smoothing()
	_apply_size()
	if new_seed:
		current_seed = map_seed if map_seed != 0 else _fresh_seed()
	result = MapGen.generate(style, make_params(), current_seed)
	var land := 0
	for v in result.land:
		land += v
	land_pct = 100 * land / maxi(result.land.size(), 1)
	node_count = 0
	for o in result.obstacles:
		node_count += 1 if o["node"] >= 0 else 0
	_build()
	build_ms = maxi(Time.get_ticks_msec() - t0, 1)


func _fresh_seed() -> int:
	return randi_range(1, 9999)   # F3's map_seed slider goes to 9999: any shown seed can be typed back


## Setters call this. Several changes in one frame (Load in the F3 panel) rebuild once.
func _changed(new_seed := false, relayout := false) -> void:
	_want_new_seed = _want_new_seed or new_seed
	_want_relayout = _want_relayout or relayout
	if not _ready_done or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild_deferred.call_deferred()


func _rebuild_deferred() -> void:
	if not _rebuild_queued:
		return
	_rebuild_queued = false
	var new_seed := _want_new_seed
	var relayout := _want_relayout
	_want_new_seed = false
	_want_relayout = false
	rebuild(new_seed, relayout)


## Runs a queued rebuild now (the caller needs the new map in this same frame).
func _apply_pending_now() -> void:
	_rebuild_deferred()


func make_params() -> MapGen.Params:
	var p := MapGen.Params.new()
	var cell := cell_px()
	var scale := float(map_cols * map_rows) / REF_CELLS
	p.cell = cell
	p.world = map_size()
	p.cols = map_cols
	p.rows = map_rows
	p.patch_count = roundi(patch_count * scale)
	p.patch_min_size = patch_min_size
	p.patch_max_size = patch_max_size
	p.noise_frequency = noise_frequency
	p.patch_noise_threshold = patch_noise_threshold
	p.deco_density = deco_density
	p.deco_min_spacing = deco_min_spacing
	p.obstacle_count = roundi(obstacle_count * scale)
	p.obstacle_min_spacing = obstacle_min_spacing
	p.spawn_clear_radius = spawn_clear_radius
	p.border_density = border_density
	p.dark_grass_chance = dark_grass_chance
	p.agent_radius = agent_radius
	p.island_on = island_on
	p.island_noise_frequency = island_noise_frequency
	p.island_noise = island_noise
	p.island_falloff = island_falloff
	p.island_threshold = island_threshold
	p.coast_cells = coast_cells
	p.home_clear_cells = home_clear_cells
	p.corridor_half = corridor_half
	p.forest_end = forest_end
	p.rocky_end = rocky_end
	p.area_wobble = area_wobble
	p.zone = _zone
	p.spawns = _spawns
	p.player_spawn = _player_spawn
	return p


## MapGen.Area at a world position, or -1 on water / off the map.
func area_at(pos: Vector2) -> int:
	if result == null:
		return -1
	var c := Vector2i((pos / cell_px()).floor())
	if c.x < 0 or c.y < 0 or c.x >= result.cols or c.y >= result.rows:   # the size the result was built with
		return -1
	var i := c.y * result.cols + c.x
	return -1 if result.land[i] == 0 else result.area[i]


func home_point() -> Vector2:
	return _player_spawn


## "home" or "boss" (zone left edge - 96 px, zone centre y).
func teleport_player(to: String) -> void:
	var player := get_node_or_null(player_path) as CharacterBody2D
	if player == null:
		return
	player.global_position = _player_spawn if to == "home" else _free_spot(Vector2(_zone.position.x - 96.0, _zone.get_center().y))
	player.velocity = Vector2.ZERO
	if _camera:
		_camera.reset_smoothing()


## Nearest spot to `target` (rings of 16 px, up to 480 px out) where a walker stands on land, clear of every rock.
func _free_spot(target: Vector2) -> Vector2:
	if result == null:
		return target
	for ring in 31:
		for k in maxi(ring * 8, 1):
			var a := TAU * k / maxi(ring * 8, 1)
			var pos := target + Vector2.from_angle(a) * ring * 16.0
			if _walker_fits(pos):
				return pos
	return target


func _walker_fits(pos: Vector2) -> bool:
	for off in [Vector2.ZERO, Vector2(agent_radius, 0), Vector2(-agent_radius, 0), Vector2(0, agent_radius), Vector2(0, -agent_radius)]:
		var c := Vector2i(((pos + off) / cell_px()).floor())
		if c.x < 0 or c.y < 0 or c.x >= result.cols or c.y >= result.rows or result.land[c.y * result.cols + c.x] == 0:
			return false
	for o in result.obstacles:
		if pos.distance_to(o["pos"]) <= o["radius"] + agent_radius:
			return false
	return true


func cell_px() -> float:
	return float(style.tile_size * style.pixel_scale)


func map_size() -> Vector2:
	return Vector2(maxi(map_cols, 12), maxi(map_rows, 12)) * cell_px()


## Where everything starts. Pure function of the exports.
func layout() -> Dictionary:
	var size := map_size()
	var zsize := Vector2(zone_width, zone_height)
	var c := Vector2(size.x * zone_x, size.y * zone_y)
	var pad := cell_px()   # keep the zone off the walls
	c.x = clampf(c.x, minf(pad + zsize.x * 0.5, size.x * 0.5), maxf(size.x - pad - zsize.x * 0.5, size.x * 0.5))
	c.y = clampf(c.y, minf(pad + zsize.y * 0.5, size.y * 0.5), maxf(size.y - pad - zsize.y * 0.5, size.y * 0.5))
	var player := Vector2(size.x * player_spawn_x, size.y * player_spawn_y)
	return {
		"zone": Rect2(c - zsize * 0.5, zsize),
		"boss": c + Vector2(boss_offset_x, 0.0),
		"player": player,
		"dummy": player + Vector2(dummy_offset_x, dummy_offset_y),
	}


## Moves the FightZone, Boss, Player and Dummy to the layout and remembers the spawns for MapGen.
## Spawns come from the layout, never from live positions: the same exports = the same map.
func _place_actors() -> void:
	var l := layout()
	_zone = l["zone"]
	_player_spawn = l["player"]
	var home_pos: Vector2 = l["player"] + Vector2(home_offset_x, home_offset_y)
	_spawns = PackedVector2Array([l["player"], l["boss"], l["dummy"], home_pos])
	var home := get_node_or_null(home_path) as Node2D
	if home:
		home.global_position = home_pos
	var zone := get_node_or_null(fight_zone_path) as Node2D
	if zone:
		zone.global_position = _zone.get_center()
		var cs := zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs:
			var shape := RectangleShape2D.new()
			shape.size = _zone.size
			cs.shape = shape
	var boss := get_node_or_null(boss_path) as Node2D
	if boss:
		if boss.has_method("set_home"):
			boss.call("set_home", l["boss"])
		else:
			boss.global_position = l["boss"]
	var player := get_node_or_null(player_path) as Node2D
	if player:
		player.global_position = l["player"]
	var dummy := get_node_or_null(dummy_path) as Node2D
	if dummy:
		dummy.global_position = l["dummy"]


## Walls (4 bodies, one cell thick, inside the map rect), camera limits, background size.
func _apply_size() -> void:
	var size := map_size()
	var t := cell_px()
	for c in _walls.get_children():
		_walls.remove_child(c)
		c.queue_free()
	var specs := {
		"Top": [Vector2(size.x * 0.5, t * 0.5), Vector2(size.x, t)],
		"Bottom": [Vector2(size.x * 0.5, size.y - t * 0.5), Vector2(size.x, t)],
		"Left": [Vector2(t * 0.5, size.y * 0.5), Vector2(t, size.y)],
		"Right": [Vector2(size.x - t * 0.5, size.y * 0.5), Vector2(t, size.y)],
	}
	for n in specs:
		var body := StaticBody2D.new()      # default layer 1, as the hand-placed walls had
		body.name = n
		body.collision_mask = 0
		body.position = specs[n][0]
		var shape := RectangleShape2D.new()
		shape.size = specs[n][1]
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		cs.shape = shape
		body.add_child(cs)
		_walls.add_child(body)
	_apply_camera()
	var bg := get_node_or_null(background_path) as Control
	if bg:
		bg.position = Vector2.ZERO
		bg.size = size
		if bg is ColorRect and style:
			(bg as ColorRect).color = style.water_color


func _apply_camera() -> void:
	if _camera == null:
		return
	var size := map_size()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(size.x)
	_camera.limit_bottom = int(size.y)
	_camera.position_smoothing_enabled = camera_smoothing
	_camera.position_smoothing_speed = camera_smoothing_speed


# ------------------------------------------------------------------- build ---

func _build() -> void:
	_build_water()
	var ts := _make_tileset()
	_dirt.tile_set = ts
	_grass.tile_set = ts
	_dirt.clear()
	_grass.clear()
	for cell in result.dirt:
		_dirt.set_cell(cell, 0, result.dirt[cell])
	for cell in result.grass:
		_grass.set_cell(cell, 0, result.grass[cell])

	for container in [_deco, _obstacles, _border]:
		for c in container.get_children():
			container.remove_child(c)
			c.queue_free()
	var s := float(style.pixel_scale)
	for d in result.border:
		_add_sprite(_border, style.border, d["region"], d["pos"], s, d["flip"])
	for d in result.deco:
		_add_sprite(_deco, style.deco[d["set"]], d["region"], d["pos"], s, false)
	for o in result.obstacles:
		if o["node"] >= 0:
			var rn: ResourceNode = RESOURCE_NODE.instantiate()
			rn.setup(style.resource_nodes[o["node"]], o["region"])
			rn.position = o["pos"]
			_obstacles.add_child(rn)
			var node_boss := get_node_or_null(boss_path) as PhysicsBody2D
			if node_boss:
				node_boss.add_collision_exception_with(rn)
			continue
		var body := StaticBody2D.new()      # default layer 1 = the walls' layer
		body.name = "Rock"
		body.collision_mask = 0
		body.position = o["pos"]
		body.add_to_group("map_obstacle")
		var shape := CircleShape2D.new()
		shape.radius = o["radius"]
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"   # F1 looks it up by this name
		cs.shape = shape
		body.add_child(cs)
		_obstacles.add_child(body)
		# The boss (radius 28, no pathfinding) walks through rocks: a rock is cover against the
		# player and arrows, never a hiding place from the boss's charge.
		var boss := get_node_or_null(boss_path) as PhysicsBody2D
		if boss:
			boss.add_collision_exception_with(body)
		# Sprite stands with its feet at the bottom of the collision circle.
		_add_sprite(body, style.obstacles, o["region"], Vector2(0, o["radius"]), s, false)


func _build_water() -> void:
	_water.clear()
	if style.water_texture and not result.water.is_empty():
		_water.tile_set = _make_tileset(style.water_texture, result.water.values())
		for cell in result.water:
			_water.set_cell(cell, 0, result.water[cell])
	for c in _water_body.get_children():
		_water_body.remove_child(c)
		c.queue_free()
	# One rectangle per run of coast water (water touching land, 8 neighbours) in a row.
	var p := make_params()
	var cell := cell_px()
	for y in map_rows:
		var x0 := -1
		for x in map_cols + 1:
			var coast := x < map_cols and not MapGen.is_land(result, p, Vector2i(x, y)) and _touches_land(p, x, y)
			if coast and x0 < 0:
				x0 = x
			elif not coast and x0 >= 0:
				var shape := RectangleShape2D.new()
				shape.size = Vector2((x - x0) * cell, cell)
				var cs := CollisionShape2D.new()
				cs.shape = shape
				cs.position = Vector2((x0 + x) * 0.5 * cell, (y + 0.5) * cell)
				_water_body.add_child(cs)
				x0 = -1


func _touches_land(p: MapGen.Params, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if MapGen.is_land(result, p, Vector2i(x + dx, y + dy)):
				return true
	return false


func _make_tileset(texture: Texture2D = null, coord_list: Array = []) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(style.tile_size, style.tile_size)
	var src := TileSetAtlasSource.new()
	src.texture = texture if texture else style.tileset_texture
	src.texture_region_size = ts.tile_size
	var used: Dictionary = {}
	for coords in (coord_list if texture else result.dirt.values() + result.grass.values()):
		used[coords] = true
	for coords in used:
		src.create_tile(coords)
	ts.add_source(src, 0)
	return ts


## `pos` is the bottom-centre of the sprite.
func _add_sprite(parent: Node, set: PropSet, region: int, pos: Vector2, s: float, flip: bool) -> void:
	var r: Rect2 = set.regions[region]
	var sp := Sprite2D.new()
	sp.texture = set.texture
	sp.region_enabled = true
	sp.region_rect = r
	sp.centered = false
	sp.flip_h = flip
	sp.scale = Vector2(s, s)
	sp.position = pos - Vector2(r.size.x * 0.5, r.size.y) * s
	parent.add_child(sp)
