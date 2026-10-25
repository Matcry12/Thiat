@tool
extends Node2D
class_name HandsVisual
## Two round hands that hold the weapon (Soul Knight / Gungeon look).
##
## Each frame it READS the current weapon model's `HandMain` / `HandOff` Marker2D
## and draws a hand on each. It never writes into the weapon (one owner: the
## model scene owns where the hands go). No weapon / no markers -> the hands
## rest beside the body at the exported rest offsets.
##
## Driven only by bind_model() / set_aim_angle() / set_drawing(), wired in
## player.gd. A bow draw is a pose offset on the OFF hand (pulled back along
## the model's own forward axis) - no combat code is reached into.
##
## LOOK: a clean circle (outline ring + fill).
## RELAXED POSE: bare hands / tools (model in group `free_hands`) or no markers, with the weapon idle:
## front hand at the body's side, back hand peeking out from behind the body, swinging on a walk.

var hand_radius := 5.0
## Node (sibling BEFORE the body) the back hand is drawn into. Missing = a code-made child at z -1.
@export var back_hand_path := NodePath("../BackHand")
## Outline thickness in px.
@export var outline_width := 2.0
## Pixel look: the disc is built from square blocks on this grid (same grid as the swing FX).
@export var pixel_size := 1.0
@export var fill_color := Color(0.96, 0.96, 0.98)
@export var outline_color := Color(0.08, 0.08, 0.1)

## The next vars are NOT @export on purpose: SpriteActorVisual.apply_rig() overwrites them from the character's BodyRig, which is their one owner (tune them under F3 "BodyRig").
## Relative to this node, in AIM space: x = toward the aim, y = to the right of it.
var rest_offset_main := Vector2(6, 15)
var rest_offset_off := Vector2(6, -15)

@export_group("Relaxed pose (screen space, x = toward facing, y = down)")
## Hand beside the torso, drawn over the body.
var idle_front := Vector2(-16, -1)
## Hand behind the torso, drawn UNDER the body so it peeks out.
var idle_back := Vector2(15, 1)
## Seconds to blend between relaxed pose and weapon markers (so a punch does not snap).
@export var relax_blend_time := 0.06
@export_group("Walk sway")
var sway_x := 5.0
var sway_y := 2.0
## Radians per second of the swing.
var sway_speed := 14.0
## Seconds for the swing to fade out on stop.
@export var sway_ease_time := 0.12

@export_group("Bow draw")
## How far the off hand is pulled back while drawing, in px.
@export var draw_pull := 8.0
## Seconds to reach full pull / to let go.
@export var draw_time := 0.12

var _model: Node2D
var _visual_scale := 1.0

## Applied by SpriteActorVisual from the character's BodyRig.
func apply_rig(r: BodyRig) -> void:
	hand_radius = r.hand_radius
	rest_offset_main = r.hand_rest_main
	rest_offset_off = r.hand_rest_off
	_visual_scale = r.visual_scale
	idle_front = r.hand_idle_front
	idle_back = r.hand_idle_back
	sway_x = r.hand_sway_x
	sway_y = r.hand_sway_y
	sway_speed = r.hand_sway_speed
	queue_redraw()
var _aim := 0.0
var _guarding := false
var _face_set := false   ## true once set_facing_left() is called (body owns the flip)
var _face_left := false
var _busy := false   ## weapon not idle (windup / active / recovery)
var _running := false
var _relax := 0.0    ## 0 = marker pose, 1 = relaxed pose (eased)
var _sway := 0.0     ## 0..1 walk-swing amount (eased)
var _phase := 0.0
var _back: Node2D    ## draws the back hand UNDER the body (z -1: over the shadow, below the body)
var _drawing := false
var _pull := 0.0     ## 0..1 eased draw amount (code-owned)

func bind_model(model: Node2D) -> void:
	_model = model
	_drawing = false
	_pull = 0.0

func set_move_state(state: String) -> void:
	_running = state == "run"

## "windup" / "active" / "recovery" / "idle" from the weapon holder.
func set_weapon_state(state: String) -> void:
	_busy = state != "idle"

func _ready() -> void:
	add_to_group("debug")
	_back = get_node_or_null(back_hand_path) as Node2D
	if _back == null:
		_back = Node2D.new()
		_back.name = "BackHand"
		_back.z_index = -1
		add_child(_back)
	_back.draw.connect(_draw_back)

## The body's remembered facing (SpriteActorVisual), so hands never disagree with the sprite flip.
func set_facing_left(on: bool) -> void:
	_face_set = true
	_face_left = on

func set_guarding(on: bool) -> void:
	_guarding = on

func _flip() -> float:
	return (-1.0 if _face_left else 1.0) if _face_set else (-1.0 if cos(_aim) < 0.0 else 1.0)

func set_aim_angle(angle: float) -> void:
	_aim = angle

## True while a bow is being drawn (normal shot wind-up, or the piercing charge).
func set_drawing(on: bool) -> void:
	_drawing = on

func is_drawing() -> bool:
	return _drawing

func pull_amount() -> float:
	return _pull

## One line for the F3 status panel.
func status_text() -> String:
	return "hands: %s  draw pull: %.2f  pose: %s (%.2f)  sway: %.2f" % ["drawing" if _drawing else "idle", _pull, "relaxed" if _relax > 0.5 else "markers", _relax, _sway]

## Bare hands / tool (group on the model root) or nothing to hold: the relaxed pose applies.
func _free_hands() -> bool:
	return not is_instance_valid(_model) or _model.is_in_group("free_hands") or _marker("HandMain") == null

func _marker(name_: String) -> Node2D:
	return _model.get_node_or_null(name_) as Node2D if is_instance_valid(_model) else null

## The two hand positions in GLOBAL space: [main, off].
func hand_positions() -> Array[Vector2]:
	var main := _marker("HandMain")
	var off := _marker("HandOff")
	var flip := _flip()     # keep main hand on the weapon's side when aiming left
	var rest_main := to_global(Vector2(rest_offset_main.x, rest_offset_main.y * flip).rotated(_aim))
	var rest_off := to_global(Vector2(rest_offset_off.x, rest_offset_off.y * flip).rotated(_aim))
	var out: Array[Vector2] = [
		main.global_position if main else rest_main,
		off.global_position if off else rest_off,
	]
	if off and _pull > 0.0:
		out[1] -= _model.global_transform.x.normalized() * draw_pull * _visual_scale * _pull
	if _relax > 0.0:
		var fx := _flip()     # same flip as the body
		var s := sin(_phase) * sway_x * _sway
		var lift := absf(sin(_phase)) * sway_y * _sway
		var front := to_global(Vector2(idle_front.x * fx + s * fx, idle_front.y - lift))
		var back := to_global(Vector2(idle_back.x * fx - s * fx, idle_back.y - lift))
		out[0] = out[0].lerp(front, _relax)
		out[1] = out[1].lerp(back, _relax)
	return out

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# Editor preview: no signals run here, so read the previewed model off WeaponVisual
		# (read-only) and redraw, so the hands show on the markers while you drag them.
		var wv := get_node_or_null("../WeaponVisual") as WeaponVisual
		_model = wv.get_model() if wv else null
		queue_redraw()
		return
	_pull = move_toward(_pull, 1.0 if _drawing else 0.0, delta / maxf(draw_time, 0.001))
	var relaxed := _free_hands() and not _busy and not _guarding and not _drawing
	_relax = move_toward(_relax, 1.0 if relaxed else 0.0, delta / maxf(relax_blend_time, 0.001))
	_sway = move_toward(_sway, 1.0 if _running else 0.0, delta / maxf(sway_ease_time, 0.001))
	if _sway > 0.0:
		_phase += delta * sway_speed
	queue_redraw()
	if _back:
		_back.queue_redraw()

func _draw() -> void:
	var p := hand_positions()
	_draw_hand(self, to_local(p[0]))
	if not _back_under():
		_draw_hand(self, to_local(p[1]))

func _draw_back() -> void:
	if _back_under():
		_draw_hand(_back, _back.to_local(hand_positions()[1]))

## Back hand goes under the body only once it is mostly in the relaxed pose.
func _back_under() -> bool:
	return _relax > 0.5

func _draw_hand(on: CanvasItem, center: Vector2) -> void:
	var n := ceili(hand_radius / pixel_size)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var d := Vector2(i, j).length() * pixel_size
			if d > hand_radius:
				continue
			var c := outline_color if d > hand_radius - outline_width else fill_color
			on.draw_rect(Rect2(center + Vector2(i, j) * pixel_size - Vector2.ONE * pixel_size * 0.5, Vector2.ONE * pixel_size), c)


# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")
func debug_name() -> String:
	return "Hands"

func debug_category() -> String:
	return "Character"
