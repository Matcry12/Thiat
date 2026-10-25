extends CanvasLayer
class_name HUD
## HUD (decision 0030). Top-left: Hotbar, then the bag when it opens (decision 0029). Bottom-left: the
## ability icons (dodge / skill / guard) above the health bar. Bottom centre: the boss bar while a boss is awake.
## No words: names and the HP number only appear in the hover tooltip (HudTooltip). Everything is
## placed with anchors + containers; the only numbers are the margins below.
##
## No shield bar here: the guard's shield is the curved GuardBar next to the player (decision 0015).

@export var player_path: NodePath
@export var boss_path: NodePath
@export var tuning_panel_path: NodePath
## Distance from the screen edges, px. The one owner of the HUD's position.
@export var margin_x := 16
@export var margin_y := 12
@export var block_gap := 8            ## between stacked blocks
@export var f3_gap := 8               ## clear space kept around the HUD when F3 is open
@export var ui_layer := 10            ## above the F3 layer, so draw order never depends on tree order

var _health: Health
var _loadout: Loadout

var _health_bar: HealthBar
var _hotbar: Hotbar
var _bag: BagPanel
var _win: CraftWindow
var _crafter: Crafter
var _abilities: AbilityBar
var _tooltip: HudTooltip
var _top_left: VBoxContainer
var _bottom_left: VBoxContainer
var _layer: CanvasLayer
var _tuning: CanvasLayer
var _boss: Boss
var _boss_bar: BossBar
var _skin: InventorySkin

func _ready() -> void:
	add_to_group("debug")
	var player: Node = get_node(player_path)
	_health = player.get_node("Health")
	_loadout = player.get_node_or_null("Loadout")
	_boss = get_node_or_null(boss_path) as Boss
	_tuning = get_node_or_null(tuning_panel_path) as CanvasLayer
	_build_ui(player)

func health_bar() -> HealthBar:
	return _health_bar

func hotbar() -> Hotbar:
	return _hotbar

func bag() -> BagPanel:
	return _bag

func craft_window() -> CraftWindow:
	return _win

func abilities() -> AbilityBar:
	return _abilities

func tooltip() -> HudTooltip:
	return _tooltip

## Space the HUD takes at the top and bottom of the left edge (px from that edge), so the F3 status
## panel can keep clear of it.
func f3_insets() -> Vector2:
	var vh := get_viewport().get_visible_rect().size.y
	var top := _top_left.get_global_rect().end.y
	var bottom := vh - _bottom_left.get_global_rect().position.y
	if _boss_bar and _boss_bar.visible:   # an awake boss bar sits at the bottom too
		bottom = maxf(bottom, vh - _boss_bar.get_global_rect().position.y)
	return Vector2(top + f3_gap, bottom + f3_gap)

func _process(_delta: float) -> void:
	_layer.layer = ui_layer
	if _hotbar and _bag:
		_hotbar.visible = not _bag.is_open()
	if _win:   # the centred window slides left rather than sit under the F3 tuning panel
		var dx := 0.0
		if _tuning and _tuning.visible and _tuning.has_method("right_panel_width") and _win.is_open():
			var vw := get_viewport().get_visible_rect().size.x
			var natural_right := _win.frame_rect().end.x - _win.shift()
			dx = minf(vw - _tuning.right_panel_width() - f3_gap - natural_right, 0.0)
		_win.set_shift(dx)
	_top_left.offset_left = margin_x
	_top_left.offset_top = margin_y
	_top_left.add_theme_constant_override("separation", block_gap)
	_bottom_left.offset_left = margin_x
	_bottom_left.offset_bottom = -margin_y
	_bottom_left.add_theme_constant_override("separation", block_gap)
	if _boss:
		_place_boss_bar()

## Bottom centre, `boss_bar_width_fraction` of the screen wide, kept clear of the bottom-left block
## (health + abilities) and of the F3 tuning panel: if the centred bar would touch them it slides / narrows.
func _place_boss_bar() -> void:
	var vw := get_viewport().get_visible_rect().size.x
	var left := _bottom_left.get_global_rect().end.x + block_gap
	var right := vw - margin_x
	if _tuning and _tuning.visible and _tuning.has_method("right_panel_width"):
		right = vw - _tuning.right_panel_width() - f3_gap
	var w := minf(vw * _skin.boss_bar_width_fraction, right - left)
	var x0 := clampf((vw - w) * 0.5, left, right - w)
	_boss_bar.offset_left = x0
	_boss_bar.offset_right = x0 + w
	_boss_bar.offset_bottom = -margin_y
	_boss_bar.offset_top = -margin_y - _skin.boss_bar_height

func _corner(preset: int) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.set_anchors_preset(preset)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(b)
	return b

func _build_ui(player: Node) -> void:
	_layer = CanvasLayer.new()
	_layer.layer = ui_layer
	add_child(_layer)
	_top_left = _corner(Control.PRESET_TOP_LEFT)
	_bottom_left = _corner(Control.PRESET_BOTTOM_LEFT)
	_bottom_left.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var inv := player.get_node_or_null("Inventory") as Inventory
	_tooltip = HudTooltip.new()
	_tooltip.name = "Tooltip"
	var skin: InventorySkin = load("res://data/ui/inventory_skin.tres")
	_skin = skin
	_tooltip.skin = skin
	_layer.add_child(_tooltip)
	if _loadout and inv:
		_tooltip.blocked = func(): return inv.held_item != null   # no name over a stack on the cursor
		_hotbar = Hotbar.new()
		_hotbar.skin = skin
		_top_left.add_child(_hotbar)
		_hotbar.bind(_loadout, inv)
		# Tab / I opens ONE centred window: crafting area on top, bag + a hotbar copy below (decision 0031).
		# The HUD hotbar at the top-left hides while it is open (it would show the same nine slots twice).
		_crafter = player.get_node_or_null("Crafter") as Crafter
		_win = CraftWindow.new()
		_win.skin = skin
		_layer.add_child(_win)
		_win.bind(inv, _loadout, _crafter)
		_layer.move_child(_tooltip, -1)   # the hover name must draw ABOVE the window (later siblings draw on top)
		_bag = _win.bag()
		_bag.skin = skin
		_win.hotbar().skin = skin
		_win.craft_requested.connect(func(r: RecipeData, straight: bool):   # the Crafter decides
			if straight:
				_crafter.craft(r)           # shift click: straight into the inventory
			else:
				_crafter.craft_to_cursor(r))   # click: onto the cursor, then put it in a slot
		_win.rebuilt.connect(func():   # recipe icons are rebuilt when the stations in range change
			for s in _win.recipe_slots():
				_tooltip.watch(s, func(): return _win.recipe_tip(s), func(): return _win.recipe_ingredients(s)))
		_win.furnace_input_clicked.connect(func(shift: bool):
			var f := _win.current_furnace()
			if f and shift:
				f.shift_input(inv)
			elif f:
				f.click_input(inv))
		_win.furnace_output_clicked.connect(func(shift: bool):
			var f := _win.current_furnace()
			if f and shift:
				f.shift_output(inv)
			elif f:
				f.click_output(inv))
		# The UI only asks; the inventory decides.
		_bag.slot_clicked.connect(func(i: int, button: int, shift: bool):
			if button == MOUSE_BUTTON_LEFT:
				if shift:
					var f := _win.current_furnace() if _win.furnace_visible() else null
					if f == null or not f.shift_in_from_slot(inv, i):   # ore goes into the open furnace
						inv.shift_move(i)
				else:
					inv.click_slot(i)
			elif button == MOUSE_BUTTON_RIGHT:
				inv.click_slot(i, true))
		_bag.closed.connect(inv.return_held)
		for s in _hotbar.slots():   # no name pops up mid-fight (boss engaged, bag closed)
			_tooltip.watch(s, func(): return "" if inv.locked() and not _bag.is_open() else s.tip_text())
		for s in _win.hotbar().slots():
			_tooltip.watch(s, s.tip_text)
		for s in _bag.cells():
			_tooltip.watch(s, s.tip_text)
		for s in [_win.marker(), _win.furnace_slots()[0], _win.furnace_slots()[1]] + _win.tab_slots():
			_tooltip.watch(s, s.tip_text)
	_abilities = AbilityBar.new()
	_abilities.skin = skin
	_bottom_left.add_child(_abilities)
	_abilities.bind(player.get_node("Dodge"), player.get_node_or_null("SkillSlot"), _loadout, player.get_node_or_null("Guard"))
	for s in _abilities.slots():
		_tooltip.watch(s, s.tip_text)
	_health_bar = HealthBar.new()
	_health_bar.skin = skin
	_bottom_left.add_child(_health_bar)
	_health_bar.bind(_health)
	_tooltip.watch(_health_bar, _health_bar.tip_text)
	if _boss:
		_build_boss_bar()

## Boss HP (see BossBar): hidden until the boss wakes. Anchored bottom-left; _place_boss_bar sets the offsets.
func _build_boss_bar() -> void:
	_boss_bar = BossBar.new()
	_boss_bar.skin = _skin
	_boss_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_layer.add_child(_boss_bar)
	_boss_bar.bind(_boss)


# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")
func debug_name() -> String:
	return "HUD"

func debug_category() -> String:
	return "HUD"

func debug_children() -> Array:
	var out: Array = [{"name": "HealthBar", "object": health_bar()}, {"name": "Hotbar", "object": hotbar()}]
	if bag():
		out.append({"name": "BagPanel", "object": bag()})
		out.append({"name": "InventorySkin", "object": bag().get_skin()})
	return out.filter(func(c): return c["object"] != null)
