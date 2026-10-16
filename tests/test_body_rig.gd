extends SceneTree
# BodyRig (decision 0028): ONE per-character setting scales the weapon/hand PICTURES and moves the pivot, but never the gameplay:
# hitbox shape/world transform and bow muzzle must be identical at visual_scale 0.7 and 1.0, for sword, bow and fists.
var _ok := true
func check(name: String, cond: bool) -> void:
	print("%s: %s" % [name, "ok" if cond else "FAIL"])
	if not cond:
		_ok = false

func _gameplay_snapshot(model: Node2D) -> Array:
	# relative to WeaponVisual (the pivot never moves per character, so this is also the player-relative position)
	var inv: Transform2D = model.get_parent().get_parent().global_transform.affine_inverse()
	var out := []
	for c in model.get_children():
		if c is Area2D or c.name == &"Muzzle":
			out.append([c.name, inv * c.global_transform])
			for cc in c.get_children():
				if cc is CollisionShape2D:
					out.append([cc.name, inv * cc.global_transform, (cc.shape as RectangleShape2D).size if cc.shape is RectangleShape2D else Vector2.ZERO])
	return out

func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var ta: Transform2D = a[i][1]
		var tb: Transform2D = b[i][1]
		if not (ta.origin.distance_to(tb.origin) < 0.01 and ta.x.distance_to(tb.x) < 0.001 and ta.y.distance_to(tb.y) < 0.001):   # float noise from /s * s
			return false
		if a[i].size() > 2 and not (a[i][2] as Vector2).distance_to(b[i][2]) < 0.001:
			return false
	return true

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var vis: SpriteActorVisual = player.get_node("Visual")
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	var hands: HandsVisual = player.get_node("Hands")
	var fx: SwingFx = player.get_node("WeaponVisual/SwingFx")
	var loadout: Loadout = player.get_node("Loadout")
	# Two copies of the tiny soldier rig: `small` shrinks the weapon / hand pictures, `full` is the unscaled picture.
	var tiny: BodyRig = load("res://data/body_rigs/tiny_soldier.tres")
	var rig_small: BodyRig = tiny.duplicate()
	rig_small.display_name = "small copy"
	rig_small.visual_scale = 0.7
	rig_small.slash_scale = 0.7
	rig_small.shadow_scale = 0.65
	var rig_full: BodyRig = tiny.duplicate()
	rig_full.visual_scale = 1.0
	check("player starts with the tiny soldier rig", vis.rig.display_name.begins_with("tiny soldier"))
	vis.rig = rig_small
	check("small rig loads and shrinks the weapon picture", vis.rig == rig_small and rig_small.visual_scale < 1.0)
	check("WeaponVisual (gameplay pivot) is NOT moved by the rig", wv.position == Vector2(0, -9) and hands.position == Vector2(0, -9))
	check("hand radius from the rig", is_equal_approx(hands.hand_radius, rig_small.hand_radius) and hands.rest_offset_main == rig_small.hand_rest_main)
	check("slash scale from the rig", is_equal_approx(fx._slash_scale, rig_small.slash_scale))

	var weapons: Array = []
	for w in loadout.weapons: weapons.append(w)
	weapons.append(loadout.unarmed)
	for w in weapons:
		if w == null or w.model == null:
			continue
		vis.rig = rig_small
		wv.set_weapon(w)
		var model := wv.get_model()
		var small := _gameplay_snapshot(model)
		var art_scale := model.scale.x
		var hand_main := (model.get_node("HandMain") as Node2D).global_position - wv.global_position
		vis.rig = rig_full
		var big := _gameplay_snapshot(wv.get_model())
		var hand_main_big := (wv.get_model().get_node("HandMain") as Node2D).global_position - wv.global_position
		check("%s: picture scales with visual_scale (%.2f)" % [w.resource_path.get_file(), art_scale], is_equal_approx(art_scale, rig_small.visual_scale) and is_equal_approx(wv.get_model().scale.x, 1.0))
		check("%s: hitbox / muzzle world transform + shape size UNCHANGED by the scale (%d nodes)" % [w.resource_path.get_file(), small.size()], _same(small, big))
		check("%s: hands move with the picture (HandMain nearer the pivot)" % w.resource_path.get_file(), hand_main.length() < hand_main_big.length() + 0.001)
	vis.rig = rig_small
	wv.set_weapon(loadout.weapons[0])
	check("guard offset scales with the picture", is_equal_approx(wv.visual_scale(), rig_small.visual_scale))

	# live tuning (F3): a rig number changes the picture on the next call, no restart
	rig_small.visual_scale = 0.5
	check("F3 edit of visual_scale applies live", is_equal_approx(wv.get_model().scale.x, 0.5))
	rig_small.hand_radius = 4.0
	check("F3 edit of hand_radius applies live", is_equal_approx(hands.hand_radius, 4.0))
	rig_small.shadow_scale = 0.5
	var sh := vis.get_node("Shadow") as Sprite2D
	check("F3 edit of shadow_scale applies live", is_equal_approx(sh.scale.x / (vis._shadow_base_scale.x), 0.5))
	rig_small.visual_scale = 0.7
	rig_small.hand_radius = 3.0
	rig_small.shadow_scale = 0.65
	check("F3 status line shows the rig", vis.status_text().contains("rig small copy"))
	quit(0 if _ok else 1)
