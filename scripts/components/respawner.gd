class_name Respawner
extends Node
## Child of the Player (W6, decision 0039). Player dies -> materials are split into a DeathBag at the
## death spot, the boss resets, and after `respawn_delay` the player wakes at the home point at full HP.
## Weapons, tools and placeables are never dropped. Counts deaths for the run (later: win screen, save).

signal respawned

@export var respawn_delay := 2.0
## Share of EACH material stack that goes into the bag (rounded down).
@export_range(0.0, 1.0, 0.05) var drop_share := 0.5
## Seconds the body fades in after waking up (a look only).
@export var fade_time := 0.4

@export_group("Bag look (placeholder)")
@export var bag_size := 18.0
@export var bag_color := Color(0.55, 0.36, 0.18)
@export var bag_outline_color := Color(0.1, 0.05, 0.02)
@export var bag_outline_width := 3.0
@export var bag_ring_color := Color(1.0, 0.85, 0.25)

var deaths := 0
## Changes when any bag look number changes, so bags only redraw then.
var look_serial := 0
var _look_hash := 0
var _left := -1.0   # < 0 = alive / not counting
var _player: CharacterBody2D   # scripts/player.gd (no class_name)

func _ready() -> void:
	add_to_group("respawner")
	_player = get_parent() as CharacterBody2D
	_player.get_node("Health").died.connect(_on_died)

func _process(_d: float) -> void:
	var h := hash([bag_size, bag_color, bag_outline_color, bag_outline_width, bag_ring_color])
	if h != _look_hash:
		_look_hash = h
		look_serial += 1

func is_waiting() -> bool:
	return _left >= 0.0

func time_left() -> float:
	return maxf(_left, 0.0)

func _on_died() -> void:
	if is_waiting():
		return
	deaths += 1
	_left = respawn_delay
	_drop_bag()
	for b in get_tree().get_nodes_in_group("boss"):
		b.reset_fight()

func _drop_bag() -> void:
	var inv := _player.get_node("Inventory") as Inventory
	inv.return_held()   # a stack on the cursor is part of what you carry
	var stacks := {}
	for i in Inventory.SIZE:
		var it := inv.slot_item(i)
		if it == null or it.category != "material":
			continue
		var n := floori(inv.slot_count(i) * drop_share)
		if n <= 0:
			continue
		inv.remove_from_slot(i, n)
		var s: Dictionary = stacks.get(it.id, {"item": it, "count": 0})
		s["count"] += n
		stacks[it.id] = s
	DeathBag.spawn(_player.get_parent(), _player.global_position, stacks)

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
	var lines: Array[String] = []
	lines.append("deaths: %d  %s" % [deaths, "respawn in %.1fs" % _left if is_waiting() else "alive"])
	var bags := get_tree().get_nodes_in_group("death_bag")
	lines.append("bags on ground: %d" % bags.size())
	for b in bags:
		lines.append("  (%d, %d): %s" % [roundi(b.global_position.x), roundi(b.global_position.y), (b as DeathBag).status_text()])
	return "\n".join(lines)
