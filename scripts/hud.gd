extends CanvasLayer
class_name HUD
## Ugly-on-purpose HUD (prototype-v0 §3: throwaway, ugly is fine, must exist).
## Player HP bar, and the dodge cooldown as a number — a gated action with no
## visible timer reads as broken (CLAUDE.md rule 7).
##
## No shield bar here: the guard's shield is the curved GuardBar next to the
## player (decision 0015), where you can read it without looking away.

@export var player_path: NodePath

var _health: Health
var _dodge: Dodge
var _loadout: Loadout
var _skill_slot: SkillSlot

var _hp_bar: ProgressBar
var _dodge_label: Label
var _weapon_label: Label
var _skill_label: Label

func _ready() -> void:
	var player: Node = get_node(player_path)
	_health = player.get_node("Health")
	_dodge = player.get_node("Dodge")
	_loadout = player.get_node_or_null("Loadout")
	_skill_slot = player.get_node_or_null("SkillSlot")
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
