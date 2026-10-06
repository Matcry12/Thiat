class_name ItemData
extends Resource
## One kind of item (wood, stone, ...). Data only: a new item is a new .tres (v1-design §5).

@export var id: StringName
@export var display_name := ""
@export var icon: Texture2D
## Placeholder tint (pickup and counter) while `icon` is empty.
@export var color := Color.WHITE
