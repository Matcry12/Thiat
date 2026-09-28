extends CanvasLayer
class_name HUD
## Ugly-on-purpose HUD (prototype-v0 §3: throwaway, ugly is fine, must exist).
## Player HP + shield bars, and the dodge cooldown as a number — a gated
## action with no visible timer reads as broken (CLAUDE.md rule 7).

@export var player_path: NodePath

var _health: Health
var _dodge: Dodge
var _guard: Guard

var _shield_bar: ProgressBar
var _hp_bar: ProgressBar
var _tank_bar: ProgressBar
var _dodge_label: Label

func _ready() -> void:
	var player: Node = get_node(player_path)
	_health = player.get_node("Health")
	_dodge = player.get_node("Dodge")
	_guard = player.get_node_or_null("Guard") as Guard
	_build_ui()
	if _guard:
		_guard.tank_changed.connect(_on_tank_changed)
		_on_tank_changed(_guard.tank, _guard.tank_max)

func _process(_delta: float) -> void:
	if _health:
		_hp_bar.max_value = _health.max_hp
		_hp_bar.value = _health.hp
		_shield_bar.max_value = maxf(_health.shield_max, 0.001)
		_shield_bar.value = _health.shield
		_shield_bar.visible = _health.shield_max > 0.0
	if _dodge:
		var cd := _dodge.cooldown_remaining()
		_dodge_label.text = "dodge: ready" if cd <= 0.0 else "dodge: %.1fs" % cd

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	root.position = Vector2(16, -104)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var vbox := VBoxContainer.new()
	root.add_child(vbox)

	# Shield drawn above/in front of HP so the two layers read clearly.
	_shield_bar = ProgressBar.new()
	_shield_bar.custom_minimum_size = Vector2(220, 10)
	_shield_bar.show_percentage = false
	_shield_bar.modulate = Color.CYAN
	vbox.add_child(_shield_bar)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(220, 18)
	_hp_bar.show_percentage = false
	_hp_bar.modulate = Color.RED
	vbox.add_child(_hp_bar)

	# Guard's shield tank — same style, below HP. Reads clearly empty (0/max)
	# when the shield has broken.
	_tank_bar = ProgressBar.new()
	_tank_bar.custom_minimum_size = Vector2(220, 10)
	_tank_bar.show_percentage = false
	_tank_bar.modulate = Color.SKY_BLUE
	_tank_bar.visible = false
	vbox.add_child(_tank_bar)

	_dodge_label = Label.new()
	vbox.add_child(_dodge_label)

func _on_tank_changed(current: float, maximum: float) -> void:
	_tank_bar.max_value = maxf(maximum, 0.001)
	_tank_bar.value = current
	_tank_bar.visible = maximum > 0.0
