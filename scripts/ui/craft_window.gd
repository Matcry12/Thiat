class_name CraftWindow
extends Control
## The crafting window (decision 0031): Tab / I opens ONE centred window. Top: the crafting area. Bottom: the
## bag (3 x 9) and a copy of the hotbar (1 x 9). Crafting is simple: one grid of result icons. An icon is LIT
## when you can craft it and DIMMED when you only hold part of its ingredients (recipes you have nothing for are
## hidden). Click a lit icon: the item lands on the cursor (the ingredients are taken then), and you put it in
## any slot like a bag stack. Shift click: straight into the inventory. The ingredients show only in the
## hover tooltip (icons + need counts). Furnace tab (a furnace in range): [input] > [progress arrow] > [output].
## Pure view: it reads Crafter / Inventory / Furnace by polling and EMITS requests; the HUD answers them.
## Looks = InventorySkin and the ItemSlot scene; the layout is containers. No words: names are hover tooltips.

signal craft_requested(recipe: RecipeData, straight: bool)   ## straight = shift click: into the inventory, not the cursor
signal furnace_input_clicked(shift: bool)
signal furnace_output_clicked(shift: bool)
signal rebuilt   ## the recipe icons are new (the HUD registers their hover names)

const SLOT_SCENE := preload("res://scenes/ui/item_slot.tscn")

@export var skin: InventorySkin

## A right-pointing arrow drawn in code until the skin has a picture. `fill` (0..1) paints the left part in
## `fill_color`: the furnace progress.
class Arrow extends Control:
	var color := Color.WHITE
	var fill_color := Color(1, 0.6, 0.2)
	var half_height := 7.0
	var fill := 0.0
	func _tri(x1: float, h: float) -> PackedVector2Array:
		var k := 1.0 - x1 / maxf(size.x, 1.0)   # the triangle narrows towards the tip
		var hh := half_height * k
		return PackedVector2Array([Vector2(0, h - half_height), Vector2(x1, h - hh), Vector2(x1, h + hh), Vector2(0, h + half_height)])
	func _draw() -> void:
		var h := size.y * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(0, h - half_height), Vector2(size.x, h), Vector2(0, h + half_height)]), color)
		if fill > 0.0:
			var x1 := size.x * clampf(fill, 0.0, 1.0)
			draw_colored_polygon(_tri(x1, h), fill_color)

var _crafter: Crafter
var _inv: Inventory
var _bag: BagPanel
var _hotbar: Hotbar
var _frame: PanelContainer
var _marker: ItemSlot
var _tab_craft: ItemSlot
var _tab_furnace: ItemSlot
var _tab_row: HBoxContainer
var _craft_section: PanelContainer
var _furnace_section: PanelContainer
var _scroll: ScrollContainer
var _grid: GridContainer
var _f_in: ItemSlot
var _f_out: ItemSlot
var _f_arrow: Arrow
var _hint: TextureRect
var _hint_tint: ColorRect
var _recipe_slots: Array[ItemSlot] = []
var _recipes: Array[RecipeData] = []
var _signature := ""
var _flash_slot: ItemSlot
var _flash_left := 0.0
var _stations_sig := ""
var _tab := "craft"
var _furnace: Furnace
var _applied: InventorySkin
var _cells_applied := false

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

func tab_slots() -> Array[ItemSlot]:
	return [_tab_craft, _tab_furnace]

func current_tab() -> String:
	return _tab

func furnace_slots() -> Array[ItemSlot]:
	return [_f_in, _f_out]

func furnace_fraction() -> float:
	return _f_arrow.fill

func current_furnace() -> Furnace:
	return _furnace

func craft_visible() -> bool:
	return _craft_section.visible

func furnace_visible() -> bool:
	return _furnace_section.visible

func hint_icon() -> TextureRect:
	return _hint

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame = PanelContainer.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP   # the window eats clicks: no sword swing through it
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	_frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	_frame.visible = false
	add_child(_frame)
	var v := VBoxContainer.new()
	v.name = "Parts"
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(v)

	# --- tab row: station marker, Crafting tab, Furnace tab (icons only)
	_tab_row = HBoxContainer.new()
	_tab_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_tab_row)
	_marker = _icon_slot(-1, false)
	_tab_row.add_child(_marker)
	_tab_craft = _icon_slot(0, true)
	_tab_row.add_child(_tab_craft)
	_tab_furnace = _icon_slot(1, true)
	_tab_row.add_child(_tab_furnace)

	# --- crafting area
	_craft_section = PanelContainer.new()
	_craft_section.name = "CraftArea"
	_craft_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_craft_section)
	var h := HBoxContainer.new()
	h.name = "CraftRow"
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_craft_section.add_child(h)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_grid)

	# --- furnace area
	_furnace_section = PanelContainer.new()
	_furnace_section.name = "FurnaceArea"
	_furnace_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_furnace_section)
	var fh := HBoxContainer.new()
	fh.alignment = BoxContainer.ALIGNMENT_CENTER
	fh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_furnace_section.add_child(fh)
	_f_in = SLOT_SCENE.instantiate()
	_f_in.index = 0
	_f_in.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_f_in.slot_clicked.connect(func(_i: int, b: int, sh: bool): if b == MOUSE_BUTTON_LEFT: furnace_input_clicked.emit(sh))
	fh.add_child(_f_in)
	_f_arrow = Arrow.new()
	_f_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_f_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fh.add_child(_f_arrow)
	_f_out = SLOT_SCENE.instantiate()
	_f_out.index = 1
	_f_out.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_f_out.slot_clicked.connect(func(_i: int, b: int, sh: bool): if b == MOUSE_BUTTON_LEFT: furnace_output_clicked.emit(sh))
	fh.add_child(_f_out)

	# --- bag + hotbar copy (the bag is the existing BagPanel, moved in here)
	_bag = BagPanel.new()
	_bag.name = "Bag"
	v.add_child(_bag)
	_hotbar = Hotbar.new()
	_hotbar.name = "HotbarCopy"
	v.add_child(_hotbar)

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

func _icon_slot(idx: int, clickable: bool) -> ItemSlot:
	var s: ItemSlot = SLOT_SCENE.instantiate()
	s.index = idx
	s.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	if clickable:
		s.slot_clicked.connect(func(i: int, b: int, _sh: bool):
			if b == MOUSE_BUTTON_LEFT:
				_tab = "craft" if i == 0 else "furnace")
	return s

# ------------------------------------------------------------------ skin

func _box(tex: Texture2D, patch: int, fill: Color, border: Color, pad: int, sk: InventorySkin) -> StyleBox:
	var b: StyleBox
	if tex != null:
		var t := StyleBoxTexture.new()
		t.texture = tex
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			t.set_texture_margin(side, patch)
		b = t
	else:
		var f := StyleBoxFlat.new()
		f.bg_color = fill
		f.border_color = border
		f.set_border_width_all(sk.slot_border_width)
		b = f
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		b.set_content_margin(side, pad)
	return b

func _apply_skin() -> void:
	var sk := get_skin()
	_frame.add_theme_stylebox_override("panel", _box(sk.window_texture, sk.window_patch_margin, sk.window_color, sk.window_border, sk.window_pad, sk))
	for sec: PanelContainer in [_craft_section, _furnace_section]:
		sec.add_theme_stylebox_override("panel", _box(sk.section_texture, sk.section_patch_margin, sk.section_color, sk.section_border, sk.section_pad, sk))
		sec.custom_minimum_size.y = sk.craft_area_height
	_frame.get_node("Parts").add_theme_constant_override("separation", sk.window_gap)
	_tab_row.add_theme_constant_override("separation", sk.craft_slot_gap)
	_grid.columns = maxi(sk.craft_grid_columns, 1)
	_grid.add_theme_constant_override("h_separation", sk.craft_slot_gap)
	_grid.add_theme_constant_override("v_separation", sk.craft_slot_gap)
	_scroll.custom_minimum_size.y = maxi(sk.craft_grid_rows, 1) * (sk.craft_slot_size + sk.craft_slot_gap)
	for s in [_marker, _tab_craft, _tab_furnace]:
		_set_skin(s, sk, sk.tab_size)
	for s in [_f_in, _f_out]:
		_set_skin(s, sk, sk.furnace_slot_size)
	_f_arrow.color = sk.furnace_arrow_color
	_f_arrow.fill_color = sk.furnace_fill_color
	_f_arrow.half_height = sk.furnace_arrow_height * 0.5
	_f_arrow.custom_minimum_size = Vector2(sk.furnace_arrow_width, sk.furnace_arrow_height + 4)
	_hint.texture = sk.lock_texture
	_hint.custom_minimum_size = Vector2(sk.slot_size * 1.5, sk.slot_size * 1.5)
	_hint_tint.visible = sk.lock_texture == null
	_hint_tint.color = sk.lock_hint_color
	_signature = ""   # rebuild the recipe icons with the new sizes

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
	_craft_section.visible = _tab == "craft"
	_furnace_section.visible = _tab == "furnace"
	if _tab == "craft":
		_update_craft(sk, delta)
	else:
		_update_furnace(sk)

func _update_tabs(sk: InventorySkin) -> void:
	var furnaces := _crafter.furnaces_in_range()
	_furnace = furnaces[0] if not furnaces.is_empty() else null
	var ids := []
	for st in _crafter.stations_in_range():
		ids.append(str(st.station_id))
	ids.sort()
	var sig := ",".join(ids)
	if sig != _stations_sig:   # the stations around you changed: open on the nearest one's tab
		_stations_sig = sig
		var nearest := _crafter.nearest_station_any()
		_tab = "furnace" if nearest != null and nearest.station_id == &"furnace" else "craft"
	if _furnace == null:
		_tab = "craft"
	_tab_row.visible = true
	_tab_craft.visible = _furnace != null    # two tabs only when there is a choice
	_tab_furnace.visible = _furnace != null
	_tab_craft.selected = _tab == "craft"
	_tab_furnace.selected = _tab == "furnace"
	_tab_craft.set_picture(sk.craft_tab_icon, sk.tab_color)
	_tab_craft.tip_override = "Crafting"
	var fi := _crafter.station_item(&"furnace")
	if fi != null:
		_tab_furnace.set_item(fi, 1)
	else:
		_tab_furnace.set_picture(null, Color(0.7, 0.35, 0.25))
	_tab_furnace.tip_override = "Furnace"
	var near := _crafter.nearest_station()
	var mi := _crafter.station_item(&"furnace") if _tab == "furnace" else (_crafter.station_item(near.station_id) if near != null else null)
	if mi != null:
		_marker.set_item(mi, 1)
	else:
		_marker.set_picture(sk.hand_icon, sk.hand_color)
	_marker.tip_override = mi.display_name if mi else "Hand"
	_marker.visible = _furnace == null   # with tabs the Furnace tab already shows the furnace: no icon twice
	# a cue on the Furnace tab while it works (smelting or output ready)
	var busy := _furnace != null and (_furnace.is_running() or _furnace.out_count > 0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * sk.furnace_tab_pulse_speed)
	_tab_furnace.modulate = Color.WHITE.lerp(sk.furnace_tab_glow_color, pulse) if busy else Color.WHITE
	for s in [_marker, _tab_craft, _tab_furnace]:
		s.refresh()

func _update_craft(sk: InventorySkin, delta: float) -> void:
	var list := _crafter.listed_recipes()
	var sig := ",".join(list.map(func(r: RecipeData): return str(r.get_instance_id())))
	if sig != _signature:
		_signature = sig
		_rebuild(list, sk)
	_flash_left = maxf(_flash_left - delta, 0.0)
	for i in _recipe_slots.size():
		var s := _recipe_slots[i]
		var lit := _crafter.can_craft(_recipes[i])
		s.backdrop = sk.craft_lit_backdrop if lit else sk.craft_dim_backdrop
		if s == _flash_slot and _flash_left > 0.0:
			s.modulate = sk.craft_flash_color
		else:
			s.modulate = sk.craft_lit_color if lit else sk.craft_dim_color
		s.refresh()

func _rebuild(list: Array[RecipeData], sk: InventorySkin) -> void:
	for s in _recipe_slots:
		_grid.remove_child(s)
		s.queue_free()
	_recipe_slots.clear()
	_recipes = list
	for i in list.size():
		var s: ItemSlot = SLOT_SCENE.instantiate()
		s.index = i
		s.size_override = sk.craft_slot_size
		s.skin = sk
		s.set_item(list[i].result, list[i].result_count)
		s.slot_clicked.connect(func(idx: int, b: int, sh: bool):
			if b == MOUSE_BUTTON_LEFT:
				_clicked(idx, sh))
		_grid.add_child(s)
		_recipe_slots.append(s)
	rebuilt.emit()

## Click on recipe icon `idx`. A dimmed icon does nothing but flash red; a lit one asks for the craft.
func _clicked(idx: int, straight: bool) -> void:
	if idx < 0 or idx >= _recipes.size():
		return
	if not _crafter.can_craft(_recipes[idx]):
		_flash_slot = _recipe_slots[idx]
		_flash_left = get_skin().craft_flash_time
		return
	craft_requested.emit(_recipes[idx], straight)

func _update_furnace(_sk: InventorySkin) -> void:
	if _furnace == null:
		return
	_f_in.set_item(_furnace.in_item, _furnace.in_count)
	_f_out.set_item(_furnace.out_item, _furnace.out_count)
	_f_in.refresh()
	_f_out.refresh()
	_f_arrow.fill = _furnace.progress_frac()
	_f_arrow.queue_redraw()

## Hover name over recipe icon `s` ("" if it is not one).
func recipe_ingredients(s: ItemSlot) -> Array:
	var i := _recipe_slots.find(s)
	return _crafter.ingredient_status(_recipes[i]) if i >= 0 else []

func recipe_tip(s: ItemSlot) -> String:
	var i := _recipe_slots.find(s)
	return _recipes[i].display_name() if i >= 0 else ""
