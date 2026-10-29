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
@export_group("Character rig (one resource per character)")
## Body frames + body/feet position + shadow size + weapon/hand/slash visual scale. null = use the scene's own Body as it is.
## Swapping the character is swapping this one resource (data/body_rigs/*.tres). F3 section "BodyRig" tunes it live.
@export var rig: BodyRig: set = _set_rig
@export var weapon_visual_path := NodePath("../WeaponVisual")
@export var hands_path := NodePath("../Hands")
@export_group("Directional body (3D-rendered sheets)")
## Used automatically when the SpriteFrames has `idle_side` (+ `idle_front` for a real front view) (see assets/characters/player/3d/): animations are
## `<idle|run|hit>_<front|side>`, timing is baked into the frames, and the old exports above (fps, code bounce) are skipped.
## A SpriteFrames with plain `idle` / `run` (the old drawn art) keeps the old behaviour: swapping art = swapping the resource.
## Facing is FRONT when the facing direction is within this many degrees of straight down, else SIDE (flipped for left).
## Facing UP has no back sprite: it keeps the side view for the current left/right.
@export var front_half_angle_deg := 45.0
## Extra degrees the facing must pass before front <-> side switches, so an aim on the border does not flicker.
@export var facing_hysteresis_deg := 6.0
## Baked run cycle: frames where a foot lands (RunDust puff) and where the body is highest (shadow shrinks).
@export var landing_frames := PackedInt32Array([1, 4])
@export var lift_frames := PackedInt32Array([2, 5])
## Scales the hit animation's baked hold times (1 = as exported from Blender).
@export_range(0.05, 4.0) var hit_time_scale := 1.0
## Side view: the left/right flip only changes when |dir.x| is above this, so jittery aiming near straight up never mirrors the body.
@export var flip_deadzone := 0.3
## Shadow shrink on the baked "up" run frames, world px (the old-art `bounce_amp_px` is a different feel number).
@export var directional_lift_px := 3.0
@export_group("Death pose")
## Used only when the SpriteFrames has a `death` animation. Plays when this actor's Health emits `died`, and
## goes back to idle/run once hp is above 0 again (Health.revive on respawn; there is no "revived" signal).
@export var health_path := NodePath("../Health")
## Speed multipliers for a GIF-timed set (one that has `death`, e.g. Pixel Plains): 1.0 = the baked GIF timing. They replace
## idle_fps / run_fps for such a set; sets without `death` keep the fps knobs above. Death holds its last frame until respawn.
@export_range(0.25, 20.0, 0.05) var idle_speed := 1.0
@export_range(0.25, 20.0, 0.05) var run_speed := 1.0
@export_range(0.25, 20.0, 0.05) var death_speed := 1.0
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
var _base := &"idle"             ## idle | run (the move state), independent of front/side
var _front := true               ## directional body: facing mostly down
var _hit_left := 0.0
var _dead := false
var _health: Health
var _shadow_base_scale := Vector2.ONE   ## the Shadow node's own scale (rig.shadow_scale multiplies it)             ## seconds of the hit animation still to play

## "idle"/"run" fps = SpriteFrames' own speed * speed_scale, so the .tres is never written to.
func _anim() -> AnimatedSprite2D:
	return get_node_or_null("Body") as AnimatedSprite2D

func _play(anim_name: StringName) -> void:
	_base = anim_name
	if _dead:
		return                       # the death pose stays until Health is back above 0
	if _hit_left > 0.0 and is_directional():
		return                       # the hit pose finishes first, then _process resumes idle/run
	_play_resolved(false)

## True when the SpriteFrames is a directional set (idle_front ...).
func is_directional() -> bool:
	var a := _anim()
	return a != null and a.sprite_frames != null and a.sprite_frames.has_animation(&"idle_side")

## False for a side-view-only set (idle_side but no idle_front, e.g. the Tiny RPG soldier): it never goes "front".
func _has_front() -> bool:
	var a := _anim()
	return a != null and a.sprite_frames != null and a.sprite_frames.has_animation(&"idle_front")

func _landing() -> PackedInt32Array:
	return rig.landing_frames if rig and not rig.landing_frames.is_empty() else landing_frames

func _lift() -> PackedInt32Array:
	return rig.lift_frames if rig and not rig.lift_frames.is_empty() else lift_frames

## `<base>_<front|side>` for a directional set, else the plain name (old art).
func resolved_name(base: StringName) -> StringName:
	return StringName("%s_%s" % [base, "front" if _front and _has_front() else "side"]) if is_directional() else base

func _play_resolved(keep_frame: bool) -> void:
	_hit_left = 0.0 if not is_directional() else _hit_left
	var a := _anim()
	if a == null or a.sprite_frames == null:
		return
	var n := resolved_name(_base)
	if not a.sprite_frames.has_animation(n):
		return
	if is_directional():
		a.speed_scale = 1.0           # hold times are baked into the frames
	else:
		var fps := run_fps if _base == &"run" else idle_fps
		a.speed_scale = (run_speed if _base == &"run" else idle_speed) if _has_death() else fps / maxf(a.sprite_frames.get_animation_speed(n), 0.001)
	if a.animation != n or not a.is_playing():
		var f := a.frame
		var p := a.frame_progress
		a.play(n)
		if keep_frame:               # front <-> side mid-run: stay on the same step of the cycle
			a.set_frame_and_progress(mini(f, a.sprite_frames.get_frame_count(n) - 1), p)

## Current animation name, for F3.
func status_text() -> String:
	var a := _anim()
	if a == null or a.sprite_frames == null:
		return "static body"
	var dir_txt := ("  facing: %s%s  hit: %.2fs" % ["front" if _front and _has_front() else "side", " (flipped)" if _facing_left and not (_front and _has_front()) else "", _hit_left]) if is_directional() else ""
	var dead_txt := "  DEAD" if _dead else ""
	var rig_txt := ("\n" + rig.status_text()) if rig else ""
	return "anim: %s  frame: %d/%d  fps: %.1f  y: %+.1f  squash: %.2f  shadow: %.2f  dust: %d" % [a.animation, a.frame + 1, a.sprite_frames.get_frame_count(a.animation), a.sprite_frames.get_animation_speed(a.animation) * a.speed_scale, a.position.y - _rest_position.y, _squash_left, _shadow_scale_now(), _dust_alive()] + dir_txt + dead_txt + rig_txt

func _shadow_scale_now() -> float:
	return shadow.scale.x / _shadow_rest_scale.x if shadow else 1.0

func _dust_alive() -> int:
	var d := get_node_or_null("RunDust")
	return d.alive_count() if d else 0

## Hides the shadow while the actor swims (WaterFx asks; the Visual owns its shadow node).
func set_shadow_hidden(v: bool) -> void:
	if shadow:
		shadow.visible = not v

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
	if has_node("Shadow"):
		_shadow_base_scale = $Shadow.scale
	_apply_rig_body()
	if not Engine.is_editor_hint() and has_node("Shadow"):
		_shadow_rest_scale = $Shadow.scale
		_shadow_rest_alpha = $Shadow.modulate.a
	var b := get_node_or_null("Body") as Node2D
	if b:
		_rest_position = b.position
		_rest_scale = b.scale
	if not Engine.is_editor_hint():
		_play(&"idle")
		_health = get_node_or_null(health_path) as Health
		if _health:
			_health.died.connect(_on_died)
		_apply_rig_siblings.call_deferred()      # WeaponVisual / Hands come later in the tree: wait until they are ready

func _has_death() -> bool:
	var a := _anim()
	return a != null and a.sprite_frames != null and a.sprite_frames.has_animation(&"death")

func _on_died() -> void:
	if not _has_death():
		return
	_dead = true
	_running = false
	_anim().speed_scale = death_speed
	_anim().play(&"death")

func _set_rig(v: BodyRig) -> void:
	if rig and rig.changed.is_connected(_on_rig_changed):
		rig.changed.disconnect(_on_rig_changed)
	rig = v
	if rig and not rig.changed.is_connected(_on_rig_changed):
		rig.changed.connect(_on_rig_changed)
	if is_node_ready():
		_on_rig_changed()

func _on_rig_changed() -> void:
	_apply_rig_body()
	_apply_rig_siblings()
	if is_node_ready() and not Engine.is_editor_hint():
		_rest_position = (body as Node2D).position
		_rest_scale = (body as Node2D).scale
		_shadow_rest_scale = ($Shadow as Node2D).scale if has_node("Shadow") else Vector2.ONE
		_play_resolved(true)

## Body frames, body position/scale (feet on the actor origin) and shadow size from the rig.
func _apply_rig_body() -> void:
	if rig == null:
		return
	var a := _anim()
	if a and rig.sprite_frames and a.sprite_frames != rig.sprite_frames:
		a.sprite_frames = rig.sprite_frames
	var b := get_node_or_null("Body") as Node2D
	if b:
		b.position = rig.body_position
		b.scale = rig.body_scale
	if has_node("Shadow"):
		($Shadow as Node2D).scale = _shadow_base_scale * rig.shadow_scale

func _apply_rig_siblings() -> void:
	if rig == null or Engine.is_editor_hint():
		return
	var wv := get_node_or_null(weapon_visual_path)
	if wv and wv.has_method("apply_rig"):
		wv.apply_rig(rig)
	var h := get_node_or_null(hands_path)
	if h and h.has_method("apply_rig"):
		h.apply_rig(rig)

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
	if _dead and _health and _health.hp > 0.0:
		_dead = false                # respawned
		_play_resolved(false)
	if a != null:
		if _dead:
			return
		if is_directional():
			_update_directional(a, delta)
		else:
			_update_run_bounce(a, delta)
		return
	if not _running:
		return
	_bob_t += delta * bob_speed
	body.position = _rest_position + Vector2(0, sin(_bob_t) * run_bob)

## Directional body: the bounce is baked into the art, so this only (1) ends the hit pose, (2) tells RunDust when a
## foot lands, (3) breathes the shadow on the baked "up" frames. Never moves the Body.
func _update_directional(a: AnimatedSprite2D, delta: float) -> void:
	if _hit_left > 0.0:
		_hit_left -= delta
		if _hit_left <= 0.0:
			_hit_left = 0.0
			_play_resolved(false)
	elif String(a.animation).begins_with("hit"):
		_play_resolved(false)         # never stay stuck on a hit pose (e.g. hit_time_scale edited live)
	var running_now := _running and _hit_left <= 0.0 and a.animation.begins_with("run")
	var lift := 0.0
	if running_now:
		var f := a.frame
		if f != _last_frame:
			_last_frame = f
			if _landing().has(f):
				landed.emit()
		if _lift().has(f):
			lift = directional_lift_px
	else:
		_last_frame = -1
	_update_shadow(lift)

## Hit pose: plays `hit_<front|side>` once, then back to idle/run. Called by flash() (HitFx calls that on every hit).
func play_hit() -> void:
	var a := _anim()
	if not is_directional() or not a.sprite_frames.has_animation(resolved_name(&"hit")):
		return
	var n := resolved_name(&"hit")
	var t := 0.0
	for i in a.sprite_frames.get_frame_count(n):
		t += a.sprite_frames.get_frame_duration(n, i) / maxf(a.sprite_frames.get_animation_speed(n), 0.001)
	_hit_left = t * hit_time_scale
	a.speed_scale = 1.0 / maxf(hit_time_scale, 0.001)
	a.play(n)

func flash(color: Color, duration: float) -> void:
	super.flash(color, duration)
	play_hit()

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

func is_facing_left() -> bool:
	return _facing_left

func set_facing(dir: Vector2) -> void:
	if is_directional():
		_set_facing_directional(dir)
		return
	if not flip_when_facing_left or absf(dir.x) < 0.001:
		return
	_facing_left = dir.x < 0.0
	(body as Object).set("flip_h", _facing_left)

## front = within front_half_angle of straight down; side = everything else (up included, no back sprite).
## Left/right comes from dir.x and is remembered, so aiming straight up/down never flips the body.
func _set_facing_directional(dir: Vector2) -> void:
	if dir.length_squared() < 0.0001:
		return
	var from_down := rad_to_deg(absf(dir.angle_to(Vector2.DOWN)))
	var limit := front_half_angle_deg + (facing_hysteresis_deg if _front else -facing_hysteresis_deg)
	var front_now := _has_front() and from_down < limit
	if absf(dir.x) > flip_deadzone:
		_facing_left = dir.x < 0.0
	(body as Object).set("flip_h", _facing_left and not front_now)
	if front_now != _front:
		_front = front_now
		if _hit_left <= 0.0:
			_play_resolved(true)
		else:
			var a := _anim()
			var n := resolved_name(&"hit")
			if a.sprite_frames.has_animation(n):
				var f := a.frame
				var p := a.frame_progress
				a.play(n)
				a.set_frame_and_progress(mini(f, a.sprite_frames.get_frame_count(n) - 1), p)

func set_weapon_state(state: String) -> void:
	match state:
		"windup": body.modulate = Color.YELLOW
		"active": body.modulate = Color.RED
		"recovery": body.modulate = Color.GRAY
		_: body.modulate = Color.WHITE

func set_aim_angle(_angle: float) -> void:
	pass  # body never rotates with aim (2.5D, decision 0009); WeaponVisual handles aim.
