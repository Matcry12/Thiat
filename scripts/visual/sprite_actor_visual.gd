@tool
extends ActorVisual
class_name SpriteActorVisual
## Placeholder sprite implementation of ActorVisual (decision 0010).
##
## Structure: a `Body` Sprite2D (the upright character) + a separate `Shadow`
## Sprite2D. The shadow is its own node so replacing the body texture never
## loses the shadow.
##
## To swap in a real asset: set `body_texture` / `shadow_texture` to the new
## PNGs, then DRAG the Body and Shadow sprites into place in the editor.
## No script change needed.

## Textures apply immediately, in the editor too (@tool), so a swapped picture is
## visible without pressing play.
##
## There is deliberately NO position/offset export here. The Body and Shadow
## sprites are placed BY HAND in the editor — drag them until the feet sit at
## this node's origin. A script that also wrote those positions would silently
## overwrite your dragging when the game starts. One owner per property.
@export var body_texture: Texture2D: set = _set_body_texture
@export var shadow_texture: Texture2D: set = _set_shadow_texture
@export var flip_when_facing_left := true
@export var idle_fps := 3.5               ## idle animation speed (frames per second); only used when Body is an AnimatedSprite2D
@export var run_fps := 8.0                ## run animation speed
@export var run_bob := 2.0                ## pixels of vertical bob while running, STATIC bodies only (an animated Body bobs by itself)
@export var bob_speed := 10.0             ## bob cycles per second-ish (radians/sec fed to sin())

@export_group("Run bounce (animated body only)")
enum BounceMode { STEPPED, SMOOTH }
enum SnapMode { NONE, WORLD_PX, ART_PX }
@export var run_bounce_on := true
@export var bounce_mode := BounceMode.SMOOTH              ## SMOOTH = eased curve (floaty); STEPPED = the per-frame table below
@export var snap_mode := SnapMode.WORLD_PX                ## SMOOTH only: round the lift to whole world px (1/2 art px), whole art px, or not at all
@export var bounce_amp_px := 3.0                          ## SMOOTH: lift at the top, in world px
@export var bounces_per_cycle := 2.0                      ## SMOOTH: bounces per full run cycle (6 frames). 2 = one per step
@export var ease_power := 1.5                             ## SMOOTH: >1 = longer, softer near the ground; <1 = more rounded top
@export var bounce_px := 1.0                              ## art pixels of lift on an "up" frame (x the per-frame value below)
@export var bounce_snap := true                           ## round the lift to whole art pixels (keeps pixel art crisp)
## Lift per run frame, in art-pixel units (1 = up). Frames 2 and 5 are the passing poses (legs
## together-ish, mid-step) = up; 1/3/4/6 are planted/contact = 0. Two bounces per 6-frame cycle.
@export var bounce_offsets := PackedFloat32Array([0, 1, 0, 0, 1, 0])
@export var squash_on := false                         ## default off: a non-integer scale (2.06) makes pixel widths uneven
@export var squash_amount := 1.0 / 32.0                   ## wider by this fraction, shorter by the same (1/32 = one art pixel)
@export var squash_time := 0.06                           ## seconds the squash lasts, fading back to normal
@export var squash_frames := PackedInt32Array([0, 3])     ## 0-based run frames where a foot lands
@export var feet_row := 29.0                              ## art row (from sprite top) of the feet's bottom edge; squash keeps this row still
@export_group("Shadow (breathes with the bounce)")
@export var shadow_on := true
@export var shadow_min_scale := 0.8   ## Shadow scale at full lift (1 = no change)
@export var shadow_min_alpha := 0.75  ## Shadow opacity at full lift (1 = no change)
@export_group("")

## Run-bounce events for RunDust (and any future effect). The visual announces; listeners decide.
signal landed        ## lift just returned to 0 while running
signal run_started   ## standing -> running

## Body is a Sprite2D (static, e.g. the dummy) or an AnimatedSprite2D (the player). Both share
## flip_h / modulate / material, so flash, tint and recoil need no special case.
@onready var body: Node2D = $Body
@onready var shadow: Sprite2D = $Shadow

var _rest_position := Vector2.ZERO   ## the position you dragged Body to; bob returns here
var _facing_left := false
var _running := false
var _bob_t := 0.0
var _rest_scale := Vector2.ONE
var _last_frame := -1
var _squash_left := 0.0
var _prev_lift := 0.0
var _shadow_rest_scale := Vector2.ONE
var _shadow_rest_alpha := 1.0

## "idle"/"run" fps = SpriteFrames' own speed * speed_scale, so the .tres is never written to.
func _anim() -> AnimatedSprite2D:
	return get_node_or_null("Body") as AnimatedSprite2D

func _play(anim_name: StringName) -> void:
	var a := _anim()
	if a == null or a.sprite_frames == null or not a.sprite_frames.has_animation(anim_name):
		return
	var fps := run_fps if anim_name == &"run" else idle_fps
	a.speed_scale = fps / maxf(a.sprite_frames.get_animation_speed(anim_name), 0.001)
	if a.animation != anim_name or not a.is_playing():
		a.play(anim_name)

## Current animation name, for F3.
func status_text() -> String:
	var a := _anim()
	if a == null or a.sprite_frames == null:
		return "static body"
	return "anim: %s  frame: %d/%d  fps: %.1f  y: %+.1f  squash: %.2f  shadow: %.2f  dust: %d" % [a.animation, a.frame + 1, a.sprite_frames.get_frame_count(a.animation), a.sprite_frames.get_animation_speed(a.animation) * a.speed_scale, a.position.y - _rest_position.y, _squash_left, _shadow_scale_now(), _dust_alive()]

func _shadow_scale_now() -> float:
	return shadow.scale.x / _shadow_rest_scale.x if shadow else 1.0

func _dust_alive() -> int:
	var d := get_node_or_null("RunDust")
	return d.alive_count() if d else 0

## The ONLY writer of Shadow.scale / alpha (never its position: that stays hand-placed). `lift` is world px.
func _update_shadow(lift: float) -> void:
	if shadow == null:
		return
	var k := 0.0
	if shadow_on:
		var full := bounce_amp_px if bounce_mode == BounceMode.SMOOTH else maxf(float(Array(bounce_offsets).max()) * bounce_px * _rest_scale.y, 0.001)
		k = clampf(lift / maxf(full, 0.001), 0.0, 1.0)
	shadow.scale = _shadow_rest_scale * lerpf(1.0, shadow_min_scale, k)
	shadow.modulate.a = _shadow_rest_alpha * lerpf(1.0, shadow_min_alpha, k)

func _ready() -> void:
	_apply_all()
	if not Engine.is_editor_hint() and has_node("Shadow"):
		_shadow_rest_scale = $Shadow.scale
		_shadow_rest_alpha = $Shadow.modulate.a
	var b := get_node_or_null("Body") as Node2D
	if b:
		_rest_position = b.position
		_rest_scale = b.scale
	if not Engine.is_editor_hint():
		_play(&"idle")

func _apply_all() -> void:
	var b := get_node_or_null("Body") as Sprite2D   ## null for an AnimatedSprite2D: its frames come from SpriteFrames
	var sh := get_node_or_null("Shadow") as Sprite2D
	if b:
		b.texture = body_texture
	if sh:
		sh.texture = shadow_texture

func _set_body_texture(v: Texture2D) -> void:
	body_texture = v
	_apply_all()

func _set_shadow_texture(v: Texture2D) -> void:
	shadow_texture = v
	_apply_all()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var a := _anim()
	if a != null:
		_update_run_bounce(a, delta)
		return
	if not _running:
		return
	_bob_t += delta * bob_speed
	body.position = _rest_position + Vector2(0, sin(_bob_t) * run_bob)

## Only writer of Body.position.y and Body.scale for an animated body. Keyed to the animation frame.
func _update_run_bounce(a: AnimatedSprite2D, delta: float) -> void:
	if not (_running and run_bounce_on and a.animation == &"run"):
		_last_frame = -1
		_prev_lift = 0.0
		_update_shadow(0.0)
		_reset_body(a)
		return
	var f := a.frame
	if f != _last_frame:
		_last_frame = f
		_squash_left = squash_time if squash_frames.has(f) else 0.0
	else:
		_squash_left = maxf(_squash_left - delta, 0.0)
	var lift_world: float   ## world px
	if bounce_mode == BounceMode.SMOOTH:
		var n := a.sprite_frames.get_frame_count(a.animation)
		var phase := (f + a.frame_progress) / float(n) * bounces_per_cycle
		lift_world = bounce_amp_px * pow(absf(sin(phase * PI)), ease_power)
		match snap_mode:
			SnapMode.WORLD_PX: lift_world = roundf(lift_world)
			SnapMode.ART_PX: lift_world = roundf(lift_world / _rest_scale.y) * _rest_scale.y
	else:
		var lift := (bounce_offsets[f] if f < bounce_offsets.size() else 0.0) * bounce_px
		if bounce_snap:
			lift = roundf(lift)
		lift_world = lift * _rest_scale.y
	_update_shadow(lift_world)
	if lift_world <= 0.0 and _prev_lift > 0.0:
		landed.emit()
	_prev_lift = lift_world
	var k := (_squash_left / squash_time) if (squash_on and squash_time > 0.0) else 0.0
	a.scale = _rest_scale * Vector2(1.0 + squash_amount * k, 1.0 - squash_amount * k)
	# feet stay put: the sprite is centred, so the feet sit (feet_row - h/2) art px below the node origin
	var half_h := a.sprite_frames.get_frame_texture(a.animation, f).get_height() * 0.5
	var feet := (feet_row - half_h) * _rest_scale.y
	a.position = _rest_position + Vector2(0, -lift_world + feet * (1.0 - a.scale.y / _rest_scale.y))

func _reset_body(a: AnimatedSprite2D) -> void:
	a.position = _rest_position
	a.scale = _rest_scale

func flash_target() -> CanvasItem:
	return get_node_or_null("Body") as CanvasItem

func set_move_state(state: String) -> void:
	var was_running := _running
	_running = state == "run"
	if _running and not was_running:
		run_started.emit()
	_play(&"run" if _running else &"idle")   # dodge counts as run too
	if not _running:
		_prev_lift = 0.0
		_update_shadow(0.0)
		body.position = _rest_position
		body.scale = _rest_scale
		_last_frame = -1

func set_facing(dir: Vector2) -> void:
	if not flip_when_facing_left or absf(dir.x) < 0.001:
		return
	# TODO: an 8-direction sprite set would pick an animation/frame name here
	# instead of a left/right flip.
	_facing_left = dir.x < 0.0
	(body as Object).set("flip_h", _facing_left)

func set_weapon_state(state: String) -> void:
	match state:
		"windup": body.modulate = Color.YELLOW
		"active": body.modulate = Color.RED
		"recovery": body.modulate = Color.GRAY
		_: body.modulate = Color.WHITE

func set_aim_angle(_angle: float) -> void:
	pass  # body never rotates with aim (2.5D, decision 0009); WeaponVisual handles aim.
