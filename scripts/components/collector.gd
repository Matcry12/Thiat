class_name Collector
extends Node
## Child of the Player. Pulls settled pickups in and banks them in the Inventory. A full inventory leaves them on the ground.

@export var magnet_radius := 70.0
@export var magnet_speed := 420.0
@export var pickup_radius := 14.0
@export var inventory_path: NodePath = ^"../Inventory"
@export var pickup_hop_time := 0.35   ## read by Pickup
@export var pickup_size := 7.0   ## placeholder diamond, read by Pickup
@export var scatter_radius := 26.0   ## read by ResourceNode for drop spread

var last_pickup := ""   # for F3
var last_gather := ""   # status of the last node hit, for F3

func _ready() -> void:
	add_to_group("collector")

func inventory() -> Inventory:
	return get_node_or_null(inventory_path) as Inventory

func _physics_process(delta: float) -> void:
	var inv := inventory()
	var me := get_parent() as Node2D
	if inv == null or me == null:
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
