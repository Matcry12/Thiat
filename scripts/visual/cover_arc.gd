@tool
extends Node2D
class_name CoverArc
## The guard arc: ONE curve with two jobs (decision 0015, "merged into the glow").
##   WHERE — it turns with the aim and spans exactly the protected side.
##   HOW MUCH — a bright fill shows how much guard is left.
## The full width is always drawn as a dim TRACK, so a half-empty arc still shows
## the whole protected side and never reads as "half-protected" — that was the
## reason merging was first turned down.
##
## Placeholder art in its own slot: GuardVisual only ever sets this node's
## `rotation`, `visible`, `modulate`, plus `arc_degrees` / `value` if it has them
## (duck-typed). So it can be swapped for a sprite glow and still turn.
##
## @tool so it DRAWS IN THE EDITOR: you cannot drag what you cannot see. Drag its
## position freely — it turns around wherever you put it.
##
## Drawn centred on +X, the direction its rotation points.

## NOT an @export, on purpose: the player copies Guard.parry_arc_degrees into
## it every frame, so a value typed here in the Inspector would silently do
## nothing — the user did exactly that. Set the width on the Guard node (or F3
## -> Guard). One owner per property.
var arc_degrees := 180.0:
	set(v):
		arc_degrees = v
		queue_redraw()
## Guard left, 0..1. Not an @export for the same reason as arc_degrees: code
## writes it, so an Inspector field would be a trap.
var value := 1.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
@export var radius := 30.0:
	set(v):
		radius = v
		queue_redraw()
@export var width := 3.0:
	set(v):
		width = v
		queue_redraw()
@export var color := Color(0.6, 0.9, 1.0, 0.9):
	set(v):
		color = v
		queue_redraw()
## The empty part of the arc. Dim, but never invisible: it is what keeps the
## full protected width readable when the guard is low.
@export var track_color := Color(0.6, 0.9, 1.0, 0.2):
	set(v):
		track_color = v
		queue_redraw()
@export var segments := 32
## EDITOR PREVIEW ONLY. In the editor no player code runs to copy the width
## in, so the arc showed its own default (180) no matter what Guard said — the
## user set 100 and "didn't see it change". In the editor it reads the width
## from this node instead. While the game runs this is ignored: the player
## mirrors the width every frame, and the arc never reads Guard.
@export var preview_width_from: NodePath = NodePath("../../Guard")

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		sync_editor_preview()

## Separate from _process so a test can call it outside the editor.
func sync_editor_preview() -> void:
	var src := get_node_or_null(preview_width_from)
	if src == null:
		return
	var w = src.get("parry_arc_degrees")
	if (w is float or w is int) and not is_equal_approx(arc_degrees, w):
		arc_degrees = w

func _draw() -> void:
	var half := deg_to_rad(clampf(arc_degrees, 1.0, 360.0)) * 0.5
	draw_arc(Vector2.ZERO, radius, -half, half, segments, track_color, width, true)
	if value > 0.001:
		# Fill shrinks toward the aim line from both ends, so the middle — where
		# you are pointing — is the last part to go.
		var fill_half := half * value
		var steps := maxi(2, int(ceil(segments * value)))
		draw_arc(Vector2.ZERO, radius, -fill_half, fill_half, steps, color, width, true)
