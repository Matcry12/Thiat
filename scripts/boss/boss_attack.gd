extends Node2D
class_name BossAttack
## Base for one boss attack: a small node under Boss/Attacks, driven by boss.gd.
## A new attack = a new node with a script that extends this (+ its Hitbox /
## Telegraph children in the scene). Nothing else changes: boss.gd finds every
## BossAttack child and keys it by `get_action_name()`.
##
## Lifecycle: TELEGRAPH (warning, no damage) -> ACTIVE (damage lands) ->
## RECOVERY (the boss is open) -> done. Numbers are @export; hit areas are the
## Hitbox shapes authored in boss.tscn (decision 0011), and each Telegraph is
## sized from that same shape so the warning matches what lands.
## Never reads Input.

enum Phase { IDLE, TELEGRAPH, ACTIVE, RECOVERY }

## Every phase change, with that phase's length from the data (0 for IDLE = attack over). The boss forwards it to its
## visual, which fills the window with an animation: art follows these numbers, never the other way round.
signal phase_changed(action: String, phase: int, duration: float)

## Empty = the node's name in lower case ("Slam" -> "slam").
@export var action_name := ""
@export var min_phase := 1
@export var damage := 20.0
@export var parryable := true
@export var telegraph_time := 0.8
@export var active_time := 0.15
@export var recovery_time := 0.6
@export var cooldown := 4.0

var phase: Phase = Phase.IDLE
var cooldown_left := 0.0
var boss: Node2D
var target: Node2D

var _t := 0.0
## One WeaponData shared by this attack's hitboxes, refreshed every tick so a
## slider in the F3 panel changes the very next hit (same trick as Attacker).
var _weapon := WeaponData.new()

func _ready() -> void:
	add_to_group("boss_attack")

func get_action_name() -> String:
	return action_name if action_name != "" else String(name).to_lower()

func ready_to_use() -> bool:
	return phase == Phase.IDLE and cooldown_left <= 0.0

func is_busy() -> bool:
	return phase != Phase.IDLE

## Seconds spent in the current phase (F3 status, tests).
func phase_time() -> float:
	return _t

func tick_cooldown(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)

func begin(by: Node2D, at: Node2D) -> void:
	boss = by
	target = at
	_enter(Phase.TELEGRAPH)

## Advances the attack. True once it has finished (cooldown already started).
func tick(delta: float) -> bool:
	_weapon.damage = damage
	_weapon.parryable = parryable
	_t += delta
	match phase:
		Phase.TELEGRAPH:
			if _t >= telegraph_time:
				_enter(Phase.ACTIVE)
		Phase.ACTIVE:
			if _active_tick(delta):
				_enter(Phase.RECOVERY)
		Phase.RECOVERY:
			if _t >= recovery_time:
				_finish()
				return true
	return false

## Stops mid-attack (stagger, death, passive). Still starts the cooldown.
func cancel() -> void:
	if phase == Phase.IDLE:
		return
	_on_cancel()
	_finish()

## F1 overlay: [{shape, xform, color}] for the warning areas to outline.
func debug_areas() -> Array:
	return []

# ---- for subclasses ----
func _on_telegraph() -> void:
	pass

func _on_active() -> void:
	pass

func _on_recovery() -> void:
	pass

func _on_cancel() -> void:
	pass

func _active_tick(_delta: float) -> bool:
	return _t >= active_time

## Length of a phase as the visual should plan it. An attack whose ACTIVE time is really a distance (the charge) says so here.
func _window_time(p: Phase) -> float:
	return telegraph_time if p == Phase.TELEGRAPH else (active_time if p == Phase.ACTIVE else recovery_time)

## Direction the body must face while this attack runs, or ZERO = follow the player. A charge is locked to its lane.
func facing_dir() -> Vector2:
	return Vector2.ZERO

func _cooldown_after() -> float:
	return cooldown

func _hook(hitbox: Hitbox) -> void:
	hitbox.weapon = _weapon

func _shape_of(hitbox: Hitbox) -> Shape2D:
	var cs := hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return cs.shape if cs else null

func _warn_color() -> Color:
	return Color.ORANGE if parryable else Color.PURPLE

func _enter(p: Phase) -> void:
	phase = p
	_t = 0.0
	match p:
		Phase.TELEGRAPH: _on_telegraph()
		Phase.ACTIVE: _on_active()
		Phase.RECOVERY: _on_recovery()
	phase_changed.emit(get_action_name(), int(p), _window_time(p))

func _finish() -> void:
	phase = Phase.IDLE
	phase_changed.emit(get_action_name(), 0, 0.0)
	cooldown_left = _cooldown_after()
