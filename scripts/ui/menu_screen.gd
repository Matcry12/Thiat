class_name MenuScreen
extends Control
## A full-screen menu page (W8, decision 0040; looks = Island Workshop, DESIGN.md 6-7): dim, then baked planks / buttons at
## whole-number 2x. Used by the title screen (style TITLE: logo plaque + panel) and the pause menu (style PAUSE: "Paused" plank).
## Settings page = the shared SettingsPanel, swapped in for the button list. Parts + positions: assets/ui/game/README.md.
## `items`: Array of {text, cb (Callable), enabled (bool, default true)}; {text, settings: true} opens the settings page.

enum Style { TITLE, PAUSE }
const SKIN := "res://data/ui/inventory_skin.tres"
const ARROW_POS := Vector2(5, 7)   ## the hover arrow, art px from the button's top-left
const CANVAS := Vector2(576, 324)   ## the mock canvas, art px
static var _skin: InventorySkin

@export var style := Style.TITLE
@export var title_text := "Paused"   ## PAUSE header plank text
@export var version_text := "v0.9"
@export var ground_color := Color8(46, 90, 34)   ## TITLE only: behind the dim (there is no world yet)
@export var use_dim := true   ## false = draw no dim here (a caller that dims already)
@export_group("Layout (art px)")
@export var button_art_size := Vector2i(122, 20)   ## TITLE button (image is 3 px taller: shadow)
@export var pause_button_art_size := Vector2i(138, 20)
@export var button_step := 26   ## art px between TITLE buttons
@export var pause_button_step := 28
@export var button_origin := Vector2i(14, 15)   ## TITLE: first button, relative to the panel box
@export var pause_button_origin := Vector2i(16, 39)
@export var header_y := 4   ## PAUSE header text top, from the panel box top
@export var title_panel_y := 112   ## TITLE panel box top (mock 576x324)
@export var logo_y := 40
@export var plaque_pad := Vector2i(16, 10)
@export var rope_y := 37
@export var version_pos := Vector2i(8, 310)

var items: Array = []
var _list: Control
var _settings: SettingsPanel
var _buttons := {}
var _stage: Control
var _rebuild_queued := false

static func skin() -> InventorySkin:
	if _skin == null:
		_skin = load(SKIN)
	return _skin

## A menu button (art_size = the real button, e.g. 122x20; the picture is 3 art px taller for its shadow).
## The text outline follows the state (hot = focused or hovered): it is set when the state CHANGES, never inside the draw.
static func make_button(text: String, art_size: Vector2i, primary := false) -> Button:
	var sk := skin()
	var sc := sk.art_scale
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(art_size.x, art_size.y + 3) * sc
	b.size = b.custom_minimum_size
	b.add_theme_font_override("font", sk.ui_font("bold"))
	b.add_theme_font_size_override("font_size", PixelArt.font_px(sk, "bold"))
	var p := "button_menu_primary" if primary else "button_menu_idle"
	var pp := "button_menu_primary_pressed" if primary else "button_menu_pressed"
	var idle := PixelArt.box(sk.button_menu_primary_tex if primary else sk.button_menu_idle_tex, p, sc)
	var hover := idle if primary else PixelArt.box(sk.button_menu_hover_tex, "button_menu_hover", sc)
	var down := PixelArt.box(sk.button_menu_primary_pressed_tex if primary else sk.button_menu_pressed_tex, pp, sc)
	b.add_theme_stylebox_override("normal", idle)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("hover_pressed", down)
	b.add_theme_stylebox_override("disabled", PixelArt.box(sk.button_menu_disabled_tex, "button_menu_disabled", sc))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new() if primary else hover)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, sk.pal_cream)
	b.add_theme_color_override("font_disabled_color", sk.pal_muted.lightened(0.3))
	b.add_theme_constant_override("outline_size", sk.text_outline_size)
	var st := {"hover": false, "focus": false}   # tracked here: has_focus() / is_hovered() still show the old state inside the exit signals
	var sync := func():
		var oc := sk.text_outline_color
		if b.disabled:
			oc = sk.pal_line.lerp(sk.pal_paper, 0.35)
		elif st.hover or st.focus:
			oc = sk.pal_line
		b.add_theme_color_override("font_outline_color", oc)
		b.queue_redraw()
	b.mouse_entered.connect(func():
		st.hover = true
		if not b.disabled:
			b.grab_focus()   # one arrow: the hovered one is the focused one
		sync.call())
	b.mouse_exited.connect(func():
		st.hover = false
		sync.call())
	b.focus_entered.connect(func():
		st.focus = true
		sync.call())
	b.focus_exited.connect(func():
		st.focus = false
		sync.call())
	b.draw.connect(func():
		if not b.disabled and (st.hover or st.focus):
			PixelArt.draw_pic(b, sk.menu_arrow_tex, ARROW_POS * sc, sc))
	b.set_meta("sync_outline", sync)
	sync.call()
	return b

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skin().changed.connect(_on_skin_changed)
	_build()
	if is_visible_in_tree():
		focus_first()

func _exit_tree() -> void:
	if skin().changed.is_connected(_on_skin_changed):
		skin().changed.disconnect(_on_skin_changed)

## F3 / inspector edits to the skin (art scale, outline, dim, textures): the page is rebuilt once, next frame, keeping its page and focus.
func _on_skin_changed() -> void:
	if not _rebuild_queued:
		_rebuild_queued = true
		_rebuild.call_deferred()

func _rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	var on_settings := on_settings_page()
	var focused := ""
	for k in _buttons:
		if (_buttons[k] as Button).has_focus():
			focused = k
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_buttons.clear()
	_build()
	if on_settings:
		show_settings()
	elif is_visible_in_tree():
		if _buttons.has(focused) and not (_buttons[focused] as Button).disabled:
			(_buttons[focused] as Button).grab_focus()
		else:
			focus_first()

func _build() -> void:
	var sk := skin()
	var sc := sk.art_scale
	var ground := ColorRect.new()
	ground.name = "Ground"
	ground.color = ground_color
	ground.visible = style == Style.TITLE
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(sk.dim_color, sk.dim_alpha_menu if style == Style.TITLE else sk.dim_alpha_pause)
	dim.visible = use_dim
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	# the stage = the mock canvas (576x324 art px) at `sc`, centred; parts sit at mock coordinates
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.set_anchors_preset(Control.PRESET_CENTER)
	_stage.custom_minimum_size = CANVAS * sc
	_stage.offset_left = -CANVAS.x * 0.5 * sc
	_stage.offset_right = CANVAS.x * 0.5 * sc
	_stage.offset_top = -CANVAS.y * 0.5 * sc
	_stage.offset_bottom = CANVAS.y * 0.5 * sc
	add_child(_stage)
	_list = Control.new()
	_list.name = "Page"
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_list)
	var bsize := button_art_size if style == Style.TITLE else pause_button_art_size
	var panel_w := 150 if style == Style.TITLE else 170
	var panel_h := 128 if style == Style.TITLE else 130
	var box := Vector2((CANVAS.x - panel_w) / 2, title_panel_y if style == Style.TITLE else (CANVAS.y - panel_h) / 2)
	if style == Style.TITLE:
		_title_art(sk, sc)
		_list.add_child(PixelArt.pic(sk.panel_title_tex, sc, box - Vector2(8, 8)))
	else:
		_list.add_child(PixelArt.pic(sk.panel_pause_tex, sc, box - Vector2(8, 8)))
		var h := PixelArt.label(title_text, sk, "bold", sk.pal_cream, true, false, Color(0, 0, 0, 0), 2)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.position = (box + Vector2(0, header_y)) * sc
		h.size = Vector2(panel_w * sc, PixelArt.font_px(sk, "bold", 2))
		_list.add_child(h)
	var origin := Vector2(button_origin if style == Style.TITLE else pause_button_origin)
	var step := button_step if style == Style.TITLE else pause_button_step
	for i in items.size():
		var it: Dictionary = items[i]
		var b := make_button(it["text"], bsize, style == Style.TITLE and i == 0)
		b.disabled = not it.get("enabled", true)
		b.get_meta("sync_outline").call()   # `disabled` changed after the button was built
		b.pressed.connect(show_settings if it.get("settings", false) else it["cb"])
		b.position = (box + origin + Vector2(0, step * i)) * sc
		_list.add_child(b)
		_buttons[it["text"]] = b
	if style == Style.TITLE and version_text != "":
		var v := PixelArt.label(version_text, sk, "body", sk.pal_paper)
		v.position = Vector2(version_pos) * sc
		_list.add_child(v)
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.back_pressed.connect(back)
	_stage.add_child(_settings)
	_settings.position = (CANVAS * 0.5 - _settings.size / sc / 2.0) * sc

func _title_art(sk: InventorySkin, sc: int) -> void:
	var logo_box_w := 216
	var tx := (576 - logo_box_w) / 2
	_list.add_child(PixelArt.pic(sk.title_plaque_tex, sc, Vector2(tx - plaque_pad.x - 8, logo_y - plaque_pad.y - 8)))
	_list.add_child(PixelArt.pic(sk.title_logo_tex, sc, Vector2(tx - 2, logo_y - 2)))
	_list.add_child(PixelArt.pic(sk.title_rope_tex, sc, Vector2(tx, logo_y + rope_y - 3)))

func button(text: String) -> Button:
	return _buttons.get(text)

func show_settings() -> void:
	_list.visible = false
	_settings.visible = true
	_settings.refresh()

## Keyboard focus on the first enabled button (call when the list is shown).
func focus_first() -> void:
	for b in _buttons.values():
		if not (b as Button).disabled:
			b.grab_focus()
			return

## Settings page -> button list. Returns false when it was already on the list (nothing to go back from).
func back() -> bool:
	if not _settings.visible:
		return false
	_settings.visible = false
	_list.visible = true
	if is_visible_in_tree():
		focus_first()
	return true

func on_settings_page() -> bool:
	return _settings != null and _settings.visible

func settings_panel() -> SettingsPanel:
	return _settings
