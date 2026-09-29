extends CanvasLayer
class_name HUD
## Ugly-on-purpose HUD (prototype-v0 §3: throwaway, ugly is fine, must exist).
## Player HP bar, and the dodge cooldown as a number — a gated action with no
## visible timer reads as broken (CLAUDE.md rule 7).
##
## No shield bar here: the guard's shield is the curved GuardBar next to the
## player (decision 0015), where you can read it without looking away.

@export var player_path: NodePath
@export var boss_path: NodePath

var _health: Health
var _dodge: Dodge
var _loadout: Loadout
var _skill_slot: SkillSlot
var _guard: Guard
var _boss: Boss

var _hp_bar: ProgressBar
var _dodge_label: Label
var _weapon_label: Label
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
	_build_ui()

func _process(_delta: float) -> void:
	if _health:
		_hp_bar.max_value = _health.max_hp
		_hp_bar.value = _health.hp
	if _dodge:
		var cd := _dodge.cooldown_remaining()
		_dodge_label.text = "dodge: ready" if cd <= 0.0 else "dodge: %.1fs" % cd
	if _loadout:
		_weapon_label.text = "weapon: %s | swap: %s" % [_weapon_name(), _swap_text()]
	if _skill_slot and _loadout:
		_skill_label.text = _skill_text()
	if _guard:
		_guard_label.text = _guard_text()
	if _boss:
		_boss_bar.max_value = _boss.health.max_hp
		_boss_bar.value = _boss.health.hp
		_boss_marker.position.x = _boss_bar.custom_minimum_size.x * _boss.phase2_threshold
		_boss_label.text = "BOSS  phase %d%s" % [_boss.phase, "  ENRAGED" if _boss.enraged else ""]

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

func _weapon_name() -> String:
	var w: WeaponData = _loadout.active_weapon()
	if w == null:
		return "(none)"
	return w.resource_path.get_file().get_basename() if w.resource_path != "" else "(unsaved)"

func _swap_text() -> String:
	if _loadout.is_casting():
		return "swapping… %.1fs" % _loadout.cast_left()
	var cd := _loadout.cooldown_left()
	return "ready" if cd <= 0.0 else "%.1fs" % cd

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	root.position = Vector2(16, -128)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var vbox := VBoxContainer.new()
	root.add_child(vbox)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(220, 18)
	_hp_bar.show_percentage = false
	_hp_bar.modulate = Color.RED
	vbox.add_child(_hp_bar)

	_dodge_label = Label.new()
	vbox.add_child(_dodge_label)

	_weapon_label = Label.new()
	vbox.add_child(_weapon_label)

	_skill_label = Label.new()
	vbox.add_child(_skill_label)

	_guard_label = Label.new()
	vbox.add_child(_guard_label)

	if _boss:
		_build_boss_bar()

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
