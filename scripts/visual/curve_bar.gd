@tool
extends Node2D
class_name CurveBar
## A bar bent along a circle — shows a 0..1 value next to a character instead of
## up in the HUD, where you can read it without looking away from the fight.
## Generic on purpose: today it is the guard's shield bar (node "GuardBar"),
## tomorrow the same script can show a dodge cooldown or a boss charge.
##
## @tool so it DRAWS IN THE EDITOR: drag it, and shape it with Radius / Start /
## Span while you watch. Code only ever writes `value`, `visible` and
## `modulate` — position, radius and angles are yours.
##
## Angles in degrees, Godot style: 0 = right, 90 = straight DOWN (y points down),
## 180 = left. The fill grows from `start_degrees` by `span_degrees`; a negative
## span fills the other way round.

## The amount shown, 0..1. Set by code at runtime; set it by hand in the editor
## only to preview how a half-empty bar looks — the game overwrites it.
@export_range(0.0, 1.0) var value := 1.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
@export var radius := 20.0:
	set(v):
		radius = v
		queue_redraw()
@export var width := 4.0:
	set(v):
		width = v
		queue_redraw()
## Default: a smile under the feet, filling left -> right.
@export var start_degrees := 150.0:
	set(v):
		start_degrees = v
		queue_redraw()
@export var span_degrees := -120.0:
	set(v):
		span_degrees = v
		queue_redraw()
@export var fill_color := Color(0.55, 0.85, 1.0, 1.0):
	set(v):
		fill_color = v
		queue_redraw()
## The empty track behind the fill, so you can see how much is MISSING.
@export var back_color := Color(0.0, 0.0, 0.0, 0.45):
	set(v):
		back_color = v
		queue_redraw()
@export var segments := 32

func _draw() -> void:
	var a0 := deg_to_rad(start_degrees)
	var span := deg_to_rad(span_degrees)
	draw_arc(Vector2.ZERO, radius, a0, a0 + span, segments, back_color, width, true)
	if value > 0.001:
		var steps := maxi(2, int(ceil(segments * value)))
		draw_arc(Vector2.ZERO, radius, a0, a0 + span * value, steps, fill_color, width, true)
