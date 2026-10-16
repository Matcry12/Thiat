class_name Placer
extends Node
## Puts stations in the world (decision 0031). While the selected hotbar slot holds an item with a
## `placeable` scene, a ghost of it follows the player, snapped to a grid cell `place_distance` px along the aim.
## The ghost is white when the spot is free and red when it is not; the attack click places it (the item
## leaves the inventory). Refused on water, on resource nodes / rocks, on pickups, on other stations, in the boss area, on the
## land bridge to the boss (a station must never wall off the only path), where it would cut the walk to the boss ("neck"), on top of the player, and while a boss is engaged. The ghost is the real station scene with `ghost = true`, so new art shows up in it
## for free.

signal placed(station: Station)

@export var inventory_path: NodePath = ^"../Inventory"
@export var loadout_path: NodePath = ^"../Loadout"
@export var place_distance := 70.0      ## px from the player, along the aim
@export var grid_px := 32.0             ## the snap grid
@export var clearance := 2.0            ## extra free space kept around the footprint, px
@export var player_radius := 14.0
@export var ok_color := Color(0.55, 1.0, 0.55, 0.75)     ## ghost tint on a free spot
@export var bad_color := Color(1.0, 0.25, 0.25, 0.75)    ## ghost tint on a refused spot
@export var outline_ok := Color(0.4, 1.0, 0.4, 1.0)      ## the 1 px box around the footprint
@export var outline_bad := Color(1.0, 0.2, 0.2, 1.0)
@export var outline_width := 1.0
@export var flash_time := 0.4   ## s the ghost stays red after a click refused by the path check

var last_refusal := ""    ## "" / water / node / station / boss / player / off (for F3)
var last_placed := ""

var last_neck_ms := 0.0   ## cost of the last path flood (F3)
var _neck_key: Array = []
var _neck_value := false
var _flash_left := 0.0
var _ghost: Station
var _ghost_item: ItemData

func _inv() -> Inventory:
	return get_node_or_null(inventory_path) as Inventory

func _loadout() -> Loadout:
	return get_node_or_null(loadout_path) as Loadout

func _me() -> Node2D:
	return get_parent() as Node2D

## The placeable in the selected hotbar slot (null = nothing to place).
func held_item() -> ItemData:
	var inv := _inv()
	var lo := _loadout()
	if inv == null or lo == null:
		return null
	var it := inv.slot_item(lo.selected_slot)
	return it if it != null and it.placeable != null else null

func is_holding() -> bool:
	return held_item() != null

## Where the station would go: a grid cell centre in front of the player.
func target_pos() -> Vector2:
	var aim := Vector2.RIGHT
	var a = _me().get("aim_direction")
	if a is Vector2 and a != Vector2.ZERO:
		aim = a
	return snap(_me().global_position + aim * place_distance)

func snap(p: Vector2) -> Vector2:
	return (p / grid_px).floor() * grid_px + Vector2.ONE * grid_px * 0.5

## "" when a station with this `footprint` may stand centred on `pos`; else why not. `art_local` = the picture's
## box relative to the centre: a tall station (the furnace) must not hide another one behind it, so the
## picture boxes may not overlap either (default: just the footprint). `with_neck` also runs the path flood
## (about 50 ms): only the place click does that, never the per-frame ghost check.
func check_at(pos: Vector2, footprint: Vector2, art_local := Rect2(), with_neck := false) -> String:
	var rect := Rect2(pos - footprint * 0.5, footprint).grow(clearance)
	var mine := art_local
	mine.position += pos
	if not art_local.has_area():
		mine = Rect2(pos - footprint * 0.5, footprint)
	var inv := _inv()
	if inv != null and inv.locked():
		return "locked"
	var m := get_tree().get_first_node_in_group("arena_map") as ArenaMap
	if m != null and m.result != null:
		for p in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), pos]:
			if m.area_at(p) == -1:
				return "water"
		for p in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), pos]:
			if m.in_boss_area(p):
				return "boss"
			if m.in_corridor(p):
				return "corridor"
		if m.in_corridor_rect(rect):
			return "corridor"
	for o: Node2D in get_tree().get_nodes_in_group("map_obstacle"):
		if o is ResourceNode and o.is_broken():
			continue
		var cs := o.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs == null or cs.disabled or not cs.shape is CircleShape2D:
			continue
		if _circle_hits_rect(o.global_position, (cs.shape as CircleShape2D).radius, rect):
			return "node"
	for pk: Node2D in get_tree().get_nodes_in_group("pickup"):
		if rect.has_point(pk.global_position):
			return "pickup"
	for s: Station in get_tree().get_nodes_in_group("station"):
		if rect.intersects(Rect2(s.global_position - s.footprint() * 0.5, s.footprint())):
			return "station"
		var other_art := s.art_rect_local()
		other_art.position += s.global_position
		if mine.intersects(other_art):
			return "station"
	if _circle_hits_rect(_me().global_position, player_radius, rect):
		return "player"
	if with_neck and m != null and _blocks_path(m, pos, rect):
		return "neck"
	return ""

## The walk-flood check from home to the boss zone with this footprint (and every placed station) as solid
## boxes. One flood: cached per (spot, stations placed), so it runs on a click or when the ghost changes cell.
func _blocks_path(m: ArenaMap, pos: Vector2, rect: Rect2) -> bool:
	var stations := get_tree().get_nodes_in_group("station")
	var key := [pos, rect.size, stations.size(), m.result]
	if key == _neck_key:
		return _neck_value
	var rects: Array[Rect2] = [rect]
	for s: Station in stations:
		rects.append(Rect2(s.global_position - s.footprint() * 0.5, s.footprint()))
	_neck_key = key
	_neck_value = m.blocks_boss_path(rects)
	last_neck_ms = m.last_walk_check_ms
	return _neck_value

func _circle_hits_rect(c: Vector2, r: float, rect: Rect2) -> bool:
	var nearest := c.clamp(rect.position, rect.end)
	return nearest.distance_to(c) < r

## Places the held station at the target. Returns false (and says why in `last_refusal`) if it cannot.
func try_place() -> bool:
	var it := held_item()
	if it == null:
		return false
	var scene := it.placeable
	var st: Station = scene.instantiate()
	var pos := target_pos()
	last_refusal = check_at(pos, st.footprint(), st.art_rect_local(), true)
	if last_refusal != "":
		st.free()
		if last_refusal == "neck":
			_flash_left = flash_time   # the cheap ghost check said yes; the click found it would cut the path
		return false
	return _place(it, st, pos, true)

## The checks are done by the caller. `consume` = take the item from the selected slot (F3 buttons do not).
func _place(it: ItemData, st: Station, pos: Vector2, consume: bool) -> bool:
	st.item = it
	_me().get_parent().add_child(st)
	st.global_position = pos
	var inv := _inv()
	var lo := _loadout()
	if consume and inv and lo and inv.slot_item(lo.selected_slot) == it:
		inv.remove_from_slot(lo.selected_slot, 1)
	last_placed = "%s at %d,%d" % [it.display_name, pos.x, pos.y]
	placed.emit(st)
	return true

## F3 "Place X here": puts a free-of-charge station in front of the player (checks apply; the spot
## search steps forward until it is free). Returns the station or null.
func place_free(it: ItemData) -> Station:
	for k in 8:
		var st: Station = it.placeable.instantiate()
		var aim := Vector2.RIGHT
		var a = _me().get("aim_direction")
		if a is Vector2 and a != Vector2.ZERO:
			aim = a
		var pos := snap(_me().global_position + aim * (place_distance + k * grid_px * 2.0))
		if check_at(pos, st.footprint(), st.art_rect_local(), true) == "":
			_place(it, st, pos, false)
			return st
		st.free()
	return null

func _physics_process(delta: float) -> void:
	var it := held_item()
	if it == null:
		if _ghost != null:
			_ghost.queue_free()
			_ghost = null
			_ghost_item = null
		return
	if _ghost == null or _ghost_item != it:
		if _ghost != null:
			_ghost.queue_free()
		_ghost = it.placeable.instantiate()
		_ghost.ghost = true
		_ghost_item = it
		_ghost.z_index = 5
		_me().get_parent().add_child(_ghost)
	var pos := target_pos()
	_ghost.global_position = pos
	var flashing := _flash_left > 0.0
	_flash_left = maxf(_flash_left - delta, 0.0)
	var keep := last_refusal
	last_refusal = check_at(pos, _ghost.footprint(), _ghost.art_rect_local())
	if flashing and last_refusal == "":
		last_refusal = "neck" if keep == "neck" else last_refusal
	var bad := last_refusal != ""
	_ghost.modulate = bad_color if bad else ok_color
	_ghost.outline.default_color = outline_bad if bad else outline_ok
	_ghost.outline.width = outline_width

func ghost() -> Station:
	return _ghost
