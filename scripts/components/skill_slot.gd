extends Node
class_name SkillSlot
## The E skill (decision 0018). A component like Dodge/Loadout: never reads
## Input; the owner calls try_use()/cancel() and writes aim_direction every
## frame. Each weapon's skill scene (WeaponData.skill) is instanced once, on
## first use, as a child with no owner (so the editor never saves it into
## player.tscn), and cooldowns are kept PER WEAPON.

@export var weapon_holder_path: NodePath

## Forwarded from the running skill, so visuals can follow it (e.g. the bow draw) without reaching into skills.
signal skill_state_changed(state: String)

## Written by the owner every frame; forwarded to the running skill.
var aim_direction := Vector2.RIGHT

var _weapon_holder: WeaponHolder
var _user: Node2D
var _skills := {}      ## WeaponData -> Skill
var _cooldowns := {}   ## WeaponData -> seconds left
var _current: Skill
var _current_weapon: WeaponData

func _ready() -> void:
	add_to_group("debug")
	_weapon_holder = get_node_or_null(weapon_holder_path) as WeaponHolder
	_user = get_parent() as Node2D

## The weapon's skill instance (built on first ask), null if it has none.
## Also used by F1/F3/HUD to read the numbers of a skill that is not running.
func skill_for(weapon: WeaponData) -> Skill:
	if weapon == null or weapon.skill == null:
		return null
	if not _skills.has(weapon):
		var s := weapon.skill.instantiate() as Skill
		s.weapon_holder = _weapon_holder
		assert(s != null, "SkillSlot: %s.skill scene root must extend Skill (scripts/skills/skill.gd)" % weapon.resource_path)
		add_child(s)   # no owner set on purpose
		s.state_changed.connect(skill_state_changed.emit)
		_skills[weapon] = s
	return _skills[weapon]

func try_use(weapon: WeaponData, aim: Vector2) -> bool:
	var s := skill_for(weapon)
	if s == null or is_active() or cooldown_left(weapon) > 0.0:
		return false
	_current = s
	_current_weapon = weapon
	_cooldowns[weapon] = weapon.skill_cooldown
	s.aim_direction = aim
	s.activate(_user, aim)
	return true

## Cancels a running skill and refunds its cooldown (a cancelled skill did not
## happen — same as cancel_swap charging nothing). No-op when idle.
func cancel() -> void:
	if not is_active():
		return
	_current.cancel()
	_cooldowns[_current_weapon] = 0.0

func is_active() -> bool:
	return _current != null and _current.is_active()

func moves_body() -> bool:
	return is_active() and _current.moves_body()

func move_scale() -> float:
	return _current.move_scale() if is_active() else 1.0

func cooldown_left(weapon: WeaponData) -> float:
	return _cooldowns.get(weapon, 0.0)

func reset_cooldowns() -> void:
	_cooldowns.clear()

func _physics_process(delta: float) -> void:
	for w in _cooldowns.keys():
		_cooldowns[w] = maxf(0.0, _cooldowns[w] - delta)
	if _current:
		_current.aim_direction = aim_direction


# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")
func debug_name() -> String:
	return "SkillSlot"

func debug_category() -> String:
	return "Combat"

func debug_actions() -> Array:
	return [{"label": "Reset skill cd", "run": reset_cooldowns}]

func status_text() -> String:
	var loadout := get_parent().get_node_or_null("Loadout") as Loadout
	if loadout == null:
		return "n/a"
	var lines: Array[String] = []
	for w in loadout.weapons:
		if w == null:
			continue
		var s := skill_for(w)
		var state := "no skill"
		if s:
			var cd := cooldown_left(w)
			state = "ready" if cd <= 0.0 else "cooldown %.2fs" % cd
			if s.is_active():
				state = "ACTIVE, " + state
		lines.append("%s: %s" % [w.debug_name(), state])
	return "\n".join(lines)
