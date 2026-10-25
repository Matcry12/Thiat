extends Node
class_name HitSound
## Plays hit sounds with a little random pitch so repeats do not sound machine-gunned. The sounds themselves
## come from the HitFxProfile (data/hit_fx/*.tres -> assets/audio/*.wav): swap a file and nothing else changes.

@export_range(-30.0, 12.0, 0.2, "or_greater", "or_less") var volume_db := 0.0
## +/- fraction of pitch picked at random per play (0.08 = +/-8%).
@export_range(0.0, 0.3, 0.002, "or_greater", "or_less") var pitch_variation := 0.08
@export var voices := 8

var play_count := 0
var last_pitch := 1.0
var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	for i in voices:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func play(stream: AudioStream, db := 0.0, pitch := 1.0) -> void:
	if stream == null or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	last_pitch = pitch * (1.0 + randf_range(-pitch_variation, pitch_variation))
	p.stream = stream
	p.volume_db = db + volume_db
	p.pitch_scale = last_pitch
	p.play()
	play_count += 1
