class_name ItemCounter
extends HBoxContainer
## HUD: "Wood 3  Stone 2" under the hotbar. Hidden while the inventory is empty.

@export var gap := 12

func bind(inv: Inventory) -> void:
	inv.changed.connect(_rebuild.bind(inv))
	_rebuild(inv)

func _rebuild(inv: Inventory) -> void:
	for c in get_children():
		c.queue_free()
	add_theme_constant_override("separation", gap)
	var counts := inv.items()
	for id in counts:
		if counts[id] <= 0:
			continue
		var it := inv.item(id)
		if it.icon:
			var t := TextureRect.new()
			t.texture = it.icon
			add_child(t)
		var l := Label.new()
		l.text = "%s %d" % [it.display_name, counts[id]]
		add_child(l)
	visible = get_child_count() > 0
