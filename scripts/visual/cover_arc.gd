extends Node2D
class_name CoverArc
## The "which side am I protecting" hint (decision 0014 amendment). The shield
## icon stays upright and says THAT you are defending; this arc turns with the
## aim and says WHERE. Without it a hit from behind lands while the player is
## visibly blocking, and reads as the game cheating.
##
## Placeholder art in its own slot: GuardVisual only ever sets this node's
## `rotation`, `visible` and `modulate`, plus `arc_degrees` if it has one. So it
## can be swapped for a Sprite2D glow and still turn with the aim — delete this
## script, keep the node name.
##
## Drawn centred on +X, the direction its parent's rotation points.

## Mirrored from Guard.parry_arc_degrees by the player every frame, so the F3
## slider moves the hint and the real protected area together. Never typed
## here by hand — it would drift from what actually blocks.
@export var arc_degrees := 180.0:
	set(v):
		arc_degrees = v
		queue_redraw()
@export var radius := 30.0:
	set(v):
		radius = v
		queue_redraw()
@export var width := 3.0:
	set(v):
		width = v
		queue_redraw()
@export var color := Color(0.6, 0.9, 1.0, 0.8):
	set(v):
		color = v
		queue_redraw()
@export var segments := 24

func _draw() -> void:
	var half := deg_to_rad(clampf(arc_degrees, 1.0, 360.0)) * 0.5
	draw_arc(Vector2.ZERO, radius, -half, half, segments, color, width, true)
