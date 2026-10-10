extends SceneTree
# Boss bar: hidden until the boss wakes (engaged), fades in, phase 2 changes the fill colour + flashes,
# hides on return / after defeat (delay), sits bottom centre without touching the bottom-left block or the
# F3 tuning panel; looks + marker height come from the skin.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _until(cond: Callable) -> void:   # states, not frame counts: frames vary under load
	var n := 0
	while not cond.call() and n < 400:
		await process_frame
		n += 1

func _init() -> void:
	var screen := SubViewport.new()
	screen.size = Vector2i(1152, 648)
	root.add_child(screen)
	var arena = load("res://scenes/arena.tscn").instantiate()
	screen.add_child(arena)
	var boss: Boss = arena.get_node("Boss")
	boss.passive = true
	boss.set_physics_process(false)   # we drive aggro by hand
	await process_frame
	boss._set_aggro(Boss.Aggro.IDLE)
	var hud: HUD = arena.get_node("HUD")
	var bar: BossBar = hud._boss_bar
	var sk: InventorySkin = bar.get_skin()
	sk.boss_fade_time = 0.05
	sk.boss_hide_delay = 30.0
	await _frames(4)
	_check(bar != null and not bar.visible, "boss asleep: no bar on screen")

	boss._set_aggro(Boss.Aggro.ENGAGED)
	await _until(func(): return bar.modulate.a >= 0.99)
	_check(bar.visible and bar.is_awake() and bar.modulate.a >= 0.99, "boss engaged: the bar is shown (faded in)")
	var vw := 1152.0
	var r := bar.get_global_rect()
	_check(absf(r.get_center().x - vw * 0.5) < 1.0 and is_equal_approx(r.size.x, vw * sk.boss_bar_width_fraction), "bottom centre, %.0f%% of the screen wide" % (sk.boss_bar_width_fraction * 100))
	_check(is_equal_approx(r.end.y, 648.0 - hud.margin_y), "above the bottom margin")
	var bl := hud._bottom_left.get_global_rect()
	_check(not r.intersects(bl), "does not touch the health bar or the ability icons")
	_check(bar.size.y == sk.boss_bar_height, "height from the skin")
	sk.boss_bar_height = 32
	await _frames(3)
	_check(bar.size.y == 32 and bar.get_global_rect().size.y == 32, "boss_bar_height follows the skin live (the marker is drawn over the full height)")
	sk.boss_bar_height = 20

	# phase 2
	var c1 := bar.fill_color()
	_check(c1.is_equal_approx(sk.boss_fill_color), "phase 1 colour")
	boss.phase = 2
	boss.phase_changed.emit(2)
	await process_frame
	_check(bar._flash_left > 0.0, "phase 2 starts a flash")
	await create_timer(sk.boss_flash_time + 0.1).timeout
	_check(bar.fill_color().is_equal_approx(sk.boss_phase2_color), "phase 2 fill colour = boss_phase2_color")
	_check(not sk.boss_phase2_color.is_equal_approx(sk.boss_fill_color), "...and it differs from phase 1")

	# a leash reset back to phase 1 must NOT flash
	await _until(func(): return bar._flash_left <= 0.0)
	boss.phase = 1
	boss.phase_changed.emit(1)
	await process_frame
	_check(bar._flash_left == 0.0, "phase 1 again (leash reset): no flash")
	boss.phase = 2
	boss.phase_changed.emit(2)
	await process_frame
	_check(bar._flash_left > 0.0, "entering phase 2 flashes")
	await _until(func(): return bar._flash_left <= 0.0)
	sk.boss_inset = 5
	sk.boss_border_width = 4
	await process_frame
	_check((bar._frame as StyleBoxFlat).border_width_left == 4, "border width comes from the skin")

	# F3 open: the bar keeps out of the tuning panel
	var tp: CanvasLayer = arena.get_node("TuningPanel")
	tp.visible = true
	await _frames(4)
	r = bar.get_global_rect()
	_check(r.end.x <= vw - tp.right_panel_width() and not r.intersects(bl), "F3 open: clear of the tuning panel and the bottom-left block")
	var sp: Control = tp._status_panel
	_check(not r.intersects(sp.get_global_rect()), "F3 open: clear of the status panel")
	tp.visible = false

	# sleep again
	boss.aggro_changed.emit(int(Boss.Aggro.RETURNING))   # the signal only: the real RETURNING walk ends by itself and would race the test
	await _until(func(): return not bar.visible)
	_check(not bar.visible, "boss returning: the bar hides")
	boss.set_physics_process(false)   # something turns it back on (F3 open/close); its own leash would race this test
	boss._set_aggro(Boss.Aggro.ENGAGED)
	await _until(func(): return bar.visible)
	_check(bar.visible, "engaged again: it shows again")
	boss.defeated.emit()
	await process_frame
	_check(bar.visible, "defeated: still there for a moment so the kill reads")
	bar._hide_in = 0.01   # the delay itself is 30 s here; let it run out
	await _until(func(): return not bar.visible)
	_check(not bar.visible, "...then it hides")
	# the one hook the W7 summon can reuse
	bar.set_awake(true)
	await _until(func(): return bar.visible)
	_check(bar.visible, "set_awake(true) shows it without any aggro change")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
