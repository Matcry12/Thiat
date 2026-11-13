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
var _light: LightSource

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
	flip_h = false
	position = grip_offset   # a carried item (torch) was moved to the hand: start from the grip again
	var show_it := item != null and item.category in ["material", "placeable"] and item.icon != null
	texture = (item.held_icon if item.held_icon != null else ItemIcon.crop(item.icon)) if show_it else null
	visible = show_it
	if _light != null:
		_light.queue_free()
		_light = null
	if item != null and item.light != null:   # a glowing item lights the player while it is the selected slot
		_light = item.light.make()
		# On the player, not under WeaponVisual: that is hidden when idle, and a hidden parent hides the light.
		get_tree().get_first_node_in_group("player").add_child(_light)
		_follow_light()

func _follow_light() -> void:
	if _light != null:
		_light.global_position = global_position + _item.light.offset

func _process(_delta: float) -> void:
	_follow_light()
	if visible:   # upright, same size whatever the parent's aim rotation / mirror
		global_transform = Transform2D(0.0, Vector2.ONE * _scale(), 0.0, global_position)

## Where the hand holds the shown item this frame, or null = use the hand's default offset.
func grip_point() -> Variant:
	if _item == null or _item.held_grip == Vector2.ZERO:
		return null
	return global_position + _item.held_grip * _scale()

## Carried at the hand's idle / walk pose (a torch): put the picture so its `held_grip` sits on `hand`. HandVisual calls it every frame.
## `left` = the body faces left: the picture and its grip mirror with it.
func carry_at(hand: Vector2, left: bool) -> void:
	flip_h = left
	var g := Vector2(-_item.held_grip.x if left else _item.held_grip.x, _item.held_grip.y)
	global_position = hand - g * _scale()

## A glowing item (torch) stays in the hand while idle: you carry it, you don't put it away.
func keeps_shown() -> bool:
	return _item != null and _item.light != null

func status_text() -> String:
	return "held item: %s  light: %s" % [String(_item.id) if _item else "-", "on" if _light != null else "-"]

## The item's own held size if it has one (a torch is bigger than a wood icon), else `icon_scale`.
func _scale() -> float:
	return _item.held_scale if _item != null and _item.held_scale > 0.0 else icon_scale
