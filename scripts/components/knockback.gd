extends Node
class_name Knockback
## REAL knockback (gameplay, not an effect): a shove on the body that owns this node. It listens to the sibling
## Health.hit_taken (and Guard.blocked for the block slide) and moves the body with move_and_collide, so it
## stops at walls, rocks and bodies. Strength = the `knockback` px of the hit's HitFxProfile row (data/hit_fx/).
##
## Lives with combat/Health, NOT in HitFx: turning "Hit FX" off must not change where bodies end up. Its own
## `enabled` is the knockback switch. Boss = no Knockback node = never moves from hits (it only jolts visually).
## The shove is its own displacement: it never touches velocity or Dodge/skill state, so it cannot cancel a dodge.

signal pushed(distance: float)

@export var enabled := true
## Multiplies every shove on this actor.
@export_range(0.0, 3.0, 0.02, "or_greater", "or_less") var knockback_scale := 1.0
## 0 = full shove, 1 = immune.
@export_range(0.0, 1.0) var resistance := 0.0
## How fast the shove runs out, per second. 14 = most of it done in about 0.2 s.
@export_range(1.0, 40.0, 0.2, "or_greater", "or_less") var decay_rate := 14.0
## Shoves stack (fast arrows) but never beyond this many px waiting to be played.
@export_range(0.0, 300.0, 2, "or_greater", "or_less") var max_pending := 90.0
## Fixed profile row for this actor (the player: player_hit). Empty = pick the row from the damage tag.
@export var fixed_type: StringName = &""

## Code-owned (F3 status, F1 vector, tests).
var last_type: StringName = &"-"
var last_px := 0.0
var last_vector := Vector2.ZERO
var last_origin := Vector2.ZERO
var last_msec := -100000
var total_pushes := 0

var _body: CharacterBody2D
var _health: Health
var _guard: Guard
var _remaining := Vector2.ZERO
var _block_pending := false

func _ready() -> void:
	add_to_group("knockback")
	_body = get_parent() as CharacterBody2D
	assert(_body != null, "Knockback must be a child of a CharacterBody2D")
	_health = _body.get_node_or_null("Health") as Health
	if _health:
		_health.hit_taken.connect(_on_hit_taken)
	_guard = _body.get_node_or_null("Guard") as Guard
	if _guard:
		_guard.blocked.connect(_on_blocked)

static func profile(type: StringName) -> HitFxProfile:
	var path := "res://data/hit_fx/%s.tres" % type
	return load(path) as HitFxProfile if ResourceLoader.exists(path) else null

## A block that breaks the guard also lets damage through, both in the same frame. The hit shove wins: the
## block slide waits to the end of the frame and is dropped if a hit follows (same rule as HitFx).
func _on_blocked(_amount: float) -> void:
	_block_pending = true
	_play_pending_block.call_deferred()

func _play_pending_block() -> void:
	if _block_pending:
		_block_pending = false
		_push(&"block", -_guard.aim_direction)

## True if a hit of this profile row would really move the body now (used by HitFx to choose shove or jolt).
func would_move(px: float) -> bool:
	return enabled and px * knockback_scale * (1.0 - resistance) > 0.0 and not _dead()

func _dead() -> bool:
	return _health != null and _health.hp <= 0.0

func _on_hit_taken(info: Dictionary) -> void:
	_block_pending = false
	var type: StringName = fixed_type if fixed_type != &"" else HitFxProfile.type_for_tag(info["tag"], false)
	_push(type, info["direction"])

func _push(type: StringName, dir: Vector2) -> void:
	var p := profile(type)
	if p == null or p.knockback <= 0.0 or dir == Vector2.ZERO:
		return
	apply(dir, p.knockback, type)

## Shoves by `px` along `dir` (before scale/resistance). Returns the distance that will be played (0 if off).
func apply(dir: Vector2, px: float, type: StringName = &"manual") -> float:
	var d := px * knockback_scale * (1.0 - resistance)
	if not enabled or d <= 0.0 or dir == Vector2.ZERO or _dead():
		return 0.0
	_remaining = (_remaining + dir.normalized() * d).limit_length(max_pending)
	last_type = type
	last_px = d
	last_vector = dir.normalized() * d
	last_origin = _body.global_position
	last_msec = Time.get_ticks_msec()
	total_pushes += 1
	pushed.emit(d)
	return d

func is_pushing() -> bool:
	return _remaining.length() >= 0.5

func _physics_process(delta: float) -> void:
	if _dead():
		_remaining = Vector2.ZERO   # no sliding after death
		return
	if not is_pushing():
		_remaining = Vector2.ZERO
		return
	# Exact exponential run-out: the sum of all steps is the whole shove, whatever the frame rate.
	var step := _remaining * (1.0 - exp(-decay_rate * delta))
	if _body.move_and_collide(step):
		_remaining = Vector2.ZERO   # a wall or body: stop, never push through
	else:
		_remaining -= step

func status_text() -> String:
	var who: String = String(_body.name) if _body else "?"
	return "%s: %s%s  last %s %.0f px  pushes %d" % [who, "on" if enabled else "OFF", "  pushing" if is_pushing() else "", last_type, last_px, total_pushes]
