class_name SoundCue
extends Resource
## One sound of a SoundSet slot: a stream (an AudioStreamRandomizer gives variety) + level + pitch. Empty stream = silent.

@export var stream: AudioStream
@export_range(-30.0, 12.0, 0.2, "or_greater", "or_less") var volume_db := 0.0
## Base pitch; SoundBoard adds a small random +/- on top.
@export_range(0.3, 2.0, 0.01, "or_greater", "or_less") var pitch := 1.0
## Extra pitch as a node nears its break: pitch + pitch_gain * (1 - hp fraction). 0 = off. Only for hits that report `hp_fraction`.
@export_range(0.0, 1.0, 0.01, "or_greater", "or_less") var pitch_gain := 0.0
