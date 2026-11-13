class_name ItemData
extends Resource
## One kind of item (wood, stone, sword, ...). Data only: a new item is a new .tres (v1-design §5).

@export var id: StringName
@export var display_name := ""
@export var icon: Texture2D
## Placeholder tint (pickup, hotbar and bag square) while `icon` is empty.
@export var color := Color.WHITE
@export_enum("material", "tool", "weapon", "placeable") var category := "material"
## How many fit in one slot. Items with a `weapon` always stack to 1.
@export var max_stack := 64
## Set for tools and weapons: what the player holds when this slot is selected.
@export var weapon: WeaponData

func stack_limit() -> int:
	return 1 if weapon != null else maxi(max_stack, 1)

## Set for stations (workbench, furnace, anvil): the scene the Placer puts in the world (decision 0031).
## An item with a `placeable` is held like bare hands; a click puts it down instead of punching.
@export var placeable: PackedScene

## Set for anything that glows (torch, lantern): held in the selected slot it lights the player, placed it lights its spot.
@export var light: LightData
## Held in the hand: where the fist closes, in icon pixels from the icon's centre (a torch: its handle end). Zero = the hand's default `item_offset`.
@export var held_grip := Vector2.ZERO
## Held in the hand: picture size (1 = icon pixels). 0 = HeldItem.icon_scale.
@export var held_scale := 0.0
## Held in the hand: its own picture (an upright torch) instead of the inventory icon. Null = the icon. `held_grip` is then in this picture's pixels.
@export var held_icon: Texture2D
