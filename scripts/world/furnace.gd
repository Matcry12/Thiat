class_name Furnace
extends Node
## The furnace machine (decision 0031): an input slot, an output slot and a timer. It smelts ONE item per
## `smelt_time` while input remains and the output has room, whether or not the player is near. Child of a
## Station; its state lives here (ready for the W9 save). Pure data + rules: the panel and the in-world
## cue read it and send requests; nothing here knows about the UI.
## No fuel in v1 (ponytail: add fuel later if the playtest wants it).

signal changed

@export var recipe_dir := "res://data/smelting"

var in_item: ItemData
var in_count := 0
var out_item: ItemData
var out_count := 0
var progress := 0.0          ## seconds spent on the current item
var smelted_total := 0       ## for F3
var _recipes: Array = []

func _ready() -> void:
	add_to_group("furnace")
	reload()

func reload() -> void:
	_recipes = RecipeBook.load_dir(recipe_dir)

func recipe_for(it: ItemData) -> SmeltRecipeData:
	if it == null:
		return null
	for r: SmeltRecipeData in _recipes:
		if r.input != null and r.input.id == it.id:
			return r
	return null

## Would the input slot take `it`? (a smelt recipe exists, and the slot is empty or holds the same item)
func accepts(it: ItemData) -> bool:
	return recipe_for(it) != null and (in_item == null or in_item.id == it.id)

func is_running() -> bool:
	return _can_run()

## 0..1 of the current item (0 = idle).
func progress_frac() -> float:
	var r := recipe_for(in_item)
	return clampf(progress / maxf(r.smelt_time, 0.001), 0.0, 1.0) if r and _can_run() else 0.0

## Puts `n` of `it` in; returns the leftover that did not fit.
func put_input(it: ItemData, n: int) -> int:
	if n <= 0 or not accepts(it):
		return n
	var put := mini(n, it.stack_limit() - in_count)
	if put <= 0:
		return n
	in_item = it
	in_count += put
	changed.emit()
	return n - put

## Empties the input slot; returns [item, count] ([null, 0] if empty). Progress is lost (it is one item's worth).
func take_input() -> Array:
	var r := [in_item, in_count]
	in_item = null
	in_count = 0
	progress = 0.0
	changed.emit()
	return r

func take_output() -> Array:
	var r := [out_item, out_count]
	out_item = null
	out_count = 0
	changed.emit()
	return r

# ------------------------------------------------------------------ clicks (the panel only requests)
# Same feel as the bag: click = pick up / put down the stack on the cursor, shift click = straight to the
# inventory (or, from a bag slot, straight into the furnace). All refused while the bag is locked.

func click_input(inv: Inventory) -> bool:
	if inv.locked():
		return false
	if inv.held_item == null:
		if in_item == null:
			return false
		var t := take_input()
		return inv.hold(t[0], t[1])
	if not accepts(inv.held_item):
		return false
	var left := put_input(inv.held_item, inv.held_count)
	if left == inv.held_count:
		return false
	inv.set_held_count(left)
	return true

func click_output(inv: Inventory) -> bool:
	if inv.locked() or out_item == null:
		return false
	if inv.held_item == null:
		var t := take_output()
		return inv.hold(t[0], t[1])
	if inv.held_item.id != out_item.id:
		return false
	var put := mini(out_count, inv.held_item.stack_limit() - inv.held_count)
	if put <= 0:
		return false
	out_count -= put
	if out_count <= 0:
		out_item = null
	inv.set_held_count(inv.held_count + put)
	changed.emit()
	return true

## Shift click on the input / output slot: back into the inventory (what does not fit stays here).
func shift_input(inv: Inventory) -> bool:
	if inv.locked() or in_item == null:
		return false
	var left := inv.add(in_item, in_count)
	if left == in_count:
		return false
	in_count = left
	if left == 0:
		in_item = null
		progress = 0.0
	changed.emit()
	return true

func shift_output(inv: Inventory) -> bool:
	if inv.locked() or out_item == null:
		return false
	var left := inv.add(out_item, out_count)
	if left == out_count:
		return false
	out_count = left
	if left == 0:
		out_item = null
	changed.emit()
	return true

## Shift click on a bag / hotbar slot while this furnace is open: the stack goes into the input (if it fits).
func shift_in_from_slot(inv: Inventory, slot: int) -> bool:
	var it := inv.slot_item(slot)
	if inv.locked() or inv.held_item != null or it == null or not accepts(it):
		return false
	var n := inv.slot_count(slot)
	var left := put_input(it, n)
	if left == n:
		return false
	inv.remove_from_slot(slot, n - left)
	return true

func _can_run() -> bool:
	var r := recipe_for(in_item)
	if r == null or in_count <= 0 or r.output == null:
		return false
	return out_item == null or (out_item.id == r.output.id and out_count + r.output_count <= out_item.stack_limit())

func _physics_process(delta: float) -> void:
	advance(delta)

## Smelts for `dt` seconds. Carries the remainder, so one big step smelts several items.
func advance(dt: float) -> void:
	var dirty := false
	while dt > 0.0 and _can_run():
		var r := recipe_for(in_item)
		var need := r.smelt_time - progress
		if dt < need:
			progress += dt
			dt = 0.0
			dirty = true
			break
		dt -= need
		progress = 0.0
		in_count -= 1
		out_item = r.output
		out_count += r.output_count
		smelted_total += 1
		if in_count <= 0:
			in_item = null
		dirty = true
	if dirty:
		changed.emit()

## F3 "Finish smelting": runs the machine until it stops (input used up or output full).
func finish_all() -> void:
	var guard := 100000
	while _can_run() and guard > 0:
		var r := recipe_for(in_item)
		advance(r.smelt_time - progress)
		guard -= 1

func status_text() -> String:
	var r := recipe_for(in_item)
	var t := r.smelt_time if r else 0.0
	return "in %s x%d  %.1f/%.1fs  out %s x%d" % [
		in_item.display_name if in_item else "-", in_count, progress, t, out_item.display_name if out_item else "-", out_count]
