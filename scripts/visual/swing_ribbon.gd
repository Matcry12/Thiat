class_name SwingRibbon
extends Node2D
## The slash trail as a RIBBON (decision 0049 addendum 2): a textured band rebuilt every frame from the REAL blade path
## (SwingMotion.swing_path + screen_shift, the same maths as the picture and the hit sweep), so it always touches the blade.
## Child of WeaponVisual (inherits aim + left mirror). Driven only by tick() / hide_now(); no combat code reaches in.
## Swap note: any node with tick()/hide_now()/status() can replace it. Strip textures: x = along the arc (newest end at x=0), y = inner -> outer.

var _state := "hidden"          ## hidden | live | fading
var _frame := 0
var _fade := 0.0
var _t_head := 0.0              ## path time (0..1 of active) of the blade end of the band
var _t_tail := 0.0
var _n := 0                     ## samples valid in the arrays
var _inner := PackedVector2Array()   ## reused
var _outer := PackedVector2Array()
var _quad := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _uvs := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _cols := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
var _m: SwingMotion
var _tex: Texture2D
var _v := PackedFloat32Array()  ## texture y of the inner edge per sample (outer edge = 1); 0 = whole strip, f4 uses less so its specks stay square
var _u := PackedFloat32Array()  ## texture x (0..1) per sample: degrees behind the blade * ribbon_px_per_deg / strip width
var _cover_deg := 0.0

func _init() -> void:
	name = "SwingRibbon"
	visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func hide_now() -> void:
	_state = "hidden"
	_n = 0
	visible = false

func status() -> String:
	if _state == "hidden":
		return "hidden"
	return "%sf%d %.0f deg" % ["frozen " if _state == "fading" else "", _frame + 1, _cover_deg]

## World position of the blade end of the band (outer edge, newest sample); Vector2.INF when nothing is drawn.
func head_outer() -> Vector2:
	return to_global(_outer[_n - 1]) if _n > 0 and visible else Vector2.INF

## Path time (0..1 of active) the band starts at (never < 0); -1 when hidden.
func tail_t() -> float:
	return _t_tail if _n > 0 and visible else -1.0

## phase = WeaponVisual's phase; t = progress through it; half_deg = half the arc; flip = swing side; s = rig scale; tip = blade end in the art frame (unscaled).
func tick(m: SwingMotion, phase: String, t: float, half_deg: float, flip: float, s: float, tip: Vector2, dt: float) -> void:
	if not m.slash_on or m.slash_mode != "ribbon" or m.ribbon_textures.size() < 4 or tip == Vector2.ZERO:
		hide_now()
		return
	_m = m
	if phase == "active":
		_state = "live"
		_fade = 0.0
		_t_head = t
		_frame = 1 if t >= m.ribbon_f2_at else 0
	elif _state == "live" and phase == "recovery":
		_state = "fading"          # active ended: the band stays on the final path (no swing back), f3 then f4
	elif _state == "fading":
		_fade += dt
	else:
		hide_now()
		return
	var ft := maxf(m.slash_fade_time, 0.001)
	if _state == "fading":
		if _fade >= ft:
			hide_now()
			return
		# hard switch, no crossfade: f3 for the first half, f4 (its sparse pixels do the dissolve) for the second
		_frame = 2 if _fade / ft < 0.5 else 3
	modulate.a = 1.0
	_tex = m.ribbon_textures[_frame]
	_build(m, half_deg, flip, s, tip)
	visible = _n > 1
	queue_redraw()

func _build(m: SwingMotion, half_deg: float, flip: float, s: float, tip: Vector2) -> void:
	var deg_head: float = m.swing_path(_t_head, half_deg, flip)[1]
	# tail = where the blade was ribbon_tail_deg ago, never before the active start (bisection; angle is monotonic)
	_t_tail = 0.0
	if absf(deg_head - float(m.swing_path(0.0, half_deg, flip)[1])) > m.ribbon_tail_deg:
		var lo := 0.0
		var hi := _t_head
		for _k in 14:
			var mid := (lo + hi) * 0.5
			if absf(deg_head - float(m.swing_path(mid, half_deg, flip)[1])) > m.ribbon_tail_deg: lo = mid
			else: hi = mid
		_t_tail = hi
	var steps := m.ribbon_steps
	if _inner.size() != steps + 1:
		_inner.resize(steps + 1)
		_outer.resize(steps + 1)
		_u.resize(steps + 1)
		_v.resize(steps + 1)
	var span := _t_head - _t_tail
	var xf := get_parent().global_transform as Transform2D
	var inv := xf.affine_inverse()
	var tv := tip * s
	var a0 := 0.0
	var a1 := 0.0
	var sph: Array = m.swing_path(_t_head, half_deg, flip)
	var g_head: Vector2 = sph[0] * s + inv.basis_xform(m.screen_shift(xf, float(sph[1])))   # hand now: the band curves around it
	var s0: Array = m.swing_path(0.0, half_deg, flip)
	var g_anchor: Vector2 = g_head.lerp(s0[0] * s + inv.basis_xform(m.screen_shift(xf, float(s0[1]))), 1.0 - m.ribbon_pivot_anchor)   # what the lock pulls toward
	var head_u := pow(0.5, 1.0 / m.ribbon_taper_skew)   # u where the base profile peaks (value 1), so the lift joins smoothly
	var fill := 0.0
	if _state == "live":
		fill = m.ribbon_head_fill * (1.0 - smoothstep(m.ribbon_head_fill_release, 1.0, _t_head)) if m.ribbon_head_fill_release < 1.0 else m.ribbon_head_fill
	var deg_tail: float = m.swing_path(_t_tail, half_deg, flip)[1]
	var tex_w := float(maxi(_tex.get_width(), 1))
	for i in steps + 1:
		var t := _t_head - span * float(steps - i) / steps      # i = 0 tail ... steps = blade now
		var sp: Array = m.swing_path(t, half_deg, flip)
		var deg: float = sp[1]
		var g: Vector2 = sp[0] * s + inv.basis_xform(m.screen_shift(xf, deg))   # same as WeaponVisual's `drawn`
		g = g.lerp(g_anchor, m.ribbon_pivot_lock)
		var dir := tv.rotated(deg_to_rad(deg))
		# crescent taper: thick rounded head (u = 0), point at the tail (u = 1)
		var u := 1.0 - float(i) / steps
		var prof := pow(sin(PI * pow(u, m.ribbon_taper_skew)), m.ribbon_taper_power)
		if u < head_u:   # blade end: lift the profile toward full width (fill eases off late in active, gone in the fade)
			prof = lerpf(prof, 1.0, fill)
		if m.ribbon_tail_taper_deg > 0.0:   # needle point: thickness also falls off by degrees from the tail end
			prof *= pow(clampf(absf(deg - deg_tail) / m.ribbon_tail_taper_deg, 0.0, 1.0), m.ribbon_tail_power)
		_outer[i] = g + dir
		_inner[i] = _outer[i] - dir * (1.0 - m.ribbon_inner) * prof
		# f4 (sparse specks): 1 texel stays 1 texel tall as it is wide, no vertical streaks
		var thick := (1.0 - m.ribbon_inner) * prof * tv.length()
		var texel_px := tv.length() * deg_to_rad(1.0 / m.ribbon_px_per_deg)
		_v[i] = clampf(1.0 - thick / (texel_px * float(_tex.get_height())), 0.0, 1.0) if _frame == 3 else 0.0
		_u[i] = absf(deg_head - deg) * m.ribbon_px_per_deg / tex_w
		if i == 0: a0 = deg
		a1 = deg
	_n = steps + 1
	_cover_deg = absf(a1 - a0)

func _draw() -> void:
	if _n < 2 or _tex == null:
		return
	for i in _n - 1:
		var ua := _u[i + 1]      # sample i+1 is nearer the blade
		var ub := _u[i]
		if ua >= 1.0:            # past the end of the strip: nothing to show
			continue
		ub = minf(ub, 1.0)
		_quad[0] = _inner[i]; _quad[1] = _inner[i + 1]; _quad[2] = _outer[i + 1]; _quad[3] = _outer[i]
		if absf((_quad[2] - _quad[0]).cross(_quad[3] - _quad[1])) < 0.01:
			continue            # zero area (needle tail, or a sliver): Godot cannot triangulate it
		_uvs[0] = Vector2(ub, _v[i]); _uvs[1] = Vector2(ua, _v[i + 1]); _uvs[2] = Vector2(ua, 1.0); _uvs[3] = Vector2(ub, 1.0)
		draw_polygon(_quad, _cols, _uvs, _tex)
