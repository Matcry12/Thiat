extends CharacterBody2D
class_name Boss
## The boss body: movement, phases, enrage, stagger, and running whichever
## attack it is told to. It does NOT decide what to do next — it builds a plain
## `state` Dictionary and asks its Brain (scripts/brains/brain.gd). Attacks are
## BossAttack nodes under `Attacks` (scripts/boss/). Never reads Input.
## Nothing here names a concrete brain class, so an RL brain is a drop-in.

signal phase_changed(phase: int)
signal enraged_changed(on: bool)
signal stagger_changed(on: bool)
signal action_started(action: String)
signal defeated

enum Mode { IDLE, ACTION, STAGGER, DEAD }

@export var move_speed := 110.0
## How often an idle/chasing boss asks its brain (seconds).
@export var decision_interval := 0.25
## Phase 2 starts at this fraction of max hp.
@export var phase2_threshold := 0.6
## Player outside the FightZone this long -> enraged.
@export var enrage_delay := 3.0
@export var target_path: NodePath
@export var fight_zone_path: NodePath
@export var brain_path: NodePath = ^"Brain"

# Code-owned state: plain vars on purpose (an @export nobody may set is a lie).
var phase := 1
var mode: Mode = Mode.IDLE
var enraged := false
var outside_time := 0.0
## Debug switch: true = stands still, no attacks. Tests and the F3 button flip it.
var passive := false
var last_decision := ""
var current_action := ""

@onready var health: Health = $Health
@onready var visual: BossVisual = $Visual

var _target: Node2D
var _target_health: Health
var _zone: Area2D
var _brain: Brain
var _attacks: Dictionary = {}   # action name -> BossAttack
var _current: BossAttack
var _stagger_left := 0.0
var _decision_timer := 0.0
var _chasing := false
var _forced := ""

func _ready() -> void:
	for c in $Attacks.get_children():
		if c is BossAttack:
			_attacks[(c as BossAttack).get_action_name()] = c
	_zone = get_node_or_null(fight_zone_path) as Area2D
	if _brain == null:   # a brain handed in before _ready wins
		_brain = get_node_or_null(brain_path) as Brain
	var t := get_node_or_null(target_path) as Node2D
	if t:
		set_target(t)
	health.died.connect(_on_died)
	# Combat only emits; the visual decides how to look (CLAUDE.md §5).
	health.damaged.connect(func(_a: float): visual.on_hit())
	phase_changed.connect(visual.set_phase)
	enraged_changed.connect(visual.set_enraged)
	stagger_changed.connect(visual.set_staggered)
	defeated.connect(visual.set_defeated)

## Lets a test (or a spawner) assign the player without a scene NodePath.
func set_target(node: Node2D) -> void:
	_target = node
	_target_health = node.get_node_or_null("Health") as Health

## Swap the decision-maker at runtime (an RL brain, or a test stub).
func set_brain(b: Brain) -> void:
	if _brain and _brain != b:
		_brain.queue_free()
	_brain = b
	if b.get_parent() == null:
		b.name = "Brain"
		add_child(b)

func get_brain() -> Brain:
	return _brain

func attack_names() -> Array:
	return _attacks.keys()

func get_attack(action: String) -> BossAttack:
	return _attacks.get(action)

func _physics_process(delta: float) -> void:
	if mode == Mode.DEAD:
		return
	for a in _attacks.values():
		(a as BossAttack).tick_cooldown(delta)
	_update_phase()
	_update_enrage(delta)

	if mode == Mode.STAGGER:
		_stagger_left -= delta
		if _stagger_left <= 0.0:
			mode = Mode.IDLE
			_decision_timer = 0.0
			stagger_changed.emit(false)
		return

	if passive or _target == null or _target_dead():
		_abort_action()
		mode = Mode.IDLE
		_chasing = false
		return

	if mode == Mode.ACTION:
		if _current.tick(delta):
			_current = null
			current_action = ""
			mode = Mode.IDLE
			_decision_timer = 0.0
		return

	_decision_timer -= delta
	if _decision_timer <= 0.0 or _forced != "":
		_decision_timer = decision_interval
		_apply(_forced if _forced != "" else _ask_brain(), _forced != "")
		_forced = ""
	if mode == Mode.IDLE:
		# The brain decides how close to get ("chase" until it says "idle").
		var to_target := _target.global_position - global_position
		if _chasing and to_target != Vector2.ZERO:
			velocity = to_target.normalized() * move_speed
		else:
			velocity = Vector2.ZERO
		move_and_slide()

func _ask_brain() -> String:
	if _brain == null:
		return "idle"
	last_decision = _brain.choose_action(build_state())
	return last_decision

## The observation the brain sees (doubles as the future RL observation).
func build_state() -> Dictionary:
	var cds := {}
	for n in _attacks:
		cds[n] = (_attacks[n] as BossAttack).cooldown_left
	var to_target := Vector2.ZERO
	if _target:
		to_target = _target.global_position - global_position
	return {
		"hp_fraction": health.hp / maxf(health.max_hp, 1.0),
		"phase": phase,
		"player_distance": to_target.length(),
		"player_angle": to_target.angle(),
		"player_weapon": _player_weapon(),
		"cooldowns": cds,
		"enraged": enraged,
	}

func _player_weapon() -> String:
	var loadout := _target.get_node_or_null("Loadout") if _target else null
	if loadout and loadout.has_method("active_weapon"):
		var w: WeaponData = loadout.active_weapon()
		if w:
			return w.behavior
	return "none"

## A brain that asks for the impossible (unknown name, on cooldown, locked by
## phase) gets a no-op, never a crash. `forced` (debug) skips cooldown + phase.
func _apply(action: String, forced: bool) -> void:
	if action == "chase":
		_chasing = true
		return
	_chasing = false
	var a: BossAttack = _attacks.get(action)
	if a == null:
		return
	if not forced and (not a.ready_to_use() or a.min_phase > phase):
		return
	_current = a
	current_action = action
	mode = Mode.ACTION
	velocity = Vector2.ZERO
	action_started.emit(action)
	a.begin(self, _target)

## Called by Guard.resolve() (duck-typed) on a successful parry: drop the
## current attack and do nothing for `duration`.
func stagger(duration: float) -> void:
	if mode == Mode.DEAD:
		return
	var was_staggered := mode == Mode.STAGGER
	_abort_action()
	mode = Mode.STAGGER
	_stagger_left = maxf(_stagger_left if was_staggered else 0.0, duration)
	_chasing = false
	velocity = Vector2.ZERO
	stagger_changed.emit(true)

func _abort_action() -> void:
	if _current:
		_current.cancel()
	_current = null
	current_action = ""

func _update_phase() -> void:
	if phase == 1 and health.hp <= health.max_hp * phase2_threshold:
		phase = 2
		phase_changed.emit(phase)

func _update_enrage(delta: float) -> void:
	if _zone == null or not (_target is PhysicsBody2D):
		return
	if _zone.overlaps_body(_target as PhysicsBody2D):
		outside_time = 0.0
		if enraged:
			enraged = false
			enraged_changed.emit(false)
	else:
		outside_time += delta
		if not enraged and outside_time > enrage_delay:
			enraged = true
			enraged_changed.emit(true)

func _target_dead() -> bool:
	return _target_health != null and _target_health.hp <= 0.0

func _on_died() -> void:
	if mode == Mode.DEAD:
		return
	_abort_action()
	mode = Mode.DEAD
	velocity = Vector2.ZERO
	# Bolts already in the air must not outlive the boss.
	for p in get_tree().get_nodes_in_group("projectile"):
		if p is Projectile and (p as Projectile).get_shooter() == self:
			p.queue_free()
	defeated.emit()

# ---- debug (F3 panel / tests) ----

## Debug: next decision runs this action, ignoring cooldown and phase.
func force_next(action: String) -> void:
	if _attacks.has(action):
		_forced = action

## Debug: jump to phase 2 by dropping hp just under the threshold.
func force_phase_2() -> void:
	health.hp = minf(health.hp, health.max_hp * phase2_threshold * 0.99)

func get_fight_zone() -> Area2D:
	return _zone

func status_text() -> String:
	var lines: Array[String] = []
	lines.append("hp: %.0f/%.0f  phase: %d  mode: %s" % [health.hp, health.max_hp, phase, Mode.keys()[mode].to_lower()])
	var att := "-"
	if _current:
		att = "%s (%s %.2fs)" % [current_action, BossAttack.Phase.keys()[_current.phase].to_lower(), _current.phase_time()]
	lines.append("action: %s  passive: %s" % [att, passive])
	var cds: Array[String] = []
	for n in _attacks:
		cds.append("%s %.1f" % [n, (_attacks[n] as BossAttack).cooldown_left])
	lines.append("cooldowns: " + "  ".join(cds))
	lines.append("enraged: %s  outside: %.1f/%.1fs" % [enraged, outside_time, enrage_delay])
	lines.append("brain: %s -> '%s'" % [_brain.get_script().get_global_name() if _brain else "none", last_decision])
	if mode == Mode.STAGGER:
		lines.append("staggered: %.2fs left" % _stagger_left)
	return "\n".join(lines)
