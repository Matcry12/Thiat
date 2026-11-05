class_name CraftWindow
extends Control
## The bag + crafting book (decisions 0029 / 0031, look = Island Workshop, docs/design/DESIGN.md section 6-7).
## Tab / I opens ONE window: an open book on top (left page = a 6 x 4 grid of recipe icons, right page = the chosen
## recipe: ingredients with have / need, a quantity stepper and a Craft button), the bag + a hotbar copy below.
## Click an icon = choose it. Craft = the item lands on the cursor (put it in any slot), shift + Craft = straight into
## the inventory. A Furnace tab shows [input] > [progress] > [output] when a furnace is near.
## Pure view: it reads Crafter / Inventory / Furnace by polling and EMITS requests; the HUD answers them.
## Everything is placed in ART px (1 art px = skin.art_scale screen px, whole numbers) from the baked parts in
## assets/ui/game (README: "Bag + crafting book"). Organic pictures are never stretched.

signal craft_requested(recipe: RecipeData, straight: bool)   ## straight = shift + Craft: into the inventory, not the cursor
signal furnace_input_clicked(shift: bool)
signal furnace_output_clicked(shift: bool)
signal rebuilt   ## the recipe icons are new (the HUD registers their hover names)
signal recipe_chosen(recipe: RecipeData)
signal catalog_clicked(item: ItemData, button: int)   ## a click on an icon of the optional Items tab (left = full stack, right = one: the answerer decides)

const SLOT_SCENE := preload("res://scenes/ui/item_slot.tscn")
const GRID_COLS := 6
const GRID_ROWS := 4

@export var skin: InventorySkin
@export_group("Layout (art px)")
## Book top edge, art px from the screen top (the mock puts it at 14). Horizontally the window is centred.
@export var top_art := 14
## Gap between the book and the bag, art px.
@export var book_bag_gap_art := 6
@export var qty_max := 20
## Content margins of the stepper / Craft buttons (left, top, right, bottom).
@export var btn_content_art := Vector4i(2, 0, 2, 3)
## Craft button text inset right of the hammer / padlock (lit / dim), art px.
@export var craft_text_inset_art := Vector2i(22, 14)
## Longest item name that fits the page beside the item slot, art px.
@export var name_max_art := 108
## Ingredient row height in the well, art px (a 16 px icon + 2).
@export var row_step_art := 18
@export_group("Text")
## Items tab (only with a catalog): left page title and the note under the chosen item.
@export var items_title := "Items"
## Picture for the Items tab and its page title; empty = the first catalog item's own picture.
@export var items_tab_icon: Texture2D
@export var items_note := "Click: full stack.\nRight click: one."
## Description text in the readable default font instead of the pixel one.
@export var clean_desc := false   ## (the pixel font reads better on the book page; this is only a toggle)
## One line under each item name in the book (data, by item id); a missing id falls back to its category.
@export var blurbs := {
	"workbench": "Craft tools and gear.", "furnace": "Melt ore into metal.", "anvil": "Forge strong tools.",
	"stone_axe": "Chops trees faster.", "stone_pickaxe": "Breaks rocks and ore.", "bow": "Shoot from far away.",
	"copper_bar": "Melt ore into metal.", "wooden_sword": "A simple blade.", "copper_axe": "Strong and sharp.",
	"copper_pickaxe": "Digs deeper veins.", "copper_sword": "A keen copper blade.", "sword1": "A light, quick blade.",
		"wood": "Cut from trees.", "stone": "Chipped from rocks.", "copper_ore": "Smelt it in a furnace.", "gel": "Dropped by slimes.",
}
@export var category_blurbs := {
	"material": "A raw material.", "tool": "Helps you gather.", "weapon": "Use it in a fight.", "placeable": "Place it in the world.",
}
@export var furnace_note := "Put ore on the left.\nTake bars on the right."
## Lowest art y the description + "Makes" text may reach (the stepper row starts at 108).
@export var desc_room_art := 104
## Label top nudge, art px (a pixel font's glyph box sits a little high / low in a Label). The screen offset is rounded to whole pixels.
@export var text_dy_art := 1.5

## Furnace progress arrow, built from skin parts on whole art pixels: a track + fill shaft and the baked menu_arrow head.
## `fill` (0..1) paints the shaft from the left in `fill_color`.
class Arrow extends Control:
	var color := Color.WHITE
	var fill_color := Color(1, 0.6, 0.2)
	var head: Texture2D       ## already upscaled
	var art := 2              ## screen px per art px
	var shaft_art := 4        ## shaft thickness, art px
	var fill := 0.0
	func _draw() -> void:
		var hw := head.get_width() if head else 0
		var sh := shaft_art * art
		var y := roundf((size.y - sh) * 0.5 / art) * art
		var w := size.x - hw
		draw_rect(Rect2(0, y, w, sh), color)
		if fill > 0.0:
			draw_rect(Rect2(0, y, floorf(w * clampf(fill, 0.0, 1.0) / art) * art, sh), fill_color)
		if head:
			draw_texture(head, Vector2(w, roundf((size.y - head.get_height()) * 0.5 / art) * art), fill_color if fill >= 1.0 else color)

var _crafter: Crafter
var _inv: Inventory
var _bag: BagPanel
var _hotbar: Hotbar
var _frame: Control        ## the window rectangle (book + bag); the tabs stick out on its left
var _book: Control         ## origin = the book's box top-left
var _cover: TextureRect
var _tab_idle: Array[TextureRect] = []
var _tab_active: TextureRect
var _marker: ItemSlot
var _tab_craft: ItemSlot
var _tab_furnace: ItemSlot
var _title: Label
var _empties: Array[TextureRect] = []
var _craft_page: Control
var _furnace_page: Control
var _grid_box: Control
var _right: Control        ## the chosen-item page (both tabs)
var _sel_slot: ItemSlot
var _name: Label
var _type: Label
var _well: NinePatchRect
var _ing: Control
var _banner: NinePatchRect
var _banner_lock: TextureRect
var _banner_text: Label
var _desc: Label
var _makes: Label
var _steps: Control        ## stepper + Craft row
var _minus: Button
var _plus: Button
var _qty_box: NinePatchRect
var _qty_label: Label
var _craft_btn: Button
var _craft_lock: TextureRect
var _craft_hammer: TextureRect
var _f_in: ItemSlot
var _f_out: ItemSlot
var _f_arrow: Arrow
var _f_note: Label
var _f_in_label: Label
var _f_out_label: Label
var _tab_anvil: ItemSlot
var _tab_items: ItemSlot   ## 4th tab, only while a catalog is set
var catalog: Array[ItemData] = []   ## optional list of items to hand out (set_catalog); empty = no Items tab
var _cat_slots: Array[ItemSlot] = []
var _cat_page := 0
var _cat_sel: ItemData
var _cat_sig := ""
var _hint: TextureRect
var _hint_tint: ColorRect
var _recipe_slots: Array[ItemSlot] = []
var _recipes: Array[RecipeData] = []
var _sel: RecipeData
var _qty := 1
var _signature := ""
var _panel_sig := ""
var _flash_slot: ItemSlot
var _flash_left := 0.0
var _stations_sig := ""
var _tab := "craft"
var _furnace: Furnace
var _applied: InventorySkin
var _can_craft_now := false

func bind(inv: Inventory, loadout: Loadout, c: Crafter) -> void:
	_inv = inv
	_crafter = c
	_hotbar.bind(loadout, inv)
	_bag.bind(inv, _hotbar)

func bag() -> BagPanel:
	return _bag

func hotbar() -> Hotbar:
	return _hotbar

func get_skin() -> InventorySkin:
	if skin == null:
		skin = load("res://data/ui/inventory_skin.tres")
	return skin

## Slides the whole window sideways (px, <= 0): the HUD keeps it clear of the F3 tuning panel.
func set_shift(dx: float) -> void:
	offset_left = dx
	offset_right = dx

func shift() -> float:
	return offset_left

## The window's screen rectangle (empty while closed): the F3 panel keeps clear of it.
func frame_rect() -> Rect2:
	return _frame.get_global_rect() if _frame.visible else Rect2()

func is_open() -> bool:
	return _frame.visible

func recipe_slots() -> Array[ItemSlot]:
	return _recipe_slots

func shown_recipes() -> Array[RecipeData]:
	return _recipes

func marker() -> ItemSlot:
	return _marker

## Give the book an Items tab listing `list` (24 icons a page, same grid as the recipes). An empty list takes the tab away.
func set_catalog(list: Array[ItemData]) -> void:
	catalog = list
	_cat_page = 0
	_cat_sel = list[0] if not list.is_empty() else null
	_cat_sig = ""
	if list.is_empty() and _tab == "items":
		_tab = "craft"

func catalog_slots() -> Array[ItemSlot]:
	return _cat_slots

func catalog_pages() -> int:
	return maxi(ceili(catalog.size() / float(GRID_COLS * GRID_ROWS)), 1)

func catalog_page() -> int:
	return _cat_page

func set_catalog_page(i: int) -> void:
	_cat_page = clampi(i, 0, catalog_pages() - 1)

func catalog_selected() -> ItemData:
	return _cat_sel

## The side tab that opens the Items page (null picture-wise while no catalog is set).
func items_tab() -> ItemSlot:
	return _tab_items

## How many side tabs show now (3, or 4 with a catalog).
func tab_count() -> int:
	return 3 + (1 if not catalog.is_empty() else 0)

func select_tab(name: String) -> void:
	_tab = name

func tab_slots() -> Array[ItemSlot]:
	return [_tab_craft, _tab_furnace, _tab_items]   # the Items tab is hidden (no hover) until a catalog is set

func current_tab() -> String:
	return _tab

func furnace_slots() -> Array[ItemSlot]:
	return [_f_in, _f_out]

func furnace_fraction() -> float:
	return _f_arrow.fill

func current_furnace() -> Furnace:
	return _furnace

func craft_visible() -> bool:
	return _craft_page.visible

func furnace_visible() -> bool:
	return _furnace_page.visible

func hint_icon() -> TextureRect:
	return _hint

func selected_recipe() -> RecipeData:
	return _sel

func quantity() -> int:
	return _qty

func craft_button() -> Button:
	return _craft_btn

## Is the Craft button lit (the chosen recipe can be made `quantity()` times now)?
func craft_enabled() -> bool:
	return _can_craft_now

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP   # the window eats clicks: no sword swing through it
	_frame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_frame.visible = false
	add_child(_frame)

	_book = Control.new()
	_book.name = "Book"
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_book)
	for i in 3:   # tabs tucked BEHIND the cover
		var t := TextureRect.new()
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.stretch_mode = TextureRect.STRETCH_KEEP
		_book.add_child(t)
		_tab_idle.append(t)
	_cover = TextureRect.new()
	_cover.name = "Cover"
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.stretch_mode = TextureRect.STRETCH_KEEP
	_book.add_child(_cover)

	_title = _label()
	_book.add_child(_title)
	_marker = _icon_slot(-1, false)
	_book.add_child(_marker)
	for i in GRID_COLS * GRID_ROWS:
		var e := TextureRect.new()
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		e.stretch_mode = TextureRect.STRETCH_KEEP
		_book.add_child(e)
		_empties.append(e)

	# --- left page, crafting tab: the recipe icons
	_craft_page = Control.new()
	_craft_page.name = "CraftArea"
	_craft_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_craft_page)
	_grid_box = Control.new()
	_grid_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_craft_page.add_child(_grid_box)

	# --- left page, furnace tab: [input] > [progress arrow] > [output]
	_furnace_page = Control.new()
	_furnace_page.name = "FurnaceArea"
	_furnace_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_furnace_page)
	_f_in = SLOT_SCENE.instantiate()
	_f_in.index = 0
	_f_in.icon_top_art = 3
	_f_in.slot_clicked.connect(func(_i: int, b: int, sh: bool): if b == MOUSE_BUTTON_LEFT: furnace_input_clicked.emit(sh))
	_furnace_page.add_child(_f_in)
	_f_in_label = _label()
	_f_in_label.text = "Ore"
	_furnace_page.add_child(_f_in_label)
	_f_out_label = _label()
	_f_out_label.text = "Bar"
	_furnace_page.add_child(_f_out_label)
	_f_arrow = Arrow.new()
	_f_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_furnace_page.add_child(_f_arrow)
	_f_out = SLOT_SCENE.instantiate()
	_f_out.index = 1
	_f_out.icon_top_art = 3
	_f_out.slot_clicked.connect(func(_i: int, b: int, sh: bool): if b == MOUSE_BUTTON_LEFT: furnace_output_clicked.emit(sh))
	_furnace_page.add_child(_f_out)

	# --- right page: the chosen item
	_right = Control.new()
	_right.name = "Chosen"
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_right)
	_sel_slot = SLOT_SCENE.instantiate()
	_sel_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sel_slot.icon_top_art = 3
	_right.add_child(_sel_slot)
	_name = _label()
	_right.add_child(_name)
	_type = _label()
	_right.add_child(_type)
	_well = NinePatchRect.new()
	_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right.add_child(_well)
	_ing = Control.new()
	_ing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right.add_child(_ing)
	_banner = NinePatchRect.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right.add_child(_banner)
	_banner_lock = TextureRect.new()
	_banner_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_lock.stretch_mode = TextureRect.STRETCH_KEEP
	_banner.add_child(_banner_lock)
	_banner_text = _label()
	_banner.add_child(_banner_text)
	_desc = _label()
	_desc.autowrap_mode = TextConfig.WRAP
	_right.add_child(_desc)
	_makes = _label()
	_right.add_child(_makes)
	_steps = Control.new()
	_steps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right.add_child(_steps)
	_minus = Button.new()
	_minus.text = "<"
	_minus.focus_mode = Control.FOCUS_NONE
	_minus.pressed.connect(func():
		if _tab == "items":
			set_catalog_page(_cat_page - 1)
		else:
			_qty = maxi(_qty - 1, 1))
	_steps.add_child(_minus)
	_qty_box = NinePatchRect.new()
	_qty_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_steps.add_child(_qty_box)
	_qty_label = _label()
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qty_box.add_child(_qty_label)
	_plus = Button.new()
	_plus.text = ">"
	_plus.focus_mode = Control.FOCUS_NONE
	_plus.pressed.connect(func():
		if _tab == "items":
			set_catalog_page(_cat_page + 1)
		else:
			_qty = mini(_qty + 1, qty_max))
	_steps.add_child(_plus)
	_craft_btn = Button.new()
	_craft_btn.text = "Craft"
	_craft_btn.focus_mode = Control.FOCUS_NONE
	_craft_btn.pressed.connect(func(): craft_selected(Input.is_key_pressed(KEY_SHIFT)))
	_steps.add_child(_craft_btn)
	_craft_hammer = TextureRect.new()
	_craft_hammer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_craft_hammer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_craft_hammer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_craft_btn.add_child(_craft_hammer)
	_craft_lock = TextureRect.new()
	_craft_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_craft_lock.stretch_mode = TextureRect.STRETCH_KEEP
	_craft_btn.add_child(_craft_lock)

	_f_note = _label()
	_f_note.autowrap_mode = TextConfig.WRAP
	_right.add_child(_f_note)

	# --- the tab pictures in FRONT of the cover, and the clickable icons on them
	_tab_active = TextureRect.new()
	_tab_active.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_active.stretch_mode = TextureRect.STRETCH_KEEP
	_book.add_child(_tab_active)
	_tab_craft = _icon_slot(0, true)
	_book.add_child(_tab_craft)
	_tab_furnace = _icon_slot(1, true)
	_book.add_child(_tab_furnace)
	_tab_anvil = _icon_slot(2, true)
	_book.add_child(_tab_anvil)
	_tab_items = _icon_slot(3, true)
	_book.add_child(_tab_items)

	# --- bag + hotbar copy (the bag is the existing BagPanel)
	_bag = BagPanel.new()
	_bag.name = "Bag"
	_frame.add_child(_bag)
	_hotbar = Hotbar.new()
	_hotbar.name = "HotbarCopy"
	_frame.add_child(_hotbar)

	# --- the lock icon (shown when the window cannot open): lives on the always-visible root
	_hint = TextureRect.new()
	_hint.name = "LockHint"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hint.set_anchors_preset(Control.PRESET_CENTER)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BOTH
	_hint_tint = ColorRect.new()
	_hint_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(_hint_tint)
	_hint.visible = false
	add_child(_hint)

## Wrap mode in one place (Godot enum, kept short here).
class TextConfig:
	const WRAP := TextServer.AUTOWRAP_WORD_SMART

func _label() -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _icon_slot(idx: int, clickable: bool) -> ItemSlot:
	var s: ItemSlot = SLOT_SCENE.instantiate()
	s.index = idx
	s.bare = true
	s.icon_top_art = 3
	s.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	if clickable:
		s.slot_clicked.connect(func(i: int, b: int, _sh: bool):
			if b == MOUSE_BUTTON_LEFT:
				_tab = ["craft", "furnace", "anvil", "items"][i])
	return s

# ------------------------------------------------------------------ skin / layout

func _at(n: Control, x: float, y: float) -> void:
	n.position = Vector2(x, y) * get_skin().art_scale

func _sz(n: Control, w: float, h: float) -> void:
	n.size = Vector2(w, h) * get_skin().art_scale

func _text_at(l: Label, x: float, y: float) -> void:
	var S := get_skin().art_scale
	l.position = Vector2(roundf(x * S), roundf((y + text_dy_art) * S))   # whole screen pixels at any art scale

## Small book button: four state pictures (part names = slices.json), label in the pixel bold font. The craft button's disabled look is its own part.
func _btn_style(b: Button, sk: InventorySkin, disabled_tex: Texture2D, disabled_part: String) -> void:
	var S := sk.art_scale
	PixelArt.style_button(b, {
		"normal": [sk.button_small_idle_tex, "button_small_idle"], "hover": [sk.button_small_hover_tex, "button_small_hover"],
		"pressed": [sk.button_small_pressed_tex, "button_small_pressed"], "disabled": [disabled_tex, disabled_part]}, S, btn_content_art)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", sk.ui_font("bold"))
	b.add_theme_font_size_override("font_size", PixelArt.font_px(sk, "bold"))
	b.add_theme_constant_override("outline_size", sk.text_outline_size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, sk.pal_cream)
	b.add_theme_color_override("font_outline_color", sk.text_outline_color)
	b.add_theme_color_override("font_disabled_color", sk.pal_muted)

func _apply_skin() -> void:
	var sk := get_skin()
	var S := sk.art_scale
	var W := 330
	var H := 136 + book_bag_gap_art + 124
	_frame.custom_minimum_size = Vector2(W, H) * S
	_frame.size = Vector2(W, H) * S
	_frame.offset_left = -W * S / 2.0
	_frame.offset_right = W * S / 2.0
	_frame.offset_top = top_art * S
	_frame.offset_bottom = (top_art + H) * S
	_book.position = Vector2.ZERO
	PixelArt.set_pic(_cover, sk.book_cover_tex, S)
	_cover.position = Vector2(-8, -8) * S   # the picture has an 8 px pad round the box
	PixelArt.set_pic(_tab_active, sk.book_tab_active_tex, S)
	for i in 3:   # only two idle pictures exist: the third tab reuses the first
		PixelArt.set_pic(_tab_idle[i], sk.book_tab_idle_2_tex if i == 1 else sk.book_tab_idle_1_tex, S)
	for s in [_marker, _tab_craft, _tab_furnace, _tab_anvil, _tab_items, _f_in, _f_out, _sel_slot]:
		_set_skin(s, sk, 0)
	_sel_slot.frame_override = sk.slot_sel_tex
	# left page
	PixelArt.style_label(_title, sk, "bold", sk.pal_cream)
	_text_at(_title, 28, 11)
	_at(_marker, 10, 3)
	for i in _empties.size():
		PixelArt.set_pic(_empties[i], sk.slot_idle_tex, S)
		_at(_empties[i], 11 + 24 * (i % GRID_COLS), 25 + 24 * (i / GRID_COLS))   # the picture is 1 px bigger than the slot
	_grid_box.position = Vector2.ZERO
	# tabs (the idle ones behind; the active one and the icons are placed in _update_tabs)
	# right page (x = 173 in the book)
	_at(_sel_slot, 173, 10)
	PixelArt.style_label(_name, sk, "bold", sk.pal_cream)
	_text_at(_name, 201, 12)
	PixelArt.style_label(_type, sk, "body", sk.pal_goldtxt)
	_text_at(_type, 201, 23)
	PixelArt.set_nine(_well, sk.well_tex, "well", S)
	_at(_well, 173, 36)
	_at(_ing, 173, 36)
	PixelArt.set_nine(_banner, sk.lock_banner_tex, "lock_banner", S)
	PixelArt.set_pic(_banner_lock, sk.padlock_tex, S)
	_at(_banner_lock, 2, 3)
	PixelArt.style_label(_banner_text, sk, "body", sk.pal_cream, false)
	_at(_banner_text, 12, 1)
	_style_desc(sk)
	PixelArt.style_label(_makes, sk, "body", sk.pal_line, false)
	_steps.position = Vector2.ZERO
	_at(_minus, 173, 108)
	_sz(_minus, 14, 19)
	_at(_plus, 215, 108)
	_sz(_plus, 14, 19)
	_at(_craft_btn, 237, 108)
	_sz(_craft_btn, 75, 19)
	for b in [_minus, _plus]:
		_btn_style(b, sk, sk.button_small_disabled_tex, "button_small_disabled")
	_btn_style(_craft_btn, sk, sk.craft_disabled_tex, "craft_disabled")
	for k in ["normal", "hover", "pressed", "disabled"]:   # the label sits right of the hammer / padlock
		(_craft_btn.get_theme_stylebox(k) as StyleBoxTexture).content_margin_left = (craft_text_inset_art.x if k != "disabled" else craft_text_inset_art.y) * S
	PixelArt.set_nine(_qty_box, sk.qty_box_tex, "qty_box", S)
	_at(_qty_box, 190, 108)
	_sz(_qty_box, 22, 18)
	PixelArt.style_label(_qty_label, sk, "bold", sk.pal_cream)
	_qty_label.position = Vector2(0, roundf((4 + text_dy_art) * S))
	_qty_label.size = Vector2(22 * S, 11 * S)
	_craft_hammer.texture = sk.craft_tab_icon
	_craft_hammer.size = Vector2(16, 16) * S
	_at(_craft_hammer, 4, -1)
	PixelArt.set_pic(_craft_lock, sk.padlock_tex, S)
	_at(_craft_lock, 6, 5)
	PixelArt.style_label(_f_note, sk, "body", sk.pal_line, false, clean_desc)
	_at(_f_note, 173, 40)
	_f_note.custom_minimum_size.x = 139 * S
	# furnace page: [Ore slot] > [arrow] > [Bar slot], centred in the left page
	var fy := 52
	_at(_f_in, 38, fy)
	_at(_f_out, 38 + 22 + 10 + 30 + 10, fy)
	_f_arrow.art = S
	_f_arrow.head = PixelArt.up(sk.menu_arrow_tex, S)
	_f_arrow.position = Vector2(38 + 22 + 10, fy) * S
	_f_arrow.size = Vector2(30, 22) * S
	_f_arrow.color = sk.pal_line
	_f_arrow.fill_color = sk.pal_hp_d
	for pair in [[_f_in_label, 38], [_f_out_label, 38 + 22 + 10 + 30 + 10]]:
		PixelArt.style_label(pair[0], sk, "body", sk.pal_line, false)
		pair[0].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pair[0].size = Vector2(22 * S, 11 * S)
		_text_at(pair[0], pair[1], fy + 24)
	# bag + hotbar copy, under the book
	var bag_x := (W - 222) / 2.0
	var bag_y := 136.0 + book_bag_gap_art
	_at(_bag, bag_x + 8, bag_y + 12)
	var art := PixelArt.art_mode(sk)
	_hotbar.set("gap_override", S if art else -1)
	_at(_hotbar, bag_x + 8, bag_y + 12 + _bag.hotbar_row_dy_art)
	_hint.texture = sk.lock_texture
	_hint.custom_minimum_size = Vector2(sk.slot_size * 1.5, sk.slot_size * 1.5)
	_hint_tint.visible = sk.lock_texture == null
	_hint_tint.color = sk.lock_hint_color
	_signature = ""   # rebuild the recipe icons with the new look
	_cat_sig = ""
	_panel_sig = ""

func _style_desc(sk: InventorySkin) -> void:
	PixelArt.style_label(_desc, sk, "body", sk.pal_line, false, clean_desc)
	_desc.custom_minimum_size.x = 139 * sk.art_scale

func _set_skin(s: ItemSlot, sk: InventorySkin, size_px: int) -> void:
	s.size_override = size_px
	s.skin = sk
	s.apply_skin()

# ------------------------------------------------------------------ polling

func _process(delta: float) -> void:
	if _crafter == null or _inv == null:
		return
	var sk := get_skin()
	if sk != _applied:
		if _applied != null:
			_applied.changed.disconnect(_apply_skin)
		_applied = sk
		sk.changed.connect(_apply_skin)
		_apply_skin()
	_hint.visible = _bag.hint_visible()
	var open := _bag.is_open()
	_frame.visible = open
	if not open:
		return
	_update_tabs(sk)
	_craft_page.visible = _tab != "furnace"
	_furnace_page.visible = _tab == "furnace"
	for e in _empties:
		e.visible = _tab != "furnace"
	if _tab == "items":
		_update_catalog(sk)
	elif _tab != "furnace":
		if not _cat_slots.is_empty():
			_clear_catalog()
		_update_craft(sk, delta)
	else:
		_update_furnace(sk)

func _update_tabs(sk: InventorySkin) -> void:
	var S := sk.art_scale
	var furnaces := _crafter.furnaces_in_range()
	_furnace = furnaces[0] if not furnaces.is_empty() else null
	var ids := []
	for st in _crafter.stations_in_range():
		ids.append(str(st.station_id))
	ids.sort()
	var sig := ",".join(ids)
	var anvil_near := ids.has("anvil")
	if sig != _stations_sig:   # the stations around you changed: open on the nearest one's tab
		_stations_sig = sig
		var nearest := _crafter.nearest_station_any()
		if _tab != "items":   # the Items tab is chosen by hand: a station coming or going never moves you off it
			_tab = "craft"
			if nearest != null and nearest.station_id == &"furnace":
				_tab = "furnace"
			elif nearest != null and nearest.station_id == &"anvil":
				_tab = "anvil"
	if (_tab == "furnace" and _furnace == null) or (_tab == "anvil" and not anvil_near):
		_tab = "craft"
	# three side tabs, always: Craft, Furnace, Anvil. A station that is not near is dimmed and cannot be clicked.
	var tabs := [_tab_craft, _tab_furnace, _tab_anvil]
	var names := ["craft", "furnace", "anvil"]
	var avail := [true, _furnace != null, anvil_near]
	if not catalog.is_empty():   # the optional 4th tab (Test yard): always available
		tabs.append(_tab_items)
		names.append("items")
		avail.append(true)
	_tab_items.visible = not catalog.is_empty()
	var idle_i := 0
	for i in tabs.size():
		var s: ItemSlot = tabs[i]
		var ty := 12 + 24 * i
		var active: bool = _tab == names[i]
		s.selected = active
		s.visible = true
		s.mouse_filter = Control.MOUSE_FILTER_STOP if avail[i] else Control.MOUSE_FILTER_IGNORE
		_at(s, -22 + 1, ty)
		s.icon_modulate = Color.WHITE if active else Color(1, 1, 1, 0.75 if avail[i] else 0.35)
		if active:
			_at(_tab_active, -22, ty)
		else:
			_at(_tab_idle[idle_i], -22, ty)
			idle_i += 1
	_tab_active.visible = true
	for i in 3:
		_tab_idle[i].visible = i < idle_i
	_tab_craft.set_picture(sk.craft_tab_icon, sk.tab_color)
	_tab_craft.tip_override = "Crafting"
	var fi := _crafter.station_item(&"furnace")
	if fi != null:
		_tab_furnace.set_item(fi, 1)
	else:
		_tab_furnace.set_picture(null, Color(0.7, 0.35, 0.25))
	_tab_furnace.tip_override = "Furnace"
	var ai := _crafter.station_item(&"anvil")
	if ai != null:
		_tab_anvil.set_item(ai, 1)
	else:
		_tab_anvil.set_picture(null, Color(0.45, 0.45, 0.5))
	_tab_anvil.tip_override = "Anvil"
	if not catalog.is_empty():
		_items_icon(_tab_items, sk)
		_tab_items.tip_override = items_title
	var near := _crafter.nearest_station()
	var mi := _crafter.station_item(&"furnace") if _tab == "furnace" else (_crafter.station_item(near.station_id) if near != null else null)
	_marker.set_picture(sk.craft_tab_icon, sk.tab_color)   # the small hammer; the name says which station
	_marker.tip_override = mi.display_name if mi else "Hand"
	if _tab == "items" and not catalog.is_empty():
		_items_icon(_marker, sk)
		_marker.tip_override = items_title
	_marker.visible = _furnace == null   # with a furnace tab the header drops the icon
	_title.text = "Furnace" if _tab == "furnace" else ("Anvil" if _tab == "anvil" else (items_title if _tab == "items" else "Recipes"))
	_title.position.x = (32 if _furnace == null else 12) * S
	# a cue on the Furnace tab while it works (smelting or output ready)
	var busy := _furnace != null and (_furnace.is_running() or _furnace.out_count > 0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * sk.furnace_tab_pulse_speed)
	_tab_furnace.modulate = Color.WHITE.lerp(sk.furnace_tab_glow_color, pulse) if busy else Color.WHITE
	for s in tabs + [_marker]:
		s.refresh()
	if catalog.is_empty():
		_tab_items.visible = false

func _update_craft(sk: InventorySkin, delta: float) -> void:
	var list := _crafter.listed_recipes()
	if _tab == "anvil":
		var only: Array[RecipeData] = []
		for r in list:
			if r.station == &"anvil":
				only.append(r)
		list = only
	var sig := _tab + ":" + ",".join(list.map(func(r: RecipeData): return str(r.get_instance_id())))
	if sig != _signature:
		_signature = sig
		_rebuild(list, sk)
	_flash_left = maxf(_flash_left - delta, 0.0)
	var art := PixelArt.art_mode(sk)
	for i in _recipe_slots.size():
		var s := _recipe_slots[i]
		var r := _recipes[i]
		var lit := _crafter.can_craft(r)
		s.selected = r == _sel
		s.station_locked = not _crafter.station_ok(r)
		s.grey_icon = not lit
		s.backdrop = sk.craft_lit_backdrop if lit else sk.craft_dim_backdrop
		var col := sk.craft_lit_color if lit else sk.craft_dim_color
		if s == _flash_slot and _flash_left > 0.0:
			s.modulate = sk.craft_flash_color
		elif art:   # the picture dims, the frame stays
			s.modulate = Color.WHITE
			s.icon_modulate = Color(1, 1, 1, sk.missing_icon_alpha) if not lit else Color.WHITE
			if not lit:
				s.icon_modulate = Color(col.r, col.g, col.b, sk.missing_icon_alpha)
		else:
			s.modulate = col
		s.refresh()
	_update_chosen(sk)

func _rebuild(list: Array[RecipeData], sk: InventorySkin) -> void:
	for s in _recipe_slots:
		_grid_box.remove_child(s)
		s.queue_free()
	_recipe_slots.clear()
	_recipes = list
	if _sel == null or not list.has(_sel):
		_sel = list[0] if not list.is_empty() else null
		_qty = 1
	var S := sk.art_scale
	for i in mini(list.size(), GRID_COLS * GRID_ROWS):   # ponytail: no scrolling, 24 recipes fit; add a scroll when the list grows past it
		var s: ItemSlot = SLOT_SCENE.instantiate()
		s.index = i
		s.icon_top_art = 3
		s.skin = sk
		s.set_item(list[i].result, list[i].result_count)
		s.slot_clicked.connect(func(idx: int, b: int, _sh: bool):
			if b == MOUSE_BUTTON_LEFT:
				_clicked(idx))
		_grid_box.add_child(s)
		s.position = Vector2(12 + 24 * (i % GRID_COLS), 26 + 24 * (i / GRID_COLS)) * S
		_recipe_slots.append(s)
	rebuilt.emit()

## Click on recipe icon `idx`: it becomes the chosen recipe. A dimmed icon also flashes red.
func _clicked(idx: int) -> void:
	if idx < 0 or idx >= _recipes.size():
		return
	if _sel != _recipes[idx]:
		_qty = 1   # a new recipe starts at one craft
	_sel = _recipes[idx]
	_panel_sig = ""
	recipe_chosen.emit(_sel)
	if not _crafter.can_craft(_sel):
		_flash_slot = _recipe_slots[idx]
		_flash_left = get_skin().craft_flash_time

## Choose recipe `i` of the shown list (tests, shortcuts).
func select_recipe(i: int) -> void:
	_clicked(i)

func _need_total(g: IngredientData) -> int:
	return g.count * _qty

## Can the Craft button make `quantity()` crafts now? Asked of the Crafter (ingredients, station, lock, the held stack
## and its limit), so what the button shows is what Crafter will do.
func _can_craft_qty(r: RecipeData, straight := false) -> bool:
	return r != null and _crafter.craftable_count(r, not straight) >= _qty

## The Craft button: asks for `quantity()` crafts of the chosen recipe. Refused (nothing asked) when it is not lit.
func craft_selected(straight: bool) -> bool:
	if _tab == "items" or _sel == null or not _can_craft_qty(_sel, straight):
		return false
	for i in _qty:
		craft_requested.emit(_sel, straight)
	return true

func _station_name(r: RecipeData) -> String:
	var it := _crafter.station_item(r.station)
	var n := it.display_name.to_lower() if it != null else String(r.station)
	return ("an " if n[0] in "aeiou" else "a ") + n

func _update_chosen(sk: InventorySkin) -> void:
	var r := _sel
	_right.visible = r != null
	_f_note.visible = false
	for n in [_well, _ing, _steps, _minus, _plus, _qty_box, _craft_btn]:
		n.visible = true
	if r == null:
		return
	var S := sk.art_scale
	_can_craft_now = _can_craft_qty(r)
	var sig := "%d|%d|%s|%s|%s" % [r.get_instance_id(), _qty, ",".join(r.ingredients.map(func(g): return "%d" % _inv.count(g.item.id))), _crafter.station_ok(r), clean_desc]
	if sig != _panel_sig:
		_panel_sig = sig
		_build_chosen(r, sk, S)
	_qty_label.text = str(_qty)
	_minus.disabled = _qty <= 1
	_plus.disabled = _qty >= qty_max
	_craft_btn.disabled = not _can_craft_now
	_craft_hammer.visible = _can_craft_now
	_craft_lock.visible = not _can_craft_now
	_craft_btn.text = "Craft"
	_craft_btn.add_theme_constant_override("h_separation", 0)

func _build_chosen(r: RecipeData, sk: InventorySkin, S: int) -> void:
	_sel_slot.set_item(r.result, r.result_count)
	_sel_slot.refresh()
	_set_name(r.result.display_name)
	_type.text = _kind_name(r.result)
	for c in _ing.get_children():
		_ing.remove_child(c)
		c.queue_free()
	var rows := r.ingredients.size()
	var locked := not _crafter.station_ok(r)
	var wh := 4 + row_step_art * rows + (14 if locked else 0)
	_sz(_well, 139, wh)
	for i in rows:
		var g := r.ingredients[i]
		var s: ItemSlot = SLOT_SCENE.instantiate()
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.size_override = 16 * S   # a bare icon: the dark well is its background
		s.bare = true
		s.skin = sk
		s.set_item(g.item, 1)
		s.count_text = " "   # no stack number: have / need is the label beside it
		s.position = Vector2(4, 2 + row_step_art * i) * S
		_ing.add_child(s)
		s.refresh()
		var have := _inv.count(g.item.id)
		var need := _need_total(g)
		var l := PixelArt.label("%d/%d" % [have, need], sk, "bold", sk.pal_okg if have >= need else sk.pal_hp_l)
		_text_at(l, 4 + 16 + 5, 2 + row_step_art * i + 3)
		_ing.add_child(l)
	_banner.visible = locked
	if locked:
		_banner_text.text = "Needs %s" % _station_name(r)
		_at(_banner, 173 + 2, 36 + 2 + rows * row_step_art + 1)
		_sz(_banner, PixelArt.text_w(_banner_text.text, sk, "body") / S + 18, 12)
	var desc := String(blurbs.get(String(r.result.id), category_blurbs.get(r.result.category, "")))
	_desc.text = desc
	_style_desc(sk)
	var dy := 36 + wh + 2
	var n := _desc_lines(desc, sk, S)
	# the stepper row starts at y 108: text that would run into it is left out (a tall well leaves no room)
	_desc.visible = n > 0 and dy + n * 11 <= desc_room_art   # the description goes first when space is short
	if _desc.visible:
		_text_at(_desc, 173, dy)
		_desc.size = Vector2(139 * S, 0)
		dy += n * 11
	_makes.text = "makes %d" % (r.result_count * _qty)
	PixelArt.style_label(_makes, sk, "body", sk.pal_line, false)   # muted, on the subtitle line beside the type
	_makes.visible = true
	_text_at(_makes, 201 + PixelArt.text_w(_type.text, sk, "body") / S + 8, 23)

## The Items tab picture on `slot`: `items_tab_icon`, else the first catalog item's own picture.
func _items_icon(slot: ItemSlot, sk: InventorySkin) -> void:
	if items_tab_icon != null:
		slot.set_picture(items_tab_icon, sk.tab_color)
	else:
		slot.set_item(catalog[0], 1)

func _kind_name(it: ItemData) -> String:
	return "Station" if it.category == "placeable" else it.category.capitalize()

## Items tab: the grid shows page `_cat_page` of the catalog in the recipe grid's places; the right page shows the chosen item.
func _update_catalog(sk: InventorySkin) -> void:
	var S := sk.art_scale
	_cat_page = clampi(_cat_page, 0, catalog_pages() - 1)
	var sig := "%d|%d" % [_cat_page, catalog.size()]
	if sig != _cat_sig or _cat_slots.is_empty() and not catalog.is_empty():
		_clear_catalog()
		_cat_sig = sig
		_signature = ""   # the recipe icons come back when you return to Craft
		for s in _recipe_slots:
			_grid_box.remove_child(s)
			s.queue_free()
		_recipe_slots.clear()
		_recipes = []
		var per := GRID_COLS * GRID_ROWS
		for i in mini(per, catalog.size() - _cat_page * per):
			var s: ItemSlot = SLOT_SCENE.instantiate()
			s.index = i
			s.icon_top_art = 3
			s.skin = sk
			s.set_item(catalog[_cat_page * per + i], 1)
			s.slot_clicked.connect(_catalog_clicked)
			_grid_box.add_child(s)
			s.position = Vector2(12 + 24 * (i % GRID_COLS), 26 + 24 * (i / GRID_COLS)) * S
			_cat_slots.append(s)
		rebuilt.emit()
	for s in _cat_slots:
		s.selected = s.item == _cat_sel
		s.refresh()
	_panel_sig = ""   # the recipe widgets are rebuilt when the tab changes back
	_right.visible = _cat_sel != null
	for n in [_well, _ing, _banner, _f_note, _craft_btn]:
		n.visible = false
	if _cat_sel == null:
		return
	_sel_slot.set_item(_cat_sel, 1)
	_sel_slot.refresh()
	_set_name(_cat_sel.display_name)
	_type.text = _kind_name(_cat_sel)
	var blurb := String(blurbs.get(String(_cat_sel.id), category_blurbs.get(_cat_sel.category, "")))
	_desc.text = (blurb + "\n\n" + items_note) if blurb != "" else items_note
	_style_desc(sk)
	_desc.visible = true
	_text_at(_desc, 173, 38)   # where the Recipes page puts its description (no ingredient well here)
	_desc.size = Vector2(139 * S, 0)
	_makes.visible = _cat_sel.stack_limit() > 1   # beside the kind, like "makes N": the stack size
	if _makes.visible:
		_makes.text = "Stack %d" % _cat_sel.stack_limit()
		PixelArt.style_label(_makes, sk, "body", sk.pal_line, false)
		_text_at(_makes, 201 + PixelArt.text_w(_type.text, sk, "body") / S + 8, 23)
	var pages := catalog_pages()
	for n in [_steps, _minus, _plus, _qty_box]:   # the stepper row becomes a page pager only when there is more than one page
		n.visible = pages > 1
	_qty_label.text = "%d/%d" % [_cat_page + 1, pages]
	_minus.disabled = _cat_page <= 0
	_plus.disabled = _cat_page >= pages - 1

func _clear_catalog() -> void:
	for s in _cat_slots:
		_grid_box.remove_child(s)
		s.queue_free()
	_cat_slots.clear()
	_cat_sig = ""

func _catalog_clicked(idx: int, b: int, _sh: bool) -> void:
	var k := _cat_page * GRID_COLS * GRID_ROWS + idx
	if k < 0 or k >= catalog.size():
		return
	_cat_sel = catalog[k]
	if b == MOUSE_BUTTON_LEFT or b == MOUSE_BUTTON_RIGHT:
		catalog_clicked.emit(_cat_sel, b)

## The item name, cut with ".." so it stays inside the book page.
func _set_name(n: String) -> void:
	var sk := get_skin()
	_name.text = PixelArt.fit_text(n, sk, "bold", name_max_art * sk.art_scale)

## How many lines the description takes (a pixel font line = 11 art px).
func _desc_lines(desc: String, sk: InventorySkin, S: int) -> int:
	if desc == "":
		return 0
	var f := sk.ui_font("body")
	var w := 139 * S
	var line := ""
	var n := 1
	for word in desc.split(" "):
		var t := word if line == "" else line + " " + word
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.NATIVE["body"] * S).x > w and line != "":
			n += 1
			line = word
		else:
			line = t
	return n

func _update_furnace(sk: InventorySkin) -> void:
	_right.visible = true
	_sel_slot.visible = true
	_panel_sig = ""   # the recipe widgets come back (rebuilt) when the tab changes
	if _furnace == null:
		return
	var S := sk.art_scale
	_f_in.set_item(_furnace.in_item, _furnace.in_count)
	_f_out.set_item(_furnace.out_item, _furnace.out_count)
	_f_in.refresh()
	_f_out.refresh()
	_f_arrow.fill = _furnace.progress_frac()
	_f_arrow.queue_redraw()
	# the right page: the furnace itself + a short how-to (no recipe widgets)
	var fi := _crafter.station_item(&"furnace")
	if fi != null:
		_sel_slot.set_item(fi, 1)
		_set_name(fi.display_name)
	_sel_slot.refresh()
	_type.text = "Station"
	for n in [_well, _ing, _banner, _desc, _makes, _steps]:
		n.visible = false
	_f_note.visible = true
	_f_note.text = furnace_note
	_f_note.size = Vector2(139 * S, 0)

func _enter_tree() -> void:
	pass

## Hover name over recipe icon `s` ("" if it is not one).
func recipe_ingredients(s: ItemSlot) -> Array:
	var i := _recipe_slots.find(s)
	return _crafter.ingredient_status(_recipes[i]) if i >= 0 else []

func recipe_tip(s: ItemSlot) -> String:
	var i := _recipe_slots.find(s)
	return _recipes[i].display_name() if i >= 0 else ""
