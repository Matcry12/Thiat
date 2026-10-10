class_name AbilityBar
extends HBoxContainer
## Dodge, E skill and guard as three small icon slots (no words). Each is an ItemSlot driven by the
## same InventorySkin: icon textures `dodge_icon` / `skill_icon` / `guard_icon` (placeholder colour when
## empty). The cooldown is a dim that drains from the top; the slot's selected frame lights while the
## ability is in use. Reads Dodge / SkillSlot / Guard by polling; never changes them.

const SLOT_SCENE := preload("res://scenes/ui/item_slot.tscn")

@export var skin: InventorySkin

var _dodge: Dodge
var _skill: SkillSlot
var _loadout: Loadout
var _guard: Guard
var _slots: Array[ItemSlot] = []

func bind(dodge: Dodge, skill: SkillSlot, loadout: Loadout, guard: Guard) -> void:
	_dodge = dodge
	_skill = skill
	_loadout = loadout
	_guard = guard

func slots() -> Array[ItemSlot]:
	return _slots

func get_skin() -> InventorySkin:
	if skin == null:
		skin = load("res://data/ui/inventory_skin.tres")
	return skin

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for n in ["Dodge", "Skill", "Guard"]:
		var s: ItemSlot = SLOT_SCENE.instantiate()
		s.name = n
		s.tip_override = n
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(s)
		_slots.append(s)

func _process(_delta: float) -> void:
	if _dodge == null or _slots.is_empty():
		return
	var sk := get_skin()
	add_theme_constant_override("separation", sk.slot_gap)
	for s in _slots:
		s.skin = sk
	_slots[0].set_picture(sk.dodge_icon, sk.dodge_color)
	_slots[0].cooldown_frac = clampf(_dodge.cooldown_remaining() / maxf(_dodge.cooldown, 0.001), 0.0, 1.0)
	_slots[0].selected = _dodge.is_dashing()
	var w: WeaponData = _loadout.active_weapon() if _loadout else null
	var skill: Skill = _skill.skill_for(w) if _skill and w else null
	_slots[1].set_picture(sk.skill_icon, sk.skill_color)
	_slots[1].tip_override = skill.skill_name if skill else "No skill"
	_slots[1].cooldown_frac = 1.0 if skill == null else clampf(_skill.cooldown_left(w) / maxf(w.skill_cooldown, 0.001), 0.0, 1.0)
	_slots[1].selected = _skill.is_active()
	_slots[2].set_picture(sk.guard_icon, sk.guard_color)
	_slots[2].cooldown_frac = 1.0 if _guard.state == Guard.State.BROKEN else 1.0 - _guard.tank_fraction()
	_slots[2].selected = _guard.is_guarding()
	for s in _slots:
		s.refresh()
