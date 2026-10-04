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
@export var run_fps := 10.0               ## run animation speed
@export var run_bob := 2.0                ## pixels of vertical bob while running, STATIC bodies only (an animated Body bobs by itself)
@export var bob_speed := 10.0             ## bob cycles per second-ish (radians/sec fed to sin())

## Body is a Sprite2D (static, e.g. the dummy) or an AnimatedSprite2D (the player). Both share
## flip_h / modulate / material, so flash, tint and recoil need no special case.
@onready var body: Node2D = $Body
@onready var shadow: Sprite2D = $Shadow

var _rest_position := Vector2.ZERO   ## the position you dragged Body to; bob returns here
var _facing_left := false
var _running := false
var _bob_t := 0.0

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
	return "anim: %s  frame: %d/%d  fps: %.1f" % [a.animation, a.frame + 1, a.sprite_frames.get_frame_count(a.animation), a.sprite_frames.get_animation_speed(a.animation) * a.speed_scale]

func _ready() -> void:
	_apply_all()
	var b := get_node_or_null("Body") as Node2D
	if b:
		_rest_position = b.position
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
	if not _running or _anim() != null:
		return
	_bob_t += delta * bob_speed
	body.position = _rest_position + Vector2(0, sin(_bob_t) * run_bob)

func flash_target() -> CanvasItem:
	return get_node_or_null("Body") as CanvasItem

func set_move_state(state: String) -> void:
	_running = state == "run"
	_play(&"run" if _running else &"idle")   # dodge counts as run too
	if not _running:
		body.position = _rest_position

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
