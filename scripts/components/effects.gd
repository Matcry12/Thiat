class_name Effects
extends Node
## The player's active timed effects (food-algorithm.md, decision 0072). The one owner: nothing else changes them.
## One effect per kind. Stacking (rule 6): stronger level replaces; same level keeps the longer time; weaker or no change is refused.
## Ticks in _physics_process (pause stops it). Regen heals through Health.heal().

signal changed

class Active:
	var effect: EffectData
	var level := 1
	var time_left := 0.0
	var duration := 0.0

var _list: Array[Active] = []
var _health: Health

func _ready() -> void:
	add_to_group("debug")
	_health = get_parent().get_node_or_null("Health") as Health

func _find(id: StringName) -> Active:
	for a in _list:
		if a.effect.id == id:
			return a
	return null

## Would `apply` change anything? (Regen at full hp is the Consumer's rule, not this one.)
func can_apply(grant: EffectGrant) -> bool:
	if grant == null or grant.effect == null:
		return false
	var cur := _find(grant.effect.id)
	return cur == null or grant.level > cur.level or (grant.level == cur.level and grant.duration > cur.time_left)

func apply(grant: EffectGrant) -> bool:
	if not can_apply(grant):
		return false
	var a := _find(grant.effect.id)
	if a == null:
		a = Active.new()
		a.effect = grant.effect
		_list.append(a)
	a.level = grant.level
	a.time_left = grant.duration
	a.duration = grant.duration
	changed.emit()
	return true

func clear() -> void:
	if not _list.is_empty():
		_list.clear()
		changed.emit()

func level_of(id: StringName) -> int:
	var a := _find(id)
	return a.level if a != null else 0

## Product of the active debuffs' speed_mult (1.0 = none). The player multiplies its walk speed by it.
func speed_mult() -> float:
	var m := 1.0
	for a in _list:
		m *= a.effect.speed_mult
	return m

## For the HUD: one Dictionary per effect: id (StringName), display_name, level (int), time_left (s), duration (s), is_debuff (bool), icon (Texture2D or null).
func active() -> Array:
	var out: Array = []
	for a in _list:
		out.append({"id": a.effect.id, "display_name": a.effect.display_name, "level": a.level, "time_left": a.time_left,
				"duration": a.duration, "is_debuff": a.effect.is_debuff, "icon": a.effect.icon})
	return out

func _physics_process(delta: float) -> void:
	if _list.is_empty():
		return
	var ended := false
	for a in _list:
		var dt := minf(delta, a.time_left)
		if a.effect.hp_per_level_per_s > 0.0 and _health != null:
			_health.heal(a.level * a.effect.hp_per_level_per_s * dt)
		a.time_left -= dt
		ended = ended or a.time_left <= 0.0
	if ended:
		for i in range(_list.size() - 1, -1, -1):
			if _list[i].time_left <= 0.0:
				_list.remove_at(i)
		changed.emit()

# ---- save
func to_array() -> Array:
	var out: Array = []
	for a in _list:
		out.append({"id": String(a.effect.id), "level": a.level, "time_left": a.time_left, "duration": a.duration})
	return out

func from_array(arr: Array) -> void:
	_list.clear()
	for e in arr:
		var path := "res://data/effects/%s.tres" % String(e.get("id", ""))
		if not ResourceLoader.exists(path):
			continue
		var a := Active.new()
		a.effect = load(path) as EffectData
		a.level = int(e.get("level", 1))
		a.time_left = float(e.get("time_left", 0.0))
		a.duration = float(e.get("duration", a.time_left))
		if a.time_left > 0.0:
			_list.append(a)
	changed.emit()

# ---- F3 debug contract
func debug_name() -> String:
	return "Effects"

func debug_category() -> String:
	return "Character"

func debug_actions() -> Array:
	return [
		{"label": "Give Regen", "run": func(): _give(&"regen", 2, 10.0)},
		{"label": "Give Sick", "run": func(): _give(&"sick", 1, 15.0)},
		{"label": "Clear effects", "run": clear},
	]

func _give(id: StringName, level: int, secs: float) -> void:
	var g := EffectGrant.new()
	g.effect = load("res://data/effects/%s.tres" % id) as EffectData
	g.level = level
	g.duration = secs
	apply(g)

func status_text() -> String:
	var lines: PackedStringArray = []
	for a in _list:
		lines.append("%s %d  %.1fs left" % [a.effect.id, a.level, a.time_left])
	return "%s\nspeed x%.2f" % ["\n".join(lines) if not lines.is_empty() else "no effects", speed_mult()]
