class_name Collector
extends Node
## Child of the Player. Pulls settled pickups in and banks them in the Inventory. A full inventory leaves them on the ground.

@export var magnet_radius := 70.0
@export var magnet_speed := 420.0
@export var pickup_radius := 14.0
@export var inventory_path: NodePath = ^"../Inventory"
@export var pickup_hop_time := 0.35   ## read by Pickup
@export var pickup_size := 7.0   ## placeholder diamond, read by Pickup
@export var pickup_icon_px := 16.0   ## icon height on the ground in world px, whatever the icon file size (16 or 32)
@export_group("Loose item look")
@export var bob_height := 3.0   ## px the icon floats up (0 = still)
@export var bob_period := 2.0   ## seconds for one float
@export var shadow_on := true
@export var shadow_size := 14.0   ## px wide, at rest
@export var shadow_alpha := 0.35
@export var shadow_offset_y := 6.0   ## px below the icon centre
@export var shadow_min_scale := 0.8   ## shadow size at the top of the float (1 = no change)
@export_group("")
@export var scatter_radius := 26.0   ## read by ResourceNode for drop spread

var last_pickup := ""   # for F3
var last_gather := ""   # status of the last node hit, for F3

func _ready() -> void:
	add_to_group("debug")
	add_to_group("collector")

func inventory() -> Inventory:
	return get_node_or_null(inventory_path) as Inventory

func _physics_process(delta: float) -> void:
	var inv := inventory()
	var me := get_parent() as Node2D
	if inv == null or me == null or me.get("dead"):
		return
	for p: Pickup in get_tree().get_nodes_in_group("pickup"):
		if not p.settled:
			continue
		if inv.room_for(p.item) <= 0:
			continue   # bag full: it stays on the ground
		var d := p.global_position.distance_to(me.global_position)
		if d <= pickup_radius:
			var left := inv.add(p.item, p.amount)
			last_pickup = "%s x%d" % [p.item.display_name, p.amount - left]
			if left == 0:
				p.queue_free()
			else:
				p.amount = left
		elif d <= magnet_radius:
			p.global_position = p.global_position.move_toward(me.global_position, magnet_speed * delta)


# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")
func debug_name() -> String:
	return "Collector"

func debug_category() -> String:
	return "Items & Crafting"

func debug_actions() -> Array:
	return [
		{"label": "Break nearest node", "run": _debug_break_nearest},
		{"label": "Give 10 each", "run": func(): inventory().give_materials(10)},
		{"label": "Clear items", "run": func(): inventory().clear()},
	]

func status_text() -> String:
	var loadout := get_parent().get_node_or_null("Loadout") as Loadout
	var inv := inventory()
	if loadout == null or inv == null:
		return "n/a"
	var w: WeaponData = loadout.active_weapon()
	var counts := []
	for id in inv.items():
		counts.append("%s %d" % [id, inv.count(id)])
	return "%s  gather_damage %.1f  tool_power %d\nlast hit: %s\nreaction: %s\nitems: %s  on ground: %d\n(density changes apply on New map)" % [
		"HOLSTERED" if loadout.is_holstered() else "armed",
		w.gather_damage if w else 0.0, w.tool_power if w else 0,
		last_gather if last_gather != "" else "-",
		(get_tree().get_first_node_in_group("node_reaction_fx") as NodeReactionFx).last_text if get_tree().get_first_node_in_group("node_reaction_fx") else "-",
		", ".join(counts) if counts else "none",
		get_tree().get_nodes_in_group("pickup").size()]

## F3: breaks the closest unbroken node at once, as if hit by a god tool.
func _debug_break_nearest() -> void:
	var me := get_parent() as Node2D
	var best: ResourceNode
	for n: ResourceNode in get_tree().get_nodes_in_group("resource_node"):
		if n.is_broken():
			continue
		if best == null or n.global_position.distance_to(me.global_position) < best.global_position.distance_to(me.global_position):
			best = n
	if best:
		var w := WeaponData.new()
		w.gather_damage = 999.0
		w.tool_power = 9
		w.tool_kind = best.data.preferred_tool
		best.take_gather_hit(w, me)
