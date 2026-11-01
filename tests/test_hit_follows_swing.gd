extends SceneTree
# Decision 0050: a sword with a SwingMotion hits where its PICTURE's blade passes (not in the old fixed-pivot wedge).
#  - a dummy on the picture's blade (start side and end side) is hit, aim right and left, first way and reversed (alternate)
#  - a dummy inside the OLD wedge but away from the new blade path is not hit
#  - hit_follows_blade = true hits a far-side dummy only after the blade has got there; false hits on the first active frame
#  - the picture and the hit path use the same function (SwingMotion.swing_path)
var _fail := 0
var _holder: WeaponHolder
var _wv: WeaponVisual
var _dummy: Node2D
var _hp: Health
var _hb: Hitbox
var _player_hp: Health

func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fail += 1

func _frames(n: int) -> void:
	for i in n:
		_player_hp.hp = _player_hp.max_hp   # something in the arena chips at the player over a long test; this test is not about that
		await physics_frame

func _park() -> void:
	_dummy.global_position = _wv.global_position + Vector2(900, 900)
	_hp.hp = _hp.max_hp

## Idle long enough that the next swing goes the first way again.
func _reset_side() -> void:
	await _frames(52)

## One swing with the dummy parked. Records the picture's blade during active: [{t, grip, tip}] (world px).
func _record(aim: float, reversed: bool) -> Array:
	await _reset_side()
	_wv.set_aim_angle(aim)
	_park()
	if reversed:
		_holder.try_attack()
		await _until_idle()
	_holder.try_attack()
	var out := []
	var guard := 0
	while _holder.phase != WeaponHolder.Phase.IDLE and guard < 400:
		_player_hp.hp = _player_hp.max_hp
		await physics_frame
		guard += 1
		if _wv._phase == "active":
			var gt := _wv.picture_grip_tip()
			out.append({"t": _wv._t, "grip": gt["grip"], "tip": gt["tip"]})
	return out

func _until_idle() -> void:
	var guard := 0
	while _holder.phase != WeaponHolder.Phase.IDLE and guard < 400:
		await physics_frame
		guard += 1

## Replays the same swing (same side, same aim) with the dummy at `pos`. Returns the active-frame index (0 = first) of the first hit, -1 = no hit.
func _replay(aim: float, reversed: bool, pos: Vector2) -> int:
	await _reset_side()
	_wv.set_aim_angle(aim)
	_park()
	if reversed:
		_holder.try_attack()
		await _until_idle()
		_park()
	_dummy.global_position = pos
	_holder.try_attack()
	var guard := 0
	while _holder.phase != WeaponHolder.Phase.ACTIVE and guard < 400:
		await physics_frame
		guard += 1
	var idx := 0
	while _holder.phase == WeaponHolder.Phase.ACTIVE and guard < 800:
		if _hp.hp < _hp.max_hp:
			break
		await physics_frame
		idx += 1
		guard += 1
	var hit: bool = _hp.hp < _hp.max_hp
	await _until_idle()
	hit = hit or _hp.hp < _hp.max_hp
	return idx if hit else -1

func _pick(rec: Array, t: float) -> Vector2:
	var best: Dictionary = rec[0]
	for r in rec:
		if absf(r["t"] - t) < absf(best["t"] - t):
			best = r
	return (best["grip"] as Vector2).lerp(best["tip"], 0.8)   # 80% along the blade

static func _dist_to_poly(poly: PackedVector2Array, p: Vector2) -> float:
	if Geometry2D.is_point_in_polygon(p, poly):
		return 0.0
	var d := INF
	for i in poly.size():
		d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])))
	return d

func _dist_to_poses(poses: Array, p: Vector2) -> float:
	var d := INF
	for pose in poses:
		d = minf(d, _dist_to_poly(pose[1] * Hitbox.shape_outline(pose[0]), p))
	return d

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	_dummy = arena.get_node("Dummy")
	_dummy.set_physics_process(false)
	_hp = _dummy.get_node("Health")
	player.set_physics_process(false)
	for b in [player, _dummy]:
		var kb = b.get_node_or_null("Knockback")
		if kb: kb.enabled = false
	_holder = player.get_node("WeaponHolder")
	_player_hp = player.get_node("Health")
	_wv = player.get_node("WeaponVisual")
	var w: WeaponData = _wv.weapon
	var m: SwingMotion = w.swing_motion
	w.step_distance = 0.0
	_check(m != null and not w.hit_follows_blade, "sword has a SwingMotion, hit_follows_blade defaults to false")
	_hb = _holder.hitbox
	await _frames(3)

	# the picture and the hit path are one function: the hit shape's blade angle at t equals swing_path's
	var half := w.arc_degrees * 0.5
	for flip in [1.0, -1.0]:
		var a0: Array = m.swing_path(0.0, half, flip)
		var a1: Array = m.swing_path(1.0, half, flip)
		_check(signf(a1[0].y - a0[0].y) == flip, "swing_path flip %+.0f: the grip ends on the %s side" % [flip, "+y" if flip > 0 else "-y"])

	# 1) the picture's blade passes -> hit. Start side and end side, aim right / left, first way / reversed.
	var starts := {}
	for aim in [0.0, PI]:
		for reversed in [false, true]:
			var rec: Array = await _record(aim, reversed)
			_check(rec.size() >= 8, "recorded %d active frames (aim %.0f%s)" % [rec.size(), rad_to_deg(aim), ", reversed" if reversed else ""])
			for t in [0.12, 0.88]:
				var pos := _pick(rec, t)
				var at := await _replay(aim, reversed, pos)
				_check(at >= 0, "blade at t=%.2f hits (aim %.0f%s)  first hit at active frame %d" % [t, rad_to_deg(aim), ", reversed" if reversed else "", at])
				if t < 0.2:
					starts["%d%s" % [roundi(rad_to_deg(aim)), reversed]] = _wv.global_transform.affine_inverse() * pos
	# mirrored places: the start side of the reversed swing is on the other side of the aim line
	_check(signf(starts["0false"].y) == -signf(starts["0true"].y), "reversed swing starts on the other side of the aim line (y %.0f vs %.0f)" % [starts["0false"].y, starts["0true"].y])
	_check(signf(starts["180false"].y) == -signf(starts["180true"].y), "...also when aiming left")

	# 2) inside the OLD wedge, away from the new blade path -> no hit
	_wv.set_aim_angle(0.0)
	await _frames(3)
	var old_poses := _hb.arc_poses(24)
	var new_poses := _hb.motion_poses(0.0, 1.0, 48)
	_check(old_poses.size() > 0 and new_poses.size() > 0, "both pose sets exist (old %d, new %d)" % [old_poses.size(), new_poses.size()])
	# 0050 follow-up: the hit shape now runs from the grip along the blade, so it covers the whole old wedge (nothing in the wedge is
	# >17 px from the new path any more). The "away from the path" dummy is now a point BEHIND the player, far from both.
	var pick: Vector2 = _wv.global_transform * Vector2(-70, 0)
	var best := _dist_to_poses(new_poses, pick)
	_check(best > 30.0, "found a point %.0f px away from the new blade path (behind the player)" % best)
	var at_old := await _replay(0.0, false, pick)
	_check(at_old == -1, "dummy away from the new blade path is NOT hit")

	# 3) timing: snap hits on the first active frame, hit_follows_blade only when the blade gets there
	var rec: Array = await _record(0.0, false)
	var late := _pick(rec, 0.9)
	var snap := await _replay(0.0, false, late)
	_check(snap == 0, "snap (hit_follows_blade false): far-side dummy hit on the first active frame (%d)" % snap)
	w.hit_follows_blade = true
	var prog := await _replay(0.0, false, late)
	_check(prog >= 6, "hit_follows_blade: far-side dummy hit only later in active (frame %d of 12)" % prog)
	var early := _pick(rec, 0.1)
	var prog_early := await _replay(0.0, false, early)
	_check(prog_early >= 0 and prog_early <= 3, "hit_follows_blade: start-side dummy hit early (frame %d)" % prog_early)
	var prog_old := await _replay(0.0, false, pick)
	_check(prog_old == -1, "hit_follows_blade: the old-wedge-only dummy is still not hit")
	w.hit_follows_blade = false

	print("hit follows swing: %d failures" % _fail)
	quit(1 if _fail > 0 else 0)
