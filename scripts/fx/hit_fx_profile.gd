extends Resource
class_name HitFxProfile
## The numbers for ONE hit type (data/hit_fx/<type>.tres). A new hit type is a new file, not new code.
## All values are starting points: tune them in the F3 panel. Frames are 60 fps frames.

## Which hit this row is for: sword, sword_boss, lunge, arrow, charged_arrow, parry, block, player_hit,
## phase_change, kill. HitFx picks the row by this name.
@export var hit_type: StringName = &""
@export_group("Hit-stop")
## Whole-game freeze. 0 = none. Never used for player_hit (the player is not frozen by getting hit).
@export var stop_frames := 3
## Kill only: after the freeze, run slower for slowmo_time seconds. 1.0 = off.
@export var slowmo_scale := 1.0
@export var slowmo_time := 0.0
@export_group("Flash")
@export var flash_time := 0.08
@export var flash_color := Color.WHITE
## 0 = the one who was hit, 1 = the one who hit (a parry flashes the attacker).
@export_range(0, 1) var flash_who := 0
@export_group("Shake")
## Trauma added to the camera (0..1; shake size grows with its square).
@export var shake := 0.2
@export_group("Sound")
@export var sound: AudioStream
@export var volume_db := 0.0
## Base pitch; HitSound adds a random +/- on top.
@export var pitch := 1.0
