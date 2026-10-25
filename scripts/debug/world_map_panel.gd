extends PanelContainer
class_name WorldMapPanel
## F3 "World map" button: the WHOLE island as a small picture (1 px per cell, scaled to `map_width`). Biome colours, water in blues,
## markers for home (white), boss (red) and you (yellow). Redraws after every map rebuild, so releasing a map slider shows the new world.
## Debug UI only, child of the TuningPanel's root; nothing in the game reads it.

@export var map_width := 400.0
@export var marker_radius := 4.0
@export var home_color := Color(1, 1, 1)
@export var boss_color := Color(1, 0.15, 0.15)
@export var player_color := Color(1, 0.9, 0.1)

var _map: ArenaMap
var _player: Node2D
var _tex: TextureRect
var _marks: Control
var _stale := true
var drawn_count := 0   ## how many times the picture was rebuilt (tests)


func setup(map: ArenaMap, player: Node2D) -> void:
	_map = map
	_player = player
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_content_margin_all(6)
	add_theme_stylebox_override("panel", bg)
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "World map   (white = home, red = boss, yellow = you)"
	title.add_theme_font_size_override("font_size", 12)
	box.add_child(title)
	_tex = TextureRect.new()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_tex)
	_marks = Control.new()
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	_tex.add_child(_marks)
	map.rebuilt.connect(func() -> void:
		_stale = true
		if visible:
			refresh())


func toggle() -> void:
	visible = not visible
	if visible and _stale:
		refresh()


func refresh() -> void:
	var res := _map.result
	if res == null:
		return
	_tex.texture = ImageTexture.create_from_image(GroundBaker.world_map_image(res))
	_tex.custom_minimum_size = Vector2(map_width, map_width * res.rows / maxf(res.cols, 1.0))
	_tex.size = _tex.custom_minimum_size
	_stale = false
	drawn_count += 1


func _process(_delta: float) -> void:
	if visible:
		_marks.queue_redraw()


func _draw_marks() -> void:
	if _map == null or _map.result == null or _map.cell_px() <= 0.0:
		return
	var k := _marks.size / Vector2(_map.result.cols, _map.result.rows) / _map.cell_px()
	_marker(_map.home_point() * k, home_color)
	_marker(_map.boss_point() * k, boss_color)
	if _player:
		_marker(_player.global_position * k, player_color)


func _marker(at: Vector2, color: Color) -> void:
	_marks.draw_circle(at, marker_radius + 1.5, Color.BLACK)
	_marks.draw_circle(at, marker_radius, color)
