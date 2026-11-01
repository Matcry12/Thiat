extends SceneTree
# Natural sword swing (0049): swords have a SwingMotion; the PICTURE (SwingArt) moves on curves, the old pivot
# (SwingPivot + Hitbox node + arc_poses) behaves exactly as with motion = null (the swept hit path is tested in test_hit_follows_swing.gd); aiming left mirrors; recovery ends at rest.
var _fail := 0

func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fail += 1

## Steps one swing by hand (no wall clock). Returns per-step traces.
var _hflip := 1.0   # what WeaponHolder would have decided (0050: the holder owns the side, the picture follows)
func _run(wv: WeaponVisual, hb: Hitbox, aim: float, since := 0.1) -> Dictionary:
	wv.set_aim_angle(aim)
	_hflip = wv.weapon.swing_motion.next_flip(_hflip, since)
	wv.set_swing_flip(_hflip)
	var tr := {"pivot": [], "shape": [], "art": [], "tip": [], "ang": [], "poses": [], "ghosts": 0, "end_art": Vector2.ZERO}
	for st in ["windup", "active", "recovery"]:
		wv.on_weapon_state(st)
		var dur: float = {"windup": wv.weapon.windup, "active": wv.weapon.active, "recovery": wv.weapon.recovery}[st]
		var n := ceili(dur / (1.0 / 60.0))
		for i in n:
			wv._process(1.0 / 60.0)
			var pv := wv.get_node("SwingPivot") as Node2D
			tr["pivot"].append([pv.position, pv.rotation])
			tr["shape"].append((hb.get_child(0) as Node2D).global_transform)
			var art := wv.get_node("SwingArt") as Node2D
			tr["art"].append(art.get_child(0).global_position - wv.global_position)   # the Art's WORLD position, relative to the hand node
			tr["tip"].append(wv.picture_grip_tip()["tip"] - wv.global_position)
			tr["ang"].append(art.rotation)
			if st == "active":
				tr["poses"].append(hb.arc_poses(12).map(func(p): return p[1]))
				tr["ghosts"] = maxi(tr["ghosts"], wv.ghosts.count())
	for i in 30:   # settle after recovery
		wv._process(1.0 / 60.0)
	wv.on_weapon_state("idle")
	wv._process(1.0 / 60.0)
	tr["end_art"] = (wv.get_node("SwingArt") as Node2D).position
	tr["end_ang"] = (wv.get_node("SwingArt") as Node2D).rotation
	return tr

func _init():
	for p in ["wooden_sword", "copper_sword"]:
		_check(load("res://data/weapons/%s.tres" % p).swing_motion != null, "%s has a SwingMotion" % p)
	for p in ["bow", "copper_axe", "stone_pickaxe", "fists"]:
		_check(load("res://data/weapons/%s.tres" % p).swing_motion == null, "%s has none (unchanged)" % p)
	var player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	wv.set_process(false)
	var w: WeaponData = wv.weapon
	_check(w.swing_motion != null, "player holds the sword with a motion")
	w.swing_motion.screen_offset = Vector2.ZERO   # grip geometry below is checked in the aim frame; the screen shift is a plain add
	w.swing_motion.top_lift_px = 0.0   # the lift is screen-UP only (on purpose not mirrored), so the mirror checks below run without it
	var hb := wv.get_model().get_node("Hitbox") as Hitbox
	var s := wv.visual_scale()
	wv._process(1.0 / 60.0)
	var t1 := _run(wv, hb, 0.0, 99.0)
	_check((wv.get_model().get_node("Art") as Node2D).visible == false, "model Art hidden, SwingArt draws instead")
	# the grip MOVES during the swing (a fixed pivot would stay at 0,0)
	var far := 0.0
	var xs := {}
	for a in t1["art"]:
		far = maxf(far, (a as Vector2).length())
		xs[snappedf(a.x, 1.0)] = true
	_check(far > 12.0 * s and xs.size() > 4, "grip travels (max %.1f px, %d distinct x)" % [far, xs.size()])
	_check(t1["ghosts"] >= 3, "afterimages appear during active (%d)" % t1["ghosts"])
	var rest: Vector2 = w.swing_motion.rest_grip * s
	_check(((t1["end_art"] as Vector2) - rest).length() < 1.0, "recovery ends at rest grip (%s vs %s)" % [t1["end_art"], rest])
	_check(absf(rad_to_deg(t1["end_ang"]) - w.rest_angle_degrees) < 3.0, "blade back at rest angle (%.1f)" % rad_to_deg(t1["end_ang"]))
	# alternate: swing 2 (right after) goes the other way and rests on the other side; after the reset time it is the first way again
	var t1b := _run(wv, hb, 0.0)
	var sd := signf(rad_to_deg(t1["end_ang"]))
	_check(signf(rad_to_deg(t1b["end_ang"])) == -sd and absf(rad_to_deg(t1b["end_ang"]) + sd * absf(w.rest_angle_degrees)) < 3.0, "swing 2 rests on the opposite side (%.1f vs %.1f deg)" % [rad_to_deg(t1b["end_ang"]), rad_to_deg(t1["end_ang"])])
	_check(absf(t1b["end_art"].y + t1["end_art"].y) < 1.0, "swing 2 rest grip mirrored (y %.1f vs %.1f)" % [t1b["end_art"].y, t1["end_art"].y])
	var mid: int = t1["art"].size() * 2 / 3   # inside active/recovery
	_check(absf(t1b["art"][mid].y + t1["art"][mid].y) < 0.5 and absf(t1b["ang"][mid] + t1["ang"][mid]) < 0.05, "swing 2 mid-swing is the mirror of swing 1 (y %.1f vs %.1f)" % [t1b["art"][mid].y, t1["art"][mid].y])
	_check(absf(t1b["tip"][mid].y + t1["tip"][mid].y) < 0.5 and absf(t1b["tip"][mid].x - t1["tip"][mid].x) < 0.5, "swing 2 blade TIP mirrors in world (y %.1f vs %.1f)" % [t1b["tip"][mid].y, t1["tip"][mid].y])
	_check(wv.status_text().contains("reversed"), "status shows direction (%s)" % wv.status_text())
	for i in 150:   # 2.5 s idle > alternate_reset_time
		wv._process(1.0 / 60.0)
	_check(absf(rad_to_deg((wv.get_node("SwingArt") as Node2D).rotation) - w.rest_angle_degrees) < 1.0, "after the reset time the resting blade is back on the first side")
	var t1c := _run(wv, hb, 0.0, 2.5)
	_check(absf(t1c["art"][mid].y - t1["art"][mid].y) < 0.5, "after the reset time the next swing is the first way again")
	_check(wv.status_text().contains("first"), "status shows first direction")
	wv.set_aim_angle(0.0)
	wv.on_weapon_state("idle")
	for i in 150:
		wv._process(1.0 / 60.0)
	var gt := wv.picture_grip_tip()
	_check(gt.has("tip") and ((gt["tip"] - gt["grip"]) as Vector2).length() > 40.0 * s, "F1 grip cross + Tip marker found on the sword model (blade %.0f px)" % ((gt["tip"] - gt["grip"]) as Vector2).length())
	# mirror: aiming left flips the aim-frame y of the grip
	wv.on_weapon_state("windup")
	for i in 5:
		wv._process(1.0 / 60.0)
	wv.set_aim_angle(0.0)
	var tip_r: Vector2 = wv.picture_grip_tip()["tip"] - wv.global_position
	var right := (wv.get_node("SwingArt") as Node2D).global_position - wv.global_position
	wv.set_aim_angle(PI)
	var left := (wv.get_node("SwingArt") as Node2D).global_position - wv.global_position
	var tip_l: Vector2 = wv.picture_grip_tip()["tip"] - wv.global_position
	_check(absf(tip_l.x + tip_r.x) < 0.01 and absf(tip_l.y - tip_r.y) < 0.01, "aim left mirrors the blade tip in world")
	_check(absf(left.x + right.x) < 0.01 and absf(left.y - right.y) < 0.01, "aim left mirrors (%s -> %s)" % [right, left])
	wv.on_weapon_state("idle")
	# gameplay identical with motion = null
	var motion := w.swing_motion
	w.swing_motion = null
	wv.set_weapon(w)
	_check(wv.get_node("SwingArt").visible == false, "motion = null hides SwingArt")
	hb = wv.get_model().get_node("Hitbox") as Hitbox
	wv.get_model().get_node("Art").visible = true
	# _run reads SwingArt; with no motion it only keeps the hit-side traces
	var t0 := _run_hit_only(wv, hb)
	w.swing_motion = motion
	wv.set_weapon(w)
	hb = wv.get_model().get_node("Hitbox") as Hitbox
	var t2 := _run_hit_only(wv, hb)
	_check(str(t0["pivot"]) == str(t2["pivot"]), "SwingPivot pose per step identical")
	_check(str(t0["shape"]) == str(t2["shape"]), "Hitbox shape transform per step identical")
	_check(str(t0["poses"]) == str(t2["poses"]), "swept hit poses identical (%d steps)" % t0["poses"].size())
	print("natural swing: %d failures" % _fail)
	quit(1 if _fail > 0 else 0)

func _run_hit_only(wv: WeaponVisual, hb: Hitbox) -> Dictionary:
	wv.set_aim_angle(0.3)
	var tr := {"pivot": [], "shape": [], "poses": []}
	for st in ["windup", "active", "recovery"]:
		wv.on_weapon_state(st)
		var dur: float = {"windup": wv.weapon.windup, "active": wv.weapon.active, "recovery": wv.weapon.recovery}[st]
		for i in ceili(dur / (1.0 / 60.0)):
			wv._process(1.0 / 60.0)
			var pv := wv.get_node("SwingPivot") as Node2D
			tr["pivot"].append([pv.position, pv.rotation])
			tr["shape"].append((hb.get_child(0) as Node2D).global_transform)
			if st == "active":
				tr["poses"].append(hb.arc_poses(12).map(func(p): return p[1]))
	wv.on_weapon_state("idle")
	for i in 30:
		wv._process(1.0 / 60.0)
	return tr
