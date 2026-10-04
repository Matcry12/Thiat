extends Node
class_name HitRecoil
## Visual jolt: moves ONE Visual node a few px away from the hit and springs it back. The body, hurtbox and
## everything else stay where they are (a boss never moves from hits). Child of the visual, named "HitRecoil",
## like HitFlash. The rest position is read when a jolt starts, so a Visual dragged in the editor is respected.

var _host: Node2D
var _rest := Vector2.ZERO
var _dir := Vector2.ZERO
var _px := 0.0
var _time := 0.1
var _t := 0.0
var _active := false
var _out := 0.25
var _ease := 2.0

static func play(host: Node2D, dir: Vector2, px: float, time: float, out_fraction := 0.25, ease_curve := 2.0) -> void:
	if host == null or px <= 0.0 or dir == Vector2.ZERO:
		return
	var r := host.get_node_or_null("HitRecoil") as HitRecoil
	if r == null:
		r = HitRecoil.new()
		r.name = "HitRecoil"
		host.add_child(r)
	r._out = clampf(out_fraction, 0.01, 0.99)
	r._ease = ease_curve
	r._start(host, dir.normalized(), px, maxf(time, 0.02))

func _start(host: Node2D, dir: Vector2, px: float, time: float) -> void:
	if not _active:
		_rest = host.position
	_host = host
	_dir = dir
	_px = px
	_time = time
	_t = 0.0
	_active = true

## Current jolt, px (for tests and F3).
func offset() -> Vector2:
	return _host.position - _rest if _active and _host else Vector2.ZERO

func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	var u := _t / _time
	if u >= 1.0:
		_host.position = _rest
		_active = false
		return
	# Fast out (first `out_fraction`), eased back.
	var w := u / _out if u < _out else ease((1.0 - u) / (1.0 - _out), _ease)
	_host.position = _rest + _dir * _px * w
