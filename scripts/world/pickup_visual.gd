class_name PickupVisual
extends Node2D
## The look of a loose item: its icon (a Sprite2D "Icon") or, without an icon, a coloured diamond. Pickup moves
## this node up and down for the float; it never touches the pickup's position (CLAUDE.md §5: swap = no code change).

var size := 7.0
var color := Color.WHITE
var has_icon := false

func _draw() -> void:
	if has_icon:
		return
	draw_colored_polygon(PackedVector2Array([Vector2(0, -size), Vector2(size, 0), Vector2(0, size), Vector2(-size, 0)]), color)
