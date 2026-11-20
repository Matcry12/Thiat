class_name Consumer
extends Node
## Eats food and drinks potions (food-algorithm.md rules 5-8). HOLD attack on a selected food / potion for `eating.eat_time`
## (player.gd calls `tick` every frame); then `try_use` runs. Release, slot change, dodge, death = cancel, nothing eaten.
## Success removes ONE item from the selected hotbar slot. Refused: Regen food at full hp, a stacking no-change, a potion at full hp or on cooldown. Raw food (a debuff grant) is never refused.

signal used(item: ItemData)
signal eat_started(item: ItemData)

@export var potion_cooldown := 30.0   ## s between healing potions

## Timings of eating / drinking (data/food/eating.tres).
@export var eating: EatingData = preload("res://data/food/eating.tres")

var last_refusal := ""   ## "" / "full" / "cooldown" / "no change" (F3)
var _cooldown_left := 0.0
var _eat_t := 0.0
var _eating := false
var _gap_left := 0.0
var _sound_t := 0.0
var _eat_slot := -1
var _eat_item: ItemData

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
	return it != null and (it.heal_value > 0.0 or not it.effects.is_empty())

## The selected hotbar item is food / a potion (the click eats instead of swinging or placing).
func is_holding() -> bool:
	return is_consumable(_selected())

func is_eating() -> bool:
	return _eating

## 0..1 of the current bite (0 when not eating).
func eat_progress() -> float:
	return clampf(_eat_t / maxf(eating.eat_time, 0.001), 0.0, 1.0) if _eating else 0.0

## Walk speed factor (player.gd multiplies it in).
func move_scale() -> float:
	return eating.eat_move_mult if _eating else 1.0

func cancel() -> void:
	_eating = false
	_eat_t = 0.0
	_gap_left = 0.0

## Called every physics frame by the player. `held` = attack is held and nothing else blocks it.
## Starts only if try_use would not refuse; keeps going after an item is eaten (next one starts at once).
func tick(delta: float, held: bool) -> void:
	var lo := get_parent().get_node_or_null("Loadout") as Loadout
	var slot := lo.selected_slot if lo != null else -1
	var item := _selected()
	if not held or not is_consumable(item) or (_eating and (slot != _eat_slot or item != _eat_item)):
		cancel()
		return
	if not _eating:
		if _gap_left > 0.0:
			_gap_left -= delta
			return
		if not _plan(item).ok:
			return
		_eating = true
		_eat_t = 0.0
		_sound_t = 0.0
		_eat_slot = slot
		_eat_item = item
		eat_started.emit(item)
	_eat_t += delta
	_sound_t -= delta
	if _sound_t <= 0.0 and _eat_t < eating.eat_time:
		_sound_t = eating.eat_sound_every
		_play(item.use_sound)
	if _eat_t >= eating.eat_time:
		cancel()
		if try_use(item, slot):
			_play(&"gulp")
		_gap_left = eating.eat_gap

## One slot of the player's SoundSet on the board (no board / empty slot = silent).
func _play(slot: StringName) -> void:
	var board := get_tree().get_first_node_in_group("sound_board") as SoundBoard
	if board != null:
		board.play(SoundSet.of(get_parent()), slot)

## What try_use would do with `item` right now; changes nothing but `last_refusal`.
class _Plan:
	var ok := false
	var grants: Array[EffectGrant] = []
	var can_heal := false

func _plan(item: ItemData) -> _Plan:
	var plan := _Plan.new()
	last_refusal = ""
	var effects := get_parent().get_node_or_null("Effects") as Effects
	var health := get_parent().get_node_or_null("Health") as Health
	var full := health != null and health.hp >= health.max_hp
	# Refusal checks first, then apply: the item is used when at least one part applies.
	var raw := false
	for g in item.effects:
		raw = raw or g.effect.is_debuff
		if effects != null and effects.can_apply(g) and (g.effect.is_debuff or not full):
			plan.grants.append(g)
	if item.heal_value > 0.0:
		if _cooldown_left > 0.0:
			last_refusal = "cooldown"
		elif not full:
			plan.can_heal = true
		else:
			last_refusal = "full"
	plan.ok = not plan.grants.is_empty() or plan.can_heal or raw
	if not plan.ok and last_refusal == "":
		last_refusal = "full" if full else "no change"
	elif plan.ok:
		last_refusal = ""
	return plan

## `slot` = hotbar slot to take one item from (-1: the selected one).
func try_use(item: ItemData, slot := -1) -> bool:
	if not is_consumable(item):
		last_refusal = ""
		return false
	var plan := _plan(item)
	if not plan.ok:
		return false
	var health := get_parent().get_node_or_null("Health") as Health
	var effects := get_parent().get_node_or_null("Effects") as Effects
	for g in plan.grants:
		effects.apply(g)
	if plan.can_heal:
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
	return "eating: %s %.0f%%  gap %.2fs\npotion cooldown %.1fs\nlast refusal: %s" % ["yes" if _eating else "no", eat_progress() * 100.0, _gap_left, _cooldown_left, last_refusal if last_refusal != "" else "-"]
