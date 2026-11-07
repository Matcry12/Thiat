extends Node2D
## Round 2 of the "3D -> pixel sprite" test. Standalone, touches no player/combat code.
## Chibi (walks the circle, slashes) | old knight (idle) | current player, on the real grass tile.

const GRASS := "res://assets/game/map/Floors_Tiles.png"
const PLAYER_FRAMES := "res://assets/dev/characters/player/player_frames.tres"
@export var chibi_dir := "res://assets/dev/characters/test3d_chibi/"
@export var knight_dir := "res://assets/dev/characters/test3d/"
@export var chibi_cell := 48
@export var frame_counts := {"idle": 4, "run": 8, "slash": 6}
@export var fps := {"idle": 5.0, "run": 12.0, "slash": 14.0}
@export var run_speed := 150.0
@export var circle_radius := 110.0
@export var sprite_scale := 2.0
## Feet sit this far below the cell centre (render camera: 0.72 u * sin(40 deg) * 17 ppu).
@export var chibi_feet_offset := 7.9
@export var knight_feet_offset := 11.5
@export var walk_from := 1.0
@export var walk_to := 7.5
@export var slash_times := [8.6, 10.1, 11.6]
@export var slash_rows := [0, 2, 4]
@export var slash_len := 0.45
@export var duration := 14.0

var _chibi: Sprite2D
var _anim := "idle"
var _t := 0.0
var _row := 0
var _angle := PI * 0.5
var _clock := 0.0
var _sheets := {}
var _center := Vector2(576, 330)
var _knight: Sprite2D
var _kt := 0.0

func _ready() -> void:
	_build_ground()
	for a in frame_counts:
		_sheets[a] = load(chibi_dir + a + ".png")
	_chibi = _sprite(_sheets["idle"], frame_counts["idle"], chibi_feet_offset)
	_chibi.position = _center + Vector2(cos(_angle), sin(_angle)) * circle_radius
	_knight = _sprite(load(knight_dir + "idle.png"), 4, knight_feet_offset)
	_knight.position = _center + Vector2(-330, 90)
	var p := AnimatedSprite2D.new()
	p.sprite_frames = load(PLAYER_FRAMES)
	p.animation = &"idle"
	p.play()
	p.scale = Vector2(2, 2)
	p.position = _center + Vector2(330, 90) + Vector2(0, -19)
	add_child(p)
	_label("NEW: chibi 3D render", _center + Vector2(-110, -190))
	_label("old knight", _center + Vector2(-395, 0))
	_label("current player", _center + Vector2(268, 0))
	var cam := Camera2D.new()
	cam.position = _center
	add_child(cam)

func _sprite(tex: Texture2D, hf: int, feet: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = hf
	s.vframes = 8
	s.scale = Vector2.ONE * sprite_scale
	s.offset = Vector2(0, -feet)
	s.z_index = 1
	add_child(s)
	return s

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

func _label(s: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = s
	l.position = at
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)

func _draw() -> void:
	for p in [_chibi.position, _knight.position, _center + Vector2(330, 90)]:
		draw_set_transform(p + Vector2(0, 2), 0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, 14, Color(0, 0, 0, 0.45))

func _play(a: String) -> void:
	if a == _anim: return
	_anim = a
	_t = 0.0
	_chibi.texture = _sheets[a]
	_chibi.hframes = frame_counts[a]

func _process(delta: float) -> void:
	_clock += delta
	var moving := _clock > walk_from and _clock < walk_to
	if moving:
		# one lap counter-clockwise on screen: S -> E -> N -> W, so all 8 directions are shown
		_angle -= run_speed / circle_radius * delta
		var pos := _center + Vector2(cos(_angle), sin(_angle)) * circle_radius
		var v := pos - _chibi.position
		if v.length() > 0.01:
			_row = posmod(roundi(atan2(v.x, v.y) / (PI / 4.0)), 8)
		_chibi.position = pos
	var slashing := false
	for i in slash_times.size():
		if _clock >= slash_times[i] and _clock < slash_times[i] + slash_len:
			slashing = true
			_row = slash_rows[i]
			if _anim != "slash": _t = 0.0
	_play("slash" if slashing else ("run" if moving else "idle"))
	_t += delta
	var n: int = frame_counts[_anim]
	var f := int(_t * fps[_anim])
	_chibi.frame = _row * n + (mini(f, n - 1) if _anim == "slash" else f % n)
	_kt += delta
	_knight.frame = 0 * 4 + int(_kt * 5.0) % 4
	queue_redraw()
	if _clock >= duration:
		get_tree().quit()
