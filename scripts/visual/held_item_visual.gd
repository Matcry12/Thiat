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

## Chest hold of non-glowing items (bread, wood, workbench): pose, draw layer and eating bob. Data: data/held_item/chest_hold.tres.
@export var chest: ChestHoldData = preload("res://data/held_item/chest_hold.tres")

var _item: ItemData
var _eating := false
var _eat_t := 0.0
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
	z_as_relative = true
	z_index = 0
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

func _process(delta: float) -> void:
	_eat_t = _eat_t + delta if _eating else 0.0
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

## A shown non-glowing item: held with both hands in front of the chest.
func chest_held() -> bool:
	return visible and _item != null and _item.light == null and _item.category in ["material", "placeable"]

## Chest hold: centre the picture at `origin` (player origin + body bob) + chest_offset, drawn above the hands. `left` = body faces left.
func chest_at(origin: Vector2, left: bool) -> void:
	flip_h = false
	z_as_relative = false
	z_index = chest.z
	global_position = origin + _mirror(Vector2(chest.offset_x, chest.hand_y + chest.rest_overlap - _size().y * 0.5), left) + Vector2(0.0, bob_y())

## Eating on / off (player.gd pushes Consumer.is_eating() every frame).
func set_eating(on: bool) -> void:
	_eating = on

## This frame's eat-bob offset in px (y): -chest.bob_px in the first half of each bob, else 0. 0 when not eating. Hands add it too.
func bob_y() -> float:
	if not _eating:
		return 0.0
	return -chest.bob_px if fmod(_eat_t * chest.bob_hz, 1.0) < 0.5 else 0.0

## World point of one hand in chest hold: under the picture's bottom corners. `off` = the free hand (the far side from the facing).
func chest_hand_point(origin: Vector2, left: bool, off: bool) -> Vector2:
	var dx := maxf(_size().x * 0.5, chest.hand_min_spread) * (-1.0 if off else 1.0)
	return origin + _mirror(Vector2(chest.offset_x + dx, chest.hand_y), left) + Vector2(0.0, bob_y())

func _size() -> Vector2:
	return texture.get_size() * _scale() if texture != null else Vector2.ZERO

func _mirror(v: Vector2, left: bool) -> Vector2:
	return Vector2(-v.x if left else v.x, v.y)

func status_text() -> String:
	return "held item: %s  light: %s  mode: %s  bob: %s" % [String(_item.id) if _item else "-", "on" if _light != null else "-", "chest" if chest_held() else "side", "eating" if _eating else "-"]

## Chest hold: `chest.icon_size` / the icon's canvas width. Else the item's own held size if it has one (a torch is bigger than a wood icon), else `icon_scale`.
func _scale() -> float:
	if chest_held():
		return chest.icon_size / maxf(_item.icon.get_size().x, 1.0)
	return _item.held_scale if _item != null and _item.held_scale > 0.0 else icon_scale
