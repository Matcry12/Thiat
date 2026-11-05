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
## Game seconds until it vanishes; -1 = never. Only death drops set it (a tree's drops stay forever).
var despawn_left := -1.0
var death_drop := false   ## dropped by a dead player (F3 status, "Go to nearest drop", the save)
var pop_height := 0.0     ## px the hop arcs up at its peak (0 = a flat slide)

## `pop` > 0 arcs the hop (a death spray); `hop_time` < 0 uses the Collector's.
static func spawn(parent: Node, it: ItemData, n: int, from: Vector2, to: Vector2, pop := 0.0, hop_time := -1.0) -> Pickup:
	var p: Pickup = SCENE.instantiate()
	p.item = it
	p.amount = n
	p.position = from
	var col := parent.get_tree().get_first_node_in_group("collector") as Collector
	if col:
		p.settle_time = col.pickup_hop_time
		p.size = col.pickup_size
	if hop_time > 0.0:
		p.settle_time = hop_time
	p.pop_height = pop
	parent.add_child(p)
	p._hop(to)
	return p

const SHADOW := preload("res://assets/placeholder/shadow.png")

var _visual: PickupVisual
var _shadow: Sprite2D
var _collector: Collector
var _t := 0.0
var _phase := 0.0

func _ready() -> void:
	add_to_group("pickup")
	_collector = get_tree().get_first_node_in_group("collector") as Collector
	_phase = randf() * TAU   # so a pile does not bob in step
	_shadow = Sprite2D.new()   # its own node: on the ground, only its size follows the float
	_shadow.name = "Shadow"
	_shadow.texture = SHADOW
	_shadow.show_behind_parent = true
	add_child(_shadow)
	_visual = PickupVisual.new()
	_visual.name = "Visual"
	_visual.size = size
	_visual.color = item.color if item else Color.WHITE
	_visual.has_icon = item != null and item.icon != null
	add_child(_visual)
	if _visual.has_icon:
		var s := Sprite2D.new()
		s.name = "Icon"
		s.texture = ItemIcon.crop(item.icon)   # the visible pixels sit on the pickup's centre
		s.scale = Vector2.ONE * (_collector.pickup_icon_px if _collector else 16.0) / item.icon.get_height()
		_visual.add_child(s)
	_update_look(0.0)

## The float: after settling the icon bobs on a sine, the shadow shrinks as it rises. Visual only.
func _update_look(lift01: float) -> void:
	var c := _collector
	var h := c.bob_height if c else 3.0
	_visual.position.y = -lift01 * h
	_shadow.visible = c.shadow_on if c else true
	if _shadow.visible:
		var w := c.shadow_size if c else 14.0
		var a := c.shadow_alpha if c else 0.35
		var m := c.shadow_min_scale if c else 0.8
		_shadow.scale = Vector2.ONE * (w / SHADOW.get_width()) * lerpf(1.0, m, lift01)
		_shadow.modulate.a = a
		_shadow.position.y = c.shadow_offset_y if c else 6.0

func _process(delta: float) -> void:
	if settled:
		_t += delta
		var period := _collector.bob_period if _collector else 2.0
		_update_look(0.5 - 0.5 * cos(TAU * _t / maxf(period, 0.1) + _phase))   # 0 = on the ground, 1 = top of the float
	if despawn_left >= 0.0:
		despawn_left -= delta
		if despawn_left <= 0.0:
			queue_free()

func _hop(to: Vector2) -> void:
	var from := position
	var tw := create_tween()
	tw.tween_method(func(t: float):
		position = from.lerp(to, t) + Vector2(0.0, -4.0 * pop_height * t * (1.0 - t)),
		0.0, 1.0, maxf(settle_time, 0.01)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): settled = true)
