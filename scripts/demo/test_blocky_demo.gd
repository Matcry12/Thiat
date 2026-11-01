extends Node2D
## Round 6 throwaway: blocky (Minecraft-style) 3D-rendered characters at SMALL sizes, under the game's real 2D weapon visuals.
## Left to right: [A] blocky WITH arms + 2D sword, [B] blocky WITHOUT arms + 2D hands + sword, [C] the current player (3D body).
## Camera: the game's normal zoom for 8.5 s, then a 2x close-up. All three walk the same rectangle (down, right, up, left).
## Standalone: the game's weapon scripts are only instanced, never edited.

const GRASS := "res://assets/map/Floors_Tiles.png"
const PLAYER_FRAMES := "res://assets/characters/player/3d/player_3d_frames.tres"
const SWORD := "res://data/weapons/wooden_sword.tres"
const WeaponVisualS := preload("res://scripts/visual/weapon_visual.gd")
const SwingFxS := preload("res://scripts/visual/swing_fx.gd")
@export var size_px := 18                  # which rendered size to show (14 / 18 / 22)
@export var base := "res://assets/characters/test_blocky/"
@export var walk_speed := 90.0
@export var half := 30.0
@export var sprite_scale := 2.0
@export var feet_y := 3.5
@export var hand_y := -8.0                 # weapon/hands height above the feet (the real player uses -9)
@export var swing_period := 1.3
@export var aim_speed := 1.6
@export var aim_radius := 70.0
@export var closeup_at := 8.5
@export var duration := 14.0

class Actor:
	var root: Node2D
	var wv: Node2D
	var fx: Node2D
	var sprite: Node2D
	var info := {}
	var sheets := {}
	var aim_t := 0.0
	var phase := "idle"
	var phase_t := 0.0
	var leg := 0
	var row := 0
	var flip := false
	var anim := "idle"
	var t := 0.0
	var label: Label

var _weapon: WeaponData
var _actors: Array[Actor] = []
var _clock := 0.0
var _swing_clock := 0.0
var _c := Vector2(576, 340)
var _cam: Camera2D
var _cl: CanvasLayer

func _ready() -> void:
	_weapon = load(SWORD)
	_build_ground()
	_cam = Camera2D.new()
	_cam.position = _c
	add_child(_cam)
	_cl = CanvasLayer.new()
	add_child(_cl)
	_actors.append(_make("blocky + arms\\n(2D sword)", Vector2(-150, 0), "arms", false))
	_actors.append(_make("blocky, no arms\\n(2D hands + sword)", Vector2(0, 0), "noarms", true))
	_actors.append(_make("current player\\n(3D body)", Vector2(150, 0), "", true))

func _make(title: String, off: Vector2, variant: String, _with_hands: bool) -> Actor:
	var a := Actor.new()
	a.root = Node2D.new()
	a.root.position = _c + off + Vector2(-half, -half)
	add_child(a.root)
	if variant != "":
		var d := "%ss%d_%s/" % [base, size_px, variant]
		a.info = JSON.parse_string(FileAccess.get_file_as_string(d + "sheet_info.json"))
		for k in a.info["actions"]:
			a.sheets[k] = load(d + k + ".png")
		var s := Sprite2D.new()
		s.texture = a.sheets["idle"]
		s.vframes = 2
		s.hframes = a.info["actions"]["idle"]["frames"]
		s.scale = Vector2.ONE * sprite_scale
		s.offset = Vector2(0, -float(a.info["feet_below_cell_centre_px"]))
		s.position = Vector2(0, feet_y)
		a.sprite = s
	else:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = load(PLAYER_FRAMES)
		s.scale = Vector2(2, 2)
		s.position = Vector2(0, -19)
		s.play(&"idle_front")
		a.sprite = s
	a.root.add_child(a.sprite)
	a.wv = WeaponVisualS.new()
	a.wv.position = Vector2(0, hand_y if variant != "" else -9)
	var pivot := Node2D.new()
	pivot.name = "SwingPivot"
	pivot.position = Vector2(6, 15)
	pivot.rotation = -PI / 2
	a.wv.add_child(pivot)
	a.fx = SwingFxS.new()
	a.fx.name = "SwingFx"
	a.wv.add_child(a.fx)
	a.root.add_child(a.wv)
	a.fx.set_weapon(_weapon)
	a.wv.set_weapon(_weapon)
	a.wv.model_changed.connect(a.fx.bind_model)
	a.fx.bind_model(a.wv.get_model())
	var hb = a.wv.get_model().get_node_or_null("Hitbox")
	if hb: hb.set("weapon", _weapon)
	a.label = Label.new()
	a.label.text = title.replace("\\n", "\n")
	a.label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a.label.add_theme_font_size_override("font_size", 16)
	a.label.add_theme_color_override("font_outline_color", Color.BLACK)
	a.label.add_theme_constant_override("outline_size", 5)
	_cl.add_child(a.label)
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
	for a in _actors:
		draw_set_transform(a.root.global_position + Vector2(0, 4), 0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, 12, Color(0, 0, 0, 0.45))

func _frame_at(a: Actor, name_: String, t: float) -> int:
	var holds: Array = a.info["actions"][name_]["hold_ms"]
	var total := 0.0
	for h in holds: total += h
	var ms := fmod(t * 1000.0, total)
	var acc := 0.0
	for i in holds.size():
		acc += holds[i]
		if ms < acc: return i
	return 0

func _drive_weapon(a: Actor, delta: float, allowed: bool) -> void:
	a.aim_t += delta * aim_speed
	var origin := a.root.global_position + Vector2(0, a.wv.position.y)
	var ang := Vector2(cos(a.aim_t), sin(a.aim_t)).angle()
	a.wv.set_aim_angle(ang)
	a.phase_t += delta
	var next := a.phase
	match a.phase:
		"windup": if a.phase_t >= _weapon.windup: next = "active"
		"active": if a.phase_t >= _weapon.active: next = "recovery"
		"recovery": if a.phase_t >= _weapon.recovery: next = "idle"
	if a.phase == "idle" and allowed and _swing_clock >= swing_period:
		next = "windup"
	if next != a.phase:
		a.phase = next
		a.phase_t = 0.0
		a.wv.on_weapon_state(next)
		a.fx.on_weapon_state(next)

func _process(delta: float) -> void:
	_clock += delta
	_swing_clock += delta
	var corners := [Vector2(-half, -half), Vector2(-half, half), Vector2(half, half), Vector2(half, -half)]   # down, right, up, left
	var walking := _clock > 1.0
	for i in _actors.size():
		var a := _actors[i]
		var home := _c + Vector2(-150 + 150 * i, 0)
		var moving := false
		var dir := Vector2.ZERO
		if walking:
			var target: Vector2 = home + corners[(a.leg + 1) % 4]
			var d := target - a.root.position
			var step := walk_speed * delta
			if d.length() <= step:
				a.root.position = target
				a.leg = (a.leg + 1) % 4
			else:
				a.root.position += d.normalized() * step
			dir = d
			moving = true
			a.root.position = a.root.position.round()
		# facing rule from the game: mostly down = front, else side (flipped for left); up keeps the side
		if dir != Vector2.ZERO:
			if absf(dir.x) > absf(dir.y):
				a.row = 1
				a.flip = dir.x < 0
			elif dir.y > 0:
				a.row = 0
			else:
				a.row = 1
		var want := "run" if moving else "idle"
		if a.info.is_empty():
			var side := a.row == 1
			var spr := a.sprite as AnimatedSprite2D
			spr.flip_h = a.flip and side
			var n := StringName("%s_%s" % [want, "side" if side else "front"])
			if spr.animation != n:
				var f := spr.frame
				spr.play(n)
				spr.set_frame_and_progress(mini(f, spr.sprite_frames.get_frame_count(n) - 1), 0.0)
		else:
			if want != a.anim:
				a.anim = want
				a.t = 0.0
				(a.sprite as Sprite2D).texture = a.sheets[want]
				(a.sprite as Sprite2D).hframes = a.info["actions"][want]["frames"]
			a.t += delta
			var s := a.sprite as Sprite2D
			s.flip_h = a.flip and a.row == 1
			s.frame = a.row * int(a.info["actions"][want]["frames"]) + _frame_at(a, want, a.t)
		_drive_weapon(a, delta, _clock > 1.4)
	if _swing_clock >= swing_period and _actors[0].phase != "idle": _swing_clock = 0.0
	var z := 2.0 if _clock >= closeup_at else 1.0
	_cam.zoom = Vector2.ONE * z
	var scr := get_viewport_rect().size
	for a in _actors:
		var p := (a.root.global_position + Vector2(0, -60) - _cam.position) * z + scr * 0.5
		var w := a.label.get_minimum_size().x
		a.label.position = Vector2(clampf(p.x - w * 0.5, 8, scr.x - w - 8), clampf(p.y - 24, 8, scr.y - 60))
	queue_redraw()
	if _clock >= duration:
		get_tree().quit()
