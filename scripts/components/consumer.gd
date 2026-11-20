class_name Consumer
extends Node
## Eats food and drinks potions (food-algorithm.md rules 5-6). The attack click on a selected food / potion calls
## `try_use_selected`. Success removes ONE item from the selected hotbar slot. Refused: food at a full bar, a potion at full hp or on cooldown.

signal used(item: ItemData)

@export var potion_cooldown := 30.0   ## s between healing potions

var last_refusal := ""   ## "" / "full" / "cooldown" (F3)
var _cooldown_left := 0.0

func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)

func _ready() -> void:
	add_to_group("debug")

func cooldown_left() -> float:
	return _cooldown_left

func _inv() -> Inventory:
	return get_parent().get_node_or_null("Inventory") as Inventory

func _selected() -> ItemData:
	var lo := get_parent().get_node_or_null("Loadout") as Loadout
	var inv := _inv()
	return inv.slot_item(lo.selected_slot) if inv != null and lo != null else null

static func is_consumable(it: ItemData) -> bool:
	return it != null and (it.food_value > 0.0 or it.heal_value > 0.0)

## The selected hotbar item is food / a potion (the click eats instead of swinging or placing).
func is_holding() -> bool:
	return is_consumable(_selected())

func try_use_selected() -> bool:
	var lo := get_parent().get_node_or_null("Loadout") as Loadout
	return try_use(_selected(), lo.selected_slot if lo != null else -1)

## `slot` = hotbar slot to take one item from (-1: the selected one).
func try_use(item: ItemData, slot := -1) -> bool:
	last_refusal = ""
	if not is_consumable(item):
		return false
	var hunger := get_parent().get_node_or_null("Hunger") as Hunger
	var health := get_parent().get_node_or_null("Health") as Health
	# Refusal checks first, then apply: refused only when NO effect can apply (else a refused heal would still feed).
	var can_eat := item.food_value > 0.0 and hunger != null and hunger.food < hunger.max_food
	var can_heal := false
	if item.heal_value > 0.0:
		if _cooldown_left > 0.0:
			last_refusal = "cooldown"
		elif health != null and health.hp < health.max_hp:
			can_heal = true
		else:
			last_refusal = "full"
	if not can_eat and not can_heal:
		if last_refusal == "" or item.food_value > 0.0 and item.heal_value <= 0.0:
			last_refusal = "full"
		return false
	last_refusal = ""
	if can_eat:
		hunger.eat(item.food_value)
	if can_heal:
		health.heal(item.heal_value)
		_cooldown_left = potion_cooldown
	var inv := _inv()
	if inv != null:
		if slot < 0:
			var lo := get_parent().get_node_or_null("Loadout") as Loadout
			slot = lo.selected_slot if lo != null else -1
		inv.remove_from_slot(slot, 1)
	used.emit(item)
	return true

# ---- F3 debug contract
func debug_name() -> String:
	return "Consumer"

func debug_category() -> String:
	return "Character"

func status_text() -> String:
	return "potion cooldown %.1fs\nlast refusal: %s" % [_cooldown_left, last_refusal if last_refusal != "" else "-"]
