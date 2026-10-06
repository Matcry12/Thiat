extends CanvasLayer
class_name HUD
## HUD. Top-right: HealthBar + Hotbar (scripts/ui/, decision 0024). Bottom-left: still
## the ugly prototype text (dodge / E skill / guard), a later slice. The dodge cooldown is a number — a gated action with no
## visible timer reads as broken (CLAUDE.md rule 7).
##
## No shield bar here: the guard's shield is the curved GuardBar next to the
## player (decision 0015), where you can read it without looking away.

@export var player_path: NodePath
@export var boss_path: NodePath
@export var tuning_panel_path: NodePath
## Top-right block: distance from the screen edge, and while the F3 panels are open it moves
## to the free gap between them (width read from the panels) and drops f3_shift_y below the boss bar.
@export var margin_x := 16
@export var margin_y := 12
@export var block_gap := 8
@export var f3_shift_y := 64
@export var f3_min_bar_width := 80
@export var counter_gap := 12   ## item counter spacing
@export var top_right_layer := 10   ## above the F3 layer, so draw order never depends on tree order

var _health: Health
var _dodge: Dodge
var _loadout: Loadout
var _skill_slot: SkillSlot
var _guard: Guard
var _boss: Boss

var _health_bar: HealthBar
var _hotbar: Hotbar
var _counter: ItemCounter
var _block: VBoxContainer
var _tr_layer: CanvasLayer
var _tuning: CanvasLayer
var _dodge_label: Label
var _skill_label: Label
var _guard_label: Label
var _boss_bar: ProgressBar
var _boss_marker: ColorRect
var _boss_label: Label

func _ready() -> void:
	var player: Node = get_node(player_path)
	_health = player.get_node("Health")
	_dodge = player.get_node("Dodge")
	_loadout = player.get_node_or_null("Loadout")
	_skill_slot = player.get_node_or_null("SkillSlot")
	_guard = player.get_node_or_null("Guard")
	_boss = get_node_or_null(boss_path) as Boss
	_tuning = get_node_or_null(tuning_panel_path) as CanvasLayer
	_build_ui()

func health_bar() -> HealthBar:
	return _health_bar

func hotbar() -> Hotbar:
	return _hotbar

func _process(_delta: float) -> void:
	_tr_layer.layer = top_right_layer
	_block.add_theme_constant_override("separation", block_gap)
	if _counter:
		_counter.add_theme_constant_override("separation", counter_gap)
	var right := margin_x
	var drop := 0
	_health_bar.width_override = 0
	if _tuning and _tuning.visible and _tuning.has_method("right_panel_width"):
		right = int(_tuning.right_panel_width()) + block_gap
		drop = f3_shift_y
		var gap := int(get_viewport().get_visible_rect().size.x) - right - int(_tuning.left_panel_right()) - block_gap
		if gap < _health_bar.bar_width:
			_health_bar.width_override = maxi(gap, f3_min_bar_width)
	_block.offset_right = -right
	_block.offset_top = margin_y + drop
	if _dodge:
		var cd := _dodge.cooldown_remaining()
		_dodge_label.text = "dodge: ready" if cd <= 0.0 else "dodge: %.1fs" % cd
	if _skill_slot and _loadout:
		_skill_label.text = _skill_text()
	if _guard:
		_guard_label.text = _guard_text()
	if _boss:
		_boss_bar.max_value = _boss.health.max_hp
		_boss_bar.value = _boss.health.hp
		_boss_marker.position.x = _boss_bar.custom_minimum_size.x * _boss.phase2_threshold
		_boss_label.text = "BOSS  phase %d  %s" % [_boss.phase, Boss.Aggro.keys()[_boss.aggro].to_lower()]

## Guard has no cooldown timer: it is a state (ready / parry / block / recover /
## broken) plus the shield bar, so that is exactly what this line shows.
func _guard_text() -> String:
	var st: String = Guard.State.keys()[_guard.state].to_lower()
	return "guard: %s  shield %.0f/%.0f" % [st, _guard.tank, _guard.tank_max]

func _skill_text() -> String:
	var w: WeaponData = _loadout.active_weapon()
	var s := _skill_slot.skill_for(w)
	if s == null:
		return "E: (no skill)"
	var cd := _skill_slot.cooldown_left(w)
	return "E: %s ready" % s.skill_name if cd <= 0.0 else "E: %.1fs" % cd

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	root.position = Vector2(16, -128)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var vbox := VBoxContainer.new()
	root.add_child(vbox)

	_dodge_label = Label.new()
	vbox.add_child(_dodge_label)

	_skill_label = Label.new()
	vbox.add_child(_skill_label)

	_guard_label = Label.new()
	vbox.add_child(_guard_label)

	_build_top_right()
	if _boss:
		_build_boss_bar()

## Top-right block: life bar, then the hotbar. Right-aligned, so N slots grow to the left.
func _build_top_right() -> void:
	_tr_layer = CanvasLayer.new()
	_tr_layer.layer = top_right_layer
	add_child(_tr_layer)
	_block = VBoxContainer.new()
	_block.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_block.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block.add_theme_constant_override("separation", block_gap)
	if _counter:
		_counter.add_theme_constant_override("separation", counter_gap)
	_tr_layer.add_child(_block)
	_health_bar = HealthBar.new()
	_health_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	_block.add_child(_health_bar)
	_health_bar.bind(_health)
	if _loadout:
		_hotbar = Hotbar.new()
		_hotbar.size_flags_horizontal = Control.SIZE_SHRINK_END
		_block.add_child(_hotbar)
		_hotbar.bind(_loadout)
	var inv := get_node(player_path).get_node_or_null("Inventory") as Inventory
	if inv:
		_counter = ItemCounter.new()
		_counter.size_flags_horizontal = Control.SIZE_SHRINK_END
		_block.add_child(_counter)
		_counter.bind(inv)

## Boss HP, top centre. The thin marker sits where phase 2 starts.
func _build_boss_bar() -> void:
	var top := Control.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-210, 12)   # between the two F3 panels
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_boss_label = Label.new()
	top.add_child(_boss_label)
	_boss_bar = ProgressBar.new()
	_boss_bar.position = Vector2(0, 26)
	_boss_bar.custom_minimum_size = Vector2(420, 20)
	_boss_bar.show_percentage = false
	_boss_bar.modulate = Color(0.8, 0.2, 0.9)
	top.add_child(_boss_bar)
	_boss_marker = ColorRect.new()
	_boss_marker.color = Color.WHITE
	_boss_marker.size = Vector2(3, 20)
	_boss_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.add_child(_boss_marker)
