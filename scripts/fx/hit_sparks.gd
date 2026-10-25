extends Node2D
class_name HitSparks
## Impact sparks: tiny pixel squares flying along the hit direction. ONE node draws a fixed pool of sparks
## (no node per spark, no growth). Runs on game time, so a hit-stop freezes them mid-air. Listens to nothing:
## HitFx tells it where and how many (CLAUDE.md §5).

class Spark:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.0
	var max_life := 0.1
	var size := 2.0
	var color := Color.WHITE

## Pool size. The oldest spark is reused when it is full.
@export_range(16, 400) var max_sparks := 160
## Most sparks one physics frame may start (a pierce through three targets must not flood the screen).
@export_range(0, 60) var max_per_frame := 24
## Fan around the hit direction, degrees (full cone = twice this).
@export_range(0.0, 180.0, 1, "or_greater", "or_less") var spread_degrees := 35.0
## 0 = all sparks the same speed; 0.4 = each between 60% and 100%.
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var speed_jitter := 0.4
## Each spark lives between this share of `life` and the full life (1 = all equal).
@export_range(0.0, 1.0) var life_min := 0.7
## How fast a spark fades: 1 = fades over its whole life, 2 = over the last half.
@export_range(0.5, 6.0, 0.02, "or_greater", "or_less") var fade_rate := 2.0
## Speed lost per second (higher = they stop sooner).
@export_range(0.0, 20.0, 0.1, "or_greater", "or_less") var drag := 6.0

var spawned_total := 0
var _pool: Array[Spark] = []
var _next := 0
var _frame := -1
var _frame_count := 0

func _ready() -> void:
	z_index = 10
	set_process(false)

func pool_size() -> int:
	return _pool.size()

func live_count() -> int:
	var n := 0
	for s in _pool:
		if s.life > 0.0:
			n += 1
	return n

## `dir` ZERO = a burst in every direction.
func burst(point: Vector2, dir: Vector2, count: int, speed: float, life: float, color: Color, size: float) -> void:
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_frame_count = 0
	count = mini(count, max_per_frame - _frame_count)
	for i in count:
		var s: Spark
		if _pool.size() < max_sparks:
			s = Spark.new()
			_pool.append(s)
		else:
			s = _pool[_next % _pool.size()]
			_next += 1
		var ang := randf() * TAU if dir == Vector2.ZERO else dir.angle() + deg_to_rad(randf_range(-spread_degrees, spread_degrees))
		s.pos = point
		s.vel = Vector2.from_angle(ang) * speed * (1.0 - speed_jitter * randf())
		s.max_life = life * randf_range(life_min, 1.0)
		s.life = s.max_life
		s.size = size
		s.color = color
		_frame_count += 1
		spawned_total += 1
	if count > 0:
		set_process(true)

func _process(delta: float) -> void:
	var any := false
	for s in _pool:
		if s.life <= 0.0:
			continue
		s.life -= delta
		s.pos += s.vel * delta
		s.vel *= maxf(0.0, 1.0 - drag * delta)
		any = any or s.life > 0.0
	queue_redraw()
	if not any:
		set_process(false)

func _draw() -> void:
	for s in _pool:
		if s.life <= 0.0:
			continue
		var c := s.color
		c.a *= clampf(s.life / s.max_life * fade_rate, 0.0, 1.0)
		var px := roundf(s.size)
		draw_rect(Rect2((s.pos - Vector2(px, px) * 0.5).round(), Vector2(px, px)), c)
