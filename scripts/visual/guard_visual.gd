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
## ONE OWNER: this script only ever writes Shield/Cracks modulate, and
## rotates ITSELF (not the sprites). Their position/scale/offset are the
## user's to drag in the editor — see godot-gotchas.md / "one owner per
## property".

@export var shield_path: NodePath
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

var _shield: Sprite2D
var _cracks: Sprite2D
var _state := "ready"
var _fraction := 1.0
var _flash_remaining := 0.0
var _break_remaining := 0.0

func _ready() -> void:
	_shield = get_node_or_null(shield_path) as Sprite2D
	_cracks = get_node_or_null(cracks_path) as Sprite2D
	_apply_state()

func on_guard_state(state: String) -> void:
	_state = state
	_apply_state()

func on_parry_success() -> void:
	_flash_remaining = flash_time

func set_aim_angle(radians: float) -> void:
	rotation = radians

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
		_shield.visible = visible_now
	if _cracks:
		_cracks.visible = visible_now
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
	_apply_crack_alpha(c)

func _apply_crack_alpha(rgb_source: Color) -> void:
	if _cracks == null or not _cracks.visible:
		return
	var c := rgb_source
	c.a = pow(1.0 - _fraction, crack_curve)
	_cracks.modulate = c

func _draw() -> void:
	if _break_remaining <= 0.0:
		return
	var t := 1.0 - _break_remaining / break_effect_time
	var alpha := 1.0 - t
	var dist := break_shard_speed * break_effect_time * t
	for i in break_shard_count:
		var angle := TAU * float(i) / break_shard_count
		var pos := Vector2.RIGHT.rotated(angle) * dist
		var c := break_shard_color
		c.a *= alpha
		var half := break_shard_size * 0.5
		draw_rect(Rect2(pos - Vector2(half, half), Vector2(break_shard_size, break_shard_size)), c)
