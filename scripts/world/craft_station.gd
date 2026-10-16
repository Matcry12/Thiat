class_name CraftStation
extends Node
## Marks a Station as "craft here": recipes whose `station` equals `station_id` show up in the crafting
## panel while the player is within `craft_radius` (decision 0031). Child of a Station; knows nothing about
## recipes. F1 draws the radius.

@export var station_id: StringName = &"workbench"
@export var craft_radius := 150.0   ## px, from the station's centre

func _ready() -> void:
	add_to_group("craft_station")

func world_pos() -> Vector2:
	return (get_parent() as Node2D).global_position

func reaches(p: Vector2) -> bool:
	return world_pos().distance_to(p) <= craft_radius
