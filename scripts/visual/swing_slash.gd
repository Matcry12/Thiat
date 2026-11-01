class_name SwingSlash
extends Sprite2D
## The drawn slash smear (decision 0049 addendum, "P3"). Child of WeaponVisual (inherits aim + left mirror).
## Driven only by tick() from WeaponVisual; no combat code reaches in. Swap note: any node with tick()/hide_now() can replace it.
## While ACTIVE it sits on the live grip with its NEWEST end on the blade, so it trails behind. At the end of active it FREEZES
## (pos + angle stay) and plays frames 3 then 4 (4 fades out).

const CUT := "shader_type canvas_item;\nuniform float inner_px = 12.0;\nvoid fragment() {\n\tif (length((UV - vec2(0.5)) / TEXTURE_PIXEL_SIZE) < inner_px) { COLOR.a = 0.0; }\n}\n"

var _mat: ShaderMaterial
var _state := "hidden"           ## hidden | live | fading
var _frame := -1
var _fade := 0.0
var _frozen_pos := Vector2.ZERO
var _frozen_deg := 0.0
var _flip := 1.0

func _init() -> void:
	name = "SwingSlash"
	centered = true
	visible = false
	_mat = ShaderMaterial.new()
	_mat.shader = Shader.new()
	_mat.shader.code = CUT
	material = _mat

func hide_now() -> void:
	_state = "hidden"
	_frame = -1
	visible = false

## "hidden", "f1".."f4", or "frozen f3" etc. For the F3 status line.
func status() -> String:
	if _state == "hidden":
		return "hidden"
	return ("frozen " if _state == "fading" else "") + "f%d" % (_frame + 1)

## Called every frame. phase = WeaponVisual's phase; sweep_deg = how far the blade has turned since active started (always >= 0 in the
## swing's own direction); pos/blade_deg = live grip (this node's frame, screen offset included) and blade angle; flip = swing side; art_scale = rig scale.
func tick(m: SwingMotion, phase: String, sweep_deg: float, pos: Vector2, blade_deg: float, flip: float, art_scale: float, dt: float) -> void:
	if not m.slash_on or m.slash_mode != "sprite" or m.slash_textures.size() < 4:
		hide_now()
		return
	_mat.set_shader_parameter("inner_px", m.slash_inner_cut)
	if phase == "active":
		_state = "live"
		_frame = 1 if sweep_deg >= m.slash_show_f2_deg else (0 if sweep_deg >= m.slash_show_f1_deg else -1)
		_frozen_pos = pos
		_frozen_deg = blade_deg
		_flip = flip
		_fade = 0.0
	elif _state == "live" and phase == "recovery":
		_state = "fading"          # active just ended: from here on only f3 / f4
		if not m.slash_freeze_after_active:
			_frozen_pos = pos
			_frozen_deg = blade_deg
	elif _state == "fading":
		_fade += dt
		if not m.slash_freeze_after_active:
			_frozen_pos = pos
			_frozen_deg = blade_deg
	else:
		hide_now()
		return
	if _state == "fading":
		var ft := maxf(m.slash_fade_time, 0.001)
		if _fade >= ft:
			hide_now()
			return
		_frame = 2 if _fade < ft * 0.5 else 3
	if _frame < 0:
		visible = false
		return
	texture = m.slash_textures[_frame]
	visible = true
	scale = Vector2(1.0, _flip) * m.slash_scale * art_scale
	position = _frozen_pos
	rotation = deg_to_rad(_frozen_deg - _flip * m.head_deg(_frame))   # newest end lands on the blade
	var half := m.slash_fade_time * 0.5
	modulate.a = 1.0 if _frame < 3 else clampf(1.0 - (_fade - half) / maxf(half, 0.001), 0.0, 1.0)
