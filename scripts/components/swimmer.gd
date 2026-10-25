class_name Swimmer
extends Node
## Swimming (0038 step 3). Tells whether the actor's feet stand in SHALLOW water (a river, a lake, the coast shallows) and how much
## that slows it. Owns the fact and the number; the owner applies `speed_scale()` to its walk speed, and visuals (WaterFx) listen to
## `water_changed`. Dodge and attacks do not read it: they work in water as on land.
## Needs an ArenaMap in the group "arena_map"; without one the actor is never in water.

signal water_changed(in_water: bool)

## Walk speed multiplier while in shallow water (1 = no slowdown).
@export_range(0.05, 1.5, 0.005, "or_greater", "or_less") var water_speed_scale := 0.55

var in_water := false   ## code-owned: updated by refresh()
var _map: Node


## Look at the water under the feet. The owner calls it every physics frame before it moves.
func refresh() -> void:
	var actor := get_parent() as Node2D
	if actor == null:
		return
	if _map == null or not is_instance_valid(_map):
		_map = get_tree().get_first_node_in_group("arena_map")
	var now: bool = _map != null and _map.water_kind_at(actor.global_position) == MapGen.WaterKind.SHALLOW
	if now != in_water:
		in_water = now
		water_changed.emit(now)


func speed_scale() -> float:
	return water_speed_scale if in_water else 1.0


func status_text() -> String:
	return "in water: %s  speed x%.2f" % ["yes" if in_water else "no", speed_scale()]
