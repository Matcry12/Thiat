extends SceneTree
# Hit feel slice 2, effect half: sparks and damage-number pools stay bounded, rapid hits merge into one number,
# styles follow the profile, sparks fly along the hit direction, each layer has its own switch.
var _ok := true
func check(name: String, cond: bool) -> void:
	print("%s: %s" % [name, "ok" if cond else "FAIL"])
	if not cond:
		_ok = false

func quiet(nm: DamageNumbers, sp: HitSparks) -> void:
	var g := 0
	while (nm.live_count() > 0 or sp.live_count() > 0) and g < 900:
		await process_frame
		g += 1

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	var fx: HitFx = arena.get_node("HitFx")
	player.set_physics_process(false)
	dummy.attacker.set_physics_process(false)
	fx.stop_on = false
	fx.shake_on = false
	var sp := fx.sparks
	var nm := fx.numbers
	var info := {"amount": 7.0, "direction": Vector2.RIGHT, "victim": dummy, "source": player, "tag": &"melee"}

	# one burst, one frame: cap per frame, sparks start at the hurtbox edge and fly along +x
	await process_frame
	sp.max_per_frame = 24
	var before := sp.spawned_total
	for i in 10:
		fx.fire(&"lunge", dummy, player, info)   # 10 sparks each = 100 wanted
	check("per-frame cap: %d sparks started (cap 24)" % (sp.spawned_total - before), sp.spawned_total - before == 24)
	var fast_right := 0
	for s in sp._pool:
		if s.life > 0.0 and s.vel.x > 0.0:
			fast_right += 1
	check("sparks fly along the hit direction (%d of %d go right)" % [fast_right, sp.live_count()], fast_right == sp.live_count())
	check("sparks start at the hurtbox edge, not the centre", sp._pool[0].pos.x < dummy.global_position.x - 5.0)

	# 200 hits over 200 frames, every layer on
	for i in 200:
		fx.fire([&"sword", &"lunge", &"arrow", &"charged_arrow", &"parry", &"player_hit"][i % 6], dummy, player, info)
		await process_frame
	check("sparks pool bounded (%d <= %d)" % [sp.pool_size(), sp.max_sparks], sp.pool_size() <= sp.max_sparks)
	check("number pool bounded (%d <= %d), one Label per slot" % [nm.pool_size(), nm.max_numbers], nm.pool_size() <= nm.max_numbers and nm.get_child(0).get_child_count() == nm.pool_size())
	# 200 hits in ONE frame
	await process_frame
	var spawned := sp.spawned_total
	for i in 200:
		fx.fire(&"lunge", dummy, player, info)
	check("200 hits in one frame: sparks capped (%d new)" % (sp.spawned_total - spawned), sp.spawned_total - spawned <= sp.max_per_frame and sp.pool_size() <= sp.max_sparks)
	check("200 hits in one frame: numbers merged, pool still bounded (%d)" % nm.pool_size(), nm.pool_size() <= nm.max_numbers)
	# let everything fade: nothing lives forever
	await quiet(nm, sp)
	check("everything fades out (sparks %d, numbers %d live)" % [sp.live_count(), nm.live_count()], sp.live_count() == 0 and nm.live_count() == 0)

	# rapid arrows on one victim: merged into ONE number, amounts added
	await quiet(nm, sp)
	var live0 := nm.live_count()
	for i in 6:
		fx.fire(&"arrow", dummy, player, {"amount": 10.0, "direction": Vector2.RIGHT})
		for j in 3:
			await process_frame
	check("6 rapid arrows = 1 live number (%d)" % (nm.live_count() - live0), nm.live_count() - live0 == 1)
	var lab: Label = null
	for e in nm._pool:
		if e.label.visible:
			lab = e.label
	check("merged number shows the total (%s)" % lab.text, lab != null and lab.text == "60")
	await quiet(nm, sp)

	# styles: normal = small white, strong = bigger yellow, player = red, parry = PARRY text
	var cases := [[&"sword", 9, "white"], [&"lunge", 14, "yellow"], [&"charged_arrow", 14, "yellow"], [&"player_hit", 12, "red"], [&"parry", 16, "yellow"]]
	for c in cases:
		await quiet(nm, sp)
		fx.fire(c[0], dummy, player, {"amount": 12.0, "direction": Vector2.RIGHT})
		var l: Label = null
		for e in nm._pool:
			if e.label.visible:
				l = e.label
		var col: Color = l.modulate
		var is_col: bool = (c[2] == "white" and col.g > 0.95 and col.b > 0.95) or (c[2] == "yellow" and col.r > 0.9 and col.g > 0.8 and col.b < 0.4) or (c[2] == "red" and col.r > 0.9 and col.g < 0.4)
		check("number %s: size %d, %s, text '%s'" % [c[0], l.get_theme_font_size("font_size"), c[2], l.text], l.get_theme_font_size("font_size") == c[1] and is_col and (l.text == "PARRY") == (c[0] == &"parry"))

	# switches: each layer off = that layer silent, others still play
	await quiet(nm, sp)
	var base: Dictionary = fx.layer_counts.duplicate()
	fx.sparks_on = false
	fx.fire(&"sword_boss", arena.get_node("Boss"), player, info)
	check("sparks off: no sparks, numbers+recoil still play", fx.layer_counts["sparks"] == base["sparks"] and fx.layer_counts["numbers"] == base["numbers"] + 1 and fx.layer_counts["recoil"] == base["recoil"] + 1)
	fx.sparks_on = true
	fx.numbers_on = false
	fx.recoil_on = false
	base = fx.layer_counts.duplicate()
	fx.fire(&"sword_boss", arena.get_node("Boss"), player, info)
	check("numbers+recoil off: only sparks play", fx.layer_counts["sparks"] == base["sparks"] + 1 and fx.layer_counts["numbers"] == base["numbers"] and fx.layer_counts["recoil"] == base["recoil"])
	# a normal enemy (has Knockback) gets no recoil jolt: it moves instead
	fx.recoil_on = true
	base = fx.layer_counts.duplicate()
	fx.fire(&"lunge", dummy, player, info)
	check("dummy (real knockback): no visual recoil", fx.layer_counts["recoil"] == base["recoil"])
	# F3 test buttons reach the new layers, no HP change, no movement
	var hp: float = dummy.get_node("Health").hp
	var pos: Vector2 = dummy.global_position
	fx.numbers_on = true
	base = fx.layer_counts.duplicate()
	for k in [&"sword", &"parry", &"player_hit", &"kill", &"boss_sword", &"lunge", &"charged_arrow"]:
		fx.test_hit(k)
	check("test buttons fire sparks, numbers and recoil", fx.layer_counts["sparks"] > base["sparks"] and fx.layer_counts["numbers"] > base["numbers"] and fx.layer_counts["recoil"] > base["recoil"])
	await physics_frame
	check("test buttons: no HP change, no movement", dummy.get_node("Health").hp == hp and dummy.global_position == pos)
	Engine.time_scale = 1.0
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
