class_name SoundBoard
extends Node
## The one owner of game sounds (sound-algorithm.md). `play(set, slot, info)` picks the slot's SoundCue and plays it on a free
## voice with a little random pitch. HitFx decides WHICH set and slot; this node only plays. Delete it and the game is silent.

## Off = no sound at all (feel without sound; replaces HitFx.sound_on).
@export var enabled := true
@export_range(-30.0, 12.0, 0.2, "or_greater", "or_less") var volume_db := 0.0
## +/- fraction of pitch picked at random per play (0.08 = +/-8%).
@export_range(0.0, 0.3, 0.002, "or_greater", "or_less") var pitch_variation := 0.08
@export_range(1, 32) var voices := 8: set = _set_voices

var play_count := 0
var last_pitch := 1.0
var last_event: StringName = &"-"
var silent_count := 0           ## slots asked for that were empty (or had no set)
var last_silent: StringName = &"-"
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _test_i := 0
var _test_text := "-"

func _ready() -> void:
	add_to_group("sound_board")
	add_to_group("debug")
	_set_voices(voices)

func _set_voices(v: int) -> void:
	voices = v
	if not is_inside_tree():
		return
	while _players.size() > v:
		_players.pop_back().queue_free()
	while _players.size() < v:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_next = 0

## Plays `slot` of `set`. `info.hp_fraction` raises the pitch by the cue's pitch_gain. True = a sound started.
func play(set: SoundSet, slot: StringName, info := {}) -> bool:
	if not enabled:
		return false
	var event := StringName("%s.%s" % [set.id if set else "-", String(slot).trim_suffix("_")])
	var c := set.cue(slot) if set else null
	if c == null:
		silent_count += 1
		last_silent = event
		return false
	return _start(c, event, float(info.get("hp_fraction", 1.0)))

func _start(c: SoundCue, event: StringName, hp_fraction: float) -> bool:
	if _players.is_empty():
		return false
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	last_pitch = (c.pitch + c.pitch_gain * (1.0 - hp_fraction)) * (1.0 + randf_range(-pitch_variation, pitch_variation))
	p.stream = c.stream
	p.volume_db = c.volume_db + volume_db
	p.pitch_scale = last_pitch
	p.play()
	play_count += 1
	last_event = event
	return true

func voices_busy() -> int:
	var n := 0
	for p in _players:
		if p.playing:
			n += 1
	return n

## F3 `Test sound`: plays the next filled slot of the next set (sound only: no HP, no state).
func test_next() -> void:
	var sets := SoundSet.all()
	var n := SoundSet.SLOTS.size()
	for k in sets.size() * n:
		var s := sets[floori(float(_test_i) / n) % sets.size()]
		var slot := SoundSet.SLOTS[_test_i % n]
		_test_i += 1
		if s.cue(slot) != null:
			_test_text = "%s.%s" % [s.id, String(slot).trim_suffix("_")]
			play(s, slot, {})
			return
	_test_text = "no sounds"

# ---- F3 debug contract
func debug_name() -> String:
	return "Sound"

func debug_category() -> String:
	return "FX & Hit"

func debug_children() -> Array:
	var out: Array = []
	for s in SoundSet.all():
		out.append({"name": "Sound " + String(s.id), "object": s})
	return out

func debug_actions() -> Array:
	return [{"label": "Test sound", "run": test_next}]

func status_text() -> String:
	return "%s\nlast: %s  plays: %d  voices busy: %d/%d\nsilent: %d (last %s)\ntest: %s" % [
		"on" if enabled else "OFF", last_event, play_count, voices_busy(), _players.size(), silent_count, last_silent, _test_text]
