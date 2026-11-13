extends Sprite2D
class_name HandVisual
## One visible hand of the player (0065). Read-only follower, nothing reaches in. Both hands rest on their own marker on one side of the body (idle, run,
## weapon hidden): x mirrors with the body, y follows the body frames. While the weapon shows the holding hand goes to `MainHandGrip` (or the held item), the free hand to `OffHandGrip`.
## Process order: the holding hand sits after WeaponVisual, the free hand has process_priority 1, so both read this frame's swing pose.
## The free hand sits before Visual in the scene: at rest it is drawn behind the body. Never rotates: a round pixel hand stays crisp.

@export var hand_on := true
## 0 = the body's own pixel size (rig.body_scale), so the hand's pixels match the body's.
@export_range(0.0, 6.0, 0.05) var hand_scale := 0.0
## Draw layer at rest. 0 + placed before Visual in the scene = behind the body.
@export var hand_z := 2
## Draw layer while holding, above the weapon, so the fingers close over the handle.
@export var hold_z := 2
## Holding a material / placeable: px from the icon's centre, so the hand holds its lower edge instead of covering it.
@export var item_offset := Vector2(0, 9)
## The marker this hand rests on.
@export var rest_marker: NodePath = ^"../MainHandRest"
## Live offset on top of the rest marker.
@export var rest_nudge := Vector2.ZERO
## While running, at rest: px per run frame, x toward the facing side, y down. Changes only when the body frame changes, so it steps. Each hand has its own table: arms swing opposite ways, the hand coming forward rises. Empty = no swing.
@export var run_swing := PackedVector2Array([Vector2(3, -3), Vector2.ZERO, Vector2(-3, 0), Vector2.ZERO])
## The free hand: holds `OffHandGrip` instead of `MainHandGrip` / the held item. Never holds an item.
@export var off_hand := false
## Free hand only: hold the weapon's `OffHandGrip` marker. Off, or no marker = it stays at rest (one-handed).
@export var use_off_grip := true

@onready var _weapon: WeaponVisual = get_node("../WeaponVisual")
@onready var _held: HeldItemVisual = get_node("../WeaponVisual/HeldItem")
@onready var _body: SpriteActorVisual = get_node("../Visual")

var _at := "rest"

## Where the hand holds something this frame, or null = nothing, rest. Fists have no Grip marker: bare hands stay at rest.
func _hold_point() -> Variant:
	if not _weapon.visible:
		return null
	if off_hand:
		if _held.visible:   # a held item (torch, wood) is one-handed: the free hand stays at rest
			return null
		_at = "off_grip"
		return _weapon.picture_grip_tip().get("off_grip") if use_off_grip else null
	if _held.visible and _held.keeps_shown():   # carried (torch): the hand keeps its idle / walk pose, the item follows the hand
		return null
	if _held.visible:
		_at = "item"
		var g: Variant = _held.grip_point()
		return g if g != null else _held.global_position + item_offset
	var model := _weapon.get_model()
	_at = "grip"
	return _weapon.picture_grip_tip().get("grip") if model and model.has_node("MainHandGrip") else null

func _process(_delta: float) -> void:
	visible = hand_on and not _body.is_dead()
	if not visible:
		return
	var s := hand_scale if hand_scale > 0.0 else (_body.rig.body_scale.x if _body.rig else 1.0)
	var hold: Variant = _hold_point()
	var p: Vector2
	if hold != null:
		p = hold
		z_index = hold_z
	else:
		_at = "rest"
		z_index = hand_z
		var o: Vector2 = (get_node(rest_marker) as Node2D).position + rest_nudge + (_body.hand_frame_offset() / s).round() * s   # whole body pixels: steps, never slides
		var f := _body.run_frame()
		if f >= 0 and not run_swing.is_empty():
			o += run_swing[f % run_swing.size()]
		p = get_parent().global_position + Vector2(-o.x if _body.is_facing_left() else o.x, o.y)
	global_transform = Transform2D(0.0, Vector2.ONE * s, 0.0, p)
	if not off_hand and hold == null and _held.visible and _held.keeps_shown():
		_at = "rest, carrying"
		_held.carry_at(p, _body.is_facing_left())

func status_text() -> String:
	return "hand: %s at %s  (%.0f, %.0f) from player" % ["on" if visible else "off", _at, position.x, position.y]
