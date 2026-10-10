class_name ItemData
extends Resource
## One kind of item (wood, stone, sword, ...). Data only: a new item is a new .tres (v1-design §5).

@export var id: StringName
@export var display_name := ""
@export var icon: Texture2D
## Placeholder tint (pickup, hotbar and bag square) while `icon` is empty.
@export var color := Color.WHITE
@export_enum("material", "tool", "weapon") var category := "material"
## How many fit in one slot. Items with a `weapon` always stack to 1.
@export var max_stack := 64
## Set for tools and weapons: what the player holds when this slot is selected.
@export var weapon: WeaponData

func stack_limit() -> int:
	return 1 if weapon != null else maxi(max_stack, 1)
