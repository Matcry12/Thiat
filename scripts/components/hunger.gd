class_name Hunger
extends Node
## The food bar (food-algorithm.md, decision 0071). The one owner of `food` (0..max_food).
## Drains steadily in _physics_process (pause stops it). At 0: starving = `starve_damage` hp every `starve_interval` s,
## straight to hp (not a hit), never below `starve_floor`, so hunger alone never kills.
## Frozen by default in test runs (BOSSFIGHT_TEST_SEED set, like DayClock); a test sets `frozen = false`.

signal changed(food: float)

@export var max_food := 100.0
@export var start_food := 100.0
@export var drain_per_min := 10.0
@export var starve_damage := 1.0
@export var starve_interval := 4.0   ## s
@export var starve_floor := 1.0   ## hp: starving stops here
@export var frozen := OS.get_environment("BOSSFIGHT_TEST_SEED") != ""

var food := 0.0
var _starve_left := 0.0
var _health: Health

func _ready() -> void:
	add_to_group("debug")
	food = clampf(start_food, 0.0, max_food)
	_starve_left = starve_interval
	_health = get_parent().get_node_or_null("Health") as Health

func _physics_process(delta: float) -> void:
	if frozen:
		return
	if food > 0.0:
		set_food(food - drain_per_min / 60.0 * delta)
		_starve_left = starve_interval
	elif _health != null and _health.hp > 0.0:
		_starve_left -= delta
		if _starve_left <= 0.0:
			_starve_left += starve_interval
			_health.lose_hp(starve_damage, maxf(starve_floor, 1.0))   # starving never kills, whatever F3 says

func set_food(v: float) -> void:
	food = clampf(v, 0.0, max_food)
	changed.emit(food)

## False (nothing eaten) when the bar is full.
func eat(amount: float) -> bool:
	if food >= max_food:
		return false
	set_food(food + amount)
	return true

func refill() -> void:
	set_food(max_food)

func is_starving() -> bool:
	return food <= 0.0

func fraction() -> float:
	return food / maxf(max_food, 0.001)

# ---- F3 debug contract
func debug_name() -> String:
	return "Hunger"

func debug_category() -> String:
	return "Character"

func debug_actions() -> Array:
	return [
		{"label": "Hunger empty", "run": func(): set_food(0.0)},
		{"label": "Hunger full", "run": refill},
	]

func status_text() -> String:
	return "food %.1f/%.0f  drain %.1f/min  %s\nnext starve tick %s" % [food, max_food, drain_per_min,
			"STARVING" if is_starving() else "ok", "%.1fs" % _starve_left if is_starving() else "-"]
