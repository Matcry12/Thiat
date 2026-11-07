extends SceneTree
# Art fit (WeaponData "Art fit"): scale / nudge / turn reach the model's Art, the hit area, and give the scene back at 0.
var _fail := 0

func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fail += 1

## A temp copy of a model scene whose Grip is at `g` (never the real scene).
func _grip_scene(model: PackedScene, g: Vector2, n: String) -> PackedScene:
	var txt := FileAccess.get_file_as_string(model.resource_path)
	var gi := txt.find('[node name="MainHandGrip"')
	var sub := txt.substr(gi)
	var pi := sub.find("position = Vector2(")
	var line := "position = Vector2(%s, %s)\n" % [str(g.x), str(g.y)]
	var edited: String
	if pi >= 0:
		edited = txt.substr(0, gi) + sub.substr(0, pi) + line + sub.substr(sub.find("\n", pi) + 1)
	else:
		var e := sub.find("\n")
		edited = txt.substr(0, gi) + sub.substr(0, e + 1) + line + sub.substr(e + 1)
	var f := FileAccess.open("user://%s.tscn" % n, FileAccess.WRITE)
	f.store_string(edited)
	f.close()
	return ResourceLoader.load("user://%s.tscn" % n, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene

func _hit_span(m: Node2D) -> Vector2:   # hit shape start / end along x in MODEL space
	var hb := m.get_node("Hitbox") as Node2D
	var cs := m.get_node("Hitbox/CollisionShape2D") as CollisionShape2D
	var c := hb.position.x + cs.position.x
	var half := (cs.shape as RectangleShape2D).size.x * 0.5
	return Vector2(c - half, c + half)

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	for i in 5:
		await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	wv.set_process(false)
	for id in ["glide", "sword1", "stone_axe", "hoe"]:
		var w: WeaponData = load("res://data/weapons/%s.tres" % id).duplicate()
		wv.weapon = w
		var art := wv.get_model().get_node("Art") as Sprite2D
		var base := art.transform
		var shape := wv.get_model().get_node("Hitbox/CollisionShape2D").shape as RectangleShape2D
		var len0 := shape.size.x
		var sc0 := art.scale
		_check(wv.status_text().contains("fit: x"), id + ": defaults shown in status")
		w.art_scale = 2
		art = wv.get_model().get_node("Art")
		shape = wv.get_model().get_node("Hitbox/CollisionShape2D").shape as RectangleShape2D
		_check(art.scale.is_equal_approx(Vector2(2, 2)), id + ": scale 2 -> Art scale 2")
		if sc0.x < 2.0:
			_check(shape.size.x > len0 + 1.0, "%s: hit length grows with scale (%.1f -> %.1f)" % [id, len0, shape.size.x])
		w.art_scale = 2   # re-apply twice: no add-up
		w.art_nudge_x = 5.0
		w.art_nudge_y = -3.0
		w.art_turn_deg = 10.0
		wv._refit_hit()
		wv._refit_hit()
		art = wv.get_model().get_node("Art")
		_check(art.position.is_equal_approx(base.origin + Vector2(5, -3)), id + ": nudge moves, no add-up")
		_check(is_equal_approx(art.rotation, base.get_rotation() + deg_to_rad(10.0)), id + ": turn turns")
		w.art_scale = 0
		w.art_nudge_x = 0.0
		w.art_nudge_y = 0.0
		w.art_turn_deg = 0.0
		art = wv.get_model().get_node("Art")
		_check(art.position.is_equal_approx(base.origin) and is_equal_approx(art.rotation, base.get_rotation()) and art.scale.is_equal_approx(sc0), id + ": back to 0 = scene values")
		shape = wv.get_model().get_node("Hitbox/CollisionShape2D").shape as RectangleShape2D
		_check(is_equal_approx(shape.size.x, len0), id + ": hit length back to %.1f" % len0)
	# swing copy and ghosts follow
	var g: WeaponData = load("res://data/weapons/glide.tres").duplicate()
	wv.weapon = g
	g.art_scale = 3
	await process_frame
	if wv._swing_art and wv._swing_art.get_child_count() > 0:
		_check((wv._swing_art.get_child(wv._swing_art.get_child_count() - 1) as Node2D).scale.is_equal_approx(Vector2(3, 3)), "SwingArt copy follows live")
	# hold still toggle
	wv.debug_actions()[0]["run"].call()
	_check(wv.dev_hold_still and wv.status_text().contains("still: on"), "hold still on shows in status")
	# hold still also freezes the aim; the slider value sets it; off gives the mouse back
	wv.set_aim_angle(1.0)
	_check(is_equal_approx(wv.aim_angle, 0.0), "hold still: mouse aim ignored (aim 0 = right)")
	wv.dev_still_aim_deg = 90.0
	wv.set_aim_angle(-2.0)
	_check(is_equal_approx(wv.aim_angle, PI * 0.5) and wv.status_text().contains("aim 90"), "hold still: dev_still_aim_deg sets the aim, shown in status")
	wv.debug_actions()[0]["run"].call()
	wv.set_aim_angle(1.0)
	_check(is_equal_approx(wv.aim_angle, 1.0), "hold still off: mouse aim back")
	# no model scene carries the old editor player guide; user's scene values reach the running weapon
	for f in DirAccess.get_files_at("res://scenes/weapons"):
		if not f.ends_with("_model.tscn"):
			continue
		var ps := load("res://scenes/weapons/" + f) as PackedScene
		var st := ps.get_state()
		var eps := 0
		for i in st.get_node_count():
			if st.get_node_name(i) == &"EditorPlayer":
				eps += 1
		_check(eps == 0, f + ": no EditorPlayer")
	var gm: Node = load("res://scenes/weapons/glide_model.tscn").instantiate()
	gm.get_node("Art").position = Vector2(7, 3)   # what the user drags in the editor
	root.add_child(gm)
	await process_frame
	_check(gm.get_node("Art").position.is_equal_approx(Vector2(7, 3)), "Art position set in the scene is kept")
	gm.queue_free()
	var scene_art: Node = load("res://scenes/weapons/glide_model.tscn").instantiate()
	var base_pos: Vector2 = scene_art.get_node("Art").position - scene_art.get_node("MainHandGrip").position   # the Grip shift is part of the scene contract
	scene_art.free()
	wv.weapon = load("res://data/weapons/glide.tres").duplicate()
	await process_frame
	_check((wv.get_model().get_node("Art") as Node2D).position.is_equal_approx(base_pos), "scene Art position reaches the running weapon")
	# decimal scale (1.3): reaches Art, hit length, status; no OFF AXIS; scale 1.3 in a temp scene survives
	var wd: WeaponData = load("res://data/weapons/glide.tres").duplicate()
	wv.weapon = wd
	await process_frame
	var len1 := (wv.get_model().get_node("Hitbox/CollisionShape2D") as CollisionShape2D).shape.get_rect().size.x
	wd.art_scale = 1.3
	_check((wv.get_model().get_node("Art") as Node2D).scale.is_equal_approx(Vector2(1.3, 1.3)), "art_scale 1.3 -> Art scale 1.3")
	var len13 := (wv.get_model().get_node("Hitbox/CollisionShape2D") as CollisionShape2D).shape.get_rect().size.x
	_check(len13 > len1 and len13 < len1 * 1.4, "hit length follows 1.3 (%.1f -> %.1f)" % [len1, len13])
	_check(wv.status_text().contains("fit: x1.3") and not wv.status_text().contains("OFF AXIS"), "status shows x1.3, no OFF AXIS")
	wd.art_scale = 0.0
	var gtxt := FileAccess.get_file_as_string("res://scenes/weapons/glide_model.tscn")
	var ai := gtxt.find('[node name="Art"')
	var aeol := gtxt.find("\n", ai)
	var gt := FileAccess.open("user://scale_tmp.tscn", FileAccess.WRITE)
	gt.store_string(gtxt.substr(0, aeol + 1) + "scale = Vector2(1.3, 1.3)\n" + gtxt.substr(aeol + 1))
	gt.close()
	var sc_scene := ResourceLoader.load("user://scale_tmp.tscn", "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var wd2: WeaponData = load("res://data/weapons/glide.tres").duplicate()
	wd2.model = sc_scene
	wv.weapon = wd2
	await process_frame
	_check((wv.get_model().get_node("Art") as Node2D).scale.is_equal_approx(Vector2(1.3, 1.3)), "decimal scale typed in the scene reaches the game")
	wd2.art_scale = 0.0
	wd2.emit_changed()
	_check((wv.get_model().get_node("Art") as Node2D).scale.is_equal_approx(Vector2(1.3, 1.3)), "art_scale 0 keeps the scene's 1.3")
	# Grip on a decimal-scaled Art: the picture pixel under Grip is the same with and without the shift
	var art13 := wv.get_model().get_node("Art") as Node2D
	var gpos: Vector2 = load("res://scenes/weapons/glide_model.tscn").instantiate().get_node("MainHandGrip").position
	var pix_now := art13.transform.affine_inverse() * Vector2.ZERO
	var pix_expect := (art13.transform * Vector2.ZERO) # Art origin in shifted model space
	_check((art13.position + gpos).is_equal_approx(sc_scene.instantiate().get_node("Art").position), "shift is model-space: Art moved by exactly -Grip (decimal scale)")
	# Hand point: the player's Hand marker (+ hand_nudge): sword, axe, bow at rest
	var vis: SpriteActorVisual = player.get_node("Visual")
	var rig: BodyRig = vis.rig
	var hand: Marker2D = player.get_node("MainHandHold")
	_check(not ("hand_offset" in rig), "no hand_offset field left on the rig")
	rig.hand_follow = 0.0   # these checks are about Hand + nudge only; the frame follow has its own block below
	var hand0 := hand.position   # the scene's own value (the user may have dragged it)
	_check((wv.global_position - player.global_position).is_equal_approx(hand0), "WeaponVisual sits on the Hand marker")
	_check(wv.status_text().contains("hand %.1f,%.1f" % [hand0.x, hand0.y]), "status shows the hand")
	for id in ["sword1", "stone_axe", "bow"]:
		wv.weapon = load("res://data/weapons/%s.tres" % id).duplicate()
		await process_frame
		wv._process(0.0)
		var g0: Vector2 = wv.get_model().global_position
		var grip_rel := g0 - wv.global_position
		hand.position = hand0 + Vector2(8, 4)
		wv._apply_hand()
		wv._apply_hand()   # twice: no add-up
		wv._process(0.0)
		_check((wv.get_model().global_position - g0).is_equal_approx(Vector2(8, 4)), id + ": Hand marker moves the grip")
		_check((wv.get_model().global_position - wv.global_position).is_equal_approx(grip_rel), id + ": grip = hand + rest grip path")
		wv.hand_nudge = Vector2(3, 3)
		wv._process(0.0)
		_check((wv.get_model().global_position - g0).is_equal_approx(Vector2(11, 7)), id + ": hand_nudge moves it too, live")
		_check(wv.status_text().contains("hand %.1f,%.1f" % [hand0.x + 11, hand0.y + 7]), id + ": status shows the final hand")
		hand.position = hand0
		wv.hand_nudge = Vector2.ZERO
		wv._process(0.0)
		_check(wv.get_model().global_position.is_equal_approx(g0) and wv.position == hand0, id + ": back restores exactly")
	# flip: Hand x = 8, body flips through the real path (visual.set_facing), WeaponVisual x mirrors
	hand.position = Vector2(8, -9)
	vis.set_facing(Vector2.RIGHT)
	wv._apply_hand()
	_check(wv.position.is_equal_approx(Vector2(8, -9)), "facing right: hand x +8")
	vis.set_facing(Vector2.LEFT)
	wv._apply_hand()
	wv._apply_hand()
	_check(wv.position.is_equal_approx(Vector2(-8, -9)) and wv.hand_point().is_equal_approx(player.global_position + Vector2(-8, -9)), "facing left: hand x -8, once (no add-up), y kept")
	wv.hand_nudge = Vector2(2, 1)
	wv._apply_hand()
	_check(wv.position.is_equal_approx(Vector2(-10, -8)), "hand_nudge mirrors the same way")
	wv.hand_nudge = Vector2.ZERO
	vis.set_facing(Vector2.RIGHT)
	wv._apply_hand()
	_check(wv.position.is_equal_approx(Vector2(8, -9)), "flip back: +8")
	hand.position = Vector2(0, -9)
	vis.set_facing(Vector2.LEFT)
	wv._apply_hand()
	_check(wv.position.is_equal_approx(Vector2(0, -9)), "hand x 0: flipping changes nothing")
	vis.set_facing(Vector2.RIGHT)
	hand.position = hand0
	wv._apply_hand()
	# hand_follow: the hand goes with the bspr frames (expected value computed from the frames, no tuned numbers)
	rig.hand_follow = 1.0
	var bspr := vis.get_node("Body") as AnimatedSprite2D
	bspr.pause()
	var sf := bspr.sprite_frames
	var scale_y := rig.body_scale.y
	var ref_top := sf.get_frame_texture(&"idle", 0).get_image().get_used_rect().position.y
	var moved := 0
	for case in [[&"idle", 0], [&"idle", 1], [&"idle", 2], [&"run", 0], [&"run", 1], [&"run", 2], [&"run", 3]]:
		if not sf.has_animation(case[0]) or sf.get_frame_count(case[0]) <= case[1]:
			continue
		bspr.animation = case[0]
		bspr.frame = case[1]
		bspr.position = vis._rest_position
		var top := sf.get_frame_texture(case[0], case[1]).get_image().get_used_rect().position.y
		var dy := float(top - ref_top) * scale_y
		if dy != 0.0:
			moved += 1
		vis.set_facing(Vector2.RIGHT)
		wv._apply_hand()
		_check(is_equal_approx(wv.position.y, hand0.y + dy) and is_equal_approx(wv.position.x, hand0.x), "hand follows %s %d: dy %.1f" % [case[0], case[1], dy])
		_check(wv.status_text().contains("follow %.1f" % dy), "status shows follow %.1f" % dy)
		vis.set_facing(Vector2.LEFT)
		wv._apply_hand()
		_check(is_equal_approx(wv.position.x, -hand0.x) and is_equal_approx(wv.position.y, hand0.y + dy), "facing left: x mirrors, dy kept (%s %d)" % [case[0], case[1]])
		rig.hand_follow = 0.0
		wv._apply_hand()
		_check(wv.position.is_equal_approx(Vector2(-hand0.x, hand0.y)), "hand_follow 0: no move (%s %d)" % [case[0], case[1]])
		rig.hand_follow = 1.0
		wv.dev_hold_still = true
		wv._apply_hand()
		_check(wv.position.is_equal_approx(Vector2(-hand0.x, hand0.y)), "hold still: no move (%s %d)" % [case[0], case[1]])
		wv.dev_hold_still = false
		vis.set_facing(Vector2.RIGHT)
	_check(moved > 0, "the real frames do move the bspr picture (else this test proves nothing)")
	if sf.has_animation(&"death"):
		bspr.animation = &"death"
		bspr.frame = 0
		wv._apply_hand()
		_check(vis.hand_frame_offset() == Vector2.ZERO or sf.get_frame_texture(&"death", 0).get_size() == sf.get_frame_texture(&"idle", 0).get_size(), "death frame: no offset when its size differs")
	bspr.animation = &"idle"
	bspr.frame = 0
	bspr.play()
	wv._apply_hand()
	rig.hand_follow = 0.0
	# Grip moves the picture AND the hit area once: hit tip stays picture tip + margin, hit start stays at the hand, no false OFF AXIS
	for id in ["sword1", "wooden_sword", "stone_axe"]:
		var base: WeaponData = load("res://data/weapons/%s.tres" % id)
		var gs0: Vector2 = (base.model.instantiate() as Node2D).get_node("MainHandGrip").position
		var gap0 := NAN
		var start0 := NAN
		for gv in [Vector2(0, 0), Vector2(10, 0), Vector2(20, 0), Vector2(0, 6), Vector2(20, 6)]:
			var wg: WeaponData = base.duplicate()
			wg.model = _grip_scene(base.model, gv, "grip_case")
			wv.weapon = wg
			await process_frame
			var mm := wv.get_model()
			var pt: float = WeaponHitFit.measure(mm.get_node("Art") as Sprite2D, wg.hit_alpha_min)["tip"]
			var span := _hit_span(mm)
			var gap := span.y - pt
			if is_nan(gap0):
				gap0 = gap
				start0 = span.x
			_check(is_equal_approx(gap, gap0) and is_equal_approx(gap, wg.hit_tip_margin), "%s Grip %s: hit tip = picture tip + margin (gap %.2f)" % [id, str(gv), gap])
			_check(is_equal_approx(span.x, start0), "%s Grip %s: hit area starts at the hand (%.2f)" % [id, str(gv), span.x])
			_check(not wv.status_text().contains("OFF AXIS"), "%s Grip %s: no false OFF AXIS" % [id, str(gv)])
			wg.hit_auto_fit = false   # hand-set shape: it travels with the picture (same model-space shift)
			var span_m := _hit_span(wv.get_model())
			wg.hit_auto_fit = true
			_check(is_equal_approx(span_m.y - span_m.x, (base.model.instantiate().get_node("Hitbox/CollisionShape2D").shape as RectangleShape2D).size.x), "%s Grip %s: auto fit off gives the scene's own shape, live" % [id, str(gv)])
	wv.weapon = load("res://data/weapons/glide.tres").duplicate()
	await process_frame
	# Grip marker in the model scene: moved to (10,0) in a temp copy (never the real scene)
	var txt := FileAccess.get_file_as_string("res://scenes/weapons/glide_model.tscn")
	var gi := txt.find('[node name="MainHandGrip"')
	_check(gi >= 0, "glide model has a Grip marker")
	var gs := (load("res://scenes/weapons/glide_model.tscn").instantiate() as Node2D)
	var grip_scene: Vector2 = gs.get_node("MainHandGrip").position   # the scene's own Grip (the user may have dragged it)
	gs.free()
	var sub := txt.substr(gi)
	var pi := sub.find("position = Vector2(")
	var nl := sub.find("\n", pi) if pi >= 0 else -1
	var newline := "position = Vector2(%s, %s)\n" % [str(grip_scene.x + 10.0), str(grip_scene.y)]   # keep the dragged y, only x moves
	var edited := txt.substr(0, gi) + (sub.substr(0, pi) + newline + sub.substr(nl + 1) if pi >= 0 else sub.substr(0, sub.find("\n") + 1) + newline + sub.substr(sub.find("\n") + 1))
	var tmp := FileAccess.open("user://grip_tmp.tscn", FileAccess.WRITE)
	tmp.store_string(edited)
	tmp.close()
	var moved_scene := ResourceLoader.load("user://grip_tmp.tscn", "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	_check(moved_scene != null, "temp scene with Grip (10,0) loads")
	var gw: WeaponData = load("res://data/weapons/glide.tres").duplicate()
	wv.weapon = gw
	await process_frame
	var m0 := wv.get_model()
	var a0 := (m0.get_node("Art") as Node2D).position
	var h0 := (m0.get_node("Hitbox") as Node2D).position
	var t0 := (m0.get_node("Tip") as Node2D).position
	var l0: float = (m0.get_node("Hitbox/CollisionShape2D") as CollisionShape2D).shape.get_rect().size.x
	var gw2: WeaponData = gw.duplicate()
	gw2.model = moved_scene
	wv.weapon = gw2
	await process_frame
	var m1 := wv.get_model()
	var sh1 := m1.get_node("Hitbox/CollisionShape2D") as CollisionShape2D
	_check(m1.get_node("MainHandGrip").position == Vector2.ZERO, "Grip ends at 0,0")
	_check((m1.get_node("Art") as Node2D).position.is_equal_approx(a0 - Vector2(10, 0)), "Grip (10,0): Art shifted -10")
	_check((m1.get_node("Hitbox") as Node2D).position.is_equal_approx(h0 - Vector2(10, 0)), "Grip (10,0): Hitbox shifted -10")
	_check((m1.get_node("Tip") as Node2D).position.is_equal_approx(t0 - Vector2(10, 0)), "Grip (10,0): Tip shifted -10")
	print("   hit length ", l0, " -> ", sh1.shape.get_rect().size.x, " (shape pos ", sh1.position, " hitbox pos ", sh1.get_parent().position, ")")
	wv._refit_hit()
	wv._refit_hit()
	_check((wv.get_model().get_node("Art") as Node2D).position.is_equal_approx(a0 - Vector2(10, 0)), "re-applying art fit does not add up")
	if wv._swing_art and wv._swing_art.get_child_count() > 0:
		_check(((wv._swing_art.get_child(wv._swing_art.get_child_count() - 1) as Node2D).position).is_equal_approx(a0 - Vector2(10, 0)), "swing art copy follows the shifted Art")
	wv.weapon = load("res://data/weapons/glide.tres").duplicate()
	await process_frame
	_check((wv.get_model().get_node("Art") as Node2D).position.is_equal_approx(a0), "back to the real scene: Art as before")
	# the hand does not touch the body
	var body := vis.get_node("Body") as AnimatedSprite2D
	var bp := body.position
	var bs := body.scale
	var ba := body.animation
	hand.position = hand0 + Vector2(8, 4)
	wv._apply_hand()
	await process_frame
	_check(body.position == bp and body.scale == bs and body.animation == ba, "hand_offset leaves the body position / scale / animation alone")
	hand.position = hand0
	wv._apply_hand()
	# real flow: Hold weapon still shows the weapon by itself once physics runs (no input)
	player.set_physics_process(true)
	wv.set_process(true)
	wv.debug_actions()[0]["run"].call()
	for i in 4:
		await physics_frame
	_check(wv.visible, "Hold weapon still: weapon visible after real physics frames, no input")
	wv.debug_actions()[0]["run"].call()
	player.set_physics_process(false)
	wv.set_process(false)
	# shadow: the scene stores the base (1.0), the rig multiplies once (0.9, HEAD's look); applying again does not shrink it
	var sh := vis.get_node("Shadow") as Node2D
	var shadow_scene: Node = load("res://scenes/player.tscn").instantiate()
	_check(is_equal_approx((shadow_scene.get_node("Visual/Shadow") as Node2D).scale.x, 1.0), "player.tscn stores the shadow base scale 1.0 (no baked 0.9)")
	shadow_scene.free()
	_check(is_equal_approx(sh.scale.x, 0.9 * rig.shadow_scale / 0.9), "shadow = base x rig.shadow_scale (%.3f)" % sh.scale.x)
	vis._apply_rig_body()
	vis._apply_rig_body()
	_check(is_equal_approx(sh.scale.x, rig.shadow_scale), "applying the rig twice does not shrink the shadow")
	# per-weapon: one weapon changed does not touch another
	var s1: WeaponData = load("res://data/weapons/sword1.tres")
	_check(s1.art_scale == 0 and load("res://data/weapons/glide.tres").art_scale == 0, "other weapon resources untouched")
	print("RESULT: %s" % ("PASS" if _fail == 0 else "FAIL %d" % _fail))
	quit(1 if _fail else 0)
