class_name RunDust
extends Node2D
## Pooled dust puffs at the feet: on run-bounce landings (every Nth), when a run starts, and on a dodge.
## Visual only. It listens: `landed` / `run_started` from the parent SpriteActorVisual and `used` from the
## Dodge component (a signal that already exists) - combat never calls into it.
## Swap for art later: replace _draw() (or spawn an AnimatedSprite2D in spawn()); the triggers stay.

@export var dust_on := true
@export var dust_every_n_landings := 2   ## 1 = every landing
@export var dust_count := 3              ## puffs per landing
@export var start_puff_count := 5        ## puffs when a run starts from standing
@export var dodge_puff_count := 8        ## puffs when the dodge fires
@export var dust_size_px := 5.0          ## square side at birth, world px (shrinks as it fades)
@export var dust_life := 0.35            ## seconds
@export var dust_spread := 14.0          ## drift speed, px/s (outward + up)
@export var dust_back_speed := 22.0      ## extra speed away from the run direction, px/s
@export var dust_foot_spread := 5.0      ## random sideways start offset at the feet, px
@export var dust_color := Color(0.9, 0.85, 0.72, 0.95)
@export var pool_size := 48
@export_node_path("Node") var dodge_path: NodePath = ^"../../Dodge"

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _age := PackedFloat32Array()
var _alive := 0
var _landings := 0
var _prev_pos := Vector2.ZERO
var _dir := Vector2.ZERO   ## last movement direction (from our own position change)

func _ready() -> void:
	top_level = true   # puffs stay where they were dropped; _draw() works in world coordinates
	global_position = Vector2.ZERO
	_pos.resize(pool_size)
	_vel.resize(pool_size)
	_age.resize(pool_size)
	_age.fill(-1.0)
	if Engine.is_editor_hint():
		return
	var vis := get_parent()
	if vis.has_signal("landed"):
		vis.landed.connect(_on_landed)
		vis.run_started.connect(func(): burst(start_puff_count))
	var dodge := get_node_or_null(dodge_path)
	if dodge and dodge.has_signal("used"):
		dodge.used.connect(func(): burst(dodge_puff_count))
	_prev_pos = _feet()

func _feet() -> Vector2:
	return get_parent().global_position

func _on_landed() -> void:
	_landings += 1
	if dust_every_n_landings > 0 and _landings % dust_every_n_landings == 0:
		burst(dust_count)

## Spawn `n` puffs at the feet; drift opposite to the run direction, plus a little outward and up.
func burst(n: int) -> void:
	if not dust_on:
		return
	var feet := _feet()
	for i in n:
		var slot := _age.find(-1.0)
		if slot < 0:
			return   # pool full: drop the puff
		var side := randf_range(-1.0, 1.0)
		_pos[slot] = feet + Vector2(side * dust_foot_spread, randf_range(-1.0, 1.0))
		_vel[slot] = Vector2(side * dust_spread, -dust_spread * randf_range(0.3, 1.0)) - _dir * dust_back_speed * randf_range(0.5, 1.0)
		_age[slot] = 0.0
		_alive += 1
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var feet := _feet()
	if feet.distance_to(_prev_pos) > 0.01:
		_dir = (feet - _prev_pos).normalized()
	_prev_pos = feet
	if _alive == 0:
		return
	for i in pool_size:
		if _age[i] < 0.0:
			continue
		_age[i] += delta
		if _age[i] >= dust_life:
			_age[i] = -1.0
			_alive -= 1
		else:
			_pos[i] += _vel[i] * delta
	queue_redraw()

func _draw() -> void:
	for i in pool_size:
		if _age[i] < 0.0:
			continue
		var k := 1.0 - _age[i] / dust_life
		var s := maxf(roundf(dust_size_px * (0.5 + 0.5 * k)), 1.0)
		draw_rect(Rect2((_pos[i] - Vector2(s, s) * 0.5).round(), Vector2(s, s)), Color(dust_color, dust_color.a * sqrt(k)))

func alive_count() -> int:
	return _alive

func clear() -> void:
	_age.fill(-1.0)
	_alive = 0
	queue_redraw()
