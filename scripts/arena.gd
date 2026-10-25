extends Node2D
## Arena root. Gameplay lives in the children; this only owns the F3 pieces that cross nodes:
## run stats (hits / swings / damage on the dummy), Kill player, Go to nearest drop, Restart.

var _total_damage := 0.0
var _last_damage := 0.0
var _hits := 0
var _swings := 0

func _ready() -> void:
	add_to_group("debug")
	var holder := get_node_or_null("Player/WeaponHolder") as WeaponHolder
	if holder:
		holder.state_changed.connect(func(state: String):
			if state == "windup":
				_swings += 1)
	var dummy_health := get_node_or_null("Dummy/Health") as Health
	if dummy_health:
		dummy_health.damaged.connect(func(amount: float):
			_last_damage = amount
			_total_damage += amount
			_hits += 1)


# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")

func debug_name() -> String:
	return "Run"

func debug_category() -> String:
	return "Run"

func debug_actions() -> Array:
	return [
		{"label": "Reset stats", "run": func():
			_total_damage = 0.0
			_last_damage = 0.0
			_hits = 0
			_swings = 0},
		{"label": "Go to nearest drop", "run": _debug_go_to_nearest_drop},
		{"label": "Kill player", "danger": true, "run": func():   # a real death: ignores dodge / guard
			var r := get_node_or_null("Player/Respawner") as Respawner
			if r:
				r.kill()},
		{"label": "Restart", "danger": true, "run": func(): ArenaMap.reload_keeping_seed(get_tree())},
	]

func status_text() -> String:
	return "hurtboxes: %d\nlast dmg: %.1f  total: %.1f\nhits: %d  swings: %d  rate: %.0f%%" % [
		get_tree().get_nodes_in_group("hurtbox").size(), _last_damage, _total_damage,
		_hits, _swings, (float(_hits) / _swings * 100.0) if _swings > 0 else 0.0]

func _debug_go_to_nearest_drop() -> void:
	var player := get_node_or_null("Player") as Node2D
	var best: Node2D
	for b in get_tree().get_nodes_in_group("pickup"):
		if not (b as Pickup).death_drop:
			continue
		if best == null or b.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
			best = b
	var map := get_tree().get_first_node_in_group("arena_map") as ArenaMap
	if best and map:
		map.teleport_player(best.global_position)
	elif best:
		player.global_position = best.global_position
