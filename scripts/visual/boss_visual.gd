@tool
extends ActorVisual
class_name BossVisual
## Boss body. boss.gd never reaches inside: it connects its signals to the methods below (the contract), so any
## visual only has to provide the same methods (decision 0005, CLAUDE.md §5).
## Two looks, one contract: no `body_frames` = the flat placeholder circle; `body_frames` set = an AnimatedSprite2D
## `Body` + `Shadow` (temporary Tiny RPG orc, decision 0032). Swap back by clearing `body_frames` or swapping the resource.
##
## Animation names the SpriteFrames needs: idle, run, hit, death and one attack clip per entry in `attack_anims`.
## Timing stays in data: each attack window (telegraph / active / recovery, set on the BossAttack node) is filled by its
## share of the clip's frames, so the clip is stretched (or squeezed) to the window = speed_scale = clip length / data
## duration. The art never changes an attack's timing, and hitboxes are not touched.

@export var radius := 28.0
@export var base_color := Color(0.45, 0.07, 0.07)
@export var phase2_color := Color(0.4, 0.0, 0.3)
## Walking home after giving up: pale, so it reads as "can't be hurt right now".
@export var returning_color := Color(0.55, 0.7, 0.85)
@export var staggered_color := Color(0.85, 0.8, 0.3)
@export var defeated_color := Color(0.25, 0.25, 0.25)

@export_group("Sprite body (needs body_frames)")
@export var body_frames: SpriteFrames: set = _set_body_frames
## Where the Body sprite sits. Chosen so the feet land on the Shadow, inside the hurtbox.
@export var body_position := Vector2(0, 1): set = _set_body_position
## Whole numbers keep pixel art crisp. 3 makes the 22x15 px orc about 66x45 px (4 filled the 64 px hurtbox; the user picked 3).
@export var body_scale := Vector2(3, 3): set = _set_body_scale
@export_range(0.2, 6.0, 0.05) var shadow_scale := 1.3: set = _set_shadow_scale
@export var shadow_position := Vector2(0, 22): set = _set_shadow_position
## Boss action name -> clip. Actions not listed (and clips the frames lack) just keep the current pose.
@export var attack_anims := {"slam": &"attack1", "spread": &"attack2", "charge": &"attack1", "ring": &"attack2"}
## Clip frame index where the ACTIVE window starts (the strike), and where RECOVERY starts. Telegraph = frames before strike_frame.
@export var strike_frame := 3
@export var recover_frame := 5
## Actions whose ACTIVE window is a long move (the charge dash): the `run` clip loops for the whole window instead of a
## strike pose, and the window ends on the attack's real finish (the RECOVERY signal), not on a guessed time.
@export var loop_active_actions := PackedStringArray(["charge"])
## `run` clip speed multiplier while such a dash is on.
@export_range(0.5, 4.0, 0.1) var dash_run_speed := 2.0
## Art-pixel distance from the cell centre to the middle of the feet (measured on the Orc sheets: feet at columns 47-53 of 100).
## The flip mirrors the frame around its own centre, so the offset flips sign with the facing: the feet stay on the shadow.
@export var feet_x_px := 0.5: set = _set_feet_x
## The hurt clip is stretched to this many seconds. A hit during an attack keeps the attack pose (no stagger).
@export var hurt_time := 0.3
@export var idle_fps := 6.0
@export var run_fps := 10.0
@export var phase2_tint := Color(1.0, 0.7, 0.7)
@export var returning_tint := Color(0.7, 0.85, 1.0)
@export var staggered_tint := Color(1.0, 0.9, 0.45)
## Left/right flip only changes when |dir.x| is above this (the facing arrives normalised).
@export var flip_deadzone := 0.2

enum Pose { MOVE, ATTACK, HURT, DEAD }

var _phase := 1
var _returning := false
var _staggered := false
var _defeated := false
var _pose := Pose.MOVE
var _running := false
var _action := ""
var _atk_phase := 0           ## BossAttack.Phase: 1 telegraph, 2 active, 3 recovery
var _atk_dur := 0.0
var _atk_t := 0.0
var _hurt_left := 0.0
var _dash := false            ## ACTIVE window of a loop_active_actions attack: the run clip loops

func _ready() -> void:
	_apply_body()

func has_body() -> bool:
	return body_frames != null and get_node_or_null("Body") is AnimatedSprite2D

func _anim() -> AnimatedSprite2D:
	return get_node_or_null("Body") as AnimatedSprite2D

func _set_body_frames(v: SpriteFrames) -> void:
	body_frames = v
	_apply_body()
func _set_body_position(v: Vector2) -> void:
	body_position = v
	_apply_body()
func _set_body_scale(v: Vector2) -> void:
	body_scale = v
	_apply_body()
func _set_shadow_scale(v: float) -> void:
	shadow_scale = v
	_apply_body()
func _set_feet_x(v: float) -> void:
	feet_x_px = v
	_apply_body()
func _set_shadow_position(v: Vector2) -> void:
	shadow_position = v
	_apply_body()

func _apply_body() -> void:
	if not is_node_ready():
		return
	var a := _anim()
	if a:
		a.visible = body_frames != null
		a.sprite_frames = body_frames
		a.position = body_position
		a.scale = body_scale
		a.offset.x = -feet_x_px if not a.flip_h else feet_x_px
		if body_frames and not Engine.is_editor_hint():
			_resume_pose()
	var sh := get_node_or_null("Shadow") as Sprite2D
	if sh:
		sh.visible = body_frames != null
		sh.position = shadow_position
		sh.scale = Vector2.ONE * shadow_scale
	queue_redraw()

## After body_frames was cleared and set again (F3, swap): pick the right clip for what the boss is doing NOW.
## Idle / walk when no attack is running; the attack clip again (at the right frame) when one still is.
func _resume_pose() -> void:
	if _pose == Pose.DEAD:
		_play(&"death", 1.0)
	elif _atk_phase > 0 and _action != "":
		_pose = Pose.ATTACK
		if _dash:
			_play_dash()
		else:
			_start_attack_clip()
	else:
		_pose = Pose.MOVE
		_play_move()

func set_phase(p: int) -> void:
	_phase = p
	_tint()
	queue_redraw()

## state = Boss.Aggro (0 idle, 1 engaged, 2 returning). Only "returning" looks different.
func set_aggro(state: int) -> void:
	_returning = state == 2
	_tint()
	queue_redraw()

func set_staggered(on: bool) -> void:
	_staggered = on
	_tint()
	queue_redraw()

func set_defeated() -> void:
	_defeated = true
	_pose = Pose.DEAD
	_play(&"death", 1.0)
	_tint()
	queue_redraw()

func _tint() -> void:
	var a := _anim()
	if a == null:
		return
	var c := Color.WHITE
	if _phase >= 2:
		c = phase2_tint
	if _returning:
		c = returning_tint
	if _staggered:
		c = staggered_tint
	if _defeated:
		c = Color.WHITE
	a.modulate = c

## "idle" | "run": from the boss's own velocity (boss.gd tells us each frame; attack / hurt / death poses win).
func set_move_state(state: String) -> void:
	var run := state == "run"
	if run == _running:
		return
	_running = run
	if _pose == Pose.MOVE:
		_play_move()

func set_facing(dir: Vector2) -> void:
	var a := _anim()
	if a == null or absf(dir.x) < flip_deadzone or _pose == Pose.DEAD:
		return
	a.flip_h = dir.x < 0.0
	a.offset.x = -feet_x_px if not a.flip_h else feet_x_px

## Called for every attack phase change (boss.gd forwards BossAttack.phase_changed). phase: 0 idle (over), 1 telegraph,
## 2 active, 3 recovery. `duration` = that window's length in seconds, straight from the attack's data.
func set_attack_phase(action: String, phase: int, duration: float) -> void:
	if _pose == Pose.DEAD:
		return
	_atk_phase = phase
	_atk_dur = duration
	_atk_t = 0.0
	if phase == 0:
		_action = ""
		_dash = false
		if _pose == Pose.ATTACK and has_body():
			_pose = Pose.MOVE
			_play_move()
		return
	if phase == 1:       # a multi-beat attack (the ring) may send TELEGRAPH again: the wind-up just replays
		_action = action
	if not has_body():
		return
	var was_dash := _dash
	_dash = false
	if phase == 2 and loop_active_actions.has(_action):
		_dash = true
		_pose = Pose.ATTACK
		_play_dash()
		return
	if phase == 1 or was_dash or _action == "":
		_start_attack_clip()
	else:
		_drive_attack()

func _play_dash() -> void:
	var a := _anim()
	if a.sprite_frames.has_animation(&"run"):
		_play(&"run", dash_run_speed * run_fps / maxf(a.sprite_frames.get_animation_speed(&"run"), 0.001))

## Starts this attack's clip, paused: _drive_attack picks the frame from the window's progress.
func _start_attack_clip() -> void:
	var clip := StringName(attack_anims.get(_action, &""))
	if _anim().sprite_frames.has_animation(clip):
		_pose = Pose.ATTACK
		_anim().animation = clip
		_anim().pause()
		_drive_attack()

## Hit flash by HitFx; the orc also plays its hurt clip, unless it is mid-attack (it is not staggered by a hit).
func flash(color: Color, duration: float) -> void:
	super.flash(color, duration)
	if has_body() and _pose == Pose.MOVE and _anim().sprite_frames.has_animation(&"hit"):
		_pose = Pose.HURT
		_hurt_left = hurt_time
		_play(&"hit", _clip_seconds(&"hit") / maxf(hurt_time, 0.01))

func flash_target() -> CanvasItem:
	return _anim() if has_body() else self

func _clip_seconds(n: StringName) -> float:
	var f := _anim().sprite_frames
	return f.get_frame_count(n) / maxf(f.get_animation_speed(n), 0.001)

func _play(n: StringName, speed_scale := 1.0) -> void:
	var a := _anim()
	if a == null or a.sprite_frames == null or not a.sprite_frames.has_animation(n):
		return
	a.speed_scale = speed_scale
	a.play(n)

func _play_move() -> void:
	var n := &"run" if _running else &"idle"
	var a := _anim()
	if a == null or a.sprite_frames == null or not a.sprite_frames.has_animation(n):
		return
	var fps := run_fps if _running else idle_fps
	if a.animation != n or not a.is_playing():
		_play(n, fps / maxf(a.sprite_frames.get_animation_speed(n), 0.001))

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not has_body():
		return
	match _pose:
		Pose.ATTACK:
			_atk_t += delta
			_drive_attack()
		Pose.HURT:
			_hurt_left -= delta
			if _hurt_left <= 0.0:
				_pose = Pose.MOVE
				_play_move()

## Frame = this window's share of the clip: telegraph = [0, strike), active = [strike, recover), recovery = [recover, end).
func _drive_attack() -> void:
	if _pose != Pose.ATTACK or _dash:
		return
	var a := _anim()
	var n := a.sprite_frames.get_frame_count(a.animation)
	var lo := 0
	var hi := clampi(strike_frame, 1, n)
	if _atk_phase == 2:
		lo = hi
		hi = clampi(recover_frame, lo + 1, n)
	elif _atk_phase == 3:
		lo = clampi(recover_frame, 0, n - 1)
		hi = n
	var k := clampf(_atk_t / maxf(_atk_dur, 0.001), 0.0, 0.9999)
	a.frame = lo + int(k * (hi - lo))

## Text for F3 (Boss status area).
func status_text() -> String:
	if not has_body():
		return "visual: placeholder circle"
	var a := _anim()
	return "visual: %s  pose: %s  frame %d/%d  scale %s" % [a.animation, Pose.keys()[_pose].to_lower(), a.frame + 1, a.sprite_frames.get_frame_count(a.animation), body_scale]

func _draw() -> void:
	if has_body():
		return
	var c := base_color if _phase < 2 else phase2_color
	if _returning:
		c = returning_color
	if _staggered:
		c = staggered_color
	if _defeated:
		c = defeated_color
	draw_circle(Vector2.ZERO, radius, c)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, c.lightened(0.4), 2.0)
