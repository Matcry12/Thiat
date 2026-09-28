extends Node2D
class_name GuardVisual
## Everything you SEE about guarding that is not the sword's pose: the glow arc
## showing the protected side, the curved shield bar showing how much is left,
## their tint, and the shard burst when the guard breaks. Driven purely by
## on_guard_state() / on_parry_success() / set_aim_angle() / set_cover_degrees()
## / set_tank_fill() / on_break() — the player wires
## these, this node never reaches into Guard (CLAUDE.md rule 5). The sword's
## guard pose itself lives on WeaponVisual (decision 0015).
##
## The shield icon + crack overlay that used to live here are parked for the
## future off-hand shield weapon — see decision 0015, "Parked: the shield icon".

## The direction hint (CoverArc, or any Node2D that replaces it). Turns with
## the aim to show which side is protected.
@export var cover_path: NodePath
## The curved shield bar (a CurveBar). Shown while guarding, while broken and
## while refilling; hidden when full and idle so it does not sit on screen all
## the time.
@export var bar_path: NodePath
## Bar tint while the guard is BROKEN — the empty bar must read as "no guard",
## not just "low".
@export var broken_bar_color := Color(1.0, 0.35, 0.35, 1.0)
@export var parry_modulate := Color(0.4, 0.9, 1.0, 0.9)
@export var block_modulate := Color(0.5, 0.7, 0.85, 1.0)
@export var flash_color := Color(1.0, 1.0, 1.0, 0.9)
@export var flash_time := 0.25
@export var break_effect_time := 0.4
@export var break_shard_count := 10
@export var break_shard_speed := 90.0
@export var break_shard_size := 4.0
@export var break_shard_color := Color(0.6, 0.85, 1.0, 1.0)

var _cover: Node2D
var _bar: CanvasItem
var _fraction := 1.0
var _state := "ready"
var _flash_remaining := 0.0
var _break_remaining := 0.0

func _ready() -> void:
	_cover = get_node_or_null(cover_path) as Node2D
	_bar = get_node_or_null(bar_path) as CanvasItem
	_apply_state()

func on_guard_state(state: String) -> void:
	_state = state
	_apply_state()

func on_parry_success() -> void:
	_flash_remaining = flash_time

func set_aim_angle(radians: float) -> void:
	if _cover:
		_cover.rotation = radians

## Width of the protected side, mirrored from Guard by the player. Duck-typed so
## a Sprite2D glow can replace CoverArc without having the property.
func set_cover_degrees(degrees: float) -> void:
	if _cover and "arc_degrees" in _cover:
		_cover.set("arc_degrees", degrees)

## How much shield is left, 0..1. Duck-typed `value` so the CurveBar can be
## swapped for a TextureProgressBar or a sprite ring later.
func set_tank_fill(fraction: float) -> void:
	_fraction = clampf(fraction, 0.0, 1.0)
	if _bar and "value" in _bar:
		_bar.set("value", _fraction)
	_apply_state()

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
	var guarding := _state == "parry" or _state == "block"
	if _cover:
		_cover.visible = guarding
	if _bar:
		_bar.visible = guarding or _state == "broken" or _fraction < 0.999
		_bar.modulate = broken_bar_color if _state == "broken" else Color.WHITE
	_apply_modulate()

func _apply_modulate() -> void:
	if _cover == null or not _cover.visible:
		return
	var c := parry_modulate if _state == "parry" else block_modulate
	if _flash_remaining > 0.0:
		c = flash_color
	_cover.modulate = c

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
