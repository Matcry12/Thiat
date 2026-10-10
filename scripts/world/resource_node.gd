class_name ResourceNode
extends StaticBody2D
## A tree / rock you gather (v1 §4). No Health: Hitbox._try_hit calls take_gather_hit. Kind and art come
## from ResourceNodeData; the look lives in the Visual child (swap = no code change).

signal broken(node: ResourceNode)

var data: ResourceNodeData
var hp := 0.0
var variant := 0
var _hit_fx: Node

## Call before add_child.
func setup(d: ResourceNodeData, v: int) -> void:
	data = d
	variant = v
	hp = d.max_hp

func _ready() -> void:
	add_to_group("map_obstacle")
	add_to_group("resource_node")
	collision_mask = 0
	(get_node("CollisionShape2D").shape as CircleShape2D).radius = data.radius
	(get_node("Hurtbox/CollisionShape2D").shape as CircleShape2D).radius = data.radius + data.hurtbox_pad
	_hit_fx = get_tree().get_first_node_in_group("hit_fx")
	get_node("Visual").show_variant(data, variant)

func is_broken() -> bool:
	return hp <= 0.0

## True = it took damage. Hands on a copper rock = clink, false.
func take_gather_hit(weapon: WeaponData, source: Node2D) -> bool:
	if is_broken() or weapon == null:
		return false
	var info := {"source": source, "direction": (global_position - source.global_position).normalized()}
	if weapon.gather_damage <= 0.0 or weapon.tool_power < data.required_power:
		_note_hit()
		_fx(data.clink_type, source, info)
		return false
	var bonus := data.tool_bonus if data.preferred_tool != &"" and weapon.tool_kind == data.preferred_tool else 1.0
	hp = maxf(hp - weapon.gather_damage * bonus, 0.0)
	_note_hit()
	_fx(data.hit_type, source, info)
	if is_broken():
		_break(source)
	return true

func _note_hit() -> void:   # for the F3 [Gather] line
	var col := get_tree().get_first_node_in_group("collector") as Collector
	if col:
		col.last_gather = status_text()

func _fx(type: StringName, source: Node, info: Dictionary) -> void:
	if _hit_fx:
		_hit_fx.fire(type, self, source, info)

func _break(source: Node) -> void:
	_fx(data.break_type, source, {"source": source})
	get_node("CollisionShape2D").set_deferred("disabled", true)
	get_node("Hurtbox").set_deferred("monitorable", false)
	broken.emit(self)
	_drop()
	if data.remains_region.has_area():
		get_node("Visual").show_remains(data)
	else:
		queue_free()

func _drop() -> void:
	var col := get_tree().get_first_node_in_group("collector") as Collector
	var radius: float = col.scatter_radius if col else data.drop_scatter
	var m := get_tree().get_first_node_in_group("arena_map") as ArenaMap
	for i in randi_range(data.drop_min, data.drop_max):
		var to := position + Vector2.from_angle(randf() * TAU) * radius * sqrt(randf())
		if m and m.area_at(get_parent().to_global(to)) == -1:
			to = position
		Pickup.spawn(get_parent(), data.drop_item, 1, position, to)

func status_text() -> String:
	return "%s %.0f/%.0f hp, needs power %d" % [data.display_name, hp, data.max_hp, data.required_power]
