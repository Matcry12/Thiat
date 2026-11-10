extends Node
class_name HitFx
## The hit-feel hub (decision 0023). It LISTENS to combat signals, works out what kind of hit it was,
## looks up that type's HitFxProfile and drives the four layers: flash, hit-stop, sound, shake.
## Combat code never calls anything here (CLAUDE.md §5); delete this node and the game still plays.
##
## Layers: flash, hit-stop, sound, shake (slice 1); recoil, sparks, damage numbers (slice 2).
## Real knockback is NOT here: it is gameplay and lives in the Knockback component (scripts/components/), so the
## "Hit FX" switch can never change where a body ends up.

signal hit_fx(hit_type: StringName)

@export var player_path: NodePath
@export var boss_path: NodePath
@export var dummy_path: NodePath
## One row per hit type (data/hit_fx/). Found by each profile's `hit_type`.
@export var profiles: Array[HitFxProfile] = []
## Master switch: off = nothing plays (compare with and without).
@export var enabled := true
@export var flash_on := true
@export var stop_on := true
@export var shake_on := true
@export var recoil_on := true
@export var sparks_on := true
@export var numbers_on := true
@export var reaction_on := true
## Recoil shape: share of the jolt spent going out (the rest is the spring back), and the ease strength of the return.
@export_range(0.01, 0.99) var recoil_out_fraction := 0.25
@export_range(0.5, 5.0, 0.02, "or_greater", "or_less") var recoil_ease := 2.0
## Spark point radius for a victim whose hurtbox is not a circle, px.
@export_range(0.0, 40.0, 0.2, "or_greater", "or_less") var fallback_hit_radius := 12.0
## Damage shown by the F3 test buttons.
@export_range(1.0, 200.0, 1, "or_greater", "or_less") var test_amount := 25.0

var stop := HitStop.new()
var sound := SoundBoard.new()
var shake := CameraShake.new()
var sparks := HitSparks.new()
var numbers := DamageNumbers.new()
var node_fx := NodeReactionFx.new()
var last_hit: StringName = &"-"
## How many times each layer has played (F3 + tests): {flash, stop, sound, shake, recoil, sparks, numbers}.
var layer_counts := {"flash": 0, "stop": 0, "sound": 0, "shake": 0, "recoil": 0, "sparks": 0, "numbers": 0, "reaction": 0}

var _by_type := {}
var _shake_frame := -1
var _shake_added := 0.0
var _block_pending := false
var _block_amount := 0.0
var _player: Node
var _boss: Node
var _dummy: Node

func _ready() -> void:
	add_to_group("hit_fx")
	add_to_group("debug")
	for n in [stop, sound, shake, sparks, numbers, node_fx]:
		add_child(n)
	node_fx.name = "NodeReaction"
	sparks.name = "HitSparks"
	numbers.name = "DamageNumbers"
	stop.name = "HitStop"
	sound.name = "SoundBoard"
	shake.name = "CameraShake"
	for p in profiles:
		_by_type[p.hit_type] = p
	_player = get_node_or_null(player_path)
	_boss = get_node_or_null(boss_path)
	_dummy = get_node_or_null(dummy_path)
	for actor in [_player, _boss, _dummy]:
		var h := actor.get_node_or_null("Health") as Health if actor else null
		if h:
			h.hit_taken.connect(_on_hit_taken)
	if _player:
		var g := _player.get_node_or_null("Guard") as Guard
		if g:
			g.parried.connect(func(source: Node): fire(&"parry", _player, source))
			g.blocked.connect(_on_blocked)
	if _boss:
		_boss.phase_changed.connect(func(ph: int): if ph >= 2: fire(&"phase_change", _boss, null))
		_boss.defeated.connect(func(): fire(&"kill", _boss, null))

## A late actor (a spawned enemy) joins the hit effects like the dummy.
func register_actor(actor: Node) -> void:
	var h := actor.get_node_or_null("Health") as Health
	if h and not h.hit_taken.is_connected(_on_hit_taken):
		h.hit_taken.connect(_on_hit_taken)

func profile_list() -> Array:
	return _by_type.values()

## A block that breaks the guard also lets damage through. Both come in the same frame; the break wins, so
## the block effect waits until the end of the frame and is dropped if a player hit follows.
func _on_blocked(amount: float) -> void:
	_block_pending = true
	_block_amount = amount
	_play_pending_block.call_deferred()

func _play_pending_block() -> void:
	if _block_pending:
		_block_pending = false
		var g := _player.get_node_or_null("Guard") as Guard
		var info := {"amount": _block_amount}
		if g:
			info["direction"] = -g.aim_direction   # the attacker is in front of the guard
		fire(&"block", _player, null, info)

func _on_hit_taken(info: Dictionary) -> void:
	var victim: Node = info["victim"]
	if victim == _player:
		_block_pending = false
	var type := &"player_hit"
	if victim != _player:
		type = HitFxProfile.type_for_tag(info["tag"], victim is Boss)   # melee or untagged = sword
	var h := victim.get_node_or_null("Health") as Health if victim else null
	if h and h.hp <= 0.0 and victim.has_signal("defeated"):
		info = info.duplicate()
		info["no_sound"] = true   # break wins: the kill event that follows plays the one sound
	fire(type, victim, info["source"], info)

## Plays every layer of `hit_type`. `victim` = who was hit (or the actor the event is about); `source` = who hit.
## `info` = the Health.hit_taken dictionary (amount, direction), or {} for events without one.
func fire(hit_type: StringName, victim: Node, source: Node, info := {}) -> void:
	var p: HitFxProfile = _by_type.get(hit_type)
	last_hit = hit_type
	if p == null or not enabled:
		return
	hit_fx.emit(hit_type)
	if flash_on and p.flash_time > 0.0:
		var who := source if p.flash_who == 1 else victim
		var v := who.get_node_or_null("Visual") as ActorVisual if who else null
		if v:
			v.flash(p.flash_color, p.flash_time)
			layer_counts["flash"] += 1
	# player_hit.tres has stop_frames 0: the player is not frozen by being hit (a test guards the shipped data).
	if stop_on and (p.stop_frames > 0 or p.slowmo_time > 0.0):
		stop.request(p.stop_frames, p.slowmo_scale, p.slowmo_time)
		layer_counts["stop"] += 1
	if p.sound_slot != &"" and not info.get("no_sound", false) and sound.enabled:
		if sound.play(_sound_set(p, victim, info), p.sound_slot, info):
			layer_counts["sound"] += 1
	var dir: Vector2 = info.get("direction", _dir_between(source, victim))
	if recoil_on and p.recoil_px > 0.0:
		var who := source if p.recoil_who == 1 else victim
		# A victim that is really shoved moves instead of jolting. No Knockback node, knockback off, or a shove
		# of 0 (immune, dead): it jolts like the boss.
		var kb := who.get_node_or_null("Knockback") as Knockback if who else null
		if who and not (who == victim and kb and kb.would_move(p.knockback)):
			var rv := who.get_node_or_null("Visual") as ActorVisual
			if rv:
				rv.recoil(dir if who == victim else -dir, p.recoil_px, p.recoil_time, recoil_out_fraction, recoil_ease)
				layer_counts["recoil"] += 1
	if sparks_on and p.spark_count > 0 and victim is Node2D:
		sparks.burst(_hit_point(victim, dir), dir, p.spark_count, p.spark_speed, p.spark_life, p.spark_color, p.spark_size)
		layer_counts["sparks"] += 1
	if reaction_on and p.reaction != &"" and victim is Node2D:
		if node_fx.react(p.reaction, victim, dir, info.get("hp_fraction", 1.0), p):
			layer_counts["reaction"] += 1
	if numbers_on and p.number_size > 0 and victim is Node2D:
		numbers.pop(victim, info.get("amount", test_amount), p.number_text, p.number_size, p.number_color)
		layer_counts["numbers"] += 1
	if shake_on and p.shake > 0.0:
		# One arrow through three targets (or a kill on top of a hit) is one jolt, not three: per physics frame,
		# only the part above what was already added counts.
		var frame := Engine.get_physics_frames()
		if frame != _shake_frame:
			_shake_frame = frame
			_shake_added = 0.0
		var extra := maxf(0.0, p.shake - _shake_added)
		if extra > 0.0:
			_shake_added += extra
			shake.add_trauma(extra)
			layer_counts["shake"] += 1

## Whose set plays this hit: the target's makes the impact; a weapon whose own set has this slot filled (arrow) plays instead.
func _sound_set(p: HitFxProfile, victim: Node, info: Dictionary) -> SoundSet:
	var w := info.get("weapon") as WeaponData
	if w != null and w.sound_set != null and w.sound_set.cue(p.sound_slot) != null:
		return w.sound_set
	return SoundSet.of(victim)

func _dir_between(source: Node, victim: Node) -> Vector2:
	if source is Node2D and victim is Node2D:
		return ((victim as Node2D).global_position - (source as Node2D).global_position).normalized()
	return Vector2.ZERO

## Where the hit lands: the victim's hurtbox edge on the side the hit came from (centre if it has no direction).
func _hit_point(victim: Node2D, dir: Vector2) -> Vector2:
	var r := fallback_hit_radius
	var cs := victim.get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is CircleShape2D:
		r = (cs.shape as CircleShape2D).radius
	return victim.global_position - dir * r

## F3 trigger buttons: play the effects only. No damage, no Health call, no state change.
func test_hit(kind: StringName) -> void:
	match kind:
		&"sword": fire(&"sword", _dummy, _player)
		&"parry": fire(&"parry", _player, _boss if _boss else _dummy)
		&"player_hit": fire(&"player_hit", _player, _dummy)
		&"kill": fire(&"kill", _boss if _boss else _dummy, null)
		&"boss_sword": fire(&"sword_boss", _boss, _player)
		&"lunge": fire(&"lunge", _dummy, _player)
		&"charged_arrow": fire(&"charged_arrow", _boss if _boss else _dummy, _player, {"weapon": load("res://data/weapons/bow.tres")})

func _test_origin() -> Vector2:
	return (_player as Node2D).global_position if _player is Node2D else Vector2.ZERO

func status_text() -> String:
	return "trauma: %.2f  offset: (%.1f, %.1f)\nhit-stop: %df left%s\nlast hit: %s  sounds: %d\nsparks: %d live (pool %d)  numbers: %d live (pool %d, merged %d)\nrecoil: %d  layers: %s" % [
		shake.trauma, shake.offset.x, shake.offset.y, stop.frames_left(), "  (on)" if stop.is_active() else "",
		last_hit, sound.play_count, sparks.live_count(), sparks.pool_size(), numbers.live_count(), numbers.pool_size(),
		numbers.merged_total, layer_counts["recoil"], layer_counts]


# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")
func debug_name() -> String:
	return "HitFx"

func debug_category() -> String:
	return "FX & Hit"

func debug_children() -> Array:
	var out: Array = [
		{"name": "HitStop", "object": stop}, {"name": "CameraShake", "object": shake},
		{"name": "NodeReaction", "object": node_fx}, {"name": "HitSparks", "object": sparks}, {"name": "DamageNumbers", "object": numbers},
	]
	for prof in profile_list():   # one section per hit type (its .tres numbers)
		out.append({"name": "Hit " + String(prof.hit_type), "object": prof})
	return out

func debug_actions() -> Array:
	var acts: Array = []
	for t in [["Test sword hit", &"sword"], ["Test parry", &"parry"], ["Test player hit", &"player_hit"], ["Test kill FX", &"kill"],
			["Test boss hit", &"boss_sword"], ["Test lunge", &"lunge"], ["Test charged arrow", &"charged_arrow"]]:
		acts.append({"label": t[0], "run": test_hit.bind(t[1])})
	acts.append({"label": "Test node hit", "run": func(): node_fx.test(&"chop", _test_origin(), _by_type)})
	acts.append({"label": "Test node pop", "run": func(): node_fx.test(&"pop", _test_origin(), _by_type)})
	# Knockback is gameplay (movement), not an effect: this switch is separate from the Hit FX ones.
	acts.append({"label": "Knockback on/off", "toggle": func(): return get_tree().get_nodes_in_group("knockback").all(func(k): return k.enabled),
		"run": func():
			var kbs := get_tree().get_nodes_in_group("knockback")
			var on := not kbs.all(func(k): return k.enabled)
			for kb in kbs:
				kb.enabled = on})
	return acts
