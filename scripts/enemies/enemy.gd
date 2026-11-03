class_name Enemy
extends CharacterBody2D
## A world enemy (decision 0052): body + Health + Hurtbox + contact Hitbox + Knockback + Visual + Brain.
## All numbers come from `data`. Spawn: `var e: Enemy = data.scene.instantiate(); e.data = data; parent.add_child(e); e.global_position = p`.
## Combat emits `state_changed`; the Visual node decides what to draw (rule 5).

signal state_changed(state: String)

enum State { IDLE, WINDUP, HOP, LAND, HIT, DIE }

@export var data: EnemyData
## Used when `data` is empty (dropped in by hand). Loaded by path, not referenced, because the data points back at this scene.
@export_file("*.tres") var data_path := ""

@onready var health: Health = $Health
@onready var hitbox: Hitbox = $Hitbox
@onready var knockback: Knockback = $Knockback
@onready var visual: ActorVisual = $Visual
@onready var brain: Brain = $Brain

var state: State = State.IDLE
var home := Vector2.ZERO
var returning := false
var lane_dir := Vector2.RIGHT   ## fixed at the end of windup; F1 draws it during windup
var _t := 0.0                   ## seconds in the current state
var _cooldown := 0.0
var _wander_to := Vector2.ZERO
var _wander_wait := 0.0
var _weapon := WeaponData.new()
var _target: Node2D
var _last_action := "idle"
var _map: ArenaMap
var _blocked := false
var _homed := false   ## home = where it first stands in the tree (the spawner sets global_position after add_child)

func _enter_tree() -> void:   # before the children are ready: the Visual reads data
	if data == null:
		data = load(data_path) as EnemyData
	if data.visual == null:
		data.visual = EnemyVisualData.new()

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("debug")
	for path in ["CollisionShape2D", "Hurtbox/CollisionShape2D", "Hitbox/CollisionShape2D"]:   # own copy: never size another slime
		var cs := get_node(path) as CollisionShape2D
		cs.shape = cs.shape.duplicate()
	health.max_hp = data.max_hp
	health.hp = data.max_hp
	hitbox.weapon = _weapon
	_apply_data()
	_map = get_tree().get_first_node_in_group("arena_map") as ArenaMap
	health.hit_taken.connect(_on_hit_taken)
	health.died.connect(_on_died)
	var fx := get_tree().get_first_node_in_group("hit_fx")
	if fx and fx.has_method("register_actor"):
		fx.register_actor(self)   # flash / sparks / numbers like the dummy
	_wander_wait = randf() * data.wander_pause

## Data is the one owner of these numbers; read every frame so F3 edits reach live slimes.
func _apply_data() -> void:
	((get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius = data.body_radius
	((get_node("Hurtbox/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius = data.hurtbox_radius
	((get_node("Hitbox/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius = data.contact_radius
	_weapon.damage = data.contact_damage
	_weapon.parryable = data.parryable
	if not is_equal_approx(health.max_hp, data.max_hp):
		var f := health.hp / maxf(health.max_hp, 0.001)
		health.max_hp = data.max_hp
		health.hp = data.max_hp * f

func _in_water(p: Vector2) -> bool:
	return _map != null and _map.water_kind_at(p) != MapGen.WaterKind.NONE

func _player() -> Node2D:
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node2D
	return _target

func _player_alive() -> bool:
	var p := _player()
	return p != null and not p.get("dead")

func _set_state(s: State) -> void:
	state = s
	_t = 0.0
	_blocked = false
	if s != State.HOP:
		hitbox.end_swing()
	state_changed.emit(State.keys()[s].to_lower())

func _physics_process(delta: float) -> void:
	if state == State.DIE:
		return
	if not _homed:
		_homed = true
		home = global_position
		_wander_to = home
	_apply_data()
	_t += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	var pushed := knockback.is_pushing()
	match state:
		State.IDLE:
			_think(delta, pushed)
		State.WINDUP:
			_face_player()
			if _t >= data.hop_windup:
				lane_dir = _dir_to_player()
				visual.set_facing(lane_dir)
				_set_state(State.HOP)
				if _player_alive():
					hitbox.start_swing()
		State.HOP:
			if not _player_alive():
				hitbox.end_swing()   # a corpse is never hurt again
			if not _blocked and _in_water(global_position + lane_dir * (data.hop_distance / maxf(data.hop_time, 0.01) * delta + data.body_radius + 2.0)):
				_blocked = true   # the hop stops at the water edge
			if not _blocked:   # blocked = stays put to the end of the hop, so the hitbox still polls what it touches
				_blocked = move_and_collide(lane_dir * data.hop_distance / maxf(data.hop_time, 0.01) * delta) != null
			if _t >= data.hop_time:
				_cooldown = data.hop_cooldown
				_set_state(State.LAND)
		State.LAND:
			if _t >= data.land_time:
				_set_state(State.IDLE)
		State.HIT:
			if _t >= data.hit_stun:
				_set_state(State.IDLE)

func _think(delta: float, pushed: bool) -> void:
	var pd := -1.0
	if _player_alive():
		pd = global_position.distance_to(_player().global_position)
	var action := brain.choose_action({
		"player_distance": pd, "home_distance": global_position.distance_to(home),
		"aggro_radius": data.aggro_radius, "leash_radius": data.leash_radius,
		"returning": returning, "can_attack": _cooldown <= 0.0,
	})
	_last_action = action
	if action == "return":
		returning = true
		if not pushed:
			_walk_to(home, delta)
		return
	if returning:   # arrived: full heal
		returning = false
		health.hp = health.max_hp
	if action == "attack":
		if not pushed:
			_face_player()
			_set_state(State.WINDUP)
	elif action == "wander" and not pushed:
		_wander(delta)

func _wander(delta: float) -> void:
	if global_position.distance_to(_wander_to) < 4.0:
		_wander_wait -= delta
		if _wander_wait <= 0.0:
			_wander_wait = data.wander_pause * randf_range(0.5, 1.5)
			for i in 6:
				_wander_to = home + Vector2.from_angle(randf() * TAU) * data.wander_radius * sqrt(randf())
				if not _in_water(_wander_to):
					break
			if _in_water(_wander_to):
				_wander_to = global_position
		return
	if _walk_to(_wander_to, delta):
		_wander_to = global_position   # blocked: rest

## Walks toward `p`. True = a wall stopped it.
func _walk_to(p: Vector2, delta: float) -> bool:
	var d := p - global_position
	visual.set_facing(d)
	var step := d.limit_length(data.move_speed * delta)
	if not _in_water(global_position) and _in_water(global_position + step.normalized() * (data.body_radius + 2.0)):
		return true   # never walks into water
	return move_and_collide(step) != null

func _dir_to_player() -> Vector2:
	var p := _player()
	if p == null:
		return lane_dir
	var d := p.global_position - global_position
	return d.normalized() if d.length() > 0.01 else lane_dir

func _face_player() -> void:
	lane_dir = _dir_to_player()
	visual.set_facing(lane_dir)

func _on_hit_taken(_info: Dictionary) -> void:
	if state == State.DIE or health.hp <= 0.0:
		return
	_cooldown = maxf(_cooldown, data.hop_cooldown * 0.5)
	_set_state(State.HIT)

func _on_died() -> void:
	if state == State.DIE:
		return
	_set_state(State.DIE)
	hitbox.set_deferred("monitoring", false)
	(get_node("Hurtbox") as Hurtbox).set_deferred("monitorable", false)
	(get_node("CollisionShape2D") as CollisionShape2D).set_deferred("disabled", true)
	_drop()
	get_tree().create_timer(data.die_time).timeout.connect(queue_free)

func _drop() -> void:
	var col := get_tree().get_first_node_in_group("collector") as Collector
	var radius: float = col.scatter_radius if col else 26.0
	for row in data.drops:
		for i in row.roll():
			var to := position + Vector2.from_angle(randf() * TAU) * radius * sqrt(randf())
			Pickup.spawn(get_parent(), row.item, 1, position, to)

## Guard.resolve() duck-types this on a parry: the hop is cancelled and it staggers.
func stagger(duration: float) -> void:
	if state == State.DIE:
		return
	_cooldown = maxf(_cooldown, duration)
	_set_state(State.HIT)

func target_distance() -> float:
	var p := _player()
	return global_position.distance_to(p.global_position) if p else -1.0

func state_name() -> String:
	return State.keys()[state].to_lower()

# ---- F3 debug contract
func debug_name() -> String:
	return "Enemy " + String(data.id)

func debug_category() -> String:
	return "Combat"

func _first_of_kind() -> bool:   # one set of sections / buttons per kind, not per instance
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.data == data:
			return e == self
	return true

func debug_children() -> Array:
	if not _first_of_kind():
		return []
	return [
		{"name": "Enemy %s data" % data.id, "object": data},
		{"name": "EnemyVisual %s" % data.id, "object": data.visual},
		{"name": "Knockback Enemy %s" % data.id, "object": knockback},
	]

func debug_actions() -> Array:
	if not _first_of_kind():
		return []
	return [
		{"label": "Kill %s" % data.id, "run": _kill_all},
		{"label": "Heal %s" % data.id, "run": _heal_all},
	]

func _kill_all() -> void:
	for e: Enemy in get_tree().get_nodes_in_group("enemy"):
		if e.data == data:
			e.health.take_damage(99999.0)

func _heal_all() -> void:
	for e: Enemy in get_tree().get_nodes_in_group("enemy"):
		if e.data == data:
			e.health.hp = e.health.max_hp

func status_text() -> String:
	return "%s %s  hp %.0f/%.0f  target %.0f px  home %.0f px  brain %s  cd %.1f" % [data.id, state_name(), health.hp, health.max_hp, target_distance(), global_position.distance_to(home), _last_action, _cooldown]
