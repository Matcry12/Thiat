extends Sprite2D
class_name HeldItemVisual
## The item in the hand when it is not a weapon or tool (wood, stone, a workbench): its inventory icon at the grip.
## Child of WeaponVisual, so it follows the aim; it stays upright and never mirrored. Driven only by set_item()
## (player.gd, every frame, cheap): no combat code reaches in. Empty hand / weapon / tool = hidden.
## Swap-in note: a real held-item sprite replaces this node, same set_item() contract.

## Size of the icon in the hand (1 = icon's own pixels).
@export var icon_scale := 0.75
## Where the icon sits, in aim space: x toward the aim, y to the right of it.
@export var grip_offset := Vector2(14, 6): set = _set_grip_offset

var _item: ItemData

func _ready() -> void:
	visible = false
	position = grip_offset

func _set_grip_offset(v: Vector2) -> void:
	grip_offset = v
	position = v

## `item` = what the selected slot holds, or null. Only materials and placeables show.
func set_item(item: ItemData) -> void:
	if item == _item:
		return
	_item = item
	var show_it := item != null and item.category in ["material", "placeable"] and item.icon != null
	texture = ItemIcon.crop(item.icon) if show_it else null
	visible = show_it

func _process(_delta: float) -> void:
	if visible:   # upright, same size whatever the parent's aim rotation / mirror
		global_transform = Transform2D(0.0, Vector2.ONE * icon_scale, 0.0, global_position)

func status_text() -> String:
	return "held item: %s" % (String(_item.id) if _item else "-")
