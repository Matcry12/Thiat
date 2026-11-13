class_name ResourceNode
extends StaticBody2D
## A tree / rock you gather (v1 §4). No Health: Hitbox._try_hit calls take_gather_hit. Kind and art come
## from ResourceNodeData; the look lives in the Visual child (swap = no code change).

signal broken(node: ResourceNode)

var data: ResourceNodeData
var placement := -1   ## index into MapGen.Result.obstacles (set by ArenaMap's chunk loader); -1 = placed by hand
var hp := 0.0
var variant := 0
var _hit_fx: Node
var _since_hit := 0.0   ## game seconds since the last damaging hit (slow-mo / hit-stop / pause stretch it)
var _last_hit_preferred := true   ## the latest damaging hit used the preferred tool

## Call before add_child.
var biome := -1   ## MapGen.Biome it stands in (set by the chunk streamer before _ready): picks the biome sheet (BiomeArt)

func setup(d: ResourceNodeData, v: int) -> void:
	data = d
	variant = v
	hp = d.max_hp

func _ready() -> void:
	set_physics_process(false)   # only ticks while damaged
	add_to_group("map_obstacle")
	add_to_group("resource_node")
	collision_mask = 0
	(get_node("CollisionShape2D").shape as CircleShape2D).radius = data.radius
	(get_node("Hurtbox/CollisionShape2D").shape as CircleShape2D).radius = data.radius + data.hurtbox_pad
	get_node("Visual").show_variant(data, variant, biome)

## Where the picture's foot is, in Visual coordinates (NodeHitReaction bends / grows the picture around it).
func foot_local() -> Vector2:
	return Vector2(0, data.radius)

func is_broken() -> bool:
	return hp <= 0.0

## Its chunk came back and this node was gathered before: show it the way it was left (a stump, no collision).
func restore_broken() -> void:
	hp = 0.0
	get_node("CollisionShape2D").disabled = true
	get_node("Hurtbox").monitorable = false
	get_node("Visual").show_remains(data)

## True = it took damage. Hands on a copper rock = clink, false.
func take_gather_hit(weapon: WeaponData, source: Node2D) -> bool:
	if is_broken() or weapon == null:
		return false
	var info := {"source": source, "direction": (global_position - source.global_position).normalized(), "weapon": weapon}
	if weapon.gather_damage <= 0.0 or weapon.tool_power < data.required_power:
		_note_hit()
		_fx(data.clink_type, source, info)
		return false
	var preferred := data.preferred_tool != &"" and weapon.tool_kind == data.preferred_tool
	_last_hit_preferred = preferred
	_since_hit = 0.0
	var bonus := data.tool_bonus if preferred else 1.0
	hp = maxf(hp - weapon.gather_damage * bonus, 0.0)
	_note_hit()
	info["hp_fraction"] = hp / data.max_hp   # the hit feel scales with it (bigger as the node nears its break)
	info["no_sound"] = is_broken()   # break wins: the breaking hit plays only the break sound (one sound per event)
	_fx(data.hit_type, source, info)
	if is_broken():
		_break(source)
	elif data.reset_delay > 0.0:
		set_physics_process(true)
	return true

## No damaging hit for reset_delay game seconds: back to full HP (progress resets).
func _physics_process(delta: float) -> void:
	_since_hit += delta
	if _since_hit > data.reset_delay:
		hp = data.max_hp
		set_physics_process(false)

func _no_drop() -> bool:
	return data.drop_needs_tool and not _last_hit_preferred

func _note_hit() -> void:   # for the F3 [Gather] line
	var col := get_tree().get_first_node_in_group("collector") as Collector
	if col:
		col.last_gather = status_text()

func _fx(type: StringName, source: Node, info: Dictionary) -> void:
	if _hit_fx == null:   # looked up late: map nodes are built before HitFx joins its group
		_hit_fx = get_tree().get_first_node_in_group("hit_fx")
	if _hit_fx:
		_hit_fx.fire(type, self, source, info)

func _break(source: Node) -> void:
	_fx(data.break_type, source, {"source": source, "weapon": null, "hp_fraction": 0.0, "direction": (global_position - source.global_position).normalized()})
	get_node("CollisionShape2D").set_deferred("disabled", true)
	get_node("Hurtbox").set_deferred("monitorable", false)
	broken.emit(self)
	_drop()
	if data.remains_region.has_area():
		get_node("Visual").show_remains(data)
	else:
		get_node("Visual").vanish()

func _drop() -> void:
	if _no_drop():
		return
	var col := get_tree().get_first_node_in_group("collector") as Collector
	var radius: float = col.scatter_radius if col else data.drop_scatter
	var m := get_tree().get_first_node_in_group("arena_map") as ArenaMap
	for i in randi_range(data.drop_min, data.drop_max):
		var to := position + Vector2.from_angle(randf() * TAU) * radius * sqrt(randf())
		if m and m.area_at(get_parent().to_global(to)) == -1:
			to = position
		Pickup.spawn(get_parent(), data.drop_item, 1, position, to)

func status_text() -> String:
	return "%s %.0f/%.0f hp, needs power %d%s" % [data.display_name, hp, data.max_hp, data.required_power, ", no drop" if is_broken() and _no_drop() else ""]
