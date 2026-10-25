extends Node2D
## Throwaway test of the "3D -> pixel sprite" pipeline (tools/blender/). Standalone: touches no
## player/combat code. A 3D-rendered knight walks a circle (all 8 directions), slashes, idles,
## next to the current player sprite for a size/style comparison.

const DIR := "res://assets/characters/test3d/"
const TILES := "res://assets/map/Floors_Tiles.png"
const PLAYER_FRAMES := "res://assets/characters/player/player_frames.tres"
## Sheet layout comes from sheet_info.json: rows = 8 directions (S SE E NE N NW W SW), columns = frames.
@export var cell := 64
@export var frame_counts := {"idle": 4, "run": 8, "slash": 6}
@export var fps := {"idle": 5.0, "run": 12.0, "slash": 12.0}
@export var run_speed := 150.0
@export var circle_radius := 110.0
@export var sprite_scale := 2.0
## Feet sit this many px below the cell centre (from the render camera: 0.78 u * sin(55deg) * 18 ppu).
@export var feet_offset := 11.5
@export var duration := 14.0

var _sheets := {}
var _knight: Sprite2D
var _anim := "idle"
var _t := 0.0
var _row := 0
var _frame_t := 0.0
var _center := Vector2(576, 340)
var _angle := PI * 0.5    # position on the circle; starts at the bottom (facing east when moving CCW on screen)
var _clock := 0.0
var _slash_t := -1.0

func _ready() -> void:
	_build_ground()
	for a in frame_counts:
		_sheets[a] = load(DIR + a + ".png")
	_knight = Sprite2D.new()
	_knight.texture = _sheets["idle"]
	_knight.hframes = frame_counts["idle"]
	_knight.vframes = 8
	_knight.scale = Vector2.ONE * sprite_scale
	_knight.offset = Vector2(0, -feet_offset)
	_knight.z_index = 1
	add_child(_knight)
	var p := AnimatedSprite2D.new()
	p.sprite_frames = load(PLAYER_FRAMES)
	p.animation = &"idle"
	p.play()
	p.scale = Vector2(2, 2)
	p.position = _center + Vector2(230, 0) + Vector2(0, -19)
	add_child(p)
	_knight.position = _center + Vector2(cos(_angle), sin(_angle)) * circle_radius
	_label("3D-rendered knight", _center + Vector2(-70, -210))
	_label("current player", _center + Vector2(165, -60))
	var cam := Camera2D.new()
	cam.position = _center
	add_child(cam)

func _label(s: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = s
	l.position = at
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)

func _build_ground() -> void:
	var tex: Texture2D = load(TILES)
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
	_shadow(_knight.position)
	_shadow(_center + Vector2(230, 0))

func _shadow(p: Vector2) -> void:
	draw_set_transform(p + Vector2(0, 2), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 14, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)

func _play(a: String) -> void:
	if a == _anim: return
	_anim = a
	_t = 0.0
	_knight.texture = _sheets[a]
	_knight.hframes = frame_counts[a]

func _process(delta: float) -> void:
	_clock += delta
	var moving := false
	if _clock > 1.0 and _clock < 7.5:
		# walk one full lap counter-clockwise on screen (S -> E -> N -> W): all 8 directions
		_angle -= run_speed / circle_radius * delta
		var pos := _center + Vector2(cos(_angle), sin(_angle)) * circle_radius
		var v := pos - _knight.position
		if v.length() > 0.01:
			_row = posmod(roundi(atan2(v.x, v.y) / (PI / 4.0)), 8)
		_knight.position = pos
		moving = true
	# slash beats: facing S, E, N after the walk
	for i in 3:
		var start := 8.6 + i * 1.5
		if _clock >= start and _clock < start + 0.5:
			_row = [0, 2, 4][i]
			if _slash_t < 0.0 or _anim != "slash": _t = 0.0
			_slash_t = _clock - start
	var slashing := false
	for i in 3:
		var start := 8.6 + i * 1.5
		slashing = slashing or (_clock >= start and _clock < start + 0.5)
	_play("slash" if slashing else ("run" if moving else "idle"))
	_t += delta
	var n: int = frame_counts[_anim]
	var f := int(_t * fps[_anim])
	f = mini(f, n - 1) if _anim == "slash" else f % n
	_knight.frame = _row * n + f
	queue_redraw()
	if _clock >= duration:
		get_tree().quit()
