extends Node
class_name HitFx
## The hit-feel hub (decision 0023). It LISTENS to combat signals, works out what kind of hit it was,
## looks up that type's HitFxProfile and drives the four layers: flash, hit-stop, sound, shake.
## Combat code never calls anything here (CLAUDE.md §5); delete this node and the game still plays.
##
## Slice 1 layers only. Sparks, damage numbers, knockback and zoom punch come in slice 2.

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
@export var sound_on := true
@export var shake_on := true

var stop := HitStop.new()
var sound := HitSound.new()
var shake := CameraShake.new()
var last_hit: StringName = &"-"
## How many times each layer has played (F3 + tests): {flash, stop, sound, shake}.
var layer_counts := {"flash": 0, "stop": 0, "sound": 0, "shake": 0}

var _by_type := {}
var _shake_frame := -1
var _shake_added := 0.0
var _block_pending := false
var _player: Node
var _boss: Node
var _dummy: Node

func _ready() -> void:
	for n in [stop, sound, shake]:
		add_child(n)
	stop.name = "HitStop"
	sound.name = "HitSound"
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

func profile_list() -> Array:
	return _by_type.values()

## A block that breaks the guard also lets damage through. Both come in the same frame; the break wins, so
## the block effect waits until the end of the frame and is dropped if a player hit follows.
func _on_blocked(_amount: float) -> void:
	_block_pending = true
	_play_pending_block.call_deferred()

func _play_pending_block() -> void:
	if _block_pending:
		_block_pending = false
		fire(&"block", _player, null)

func _on_hit_taken(info: Dictionary) -> void:
	var victim: Node = info["victim"]
	if victim == _player:
		_block_pending = false
	var type := &"player_hit"
	if victim != _player:
		var tag: StringName = info["tag"]
		match tag:
			&"lunge", &"arrow", &"charged_arrow":
				type = tag
			_:
				type = &"sword_boss" if victim is Boss else &"sword"   # melee, or untagged
	fire(type, victim, info["source"])

## Plays every layer of `hit_type`. `victim` = who was hit (or the actor the event is about); `source` = who hit.
func fire(hit_type: StringName, victim: Node, source: Node) -> void:
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
	if sound_on and p.sound:
		sound.play(p.sound, p.volume_db, p.pitch)
		layer_counts["sound"] += 1
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

## F3 trigger buttons: play the effects only. No damage, no Health call, no state change.
func test_hit(kind: StringName) -> void:
	match kind:
		&"sword": fire(&"sword", _dummy, _player)
		&"parry": fire(&"parry", _player, _boss if _boss else _dummy)
		&"player_hit": fire(&"player_hit", _player, _dummy)
		&"kill": fire(&"kill", _boss if _boss else _dummy, null)

func status_text() -> String:
	return "trauma: %.2f  offset: (%.1f, %.1f)\nhit-stop: %df left%s\nlast hit: %s  sounds: %d" % [
		shake.trauma, shake.offset.x, shake.offset.y, stop.frames_left(), "  (on)" if stop.is_active() else "",
		last_hit, sound.play_count]
