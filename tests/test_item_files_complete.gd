extends SceneTree
## Every item with a weapon has: a model scene (Art, Hitbox, Grip, Tip) and an icon that loads. No tuned numbers pinned.

func _init() -> void:
	var ok := true
	var n := 0
	for f in DirAccess.get_files_at("res://data/items"):
		if not f.ends_with(".tres"):
			continue
		var item := load("res://data/items/" + f) as ItemData
		if item == null or item.weapon == null:
			continue
		n += 1
		if item.icon == null:
			print("FAIL: no icon: ", f)
			ok = false
		if item.weapon.model == null:
			print("FAIL: no model: ", f)
			ok = false
			continue
		var m := item.weapon.model.instantiate()
		# a projectile weapon (bow) has no melee hitbox / blade tip
		var need: Array = ["Art", "MainHandGrip"] if item.weapon.behavior == "projectile" else ["Art", "Hitbox", "Hitbox/CollisionShape2D", "MainHandGrip", "Tip"]
		for node in need:
			if m.get_node_or_null(node) == null:
				print("FAIL: ", f, " model has no ", node)
				ok = false
		var art := m.get_node_or_null("Art") as Sprite2D
		if art != null and art.texture == null:
			print("FAIL: ", f, " Art has no texture")
			ok = false
		m.free()
	print("weapons checked: ", n)
	if n == 0:
		ok = false
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
