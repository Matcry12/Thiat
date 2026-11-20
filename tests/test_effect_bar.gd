extends SceneTree
# Effect icons on the HUD (decision 0072): follow Effects.active(), badge only for level > 1, red frame for a debuff,
# blink in the last blink_time, null-safe without an Effects node.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _grant(id: String, level: int, secs: float) -> EffectGrant:
	var g := EffectGrant.new()
	g.effect = load("res://data/effects/%s.tres" % id) as EffectData
	g.level = level
	g.duration = secs
	return g

func _init() -> void:
	var arena = await World.make(self)
	var player = arena.get_node("Player")
	var fx: Effects = player.get_node("Effects")
	var hud: HUD = arena.get_node("HUD")
	var bar := hud.effect_bar()
	await _frames(3)
	_check(bar != null and bar.icons().is_empty(), "no effects: no icons")
	_check(hud.debug_children().any(func(c): return c["object"] == bar), "EffectBar is an F3 child of the HUD")
	var w0: float = hud._bottom_left.get_global_rect().end.x
	var boss_x0: float = hud._boss_bar.position.x if hud._boss_bar else 0.0
	fx.apply(_grant("regen", 2, 8.0))
	fx.apply(_grant("sick", 1, 12.0))
	await _frames(3)
	var ic := bar.icons()
	_check(ic.size() == 2, "two icons follow Effects.active()")
	_check(ic[0].data["id"] == &"regen" and ic[1].data["id"] == &"sick", "icons in effect order")
	_check(ic[0].has_badge() and not ic[1].has_badge(), "level badge only for level > 1")
	_check(not ic[0].is_debuff() and ic[1].is_debuff(), "debuff uses the red frame")
	_check(ic[0].data["icon"] != null and ic[1].data["icon"] != null, "both effects carry their icon texture")
	_check(ic[0].tip_text() == "Regeneration II - 8 s" and ic[1].tip_text() == "Sick - 12 s", "tooltips: " + ic[0].tip_text() + " / " + ic[1].tip_text())
	_check(ic[0].timer_text() == "8s" or ic[0].timer_text() == "7s", "timer text " + ic[0].timer_text())
	_check(not ic[0].is_blinking() and not ic[1].is_blinking(), "no blink while time left > blink_time")
	_check(ic[0].position.x < ic[1].position.x and is_equal_approx(ic[1].position.x - ic[0].position.x, bar.pitch_art * bar.get_skin().art_scale), "icons one pitch apart")
	hud._place_boss_bar()
	_check(is_equal_approx(hud._bottom_left.get_global_rect().end.x, w0), "effects do not widen the bottom-left block")
	_check(not hud._boss_bar or is_equal_approx(hud._boss_bar.position.x, boss_x0), "boss bar x unchanged with effects active")
	_check(bar.icons()[0].get_global_rect().position.x >= hud.abilities().slots()[2].get_global_rect().end.x, "icons sit right of the last ability frame")
	# blink: last blink_time seconds
	fx.clear()
	fx.apply(_grant("sick", 1, bar.blink_time - 0.5))
	await _frames(2)
	_check(bar.icons().size() == 1 and bar.icons()[0].is_blinking(), "blinks in the last blink_time")
	bar.blink_hz = 0.0001
	bar._clock = 0.0
	_check(bar.icons()[0].is_dim(), "dim on the dark half of the flash")
	bar._clock = 0.6 / bar.blink_hz
	_check(not bar.icons()[0].is_dim(), "not dim on the light half")
	# expiry removes the icon
	await _frames(int((bar.blink_time + 1.0) * 60.0))
	_check(bar.icons().is_empty(), "icon gone after the effect ends")
	# null-safe
	var lone := EffectBar.new()
	root.add_child(lone)
	lone.bind(null)
	await _frames(2)
	_check(lone.icons().is_empty(), "no Effects node: no icons, no error")
	print("RESULT: ", "PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
