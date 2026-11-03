class_name EnemyVisualData
extends Resource
## Looks of one enemy kind, shared by all its instances (EnemyData.visual). Feel of the picture only; timings live in EnemyData.

@export_group("Sprite")
## Colour multiplied onto the sprite and the blob (white = none). A skin until drawn variants exist.
@export var tint := Color.WHITE
## Whole-number pixel scale of the art. 3 = the player's body scale (BodyRig body_scale).
@export_range(1, 8, 1) var pixel_scale := 3
@export var sprite_offset := Vector2(0, -15)   ## art px; puts the feet (bottom edge of row 30 of 32) on the origin
@export_group("Hop and shadow")
@export_range(0.0, 30.0, 0.5) var hop_lift_px := 6.0   ## art px, x pixel_scale
@export_range(1.0, 30.0, 0.5) var shadow_half_width := 9.0   ## art px, x pixel_scale
@export var shadow_color := Color(0, 0, 0, 0.3)
@export_group("Placeholder blob")
@export var blob_color := Color(0.42, 0.82, 0.38)
@export var blob_outline := Color(0.12, 0.3, 0.14)
@export_range(1.0, 4.0, 0.05) var size_scale := 1.5   ## blob radius = body_radius x this
@export_range(0.0, 0.8, 0.02) var windup_squash := 0.35
@export_range(0.0, 0.8, 0.02) var hop_stretch := 0.3
@export_range(0.0, 0.8, 0.02) var land_splat := 0.3
