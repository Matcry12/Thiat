extends Node2D
## Round 3 of the "3D -> pixel sprite" test. Standalone: touches no player/combat code.
## The 3D twin of the player (3 views: S front, E side, N back; W = E flipped, like the player's flip_h)
## walks a rectangle using only 4 directions, slashes in each, next to the REAL player sprite.

const GRASS := "res://assets/game/map/Floors_Tiles.png"
const PLAYER_FRAMES := "res://assets/dev/characters/player/player_frames.tres"
const SHEETS := "res://assets/dev/characters/test3d_chibi/"
@export var run_speed := 140.0
@export var half_w := 150.0
@export var half_h := 65.0
@export var sprite_scale := 2.0
@export var walk_from := 1.0
@export var slash_times := [8.2, 9.6, 11.0, 12.4]   # down, right, up, left
@export var duration := 14.0

var _info := {}
var _sheets := {}
var _twin: Sprite2D
var _anim := "idle"
var _t := 0.0           # seconds inside the current animation
var _row := 0           # 0 S, 1 E, 2 N
var _flip := false
var _clock := 0.0
var _center := Vector2(576, 330)
var _path: Array[Vector2] = []
var _leg := 0
var _player_pos := Vector2.ZERO
var _origin := Vector2.ZERO

func _ready() -> void:
	_info = JSON.parse_string(FileAccess.get_file_as_string(SHEETS + "sheet_info.json"))
	for a in _info["actions"]:
		_sheets[a] = load(SHEETS + a + ".png")
	_build_ground()
	_origin = _center + Vector2(-110, 10)
	_path = [_origin + Vector2(-half_w, -half_h), _origin + Vector2(half_w, -half_h),
		_origin + Vector2(half_w, half_h), _origin + Vector2(-half_w, half_h), _origin + Vector2(-half_w, -half_h)]
	_twin = Sprite2D.new()
	_twin.texture = _sheets["idle"]
	_twin.vframes = 3
	_twin.hframes = _info["actions"]["idle"]["frames"]
	_twin.scale = Vector2.ONE * sprite_scale
	_twin.offset = Vector2(0, -float(_info["feet_below_cell_centre_px"]))
	_twin.position = _path[0]
	_twin.z_index = 1
	add_child(_twin)
	_player_pos = _center + Vector2(320, 10)
	var p := AnimatedSprite2D.new()
	p.sprite_frames = load(PLAYER_FRAMES)
	p.animation = &"idle"
	p.play()
	p.scale = Vector2(2, 2)
	p.position = _player_pos + Vector2(0, -19)
	p.z_index = 1
	add_child(p)
	_label("3D twin", _center + Vector2(-110, -150))
	_label("real player", _player_pos + Vector2(0, -85))
	var cam := Camera2D.new()
	cam.position = _center
	add_child(cam)

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

## Centred on `at`, clamped inside the 1152x648 frame so it never gets cut off.
func _label(s: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	var w := l.get_minimum_size().x
	var view := get_viewport_rect().size
	var tl := _center - view * 0.5
	var x := clampf(at.x - w * 0.5, tl.x + 16, tl.x + view.x - w - 16)
	l.position = Vector2(x, clampf(at.y, tl.y + 16, tl.y + view.y - 40))

func _draw() -> void:
	for p in [_twin.position, _player_pos]:
		draw_set_transform(p + Vector2(0, 2), 0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, 14, Color(0, 0, 0, 0.45))

func _set_anim(a: String) -> void:
	if a == _anim: return
	_anim = a
	_t = 0.0
	_twin.texture = _sheets[a]
	_twin.hframes = _info["actions"][a]["frames"]

## Which frame of `a` is showing after `t` seconds, using per-frame hold times (ms). One-shots stay on the last frame.
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

func _process(delta: float) -> void:
	_clock += delta
	var moving := false
	if _clock > walk_from and _leg < _path.size() - 1:
		var target := _path[_leg + 1]
		var d := target - _twin.position
		var step := run_speed * delta
		if d.length() <= step:
			_twin.position = target
			_leg += 1
		else:
			_twin.position += d.normalized() * step
		# only 4 directions: down / right / up / left (left = the side row, flipped)
		if absf(d.x) > absf(d.y):
			_row = 1
			_flip = d.x < 0
		else:
			_row = 0 if d.y > 0 else 2
			_flip = false
		moving = _leg < _path.size() - 1
	var slashing := false
	for i in slash_times.size():
		var len_s := 0.0
		for h in _info["actions"]["slash"]["hold_ms"]: len_s += h
		len_s /= 1000.0
		if _clock >= slash_times[i] and _clock < slash_times[i] + len_s:
			slashing = true
			_row = [0, 1, 2, 1][i]
			_flip = i == 3
			if _anim != "slash": _t = 0.0
	_set_anim("slash" if slashing else ("run" if moving else "idle"))
	_t += delta
	var f := _frame_at(_anim, _t, _anim != "slash")
	_twin.flip_h = _flip
	_twin.frame = _row * int(_info["actions"][_anim]["frames"]) + f
	queue_redraw()
	if _clock >= duration:
		get_tree().quit()
