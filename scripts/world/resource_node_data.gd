class_name ResourceNodeData
extends Resource
## One kind of gatherable (tree, rock, copper rock). Numbers and art live here; ResourceNode just runs them.

@export var id: StringName = &""
@export var display_name := ""
@export var max_hp := 6.0
## A weapon needs at least this tool_power to damage it; less = clink.
@export var required_power := 0
@export var drop_item: ItemData
@export var drop_min := 2
@export var drop_max := 3
## Collision circle, screen px.
@export var radius := 14.0
## Nodes per 100 land cells of that area.
@export var density_forest := 0.0
@export var density_rocky := 0.0
@export var density_boss := 0.0
@export_group("Art")
@export var texture: Texture2D
## Look variants (rects on `texture`).
@export var regions: Array[Rect2] = []
## What stays after it breaks (a stump). Empty = nothing stays.
@export var remains_region := Rect2()
@export var pixel_scale := 2
## Placeholder colour when there is no texture.
@export var color := Color.WHITE
@export_group("Hit feel")
@export var hit_type: StringName = &"chop"
@export var clink_type: StringName = &"clink"
@export var break_type: StringName = &"node_break"
