class_name Respawner
extends Node
## Child of the Player (W6, decision 0042 over 0039). Player dies -> the carried items spray out as loose
## Pickups around the corpse (Minecraft style), the boss resets, and after `respawn_delay` the player wakes at
## the home point at full HP. The Collector picks the drops up again (never while dead). Counts deaths for the run.

signal respawned

@export var respawn_delay := 2.0
## Share of EACH material stack that drops (rounded down). 1 = everything.
@export_range(0.0, 1.0, 0.05) var drop_share := 1.0
## Tools, weapons and stations drop too (whole stacks). Off = you keep them.
@export var drop_gear := true
## Game seconds until a death drop vanishes. 0 = never.
@export var despawn_time := 300.0
## Seconds the body fades in after waking up (a look only).
@export var fade_time := 0.4
@export_group("Spray")
## A stack bigger than this drops as several pickups (so a big stack sprays, not one dot).
@export var max_per_pickup := 16
@export var spray_min := 35.0   ## px from the corpse a drop lands, nearest
@export var spray_max := 90.0   ## farthest (the Collector magnet reaches 70: walk through the pile)
@export var pop_height := 28.0  ## px the hop arcs up
@export_range(0.01, 0.5, 0.002, "or_greater", "or_less") var pop_time := 0.45    ## seconds in the air
@export var drop_scale := 2.0   ## size of a death drop (its icon is tiny); the pickup and magnet radii do not change

var deaths := 0
var _left := -1.0   # < 0 = alive / not counting
var _player: CharacterBody2D   # scripts/player/player.gd (no class_name)

func _ready() -> void:
	add_to_group("debug")
	add_to_group("respawner")
	_player = get_parent() as CharacterBody2D
	_player.get_node("Health").died.connect(_on_died)

func is_waiting() -> bool:
	return _left >= 0.0

func time_left() -> float:
	return maxf(_left, 0.0)

func _on_died() -> void:
	if is_waiting():
		return
	deaths += 1
	_left = respawn_delay
	_drop_items()
	for b in get_tree().get_nodes_in_group("boss"):
		b.reset_fight()

func _drop_items() -> void:
	var inv := _player.get_node("Inventory") as Inventory
	var lo := _player.get_node("Loadout") as Loadout
	var was_armed := not lo.is_holstered()
	var before := {}
	for pk in get_tree().get_nodes_in_group("pickup"):
		before[pk.get_instance_id()] = true
	inv.return_held()   # the cursor stack is part of what you carry: it drops with the rest
	for pk: Pickup in get_tree().get_nodes_in_group("pickup"):
		if not before.has(pk.get_instance_id()):   # a cursor stack that did not fit spilled onto the ground
			_mark(pk)
	var parent := _player.get_parent()
	for i in Inventory.SIZE:
		var it := inv.slot_item(i)
		if it == null:
			continue
		var n := inv.slot_count(i)
		if it.category == "material":
			n = floori(n * drop_share)
		elif not drop_gear:
			continue
		if n <= 0:
			continue
		inv.remove_from_slot(i, n)
		while n > 0:
			var piece := mini(n, maxi(max_per_pickup, 1))
			n -= piece
			var to := _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(spray_min, spray_max)
			var p := Pickup.spawn(parent, it, piece, _player.global_position, to, pop_height, pop_time)
			_mark(p)
	if was_armed and lo.weapons.is_empty():
		lo.arm_on_next_weapon = true

func _mark(p: Pickup) -> void:
	p.death_drop = true
	p.despawn_left = despawn_time if despawn_time > 0.0 else -1.0
	p.scale = Vector2.ONE * drop_scale

func _physics_process(delta: float) -> void:
	if _left < 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		_respawn()

func _respawn() -> void:
	_left = -1.0
	var map := get_tree().get_first_node_in_group("arena_map") as ArenaMap
	if map:
		map.teleport_player("home")   # also loads the ground there and snaps the camera
	_player.respawn()
	if fade_time > 0.0:
		_player.modulate.a = 0.0
		create_tween().tween_property(_player, "modulate:a", 1.0, fade_time)
	respawned.emit()

## Debug (F3 "Kill player"): a real death, no matter dodge / guard.
func kill() -> void:
	var h := _player.get_node("Health") as Health
	h.invulnerable = false
	h.take_damage(h.hp + h.shield + h.armor + 1.0, null, false)

func status_text() -> String:
	var n := 0
	var items := 0
	var soonest := -1.0
	for p: Pickup in get_tree().get_nodes_in_group("pickup"):
		if p.death_drop:
			n += 1
			items += p.amount
			if p.despawn_left >= 0.0 and (soonest < 0.0 or p.despawn_left < soonest):
				soonest = p.despawn_left
	return "deaths: %d  %s\ndrops on ground: %d (%d items)  soonest despawn: %s" % [
		deaths, "respawn in %.1fs" % _left if is_waiting() else "alive", n, items, "%.0f s" % soonest if soonest >= 0.0 else "-"]


# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")
func debug_name() -> String:
	return "Respawner"

func debug_category() -> String:
	return "Character"
