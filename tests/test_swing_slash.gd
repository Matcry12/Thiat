extends SceneTree
# Drawn slash "P3" (0049 addendum): hidden until the blade has swept f1's span, newest end on the blade while active,
# frozen after active while the sword goes back, gone after the fade; mirrored swings land on the mirrored side.
var _fail := 0

func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fail += 1

## Newest end of the slash on screen (world angle, deg) from its node transform and the frame's head angle.
func _head_world(wv: WeaponVisual, sl: SwingSlash, m: SwingMotion, frame: int) -> float:
	var local := Vector2.from_angle(deg_to_rad(m.head_deg(frame)))   # art direction of the newest end
	var v := sl.get_global_transform().basis_xform(local)
	return rad_to_deg(v.angle())

func _blade_world(wv: WeaponVisual) -> float:
	var art := wv.get_node("SwingArt") as Node2D
	return rad_to_deg(art.get_global_transform().basis_xform(Vector2.RIGHT).angle())

var _hflip := 1.0   # what WeaponHolder would have decided (0050: the holder owns the side, the picture follows)
var _since := 99.0

func _swing(wv: WeaponVisual, aim: float) -> Dictionary:
	wv.set_aim_angle(aim)
	var m := wv.weapon.swing_motion
	_hflip = m.next_flip(_hflip, _since)
	_since = 0.1
	wv.set_swing_flip(_hflip)
	var sl := wv.slash
	var r := {"hidden_early": true, "seen_f1": false, "err": 0.0, "frozen_ok": true, "blade_moved": 0.0, "hidden_after": false, "side": 0.0}
	var dt := 1.0 / 60.0
	wv.on_weapon_state("windup")
	for i in ceili(wv.weapon.windup / dt):
		wv._process(dt)
		if sl.visible: r["hidden_early"] = false
	wv.on_weapon_state("active")
	var first_vis := -1.0
	for i in ceili(wv.weapon.active / dt):
		wv._process(dt)
		if sl.visible:
			if first_vis < 0.0: first_vis = float(i)
			var frame := 0 if sl.status() == "f1" else 1
			r["err"] = maxf(r["err"], absf(wrapf(_head_world(wv, sl, m, frame) - _blade_world(wv), -180.0, 180.0)))
			r["side"] = sl.global_position.y
	r["first_vis"] = first_vis
	r["end_pos"] = sl.position
	wv.on_weapon_state("recovery")
	var blade0 := _blade_world(wv)
	var fade_frames := ceili(m.slash_fade_time / dt)
	for i in ceili(wv.weapon.recovery / dt):
		wv._process(dt)
		if i < fade_frames - 2:
			if not sl.visible or sl.position != r["end_pos"]: r["frozen_ok"] = false
		r["blade_moved"] = maxf(r["blade_moved"], absf(wrapf(_blade_world(wv) - blade0, -180.0, 180.0)))
	r["hidden_after"] = not sl.visible
	wv.on_weapon_state("idle")
	for i in 20: wv._process(dt)
	return r

## Ribbon: outer edge on the blade tip, never before the active start, frozen after active, gone after the fade, mirrored OK, aim left OK.
func _ribbon_swing(wv: WeaponVisual, aim: float) -> Dictionary:
	wv.set_aim_angle(aim)
	var m := wv.weapon.swing_motion
	_hflip = m.next_flip(_hflip, _since)
	_since = 0.1
	wv.set_swing_flip(_hflip)
	var rb := wv.ribbon
	var r := {"seen": false, "err": 0.0, "tail_ok": true, "frozen": true, "hidden_after": false, "side": 0.0, "rest_hidden": true}
	var dt := 1.0 / 60.0
	wv.on_weapon_state("windup")
	for i in ceili(wv.weapon.windup / dt):
		wv._process(dt)
		if rb.visible: r["rest_hidden"] = false
	wv.on_weapon_state("active")
	var last := Vector2.INF
	for i in ceili(wv.weapon.active / dt):
		wv._process(dt)
		if rb.visible:
			r["seen"] = true
			var tip: Vector2 = wv.picture_grip_tip()["tip"]
			r["err"] = maxf(r["err"], rb.head_outer().distance_to(tip))
			if rb.tail_t() < 0.0: r["tail_ok"] = false
			last = rb.head_outer()
			r["side"] = rb.to_local(tip).y
	wv.on_weapon_state("recovery")
	var fade_frames := ceili(m.slash_fade_time / dt)
	for i in ceili(wv.weapon.recovery / dt):
		wv._process(dt)
		if i < fade_frames - 2 and (not rb.visible or rb.head_outer().distance_to(last) > 0.01): r["frozen"] = false
	r["hidden_after"] = not rb.visible
	wv.on_weapon_state("idle")
	for i in 20: wv._process(dt)
	return r

func _ribbon_checks(wv: WeaponVisual, m: SwingMotion) -> void:
	_check(wv.ribbon != null and not wv.ribbon.visible, "ribbon node exists, hidden at rest")
	_hflip = 1.0
	_since = 99.0
	var a := _ribbon_swing(wv, 0.0)
	_check(a["rest_hidden"], "ribbon: hidden during windup")
	_check(a["seen"] and a["err"] < 2.0, "ribbon: outer edge within 2 px of the blade tip while active (max %.2f)" % a["err"])
	_check(a["tail_ok"], "ribbon: tail never before the active start")
	_check(a["frozen"], "ribbon: frozen after active (no swing back)")
	_check(a["hidden_after"], "ribbon: hidden after the fade")
	var b := _ribbon_swing(wv, 0.0)
	_check(wv._flip < 0.0 and b["err"] < 2.0, "ribbon mirrored: tip match (max %.2f)" % b["err"])
	_check(signf(b["side"]) != signf(a["side"]), "ribbon mirrored: on the other side (%.0f vs %.0f)" % [a["side"], b["side"]])
	var c := _ribbon_swing(wv, PI)
	_check(c["err"] < 2.0, "ribbon aim left: tip match (max %.2f)" % c["err"])
	var cov := wv.ribbon.tail_t()
	m.ribbon_tail_deg = 50.0
	var d := _ribbon_swing(wv, 0.0)
	_check(d["err"] < 2.0 and d["tail_ok"], "ribbon tail_deg 50: still on the blade")
	m.ribbon_tail_deg = 110.0
	m.slash_mode = "sprite"
	var e := _ribbon_swing(wv, 0.0)
	_check(not e["seen"], "sprite mode: ribbon never shown")
	m.slash_mode = "ribbon"
	_hflip = 1.0

func _init():
	for p in ["wooden_sword", "copper_sword"]:
		var w := load("res://data/weapons/%s.tres" % p) as WeaponData
		_check(is_equal_approx(w.active, 0.2) and is_equal_approx(w.recovery, 0.32), "%s active 0.2 / recovery 0.32" % p)
	var player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	wv.set_process(false)
	wv._process(1.0 / 60.0)
	var m := wv.weapon.swing_motion
	_check(m.slash_mode == "ribbon" and m.top_lift_px == 40.0, "sword default: ribbon mode, top lift 40")
	await _ribbon_checks(wv, m)
	_hflip = 1.0
	_since = 99.0
	for i in 60: wv._process(1.0 / 60.0)
	m.slash_mode = "sprite"
	_check(not m.smear_on and not m.ghost_copies_on, "code smear + sword copies are off by default")
	_check(wv.slash != null and not wv.slash.visible, "slash node exists, hidden at rest")
	var a := _swing(wv, 0.0)
	_check(a["hidden_early"], "hidden during windup")
	_check(a["first_vis"] > 3.0, "not visible at active start (first at frame %d)" % int(a["first_vis"]))
	_check(a["err"] < 3.0, "newest end within 3 deg of the blade while active (max %.2f)" % a["err"])
	_check(a["frozen_ok"], "frozen during recovery (transform unchanged)")
	_check(a["blade_moved"] > 20.0, "...while the blade moves back (%.0f deg)" % a["blade_moved"])
	_check(a["hidden_after"], "hidden after the fade")
	var b := _swing(wv, 0.0)    # second swing in a row = mirrored (alternate)
	_check(wv._flip < 0.0, "second swing is the reversed one")
	_check(b["err"] < 3.0, "mirrored: newest end within 3 deg of the blade (max %.2f)" % b["err"])
	_check(signf(b["end_pos"].y) == -signf(a["end_pos"].y) and absf(b["end_pos"].y) > 1.0, "mirrored: slash sits on the other side of the aim line")
	var c := _swing(wv, PI)     # aim left (WeaponVisual mirrors itself), alternate again -> first way
	_check(c["err"] < 3.0, "aim left: newest end within 3 deg of the blade (max %.2f)" % c["err"])
	m.slash_on = false
	var d := _swing(wv, 0.0)
	m.slash_mode = "ribbon"   # test resource is shared: restore
	_check(d["first_vis"] < 0.0, "slash_on = false: never shown")
	print("slash test: %d failed" % _fail)
	quit(1 if _fail > 0 else 0)
