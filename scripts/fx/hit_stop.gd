extends Node
class_name HitStop
## Global hit-stop: a few frames of (almost) frozen game time when a hit lands (Nuclear Throne's "sleep").
## No actor knows about it. Works by dipping Engine.time_scale and timing the dip on UNSCALED time
## (delta / time_scale), so it lasts the same real time at any speed and in movie-maker recordings.
## HitStop is the ONE owner of Engine.time_scale while it is active: `base_scale` is the normal speed (F2 slow-mo
## sets it through toggle_slowmo()), and stop / kill slow-mo are applied on top of it and removed again after.

## Multiplies every stop. 0 = hit-stop off.
@export var hitstop_scale := 1.0
## Longest stop allowed, in frames, however many hits stack.
@export var max_frames := 12
## time_scale during the stop. Not exactly 0: delta would be 0 and some code divides by it.
@export_range(0.0001, 0.2) var stop_time_scale := 0.001
@export var fps := 60.0

## Normal game speed. Captured from Engine.time_scale when a stop starts, so outside writers (tests, demo) still work.
var base_scale := 1.0
var _active := false
var _stop_left := 0.0   ## seconds of freeze left (unscaled)
var _slow_left := 0.0   ## seconds of post-freeze slow-mo left (unscaled)
var _slow_scale := 1.0

func _ready() -> void:
	add_to_group("hit_stop")

func is_active() -> bool:
	return _active

## Frames of freeze still to go (for F3).
func frames_left() -> int:
	return ceili(_stop_left * fps) if _active else 0

## Freeze for `frames` (times hitstop_scale, capped). Overlapping stops: the longest wins, they never add up.
func request(frames: float, slowmo_scale := 1.0, slowmo_time := 0.0) -> void:
	var f := minf(frames * hitstop_scale, float(max_frames))
	var wants_slow := slowmo_scale < 1.0 and slowmo_time > 0.0
	if f < 0.5 and not wants_slow:
		return
	if not _active:
		base_scale = Engine.time_scale
		_active = true
	_stop_left = maxf(_stop_left, f / fps)
	if wants_slow:
		_slow_scale = slowmo_scale
		_slow_left = maxf(_slow_left, slowmo_time)
	_apply()

## F2: normal speed <-> 0.25. Works mid-stop too: the new base shows once the stop is over.
func toggle_slowmo() -> void:
	if not _active:
		base_scale = Engine.time_scale
	base_scale = 0.25 if is_equal_approx(base_scale, 1.0) else 1.0
	if _active:
		_apply()
	else:
		Engine.time_scale = base_scale

func _apply() -> void:
	if _stop_left > 0.0:
		Engine.time_scale = stop_time_scale
	elif _slow_left > 0.0:
		Engine.time_scale = base_scale * _slow_scale
	else:
		_end()
		return

func _end() -> void:
	if _active:
		Engine.time_scale = base_scale
	_active = false
	_stop_left = 0.0
	_slow_left = 0.0

func _process(delta: float) -> void:
	if not _active:
		return
	var dt := delta / maxf(Engine.time_scale, 0.0001)   # unscaled
	if _stop_left > 0.0:
		_stop_left = maxf(0.0, _stop_left - dt)
	elif _slow_left > 0.0:
		_slow_left = maxf(0.0, _slow_left - dt)
	_apply()

func _exit_tree() -> void:
	_end()   # a scene reload mid-freeze must not leave the game frozen
