extends Area2D
class_name Hurtbox
## What can be hit. Owner (scene root) is expected to have a Health child node.

func _ready() -> void:
	add_to_group("hurtbox")

## Null when the owner has no Health (e.g. the player in slice 1, which cannot
## yet take damage). Callers must handle null rather than assume one exists.
func get_health() -> Health:
	return owner.get_node_or_null("Health") as Health
