extends SceneTree
# Pure hit-feel maths: shake and hit-stop (decision 0023). No arena needed.
var _ok := true
func check(name: String, cond: bool) -> void:
	print("%s: %s" % [name, "ok" if cond else "FAIL"])
	if not cond:
		_ok = false

func _init():
	# --- trauma shake ---
	var sh := CameraShake.new()
	sh.max_offset = 8.0
	sh.add_trauma(1.0)
	var worst := 0.0
	var t := 0.0
	while sh.trauma > 0.0 and t < 10.0:
		worst = maxf(worst, sh.advance(1.0 / 60.0).length())
		t += 1.0 / 60.0
	check("trauma decays to 0 (took %.2fs)" % t, sh.trauma == 0.0 and t < 2.0)
	check("offset back to 0 at the end", sh.offset == Vector2.ZERO)
	check("offset stays within max_offset (worst %.2f of 8)" % worst, worst <= sh.max_offset + 0.0001 and worst > 0.5)
	sh.add_trauma(1.0)
	sh.shake_strength = 0.0
	var off := Vector2.ZERO
	for i in 30:
		off += sh.advance(1.0 / 60.0).abs()
	check("strength 0 gives offset 0", off == Vector2.ZERO)
	var weak := CameraShake.new()
	weak.add_trauma(0.2)
	var big := CameraShake.new()
	big.add_trauma(0.8)
	check("small trauma shakes far less than big (squared)", weak.advance(0.1).length() < big.advance(0.1).length() * 0.2)

	# --- hit-stop ---
	var hs := HitStop.new()
	root.add_child(hs)
	await process_frame
	Engine.time_scale = 0.25   # F2 slow-mo is on
	hs.request(3)
	check("stop dips time_scale", Engine.time_scale < 0.01 and hs.is_active())
	hs.request(8)
	hs.request(2)
	check("overlap: longest wins, not the sum (8f)", hs.frames_left() == 8)
	hs.request(100)
	check("cap: never longer than max_frames (12)", hs.frames_left() == 12)
	var guard := 0
	while hs.is_active() and guard < 100000:
		await process_frame
		guard += 1
	check("stop ended", not hs.is_active())
	check("time_scale back to the previous 0.25 (F2 survives)", is_equal_approx(Engine.time_scale, 0.25))
	Engine.time_scale = 1.0
	hs.request(2)
	while hs.is_active():
		await process_frame
	check("time_scale back to 1.0", is_equal_approx(Engine.time_scale, 1.0))
	hs.hitstop_scale = 0.0
	hs.request(5)
	check("hitstop_scale 0 = no stop", not hs.is_active() and Engine.time_scale == 1.0)
	hs.hitstop_scale = 1.0
	# kill: freeze, then slow-mo, then back
	hs.request(2, 0.3, 0.05)
	while hs.frames_left() > 0:
		await process_frame
	check("after the freeze: slow-mo 0.3", is_equal_approx(Engine.time_scale, 0.3))
	while hs.is_active():
		await process_frame
	check("slow-mo restores 1.0", is_equal_approx(Engine.time_scale, 1.0))
	hs.request(10)
	hs.queue_free()
	await process_frame
	check("freeing the node mid-stop restores time_scale", is_equal_approx(Engine.time_scale, 1.0))
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
