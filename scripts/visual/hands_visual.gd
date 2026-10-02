@tool
extends Node2D
class_name HandsVisual
## Two round hands that hold the weapon (Soul Knight / Gungeon look).
##
## Each frame it READS the current weapon model's `HandMain` / `HandOff` Marker2D
## and draws a hand on each. It never writes into the weapon (one owner: the
## model scene owns where the hands go). No weapon / no markers -> the hands
## rest beside the body at the exported rest offsets.
##
## Driven only by bind_model() / set_aim_angle() / set_drawing(), wired in
## player.gd. A bow draw is a pose offset on the OFF hand (pulled back along
## the model's own forward axis) - no combat code is reached into.
##
## PIXEL LOOK: a disc of square blocks on a `pixel_size` grid, white fill, dark
## outline - same grid as the swing FX.

@export var hand_radius := 5.0
## Outline thickness in px.
@export var outline_width := 1.5
@export var pixel_size := 1.0
@export var fill_color := Color(0.96, 0.96, 0.98)
@export var outline_color := Color(0.08, 0.08, 0.1)

@export_group("Rest pose (no weapon)")
## Relative to this node, in AIM space: x = toward the aim, y = to the right of it.
@export var rest_offset_main := Vector2(6, 15)
@export var rest_offset_off := Vector2(6, -15)

@export_group("Bow draw")
## How far the off hand is pulled back while drawing, in px.
@export var draw_pull := 8.0
## Seconds to reach full pull / to let go.
@export var draw_time := 0.12

var _model: Node2D
var _aim := 0.0
var _drawing := false
var _pull := 0.0     ## 0..1 eased draw amount (code-owned)

func bind_model(model: Node2D) -> void:
	_model = model
	_drawing = false
	_pull = 0.0

func set_aim_angle(angle: float) -> void:
	_aim = angle

## True while a bow is being drawn (normal shot wind-up, or the piercing charge).
func set_drawing(on: bool) -> void:
	_drawing = on

func is_drawing() -> bool:
	return _drawing

func pull_amount() -> float:
	return _pull

## One line for the F3 status panel.
func status_text() -> String:
	return "hands: %s  draw pull: %.2f  on markers: %s" % ["drawing" if _drawing else "relaxed", _pull, _marker("HandMain") != null]

func _marker(name_: String) -> Node2D:
	return _model.get_node_or_null(name_) as Node2D if is_instance_valid(_model) else null

## The two hand positions in GLOBAL space: [main, off].
func hand_positions() -> Array[Vector2]:
	var main := _marker("HandMain")
	var off := _marker("HandOff")
	var flip := -1.0 if cos(_aim) < 0.0 else 1.0     # keep main hand on the weapon's side when aiming left
	var rest_main := to_global(Vector2(rest_offset_main.x, rest_offset_main.y * flip).rotated(_aim))
	var rest_off := to_global(Vector2(rest_offset_off.x, rest_offset_off.y * flip).rotated(_aim))
	var out: Array[Vector2] = [
		main.global_position if main else rest_main,
		off.global_position if off else rest_off,
	]
	if off and _pull > 0.0:
		out[1] -= _model.global_transform.x.normalized() * draw_pull * _pull
	return out

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# Editor preview: no signals run here, so read the previewed model off WeaponVisual
		# (read-only) and redraw, so the hands show on the markers while you drag them.
		var wv := get_node_or_null("../WeaponVisual") as WeaponVisual
		_model = wv.get_model() if wv else null
		queue_redraw()
		return
	_pull = move_toward(_pull, 1.0 if _drawing else 0.0, delta / maxf(draw_time, 0.001))
	queue_redraw()

func _draw() -> void:
	for p in hand_positions():
		_draw_hand(to_local(p))

func _draw_hand(center: Vector2) -> void:
	var n := ceili(hand_radius / pixel_size)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var d := Vector2(i, j).length() * pixel_size
			if d > hand_radius:
				continue
			var c := outline_color if d > hand_radius - outline_width else fill_color
			draw_rect(Rect2(center + Vector2(i, j) * pixel_size - Vector2.ONE * pixel_size * 0.5, Vector2.ONE * pixel_size), c)
