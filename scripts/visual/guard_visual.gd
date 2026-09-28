extends Node2D
class_name GuardVisual
## Shield + crack-overlay sprites, driven purely by on_guard_state()/
## on_parry_success()/set_aim_angle()/set_tank_fill()/on_break() — the player
## wires these, this node never reaches into Guard (CLAUDE.md rule 5). Flat
## 2D: no perspective squashing.
##
## The crack overlay is a SHARED effect (decision 0013): any shield texture
## gets the same cracks laid over it, so a wooden/iron/magic shield later
## needs no cracked variant of its own. Nothing here may assume a texture
## size or pixel offset for either sprite.
##
## ONE OWNER: this script only ever writes Shield/Cracks modulate (and its
## own rotation when `face_aim` is on). The Shield's position/scale are the
## user's to drag in the editor — see godot-gotchas.md / "one owner per
## property".
##
## Cracks is a CHILD of Shield, not a sibling. As siblings they each had their
## own position and nothing kept them together: the user dragged the shield to
## the middle of the player and the cracks stayed floating 26px to the right.
## As a child, wherever the shield goes the cracks go — there is one position,
## and it belongs to the user.

## Off (default): the shield is a STATUS icon — upright, wherever it was
## dragged, showing THAT you are defending and how much shield is left.
## On: the node turns to face the aim, for art that is a plate held in front.
@export var face_aim := false
@export var shield_path: NodePath
## The direction hint (CoverArc, or any Node2D that replaces it). ALWAYS turns
## with the aim, even when the shield icon itself stays upright.
@export var cover_path: NodePath
@export var cracks_path: NodePath
@export var parry_modulate := Color(0.4, 0.9, 1.0, 0.9)
@export var block_modulate := Color(0.5, 0.7, 0.85, 1.0)
@export var flash_color := Color(1.0, 1.0, 1.0, 0.9)
@export var flash_time := 0.25
@export var crack_curve := 1.0  ## >1 = cracks appear later, <1 = earlier
@export var break_effect_time := 0.4
@export var break_shard_count := 10
@export var break_shard_speed := 90.0
@export var break_shard_size := 4.0
@export var break_shard_color := Color(0.6, 0.85, 1.0, 1.0)

var _cover: Node2D
var _shield: Sprite2D
var _cracks: Sprite2D
var _state := "ready"
var _fraction := 1.0
var _flash_remaining := 0.0
var _break_remaining := 0.0

func _ready() -> void:
	_shield = get_node_or_null(shield_path) as Sprite2D
	_cracks = get_node_or_null(cracks_path) as Sprite2D
	_cover = get_node_or_null(cover_path) as Node2D
	_apply_state()

func on_guard_state(state: String) -> void:
	_state = state
	_apply_state()

func on_parry_success() -> void:
	_flash_remaining = flash_time

func set_aim_angle(radians: float) -> void:
	rotation = radians if face_aim else 0.0
	if _cover:
		# Relative to this node: if face_aim already turned us, don't turn twice.
		_cover.rotation = 0.0 if face_aim else radians

## Width of the protected side, mirrored from Guard by the player. Duck-typed so
## a Sprite2D glow can replace CoverArc without having the property.
func set_cover_degrees(degrees: float) -> void:
	if _cover and "arc_degrees" in _cover:
		_cover.set("arc_degrees", degrees)

## Cracks are transparency-only, never a crop/resize of either sprite: full
## tank -> invisible cracks, empty tank -> full-strength cracks.
func set_tank_fill(fraction: float) -> void:
	_fraction = clampf(fraction, 0.0, 1.0)
	_apply_crack_alpha(_current_color())

func on_break() -> void:
	_break_remaining = break_effect_time
	queue_redraw()

func _process(delta: float) -> void:
	var redraw := false
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(0.0, _flash_remaining - delta)
		redraw = true
	if _break_remaining > 0.0:
		_break_remaining = maxf(0.0, _break_remaining - delta)
		redraw = true
	_apply_modulate()
	if redraw:
		queue_redraw()

func _apply_state() -> void:
	var visible_now: bool = _state == "parry" or _state == "block"
	if _shield:
		_shield.visible = visible_now   # Cracks is a child: it hides with the shield
	if _cover:
		_cover.visible = visible_now
	_apply_modulate()

func _current_color() -> Color:
	var c := parry_modulate if _state == "parry" else block_modulate
	if _flash_remaining > 0.0:
		c = flash_color
	return c

func _apply_modulate() -> void:
	var c := _current_color()
	if _shield and _shield.visible:
		_shield.modulate = c
	if _cover and _cover.visible:
		_cover.modulate = c             # same parry/block/flash tint as the shield
	_apply_crack_alpha(c)

## Alpha only, RGB stays white: Cracks is a child of Shield, so it already
## INHERITS the shield's parry/block tint. Copying the tint here as well would
## multiply it in twice and turn the cracks muddy.
func _apply_crack_alpha(_rgb_source: Color) -> void:
	if _cracks == null:
		return
	_cracks.modulate = Color(1.0, 1.0, 1.0, pow(1.0 - _fraction, crack_curve))

func _draw() -> void:
	if _break_remaining <= 0.0:
		return
	var t := 1.0 - _break_remaining / break_effect_time
	var alpha := 1.0 - t
	var dist := break_shard_speed * break_effect_time * t
	# Burst from wherever the user dragged the shield (read, never written).
	var origin := _shield.position if _shield else Vector2.ZERO
	for i in break_shard_count:
		var angle := TAU * float(i) / break_shard_count
		var pos := origin + Vector2.RIGHT.rotated(angle) * dist
		var c := break_shard_color
		c.a *= alpha
		var half := break_shard_size * 0.5
		draw_rect(Rect2(pos - Vector2(half, half), Vector2(break_shard_size, break_shard_size)), c)
