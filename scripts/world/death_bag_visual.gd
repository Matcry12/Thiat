class_name DeathBagVisual
extends Node2D
## Placeholder look of a DeathBag: a sack with a dark outline, a knot and a gold ring so it reads on any ground.
## Swap this node for a sprite; the bag script never reaches in. The numbers live on the Respawner (F3 "Respawner"):
## DeathBag copies them in through set_look().

var size := 18.0
var color := Color(0.55, 0.36, 0.18)
var outline_color := Color(0.1, 0.05, 0.02)
var outline_width := 3.0
var ring_color := Color(1.0, 0.85, 0.25)

func set_look(r: Respawner) -> void:
	size = r.bag_size
	color = r.bag_color
	outline_color = r.bag_outline_color
	outline_width = r.bag_outline_width
	ring_color = r.bag_ring_color
	queue_redraw()

func _draw() -> void:
	var body := Vector2(0, -size * 0.6)
	var knot := Vector2(0, -size * 1.55)
	draw_arc(Vector2.ZERO, size * 1.5, 0, TAU, 32, ring_color, 2.0)   # where the eye should go
	draw_circle(knot, size * 0.45 + outline_width, outline_color)
	draw_circle(body, size + outline_width, outline_color)
	draw_circle(body, size, color)
	draw_circle(knot, size * 0.45, ring_color)
	draw_arc(body, size * 0.6, PI * 0.15, PI * 0.85, 8, outline_color, 2.0)   # a fold, so it reads as a sack
