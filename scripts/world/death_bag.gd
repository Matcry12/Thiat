class_name DeathBag
extends Node2D
## What a dead player dropped (W6, decision 0039): material stacks waiting at the death spot.
## The Collector hands them back when the player walks over the bag (what does not fit stays inside).
## Look: the Visual child (placeholder shape). Nothing here draws or reaches into it.

const SCENE := preload("res://scenes/world/death_bag.tscn")

var items: Array[ItemData] = []
var counts: Array[int] = []
var _look_serial := -1

## Bag at `at` holding `stacks` (item id -> {item, count}); null when there is nothing to hold.
static func spawn(parent: Node, at: Vector2, stacks: Dictionary) -> DeathBag:
	if stacks.is_empty():
		return null
	var b: DeathBag = SCENE.instantiate()
	for id in stacks:
		b.items.append(stacks[id]["item"])
		b.counts.append(stacks[id]["count"])
	parent.add_child(b)
	b.global_position = at
	return b

func _ready() -> void:
	add_to_group("death_bag")
	_sync_look()

func _process(_d: float) -> void:
	_sync_look()   # F3 edits show live (a few bags, cheap)

func _sync_look() -> void:
	var r := get_tree().get_first_node_in_group("respawner") as Respawner
	var v := get_node_or_null("Visual")
	if r and v and v.has_method("set_look") and r.look_serial != _look_serial:
		_look_serial = r.look_serial
		v.set_look(r)

func total() -> int:
	var n := 0
	for c in counts:
		n += c
	return n

## Moves everything that fits into `inv`; frees the bag when empty.
func give_to(inv: Inventory) -> void:
	for i in range(items.size() - 1, -1, -1):
		counts[i] = inv.add(items[i], counts[i])
		if counts[i] <= 0:
			items.remove_at(i)
			counts.remove_at(i)
	if items.is_empty():
		queue_free()

func status_text() -> String:
	var parts: Array[String] = []
	for i in items.size():
		parts.append("%s %d" % [items[i].id, counts[i]])
	return ", ".join(parts)
