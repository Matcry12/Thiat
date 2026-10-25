extends CharacterBody2D
## Training target: takes damage, never dies (hp clamped at 1 in Health). Gets shoved by hits (Knockback child),
## then slides back to its spawn spot once left alone, so a combo never turns into chasing it.

## Seconds without a hit before it starts sliding home.
@export_range(0.0, 5.0, 0.02, "or_greater", "or_less") var home_return_delay := 1.0
## Speed of the slide home, px/s.
@export_range(10.0, 600.0, 2, "or_greater", "or_less") var home_return_speed := 120.0

@onready var visual: Node2D = $Visual
@onready var health: Health = $Health
@onready var attacker: Attacker = $Attacker

var home := Vector2.ZERO
var _idle := 0.0
var _stuck := false   # a wall or rock is in the way: wait for the next hit instead of pushing against it

func _ready() -> void:
	add_to_group("debug")
	home = global_position
	set_meta("spot", global_position)   # "Dummy to spot" (F3) goes back here; ArenaMap moves it when it re-fits the dummy
	health.damaged.connect(_on_damaged)
	health.hit_taken.connect(_on_hit_taken)

func _on_hit_taken(_info: Dictionary) -> void:
	_idle = 0.0
	_stuck = false

func _physics_process(delta: float) -> void:
	_idle += delta
	if _idle < home_return_delay or _stuck or $Knockback.is_pushing() or health.hp <= 0.0:
		return
	var to_home := home - global_position
	if to_home.length() < 0.5:
		return
	if move_and_collide(to_home.limit_length(home_return_speed * delta)):
		_stuck = true

func is_returning() -> bool:
	return _idle >= home_return_delay and not _stuck and global_position.distance_to(home) >= 0.5

func status_text() -> String:
	return "dummy: %s  %.0f px from spot  idle %.1fs" % ["returning" if is_returning() else ("blocked" if _stuck else "home" if global_position.distance_to(home) < 0.5 else "waiting"), global_position.distance_to(home), _idle]

## Forwards to Attacker: Hitbox passes `owner` (this node) as the damage
## source, and Guard.resolve() duck-types `stagger()` onto it on a parry.
func stagger(duration: float) -> void:
	attacker.stagger(duration)

func _on_damaged(amount: float) -> void:
	print("dummy took %.1f damage (hp=%.1f)" % [amount, health.hp])   # the flash comes from HitFx


# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")
func debug_name() -> String:
	return "Dummy"

func debug_category() -> String:
	return "Combat"

func debug_children() -> Array:
	return [
		{"name": "Dummy Health", "object": health},
		{"name": "Knockback " + name, "object": get_node_or_null("Knockback")},
	]

func debug_actions() -> Array:
	return [
		{"label": "Heal dummy", "run": func(): health.hp = health.max_hp},
		{"label": "Dummy to spot", "run": func():   # the spot the arena map gave it (ArenaMap keeps the "spot" meta up to date)
			if has_meta("spot"):
				global_position = get_meta("spot")
				home = get_meta("spot")},
	]
