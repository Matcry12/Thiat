class_name ItemCounter
extends HBoxContainer
## HUD: "Wood 3  Stone 2" under the hotbar. Hidden while the inventory is empty.

func bind(inv: Inventory) -> void:
	inv.changed.connect(_rebuild.bind(inv))
	_rebuild(inv)

func _rebuild(inv: Inventory) -> void:
	for c in get_children():
		remove_child(c)   # not just queue_free: freed children still count this frame
		c.queue_free()
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
