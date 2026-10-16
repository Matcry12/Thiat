class_name FurnaceCue
extends Node2D
## The in-world progress cue above a furnace (decision 0031): a small fill bar plus a warm glow on the art
## while it smelts. No text. Reads the Furnace by polling; swap this node for a sprite / particles later
## without touching the Furnace.

@export var bar_size := Vector2(28, 5)
@export var bar_offset := Vector2(0, -12)   ## from the top of the art, centred
@export var bg_color := Color(0.05, 0.03, 0.03, 0.85)
@export var fill_color := Color(1.0, 0.62, 0.2)
@export var glow_color := Color(1.35, 1.0, 0.75)   ## art modulate while smelting (>1 brightens)
@export var glow_speed := 5.0
@export var art_path: NodePath = ^"../Art"
@export var furnace_path: NodePath = ^"../../Furnace"

var _furnace: Furnace
var _art: Sprite2D

func _ready() -> void:
	_furnace = get_node_or_null(furnace_path) as Furnace
	_art = get_node_or_null(art_path) as Sprite2D
	if _furnace:
		_furnace.changed.connect(queue_redraw)

func _process(_delta: float) -> void:
	if _furnace == null:
		return
	var on := _furnace.progress_frac() > 0.0 or _furnace.is_running()
	if _art:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * glow_speed)
		_art.self_modulate = Color.WHITE.lerp(glow_color, (0.5 + 0.5 * pulse) if on else 0.0)
	queue_redraw()

func _draw() -> void:
	if _furnace == null or not _furnace.is_running():
		return
	var top := -bar_size.y
	if _art and _art.texture:
		top = _art.position.y * 1.0
	var r := Rect2(Vector2(-bar_size.x * 0.5, top) + bar_offset, bar_size)
	draw_rect(r, bg_color)
	draw_rect(Rect2(r.position, Vector2(r.size.x * _furnace.progress_frac(), r.size.y)), fill_color)
