class_name EnemyVisual
extends ActorVisual
## The enemy's picture (decision 0052). Listens to the parent Enemy's `state_changed`; combat never calls in except
## the ActorVisual contract (set_facing, HitFx flash / recoil). No data.sprite_frames = a placeholder blob drawn
## here (squash / stretch per state). With sprite_frames: an AnimatedSprite2D plays the animation named after the state.

var _enemy: Enemy
var _v: EnemyVisualData   ## shared by every slime of the kind (EnemyData.visual)
var _state := &"idle"
var _t := 0.0
var _sprite: AnimatedSprite2D
var _flip := false

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		return
	_v = _enemy.data.visual
	_enemy.state_changed.connect(_on_state)
	var frames := _enemy.data.sprite_frames
	if frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "Sprite"
		_sprite.sprite_frames = frames
		_sprite.centered = true
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
		_play()

func _on_state(s: String) -> void:
	_state = StringName(s)
	_t = 0.0
	_play()

func _play() -> void:
	if _sprite and _sprite.sprite_frames.has_animation(_state):
		_sprite.sprite_frames.set_animation_loop(_state, _state == &"idle")
		_sprite.speed_scale = _speed_scale()
		_sprite.play(_state)

## Art is stretched to the tuned timing (rule 5): speed_scale = animation length / data duration.
func _speed_scale() -> float:
	var f := _sprite.sprite_frames
	var fps := f.get_animation_speed(_state)
	var dur := _state_duration()
	if _state == &"idle" or dur <= 0.0 or fps <= 0.0:
		return 1.0
	var frames := 0.0
	for i in f.get_frame_count(_state):
		frames += f.get_frame_duration(_state, i)
	return (frames / fps) / dur

func _state_duration() -> float:
	var d := _enemy.data
	match _state:
		&"windup": return d.hop_windup
		&"hop": return d.hop_time
		&"land": return d.land_time
		&"hit": return d.hit_stun
		&"die": return d.die_time
	return 0.0

## px the body is lifted now (the hop arc).
func _lift() -> float:
	return sin(PI * _progress()) * (_v.hop_lift_px * _v.pixel_scale) if _state == &"hop" else 0.0

func set_facing(dir: Vector2) -> void:
	if absf(dir.x) > 0.1:
		_flip = dir.x < 0.0
		if _sprite:
			_sprite.flip_h = _flip

func flash_target() -> CanvasItem:
	return _sprite if _sprite else self

func _process(delta: float) -> void:
	_t += delta
	if _sprite:
		_sprite.scale = Vector2.ONE * _v.pixel_scale
		_sprite.modulate = _v.tint
		_sprite.offset = _v.sprite_offset
	if _sprite:
		_sprite.position.y = -_lift()
	queue_redraw()

## Fraction 0..1 through the current state's data duration.
func _progress() -> float:
	var dur := _state_duration() if _state != &"idle" else 1.0
	return clampf(_t / maxf(dur, 0.01), 0.0, 1.0)

func _draw() -> void:
	if _enemy == null:
		return
	var r := _enemy.data.body_radius * _v.size_scale
	var p := _progress()
	var sx := 1.0
	var sy := 1.0
	var lift := 0.0
	var alpha := 1.0
	match _state:
		&"windup":
			sx = 1.0 + _v.windup_squash * p
			sy = 1.0 - _v.windup_squash * p
		&"hop":
			sx = 1.0 - _v.hop_stretch * 0.5
			sy = 1.0 + _v.hop_stretch
			lift = sin(PI * p) * (_v.hop_lift_px * _v.pixel_scale)
		&"land":
			sx = 1.0 + _v.land_splat * (1.0 - p)
			sy = 1.0 - _v.land_splat * (1.0 - p)
		&"hit":
			sx = 1.0 - 0.15
			sy = 1.0 + 0.15
		&"die":
			sx = 1.0 + p * 0.4
			sy = 1.0 - p * 0.8
			alpha = 1.0 - p
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * r * sx, sin(a) * r * sy * 0.9 - r * sy * 0.9 - lift))
	var sh := PackedVector2Array()
	var base_r := _v.shadow_half_width * _v.pixel_scale if _sprite != null else r
	var sr := base_r * (1.0 - lift / ((_v.hop_lift_px * _v.pixel_scale) * 4.0 + 1.0))
	for i in 14:
		sh.append(Vector2(cos(TAU * i / 14.0) * sr, sin(TAU * i / 14.0) * sr * 0.4))
	draw_colored_polygon(sh, Color(_v.shadow_color, _v.shadow_color.a * alpha))
	if _sprite != null:
		return
	draw_colored_polygon(pts, Color(_v.blob_color * _v.tint, alpha))
	pts.append(pts[0])
	draw_polyline(pts, Color(_v.blob_outline * _v.tint, alpha), 1.5)
	var eye := Vector2((4.0 if not _flip else -4.0), -r * sy * 0.9 - lift)
	draw_circle(eye, 1.8, Color(0.1, 0.12, 0.1, alpha))
	draw_circle(eye + Vector2(-6.0 if not _flip else 6.0, 0), 1.8, Color(0.1, 0.12, 0.1, alpha))

