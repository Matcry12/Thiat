class_name WaterFx
extends Node2D
## What swimming looks like (0038 step 3): while the actor stands in shallow water the lower body is tinted by a shader on the Body sprite (so it
## y-sorts with the actor), ripple rings spread from the feet while it moves, and small splashes fly up (both on the ground layer, z -1, like RunDust). The shadow is hidden meanwhile. Visual only: it listens to
## `water_changed` of the Swimmer and watches its own parent's position; nothing calls into it from combat.
## Swap for art later: replace _draw() (or spawn an AnimatedSprite2D in _spawn_ripple / splash); the trigger stays the signal.

@export var fx_on := true:
	set(v):
		fx_on = v
		_apply()
@export var hide_shadow := true:
	set(v):
		hide_shadow = v
		_apply()
## The waterline: the body below this height above the feet is tinted (water_color alpha = how strongly). Drawn by a shader on the Body sprite.
@export var band_height_px := 9.0
@export var band_color := Color(0.30, 0.62, 0.85, 0.55)
## Ripple rings while moving: seconds between rings, life, final radius (px), line width, colour.
@export var ripple_interval := 0.30
@export var ripple_life := 0.75
@export var ripple_radius_px := 17.0
@export var ripple_width_px := 2.0
@export var ripple_color := Color(0.92, 0.98, 1.0, 0.85)
## Splash puffs: count when stepping into the water, count per ripple while moving, size (px), life, upward speed (px/s).
@export var splash_enter_count := 7
@export var splash_move_count := 2
@export var splash_size_px := 3.0
@export var splash_life := 0.4
@export var splash_speed := 46.0
@export var splash_color := Color(0.85, 0.95, 1.0, 0.9)
@export_node_path("Node") var swimmer_path: NodePath = ^"../../Swimmer"
@export var pool_size := 32:
	set(v):
		pool_size = maxi(v, 1)
		_resize_pool()

var in_water := false   ## code-owned (set by the signal)
var _rings := PackedFloat32Array()   # age per ring, -1 = free
var _ring_pos := PackedVector2Array()
var _sp_pos := PackedVector2Array()
var _sp_vel := PackedVector2Array()
var _sp_age := PackedFloat32Array()
var _since_ring := 0.0
var _prev := Vector2.ZERO


func _ready() -> void:
	z_index = -1
	top_level = true   # rings and splashes stay where they were made; _draw() works in world coordinates
	global_position = Vector2.ZERO
	_resize_pool()
	if Engine.is_editor_hint():
		return
	var sw := get_node_or_null(swimmer_path)
	if sw and sw.has_signal("water_changed"):
		sw.water_changed.connect(set_in_water)
	_prev = _feet()


func _feet() -> Vector2:
	return get_parent().global_position


func set_in_water(v: bool) -> void:
	in_water = v
	if v:
		_since_ring = ripple_interval   # first ring at once
		_splash(splash_enter_count)
	_apply()
	queue_redraw()


## Shadow and body shader follow the state at once (also when fx_on / hide_shadow are changed live from F3).
func _apply() -> void:
	var vis := get_parent()
	if vis == null:
		return
	var on := in_water and fx_on
	if vis.has_method("set_shadow_hidden"):
		vis.set_shadow_hidden(on and hide_shadow)
	var body := vis.get_node_or_null("Body") as CanvasItem
	if body == null:
		return
	if on:
		if not body.material is ShaderMaterial:
			var m := ShaderMaterial.new()
			m.shader = preload("res://scripts/visual/water_fx.gdshader")
			body.material = m
		(body.material as ShaderMaterial).set_shader_parameter("water_color", band_color)
		_update_line()
	elif body.material is ShaderMaterial and (body.material as ShaderMaterial).shader == preload("res://scripts/visual/water_fx.gdshader"):
		body.material = null


func _update_line() -> void:
	var body := get_parent().get_node_or_null("Body") as CanvasItem
	if body and body.material is ShaderMaterial:
		(body.material as ShaderMaterial).set_shader_parameter("waterline", _feet().y - band_height_px)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var feet := _feet()
	var moved := feet.distance_to(_prev) > 0.3
	_prev = feet
	var busy := in_water
	if in_water and fx_on:
		_update_line()
	if in_water and fx_on and moved:
		_since_ring += delta
		if _since_ring >= ripple_interval:
			_since_ring = 0.0
			_spawn_ripple(feet)
			_splash(splash_move_count)
	for i in pool_size:
		if _rings[i] >= 0.0:
			busy = true
			_rings[i] += delta
			if _rings[i] >= ripple_life:
				_rings[i] = -1.0
		if _sp_age[i] >= 0.0:
			busy = true
			_sp_age[i] += delta
			if _sp_age[i] >= splash_life:
				_sp_age[i] = -1.0
			else:
				_sp_vel[i].y += 160.0 * delta   # falls back
				_sp_pos[i] += _sp_vel[i] * delta
	if busy:
		queue_redraw()


func _spawn_ripple(at: Vector2) -> void:
	var slot := _rings.find(-1.0)
	if slot >= 0:
		_rings[slot] = 0.0
		_ring_pos[slot] = at


func _splash(n: int) -> void:
	if not fx_on:
		return
	var feet := _feet()
	for k in n:
		var slot := _sp_age.find(-1.0)
		if slot < 0:
			return
		var side := randf_range(-1.0, 1.0)
		_sp_pos[slot] = feet + Vector2(side * 6.0, randf_range(-2.0, 1.0))
		_sp_vel[slot] = Vector2(side * splash_speed * 0.5, -splash_speed * randf_range(0.5, 1.0))
		_sp_age[slot] = 0.0


func _draw() -> void:
	for i in pool_size:
		if _rings[i] >= 0.0:
			var k := _rings[i] / maxf(ripple_life, 0.001)
			draw_arc(_ring_pos[i], maxf(ripple_radius_px * k, 1.0), 0.0, TAU, 24, Color(ripple_color, ripple_color.a * (1.0 - k)), ripple_width_px)
		if _sp_age[i] >= 0.0:
			var q := 1.0 - _sp_age[i] / maxf(splash_life, 0.001)
			var s := maxf(roundf(splash_size_px * (0.5 + 0.5 * q)), 1.0)
			draw_rect(Rect2((_sp_pos[i] - Vector2(s, s) * 0.5).round(), Vector2(s, s)), Color(splash_color, splash_color.a * sqrt(q)))


func alive_count() -> int:
	var n := 0
	for i in pool_size:
		n += int(_rings[i] >= 0.0) + int(_sp_age[i] >= 0.0)
	return n


func status_text() -> String:
	return "WaterFx: %s  effects alive: %d" % ["on" if in_water else "off", alive_count()]


func _resize_pool() -> void:
	_rings.resize(pool_size)
	_ring_pos.resize(pool_size)
	_sp_pos.resize(pool_size)
	_sp_vel.resize(pool_size)
	_sp_age.resize(pool_size)
	_rings.fill(-1.0)
	_sp_age.fill(-1.0)
