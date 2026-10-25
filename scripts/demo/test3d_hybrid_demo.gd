extends Node2D
## Round 4 of the "3D -> pixel sprite" test. Standalone: the game's own scripts/scenes are only INSTANCED, never edited.
## Hybrid = 3D-rendered BODY (3 rows: S front, E 3/4 front [flip for W], N back) + the game's real 2D hands/weapon
## (WeaponVisual + SwingFx + HandsVisual, wired exactly like scenes/player.tscn / player.gd).
## Next to it: the REAL player sprite with the SAME weapon nodes, aiming and swinging in sync.
##   user args:  --static   frozen idle pose, camera 4x, used for hybrid_compare_4x.png

const GRASS := "res://assets/map/Floors_Tiles.png"
const PLAYER_FRAMES := "res://assets/characters/player/player_frames.tres"
const SHEETS := "res://assets/characters/player/3d/"
const SWORD := "res://data/weapons/sword.tres"
const WeaponVisualS := preload("res://scripts/visual/weapon_visual.gd")
const SwingFxS := preload("res://scripts/visual/swing_fx.gd")
const HandsS := preload("res://scripts/visual/hands_visual.gd")
@export var zoom := 2.0
@export var walk_speed := 90.0
@export var sprite_scale := 2.0
## Measured against the real player at 4x: the real feet sit ~3.5 px below the actor origin (matches its shadow at +4).
@export var feet_y := 3.5
@export var swing_period := 1.3
@export var aim_speed := 1.6          # rad/s the aim point circles the actor
@export var aim_radius := 70.0
@export var duration := 14.0

class Actor:
	var root: Node2D
	var wv: Node2D
	var hands: Node2D
	var fx: Node2D
	var aim_t := 0.0
	var phase := "idle"
	var phase_t := 0.0

var _info := {}
var _sheets := {}
var _static := false
var _clock := 0.0
var _c := Vector2(576, 330)
var _weapon: WeaponData
var _hy: Actor
var _rp: Actor
var _twin: Sprite2D
var _anim := "idle"
var _t := 0.0
var _row := 0
var _flip := false
var _path: Array[Vector2] = []
var _leg := 0
var _special := ""         # "hit" / "roll" one-shots
var _special_t := -1.0
var _labels := {}
var _cam: Camera2D
var _swing_clock := 0.0

func _ready() -> void:
	_static = "--static" in OS.get_cmdline_user_args()
	if _static: zoom = 4.0
	_info = JSON.parse_string(FileAccess.get_file_as_string(SHEETS + "sheet_info.json"))
	for a in _info["actions"]:
		_sheets[a] = load(SHEETS + a + ".png")
	_weapon = load(SWORD)
	_build_ground()
	var home := _c + Vector2(-70, -10)
	_path = [home + Vector2(0, -35), home + Vector2(0, 40), home + Vector2(110, 40), home + Vector2(0, 40), home + Vector2(0, -35)]
	if _static:
		home = _c + Vector2(-40, 0)
	_hy = _make_actor(home if _static else _path[0])
	_twin = Sprite2D.new()
	_twin.texture = _sheets["idle"]
	_twin.vframes = 2
	_twin.hframes = _info["actions"]["idle"]["frames"]
	_twin.scale = Vector2.ONE * sprite_scale
	_twin.offset = Vector2(0, -float(_info["feet_below_cell_centre_px"]))
	_twin.position = Vector2(0, feet_y)
	_hy.root.add_child(_twin)
	_hy.root.move_child(_twin, 0)
	_rp = _make_actor(_c + (Vector2(40, 0) if _static else Vector2(190, 25)))
	var body := AnimatedSprite2D.new()
	body.sprite_frames = load(PLAYER_FRAMES)
	body.animation = &"idle"
	body.scale = Vector2(2, 2)
	body.position = Vector2(0, -19)
	if not _static: body.play()
	_rp.root.add_child(body)
	_rp.root.move_child(body, 0)
	_cam = Camera2D.new()
	_cam.position = _c
	_cam.zoom = Vector2.ONE * zoom
	add_child(_cam)
	var cl := CanvasLayer.new()
	add_child(cl)
	for k in ["3D body + 2D hands/weapon", "real player"]:
		var l := Label.new()
		l.text = k
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 6)
		cl.add_child(l)
		_labels[k] = l

## Same composition as scenes/player.tscn: WeaponVisual (with SwingPivot + SwingFx) and Hands, both at (0,-9).
func _make_actor(at: Vector2) -> Actor:
	var a := Actor.new()
	a.root = Node2D.new()
	a.root.position = at
	add_child(a.root)
	a.wv = WeaponVisualS.new()
	a.wv.position = Vector2(0, -9)
	var pivot := Node2D.new()
	pivot.name = "SwingPivot"
	pivot.position = Vector2(6, 15)
	pivot.rotation = -PI / 2
	a.wv.add_child(pivot)
	a.fx = SwingFxS.new()
	a.fx.name = "SwingFx"
	a.wv.add_child(a.fx)
	a.root.add_child(a.wv)
	a.hands = HandsS.new()
	a.hands.position = Vector2(0, -9)
	a.hands.fill_color = Color(0.91, 0.584, 0.561, 1)
	a.hands.outline_color = Color(0.227, 0.063, 0.125, 1)
	a.root.add_child(a.hands)
	a.fx.set_weapon(_weapon)
	a.wv.set_weapon(_weapon)
	a.wv.model_changed.connect(a.fx.bind_model)
	a.fx.bind_model(a.wv.get_model())
	a.wv.model_changed.connect(a.hands.bind_model)
	a.hands.bind_model(a.wv.get_model())
	# SwingFx draws the crescent from Hitbox.arc_poses(), which needs hitbox.weapon (WeaponHolder normally sets it).
	var hb = a.wv.get_model().get_node_or_null("Hitbox")
	if hb: hb.set("weapon", _weapon)
	return a

func _build_ground() -> void:
	var tex: Texture2D = load(GRASS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in range(0, 22):
		for x in range(0, 37):
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.region_enabled = true
			sp.region_rect = Rect2(16 * (1 + rng.randi() % 3), 160, 16, 16)
			sp.centered = false
			sp.scale = Vector2(2, 2)
			sp.position = Vector2(x * 32, y * 32)
			sp.z_index = -10
			add_child(sp)

func _draw() -> void:
	for a in [_hy, _rp]:
		draw_set_transform(a.root.global_position + Vector2(0, 4), 0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, 14, Color(0, 0, 0, 0.45))

func _set_anim(a: String) -> void:
	if a == _anim: return
	_anim = a
	_t = 0.0
	_twin.texture = _sheets[a]
	_twin.hframes = _info["actions"][a]["frames"]

func _frame_at(a: String, t: float, loop: bool) -> int:
	var holds: Array = _info["actions"][a]["hold_ms"]
	var total := 0.0
	for h in holds: total += h
	var ms := t * 1000.0
	if loop: ms = fmod(ms, total)
	var acc := 0.0
	for i in holds.size():
		acc += holds[i]
		if ms < acc: return i
	return holds.size() - 1

func _total_s(a: String) -> float:
	var s := 0.0
	for h in _info["actions"][a]["hold_ms"]: s += h
	return s / 1000.0

## Drives WeaponVisual/SwingFx exactly like player.gd does: aim every frame, state strings from the holder.
func _drive(a: Actor, delta: float, swinging_allowed: bool) -> void:
	a.aim_t += delta * aim_speed
	var target := a.root.global_position + Vector2(0, -9) + Vector2(cos(a.aim_t), sin(a.aim_t)) * aim_radius
	var ang := (target - (a.root.global_position + Vector2(0, -9))).angle()
	a.wv.set_aim_angle(ang)
	a.hands.set_aim_angle(ang)
	a.phase_t += delta
	var next := a.phase
	match a.phase:
		"windup": if a.phase_t >= _weapon.windup: next = "active"
		"active": if a.phase_t >= _weapon.active: next = "recovery"
		"recovery": if a.phase_t >= _weapon.recovery: next = "idle"
	if a.phase == "idle" and swinging_allowed and _swing_clock >= swing_period:
		next = "windup"
	if next != a.phase:
		a.phase = next
		a.phase_t = 0.0
		a.wv.on_weapon_state(next)
		a.fx.on_weapon_state(next)

func _place_labels() -> void:
	var scr := get_viewport_rect().size
	for k in _labels:
		var act: Actor = _hy if k.begins_with("3D") else _rp
		var l: Label = _labels[k]
		var p := (act.root.global_position + Vector2(0, -75) - _cam.position) * zoom + scr * 0.5
		var w := l.get_minimum_size().x
		l.position = Vector2(clampf(p.x - w * 0.5, 16, scr.x - w - 16), clampf(p.y, 16, scr.y - 40))

func _process(delta: float) -> void:
	if _static:
		_place_labels()
		if _clock == 0.0:
			_drive(_hy, 0.0, false); _drive(_rp, 0.0, false)
			_hy.aim_t = 0.3; _rp.aim_t = 0.3
		_clock += delta
		for a in [_hy, _rp]:
			a.wv.set_aim_angle(0.3); a.hands.set_aim_angle(0.3)
		_twin.frame = 0
		queue_redraw()
		if _clock > 0.2: get_tree().quit()
		return
	_clock += delta
	_swing_clock += delta
	var moving := false
	if _clock > 1.0 and _leg < _path.size() - 1 and _special == "":
		var target := _path[_leg + 1]
		var d := target - _hy.root.position
		var step := walk_speed * delta
		if d.length() <= step:
			_hy.root.position = target
			_leg += 1
		else:
			_hy.root.position += d.normalized() * step
		if absf(d.x) > absf(d.y):
			_row = 1
			_flip = d.x < 0
		elif d.y > 0:
			_row = 0
			_flip = false
		else:
			_row = 1               # up: no back sprite, keep the side view (and its flip)
		moving = _leg < _path.size() - 1
	_hy.root.position = _hy.root.position.round()
	if _clock > 6.0 and _special_t < 0.0 and _clock < 6.2:
		_special = "hit"; _special_t = 0.0; _row = 0; _flip = false
	if _special != "":
		_special_t += delta
		if _special_t > _total_s(_special) + 0.25:
			_special = ""
			_row = 0
	_set_anim(_special if _special != "" else ("run" if moving else "idle"))
	_t += delta
	var f := _frame_at(_anim, _t, _anim == "idle" or _anim == "run")
	_twin.flip_h = _flip
	_twin.frame = _row * int(_info["actions"][_anim]["frames"]) + f
	_drive(_hy, delta, _clock > 1.4)
	_drive(_rp, delta, _clock > 1.4)
	if _swing_clock >= swing_period and _hy.phase != "idle": _swing_clock = 0.0
	_place_labels()
	queue_redraw()
	if _clock >= duration:
		get_tree().quit()
