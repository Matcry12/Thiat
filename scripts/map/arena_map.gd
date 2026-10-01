class_name ArenaMap
extends Node2D
## Builds the arena floor from MapGen's plan: dirt layer, grass layer (with dirt-showing holes),
## deco, rocks (the only part that collides) and bushes along the walls. All of it sits BELOW the
## characters. Every number is an @export, so the F3 panel lists it; changing one rebuilds the map
## with the SAME seed ("New map" in F3 rolls a new one).
##
## Fair fight: rocks never touch the FightZone or the spawns, and never wall off any floor
## (see MapGen). Dirt patches are looks only.

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

@export var player_path: NodePath
@export var boss_path: NodePath
@export var dummy_path: NodePath
@export var fight_zone_path: NodePath

var current_seed := 0
var result: MapGen.Result

var _spawns := PackedVector2Array()
var _player_spawn := Vector2.ZERO
var _ready_done := false
var _rebuild_queued := false
var _want_new_seed := false
var _dirt: TileMapLayer
var _grass: TileMapLayer
var _deco: Node2D
var _obstacles: Node2D
var _border: Node2D


func _ready() -> void:
	# The layers live in arena.tscn: Ground (z -10: under every character and shadow) holds the flat
	# stuff; Obstacles is Y-sorted with the characters, so a rock hides whoever stands behind it.
	_dirt = $Ground/Dirt
	_grass = $Ground/Grass
	_deco = $Ground/Deco
	_border = $Ground/Border
	_obstacles = $Obstacles
	for layer in [_dirt, _grass]:
		layer.scale = Vector2.ONE * style.pixel_scale
	# Spawns are read ONCE: the same seed must give the same map however far the player has walked.
	for path in [player_path, boss_path, dummy_path]:
		var n := get_node_or_null(path) as Node2D
		if n:
			_spawns.append(n.global_position)
	var player := get_node_or_null(player_path) as Node2D
	_player_spawn = player.global_position if player else Vector2(409, 321)
	_ready_done = true
	_want_new_seed = false
	rebuild(true)


func status_text() -> String:
	if result == null:
		return "n/a"
	return "seed: %d  dirt patches: %d  rocks: %d  deco: %d  bushes: %d" % [
		current_seed, result.patches.size(), result.obstacles.size(), result.deco.size(), result.border.size()]


## F3 Save asks this instead of reading the export: map_seed 0 means "random", but a saved file
## should bring back the map that is showing.
func save_value(prop: String) -> Variant:
	return current_seed if prop == "map_seed" else get(prop)


## "New map" button: same settings, new random seed.
func new_map() -> void:
	current_seed = _fresh_seed()
	rebuild(false)


## new_seed: roll map_seed (or a random one if it is 0); otherwise rebuild the current seed.
func rebuild(new_seed: bool) -> void:
	if not _ready_done:
		return
	if new_seed:
		current_seed = map_seed if map_seed != 0 else _fresh_seed()
	result = MapGen.generate(style, make_params(), current_seed)
	_build()


func _fresh_seed() -> int:
	return randi_range(1, 9999)   # F3's map_seed slider goes to 9999: any shown seed can be typed back


## Setters call this. Several changes in one frame (Load in the F3 panel) rebuild once.
func _changed(new_seed := false) -> void:
	_want_new_seed = _want_new_seed or new_seed
	if not _ready_done or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild_deferred.call_deferred()


func _rebuild_deferred() -> void:
	_rebuild_queued = false
	var new_seed := _want_new_seed
	_want_new_seed = false
	rebuild(new_seed)


func make_params() -> MapGen.Params:
	var p := MapGen.Params.new()
	var cell := float(style.tile_size * style.pixel_scale)
	# The project's design size, not the window: the same map in a headless test and on screen.
	var vp := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	p.cell = cell
	p.world = vp
	p.cols = ceili(vp.x / cell)
	p.rows = ceili(vp.y / cell)
	p.patch_count = patch_count
	p.patch_min_size = patch_min_size
	p.patch_max_size = patch_max_size
	p.noise_frequency = noise_frequency
	p.patch_noise_threshold = patch_noise_threshold
	p.deco_density = deco_density
	p.deco_min_spacing = deco_min_spacing
	p.obstacle_count = obstacle_count
	p.obstacle_min_spacing = obstacle_min_spacing
	p.spawn_clear_radius = spawn_clear_radius
	p.border_density = border_density
	p.dark_grass_chance = dark_grass_chance
	p.agent_radius = agent_radius
	p.zone = _zone_rect()
	p.spawns = _spawns
	p.player_spawn = _player_spawn
	return p


func _zone_rect() -> Rect2:
	var zone := get_node_or_null(fight_zone_path) as Node2D
	if zone == null:
		return Rect2()
	var cs := zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or not (cs.shape is RectangleShape2D):
		return Rect2()
	var size: Vector2 = (cs.shape as RectangleShape2D).size
	return Rect2(cs.global_position - size * 0.5, size)


# ------------------------------------------------------------------- build ---

func _build() -> void:
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
		var body := StaticBody2D.new()      # default layer 1 = the walls' layer
		body.name = "Rock"
		body.collision_mask = 0
		body.position = o["pos"]
		body.add_to_group("map_obstacle")
		var shape := CircleShape2D.new()
		shape.radius = o["radius"]
		var cs := CollisionShape2D.new()
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


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(style.tile_size, style.tile_size)
	var src := TileSetAtlasSource.new()
	src.texture = style.tileset_texture
	src.texture_region_size = ts.tile_size
	var used: Dictionary = {}
	for coords in result.dirt.values() + result.grass.values():
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
