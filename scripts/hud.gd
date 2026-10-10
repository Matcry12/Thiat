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
		_bag = BagPanel.new()
		_bag.skin = skin
		_top_left.add_child(_bag)
		_bag.bind(inv, _hotbar)
		# The UI only asks; the inventory decides.
		_bag.slot_clicked.connect(func(i: int, button: int, shift: bool):
			if button == MOUSE_BUTTON_LEFT:
				if shift:
					inv.shift_move(i)
				else:
					inv.click_slot(i)
			elif button == MOUSE_BUTTON_RIGHT:
				inv.click_slot(i, true))
		_bag.closed.connect(inv.return_held)
		for s in _hotbar.slots():   # no name pops up mid-fight (boss engaged, bag closed)
			_tooltip.watch(s, func(): return "" if inv.locked() and not _bag.is_open() else s.tip_text())
		for s in _bag.cells():
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
