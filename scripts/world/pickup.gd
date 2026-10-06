class_name Pickup
extends Node2D
## A dropped item on the ground. Hops out to `to`, then the player's Collector can take it.
## Look: a diamond in item.color (placeholder) or an Icon sprite when the item has an icon.

const SCENE := preload("res://scenes/world/pickup.tscn")

## Feel numbers live on the Collector (F3 section "Collector"), not per drop.
var settle_time := 0.35
var size := 7.0

var item: ItemData
var amount := 1
var settled := false

static func spawn(parent: Node, it: ItemData, n: int, from: Vector2, to: Vector2) -> Pickup:
	var p: Pickup = SCENE.instantiate()
	p.item = it
	p.amount = n
	p.position = from
	var col := parent.get_tree().get_first_node_in_group("collector") as Collector
	if col:
		p.settle_time = col.pickup_hop_time
		p.size = col.pickup_size
	parent.add_child(p)
	p._hop(to)
	return p

func _ready() -> void:
	add_to_group("pickup")
	if item and item.icon:
		var s := Sprite2D.new()
		s.name = "Icon"
		s.texture = item.icon
		add_child(s)
	queue_redraw()

func _hop(to: Vector2) -> void:
	var tw := create_tween()
	tw.tween_property(self, "position", to, settle_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): settled = true)

func _draw() -> void:
	if item and item.icon:
		return
	var c := item.color if item else Color.WHITE
	draw_colored_polygon(PackedVector2Array([Vector2(0, -size), Vector2(size, 0), Vector2(0, size), Vector2(-size, 0)]), c)
