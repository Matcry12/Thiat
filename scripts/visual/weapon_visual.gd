@tool
extends Node2D
class_name WeaponVisual
## The weapon's model sits on a rotating pivot (decision 0010). Since Step 1,
## the model (art + optional hitbox/muzzle) is its OWN SCENE (`WeaponData.model`,
## e.g. `scenes/weapons/wooden_sword_model.tscn`) instantiated under `SwingPivot` —
## swapping weapons swaps the whole model, never edits nodes in this scene.
## The model's children are hand-placed by its own scene's user and this
## script never writes into them; code owns only the pivot's rotation/position,
## exactly as before (decision 0011).
##
## All timing comes from `weapon` (a WeaponData resource), never a hardcoded second.

signal model_changed(model: Node2D)

## Loadout is the one owner of "current weapon" — set via set_weapon(), called
## by player.gd from loadout.active_weapon(). Not an @export: the editor never
## runs player.gd, so `preview_weapon_from` below drives the EDITOR preview
## instead (same pattern as CoverArc.preview_width_from).
var weapon: WeaponData: set = _set_weapon

## EDITOR PREVIEW ONLY. Resolved to a Loadout node; its weapons[0] is shown
## while editing, since no player.gd runs in the editor to set `weapon` for
## real (see cover_arc.gd's preview_width_from for the same trap/fix).
@export var preview_weapon_from: NodePath = NodePath("../Loadout")

## Aiming left mirrors the weapon rather than rotating it past vertical, so the
## model always reads as held upright — how Soul Knight does it.
@export var mirror_when_facing_left := true

## Swing motion, Soul Knight style (visual only - the hitbox timing is untouched):
## a readable pull-back (windup), then the blade JUMPS to the end of the arc in
## about one frame (the slash effect draws the path it "travelled"), holds there
## (follow-through), then drifts back. Ease values go to Godot's ease(): below
## 1.0 = fast start then settle, above 1.0 = slow start then accelerate.
@export var windup_ease := 0.35      ## pull-back curve
@export var recovery_ease := 0.6     ## drift back, unhurried
## Seconds the blade takes to reach the end of the arc once ACTIVE starts.
## 0.016 = one frame at 60 fps; 0 = instant.
@export var snap_time := 0.016
## Seconds the blade stays at the end of the arc at the start of RECOVERY
## (clamped to the recovery time) before it eases back to rest.
@export var follow_through_hold := 0.06

## Block pose (decision 0015). The ANGLE is per weapon (WeaponData.
## guard_angle_degrees); how fast the arm gets there is a feel number here.
## Raise must beat the 0.25s parry window by a wide margin, or the pose would
## still be travelling when the parry already landed.
@export var guard_raise_time := 0.06
@export var guard_lower_time := 0.12
@export var guard_ease := 0.4        ## below 1 = snap into the guard

## Draw layer of the blade, held item and slash, above the y-sorted actors (z 0), so a slime just south of the player never covers the swing.
## The player's body sits at 0, so the weapon is over the body too (it always was: it is drawn after it).
@export var weapon_z := 1: set = _set_weapon_z

func _set_weapon_z(v: int) -> void:
	weapon_z = v
	z_index = v

## Tick this in the EDITOR to see the weapon's guard pose instead of its rest
## pose, then edit Guard Angle / Forward / Side on the weapon's data and watch it
## move. Editor-only: the running game ignores it.
@export var preview_guard_pose := false: set = _set_preview_guard

## ONE pivot swings everything: the model's art AND its hitbox hang off it, so
## the picture and the hit area turn as a single rigid arm.
@onready var _swing_pivot: Node2D = get_node_or_null("SwingPivot")

var _model: Node2D
var _hit_status := "hit: manual"   ## F3: hit: auto LxW tip T | manual (0061)
## The character's rig (set by SpriteActorVisual): weapon visual scale. Null = the old big body (scale 1).
var rig: BodyRig

## Applies a BodyRig: rescales the weapon ART (never the hitbox / muzzle), and tells SwingFx the crescent scale.
func apply_rig(r: BodyRig) -> void:
	rig = r
	_apply_model_scale()
	var fx := get_node_or_null("SwingFx")
	if fx and fx.has_method("set_slash_scale"):
		fx.set_slash_scale(rig.slash_scale if rig else 1.0)
	if _guarding:
		_pivot_pos = _guard_offset()

## The hand point: the player's `MainHandHold` marker (sibling, draggable in the editor) + `hand_nudge` (F3, live), x mirrored when the body faces left. The ONE place
## WeaponVisual's position is set. Absolute, so re-applying never adds up. The hit area, muzzle, slash and held item are
## children of this node, so they follow the picture. No Hand marker = the scene's own position.
@export var hand_nudge := Vector2.ZERO: set = _set_hand_nudge

func _set_hand_nudge(v: Vector2) -> void:
	hand_nudge = v
	_apply_hand()

func _apply_hand() -> void:
	var h := get_node_or_null("../MainHandHold") as Node2D if is_inside_tree() else null
	if h and not Engine.is_editor_hint():
		var v := get_node_or_null("../Visual")   # the same flag that flips the body picture (SpriteActorVisual._facing_left)
		var sign_x := -1.0 if v and v.has_method("is_facing_left") and v.is_facing_left() else 1.0
		var p := h.position + hand_nudge
		if not dev_hold_still and v and v.has_method("hand_frame_offset"):
			p += v.hand_frame_offset()   # body frames / bounce move the picture; the hand goes with it (BodyRig.hand_follow)
		position = Vector2(p.x * sign_x, p.y)   # only x mirrors

## Grip marker of the model scene (draggable along the weapon in the editor): the picture pixel under it is the held point.
## Every other child of the model moves by -grip, then Grip sits at 0,0 (the rest of the code keeps its "origin = grip" rule).
## No Grip = no shift. Runs once per model, before the art fit caches anything.
func _apply_grip() -> void:
	var g := _model.get_node_or_null("MainHandGrip") as Node2D if _model else null
	if g == null:
		return
	var d := g.position
	g.position = Vector2.ZERO
	if d == Vector2.ZERO:
		return
	for c in _model.get_children():
		var n := c as Node2D
		if n != null and n != g:
			n.position -= d

func _follow_dy() -> float:
	var v := get_node_or_null("../Visual")
	return v.hand_frame_offset().y if v and v.has_method("hand_frame_offset") and not dev_hold_still else 0.0

func hand_point() -> Vector2:
	return global_position

const Fit := preload("res://scripts/weapons/weapon_hit_fit.gd")
const SOFT_SHADER := preload("res://scripts/visual/soft_pixel.gdshader")
var _soft_mat: ShaderMaterial

func soft_on() -> bool:
	return rig != null and rig.soft_edges

## Soft edges (BodyRig): the same material on everything held: the model's Art, the SwingArt copy, the ghosts, the held item icon. Off = no material, as before.
func _apply_soft() -> void:
	if _soft_mat == null:
		_soft_mat = ShaderMaterial.new()
		_soft_mat.shader = SOFT_SHADER
	_soft_mat.set_shader_parameter(&"edge_width", rig.soft_edge_width if rig else 1.0)
	var mat: Material = _soft_mat if soft_on() else null
	var art := _model.get_node_or_null("Art") as CanvasItem if _model else null
	if art:
		art.material = mat
	if _swing_art:
		for c in _swing_art.get_children():
			(c as CanvasItem).material = mat
	if ghosts:
		ghosts.set_soft(mat)
	var held := get_node_or_null("HeldItem") as CanvasItem
	if held:
		held.material = mat

func visual_scale() -> float:
	return rig.visual_scale if rig else 1.0

## Scales the model's picture about the grip (model origin). Everything that is GAMEPLAY (an Area2D hitbox, a Muzzle,
## any other Marker2D) gets the inverse scale, so its WORLD transform is exactly what it was at scale 1.
func _apply_model_scale() -> void:
	_apply_soft()
	if _model == null:
		return
	var s := visual_scale()
	_model.scale = Vector2.ONE * s
	for c in _model.get_children():
		var n := c as Node2D
		if n == null:
			continue
		if not n.has_meta("rig_base"):
			n.set_meta("rig_base", [n.position, n.scale])
		var keep_world := n is Area2D or n.name == &"Muzzle" or (n is Marker2D and n.name != &"Tip" and n.name != &"OffHandGrip")   # Tip and OffHandGrip are part of the PICTURE, they scale with it
		var base: Array = n.get_meta("rig_base")
		if keep_world:
			n.position = base[0] / s
			n.scale = base[1] / s
		else:
			n.position = base[0]
			n.scale = base[1]

var aim_angle := 0.0

## Natural swing (0049): when weapon.swing_motion is set, the PICTURE is a copy of the model's Art on `SwingArt`, moved by the
## SwingMotion. Since 0050 the Hitbox sweeps the same SwingMotion.swing_path (WeaponHolder owns the side), not the old pivot arc.
var _swing_art: Node2D
var ghosts: SwingGhosts
var slash: SwingSlash
var ribbon: SwingRibbon
var _tip := Vector2.ZERO         ## blade end in the art frame (model's Tip marker), unscaled
var _motion: SwingMotion
var _rest_w := 1.0               ## 1 = hand at the motion's rest grip, 0 = guard (pivot decides)
var _art_grip := Vector2.ZERO
var _art_deg := 0.0
var _flip := 1.0                 ## side of the current / last swing: 1 = first way, -1 = reversed (alternate)
var _rest_flip := 1.0            ## side the resting blade shows; eases back to 1 after alternate_reset_time
var _since_swing := 99.0
var _from_grip := Vector2.ZERO   ## windup start (aim frame, unflipped)
var _from_deg := 0.0
var _ease_left := 0.0            ## guard pressed mid-swing: the picture eases to the guard pose instead of snapping
var _ease_grip := Vector2.ZERO
var _ease_deg := 0.0

var _phase := "idle"
var _t := 0.0
var _blade_angle := 0.0          ## SwingPivot.rotation, relative to this node (i.e. relative to aim)
var _phase_start_angle := 0.0
var _phase_target_angle := 0.0
var _guarding := false
var _pivot_pos := Vector2.ZERO   ## SwingPivot.position — code-owned, see _guard_offset()
var _phase_start_pos := Vector2.ZERO
var _phase_target_pos := Vector2.ZERO

func _ready() -> void:
	_apply_hand()
	if not Engine.is_editor_hint():
		_swing_art = Node2D.new()
		_swing_art.name = "SwingArt"
		ghosts = SwingGhosts.new()
		ghosts.name = "SwingGhosts"
		add_child(ghosts)
		slash = SwingSlash.new()
		add_child(slash)
		ribbon = SwingRibbon.new()
		add_child(ribbon)
		add_child(_swing_art)
		move_child(ghosts, 0)       # behind the blade; all under SwingPivot's picture slot
		move_child(slash, 1)
		move_child(ribbon, 2)
		move_child(_swing_art, 3)
	_rebuild_model()
	_blade_angle = deg_to_rad(_rest_angle())
	_phase_start_angle = _blade_angle
	_phase_target_angle = _blade_angle
	_apply_all()

## Called by the owner (player.gd) on a weapon swap. Frees the previous model
## and instantiates the new one under SwingPivot. Its instance is NOT owned by
## the scene (owner left unset), so the editor never saves it into player.tscn.
func set_weapon(data: WeaponData) -> void:
	weapon = data

func _set_weapon(v: WeaponData) -> void:
	if weapon and weapon.changed.is_connected(_refit_hit):
		weapon.changed.disconnect(_refit_hit)
	weapon = v
	if weapon and not weapon.changed.is_connected(_refit_hit):
		weapon.changed.connect(_refit_hit)   # F3 edits of the hit_* numbers apply to the held model at once (0061)
	_rebuild_model()
	_apply_all()
	if not Engine.is_editor_hint():
		_retarget_pose_to_new_weapon()

## Fix: a swap used to leave the pivot at the OLD weapon's rest/guard angle
## until the next swing/guard retriggered it. Snaps the pivot straight to the
## NEW weapon's pose (rest, or guard if F is currently held) the instant the
## model changes, instead of waiting for the next animation.
func _retarget_pose_to_new_weapon() -> void:
	if _guarding:
		_blade_angle = deg_to_rad(weapon.guard_angle_degrees if weapon else -90.0)
		_pivot_pos = _guard_offset()
	else:
		_blade_angle = deg_to_rad(_rest_angle())
		_pivot_pos = Vector2.ZERO
	_phase_start_angle = _blade_angle
	_phase_target_angle = _blade_angle
	_phase_start_pos = _pivot_pos
	_phase_target_pos = _pivot_pos
	if _swing_pivot:
		_swing_pivot.rotation = _blade_angle
		_swing_pivot.position = _pivot_pos


## The current model instance (or null). Used once by the owner right after
## connecting `model_changed`, to pick up the model that was built during
## _ready() before the connection existed — see player.gd.
func get_model() -> Node2D:
	return _model

## The weapon's hit_* numbers changed (F3 / override): measure again, put the shape + Tip back in place, redo the Tip-driven effects.
func _refit_hit() -> void:
	if _model == null or weapon == null:
		return
	apply_art_fit()
	_hit_status = Fit.apply(_model, weapon)
	_apply_model_scale()
	var art := _model.get_node_or_null("Art") as CanvasItem
	if art and _motion != null:
		art.visible = true   # _setup_swing_art copies it again and hides it
	_setup_swing_art()

## Art fit (WeaponData "Art fit"): the one owner. The scene's own Art transform is remembered once (meta `art_base`), so 0 / zero gives it back and re-applying never adds up.
func apply_art_fit() -> void:
	var art := _model.get_node_or_null("Art") as Node2D if _model else null
	if art == null or weapon == null:
		return
	if not art.has_meta("art_base"):
		art.set_meta("art_base", [art.position, art.rotation, art.scale])
	var b: Array = art.get_meta("art_base")
	art.position = b[0] + Vector2(weapon.art_nudge_x, weapon.art_nudge_y)
	art.rotation = b[1] + deg_to_rad(weapon.art_turn_deg)
	art.scale = b[2] if weapon.art_scale <= 0 else Vector2.ONE * weapon.art_scale
	art.set_meta("rig_base", [art.position, art.scale])   # _apply_model_scale puts children back to this; the fit is part of the picture

## F3 dev toggle (never saved): keep the weapon shown in its rest pose while tuning its fit.
var dev_hold_still := false
@export_range(-180.0, 180.0, 1.0) var dev_still_aim_deg := 0.0   ## with `Hold weapon still` on: the fixed aim direction (0 = right, 90 = down). Dev only (an F3 edit lives in tuning.cfg like any F3 row).

func debug_actions() -> Array:
	return [{"label": "Hold weapon still", "run": func(): dev_hold_still = not dev_hold_still}]

func _fit_status() -> String:
	if weapon == null:
		return "fit: -"
	var art := _model.get_node_or_null("Art") as Node2D if _model else null
	return "fit: x%s nudge %.1f,%.1f turn %.1f  still: %s aim %d  hand %.1f,%.1f follow %.1f  (%s)" % [str(snappedf(art.scale.x, 0.01)) if art else "-", weapon.art_nudge_x, weapon.art_nudge_y, weapon.art_turn_deg, "on" if dev_hold_still else "off", int(dev_still_aim_deg), position.x, position.y, _follow_dy(), weapon.resource_path.get_file().get_basename()]

func _rebuild_model() -> void:
	_hit_status = "hit: -"
	if _swing_pivot == null:
		_swing_pivot = get_node_or_null("SwingPivot")
	if _model:
		_model.queue_free()
		_model = null
	if _swing_pivot and weapon and weapon.model:
		_model = weapon.model.instantiate()
		_model.modulate = weapon.model_tint   # copper tools reuse a model, tinted (decision 0031)
		_swing_pivot.add_child(_model)
		_apply_grip()
		apply_art_fit()
		_hit_status = Fit.apply(_model, weapon)   # before _apply_model_scale caches the node positions
		_apply_model_scale()      # before model_changed: the hitbox / muzzle are already back at their real world transform
	_setup_swing_art()
	model_changed.emit(_model)

## With a SwingMotion: copy the model's Art onto SwingArt and hide the original (it stays in the model for tools / tests).
func _setup_swing_art() -> void:
	if _swing_art == null:
		return
	for c in _swing_art.get_children():
		c.queue_free()
	_motion = weapon.swing_motion if weapon else null
	var art := _model.get_node_or_null("Art") as Node2D if _model else null
	_swing_art.visible = _motion != null and art != null
	ghosts.visible = _swing_art.visible
	slash.hide_now()
	ribbon.hide_now()
	if not _swing_art.visible:
		_motion = null
		ghosts.bind_art(null, null)
		return
	var copy := art.duplicate() as Node2D
	_swing_art.add_child(copy)
	_swing_art.modulate = weapon.model_tint
	art.visible = false
	var ghost_src := art.duplicate() as Node2D
	ghost_src.visible = true
	ghost_src.modulate = Color.WHITE
	var tip := _model.get_node_or_null("Tip") as Node2D
	_tip = tip.position if tip else Vector2.ZERO
	ghosts.bind_art(ghost_src, _motion, tip.position if tip else Vector2.ZERO)
	ghosts.modulate = weapon.model_tint
	_apply_soft()

func _rest_angle() -> float:
	return weapon.rest_angle_degrees if weapon else -45.0

## Applies pivot pose (editor preview only — during play the pivot is driven
## by _process below).
func _apply_all() -> void:
	var pivot := get_node_or_null("SwingPivot") as Node2D
	if pivot and Engine.is_editor_hint():
		if preview_guard_pose and weapon:
			pivot.rotation = deg_to_rad(weapon.guard_angle_degrees)
			pivot.position = _guard_offset()
		else:
			pivot.rotation = deg_to_rad(_rest_angle())
			pivot.position = Vector2.ZERO

## The guard's arm offset. SwingPivot.position is CODE-OWNED (like its
## rotation): drag the player's `MainHandHold` marker to move the hand, or the model's `MainHandGrip` marker
## to move the held point — never SwingPivot, or the game will move it back.
func _guard_offset() -> Vector2:
	return Vector2(weapon.guard_forward, weapon.guard_side) * visual_scale() if weapon else Vector2.ZERO

func _set_preview_guard(v: bool) -> void:
	preview_guard_pose = v
	_apply_all()

## EDITOR ONLY (see preview_weapon_from). Mirrors cover_arc.gd's
## sync_editor_preview(): reads the previewed weapon off Loadout every frame
## and pushes it through the normal setter when it changes.
func _sync_editor_preview_weapon() -> void:
	var src := get_node_or_null(preview_weapon_from)
	if src == null:
		return
	var weapons = src.get("weapons")
	var new_weapon: WeaponData = weapons[0] if (weapons is Array and weapons.size() > 0) else null
	if new_weapon != weapon:
		weapon = new_weapon

## The swing is centred on the aim: -arc/2 .. +arc/2. There is no separate
## windup angle to keep in sync — one number describes the whole motion.
func _half_arc() -> float:
	return deg_to_rad(weapon.arc_degrees) * 0.5 if weapon else 0.0

var _side := 1.0   ## side chop (SwingMotion.side_only): 1 right, -1 left

func set_aim_angle(angle: float) -> void:
	if dev_hold_still:
		angle = deg_to_rad(dev_still_aim_deg)   # dev only: held at a fixed direction, the mouse is ignored
	var m := weapon.swing_motion if weapon else null
	if m and m.side_only:   # picture AND Hitbox read this node's transform, so snapping here snaps both
		var swinging := _phase == "windup" or _phase == "active" or _phase == "recovery"
		var sa: Array = m.side_aim(angle, _side, swinging)   # the side never flips mid-swing
		_side = sa[1]
		angle = sa[0]
	aim_angle = angle
	rotation = angle
	_apply_hand()   # the body flip was set a line earlier (player.gd): hand and rotation change on the same tick
	# Soul Knight style: aiming left MIRRORS the weapon instead of turning it
	# upside down. Scaling the whole node (not flipping the sprite) mirrors the
	# hitbox with the art, so the two can never disagree (decision 0011).
	if mirror_when_facing_left:
		var facing_left: bool = cos(angle) < 0.0
		scale.y = -1.0 if facing_left else 1.0

## Hold F -> the model snaps into the guard pose; release -> back to rest.
## Driven by Guard's state (parry/block = on), wired by the player — this node
## never reads Guard.
func set_guarding(on: bool) -> void:
	if on == _guarding:
		return
	_guarding = on
	if on and _motion:
		_ease_left = guard_raise_time
		_ease_grip = _art_grip
		_ease_deg = _art_deg
	_t = 0.0
	_phase_start_angle = _blade_angle
	_phase_start_pos = _pivot_pos
	if on:
		_phase = "guard"
		_phase_target_angle = deg_to_rad(weapon.guard_angle_degrees if weapon else -90.0)
		_phase_target_pos = _guard_offset()
	else:
		_phase = "guard_release"
		_phase_target_angle = deg_to_rad(_rest_angle())
		_phase_target_pos = Vector2.ZERO

func on_weapon_state(state: String) -> void:
	# Starting a guard cancels the swing, which reports "idle" — that must not
	# drop the model out of the guard pose it is about to take.
	if _guarding and state == "idle":
		return
	if state == "windup" and _motion:
		_begin_swing_art()
	_phase = state
	_t = 0.0
	_phase_start_angle = _blade_angle
	_phase_start_pos = _pivot_pos
	_phase_target_pos = Vector2.ZERO   # every swing happens from the hand
	match state:
		"windup":
			# Half the arc BEHIND the aim...
			_phase_target_angle = -_half_arc()
		"active":
			# ...then through to half the arc AHEAD of it, so the model points
			# straight at the cursor in the middle of the swing.
			_phase_target_angle = _half_arc()
		_:
			_phase_target_angle = deg_to_rad(_rest_angle())

func _process(delta: float) -> void:
	_apply_hand()   # a moved Hand marker (Remote inspector) follows live; one assignment
	if Engine.is_editor_hint():
		_sync_editor_preview_weapon()
		# Re-apply while previewing, so edits to the weapon's .tres numbers show
		# up immediately (a Resource does not tell this node it changed).
		if preview_guard_pose:
			_apply_all()
		return
	var duration := 0.0
	if weapon != null:
		match _phase:
			"windup": duration = weapon.windup
			"active": duration = weapon.active
			"recovery": duration = weapon.recovery
	match _phase:
		"guard": duration = guard_raise_time
		"guard_release": duration = guard_lower_time
	_t = 1.0 if duration <= 0.0 else minf(1.0, _t + delta / duration)
	var k := _t
	match _phase:
		"windup": k = ease(_t, windup_ease)
		"active": k = 1.0 if snap_time <= 0.0 or duration <= 0.0 else minf(1.0, _t * duration / snap_time)
		"recovery":
			var hold := clampf(follow_through_hold / duration, 0.0, 1.0) if duration > 0.0 else 0.0
			k = ease(0.0 if _t < hold else (_t - hold) / maxf(1.0 - hold, 0.0001), recovery_ease)
			if hold >= 1.0:
				k = 0.0 if _t < 1.0 else 1.0
		"guard", "guard_release": k = ease(_t, guard_ease)
		_: k = ease(_t, 1.0)
	# While F stays held, keep tracking the weapon's guard angle, so the F3
	# slider moves the pose live instead of only on the next press.
	if _phase == "guard" and weapon:
		_phase_target_angle = deg_to_rad(weapon.guard_angle_degrees)
		_phase_target_pos = _guard_offset()
	_blade_angle = lerpf(_phase_start_angle, _phase_target_angle, k)
	_pivot_pos = _phase_start_pos.lerp(_phase_target_pos, k)
	# The model's own rotation only ever corrects for how its picture happens
	# to be drawn (baked into the model scene), and never changes during a swing.
	if _swing_pivot:
		_swing_pivot.rotation = _blade_angle
		_swing_pivot.position = _pivot_pos
	if _motion:
		_update_swing_art(duration, delta)


## The swing side is decided by WeaponHolder (combat owns it, 0050); this node only follows. Called before the "windup" state.
func set_swing_flip(f: float) -> void:
	_flip = f

## A swing starts: remember where the blade is, so the windup starts from there (the side `_flip` was set by the holder).
func _begin_swing_art() -> void:
	_from_grip = Vector2(_art_grip.x, _art_grip.y * _flip) / visual_scale()
	_from_deg = _art_deg * _flip

## The picture's pose from the SwingMotion (swing phases) or the old pivot (guard, idle). Never touches the hitbox.
func _update_swing_art(duration: float, delta: float) -> void:
	var s := visual_scale()
	_rest_w = move_toward(_rest_w, 0.0 if _guarding else 1.0, delta / maxf(guard_raise_time if _guarding else guard_lower_time, 0.001))
	var swinging := (_phase == "windup" or _phase == "active" or _phase == "recovery") and not (_phase == "recovery" and _t >= 1.0)
	_since_swing = 0.0 if swinging else _since_swing + delta
	if swinging:
		_rest_flip = _flip
	elif _since_swing > _motion.alternate_reset_time:
		_rest_flip = move_toward(_rest_flip, 1.0, delta / maxf(_motion.alternate_return_time, 0.001) * 2.0)
	var grip: Vector2
	var deg: float
	if _phase == "windup" or _phase == "active" or _phase == "recovery":
		var half := rad_to_deg(_half_arc())
		var p := _motion.pose(_phase, _t, _t * duration, -half, half, _rest_angle(), _from_grip, _from_deg)
		grip = Vector2(p[0].x, p[0].y * _flip) * s
		deg = p[1] * _flip
	else:
		var pivot_deg := rad_to_deg(_blade_angle)
		grip = _pivot_pos + Vector2(_motion.rest_grip.x, _motion.rest_grip.y * _rest_flip) * s * _rest_w
		deg = lerpf(pivot_deg, pivot_deg * _rest_flip, _rest_w)
		if _ease_left > 0.0:
			_ease_left = maxf(0.0, _ease_left - delta)
			var k := 1.0 - _ease_left / maxf(guard_raise_time, 0.001)
			grip = _ease_grip.lerp(grip, k)
			deg = lerpf(_ease_deg, deg, k)
	_art_grip = grip
	_art_deg = deg
	# aim_bias: turn the whole swing picture back toward its start side so the slash centres on the mouse;
	# full during windup/active, eased in over windup and out over recovery so rest never jumps
	var bw := 0.0
	match _phase:
		"windup": bw = _t
		"active": bw = 1.0
		"recovery": bw = 1.0 - _t
	var bd := _motion.biased(grip, deg, _flip, bw)   # the same function Hitbox sweeps with during active (SwingMotion.swing_path)
	var bias: float = bd[1] - deg
	var drawn: Vector2 = bd[0] + global_transform.affine_inverse().basis_xform(_motion.screen_shift(global_transform, bd[1], bw))   # screen px -> this node's rotated / mirrored frame
	var xf := Transform2D(deg_to_rad(bd[1]), Vector2.ONE * s, 0.0, drawn)
	_swing_art.transform = xf
	ghosts.record(xf, _phase == "active", delta)
	var sweep := (deg - (-rad_to_deg(_half_arc()) - _motion.windup_angle_pad) * _flip) * _flip if _phase == "active" else 0.0   # degrees turned since active began
	var ph: String = _phase if swinging else "idle"
	slash.tick(_motion, ph, sweep, drawn, deg + bias, _flip, s, delta)
	ribbon.tick(_motion, ph, _t, rad_to_deg(_half_arc()), _flip, s, _tip, delta)

## Where the PICTURE is held and where its blade ends, in world px (F1 draws them). The model's origin (0,0) = the grip;
## an optional `Tip` Marker2D in the model scene = the blade end. {} when there is no model.
func picture_grip_tip() -> Dictionary:
	if _model == null:
		return {}
	var xf: Transform2D = _swing_art.global_transform if _motion and _swing_art else _model.global_transform
	var out := {"grip": xf.origin}
	var tip := _model.get_node_or_null("Tip") as Node2D
	if tip:
		out["tip"] = xf * tip.position
	var off_grip := _model.get_node_or_null("OffHandGrip") as Node2D   # where the free hand holds it (0065); none = one-handed
	if off_grip:
		out["off_grip"] = xf * off_grip.position
	return out

func status_text() -> String:
	if _motion == null:
		return "soft: %s  swing: %s  motion: none (old pivot swing)  %s" % ["on" if soft_on() else "off", _phase, _hit_status] + "\n" + _fit_status()
	var side := ("  side: %s tilt %.0f" % ["right" if _side > 0.0 else "left", rad_to_deg(wrapf(aim_angle - (0.0 if _side > 0.0 else PI), -PI, PI))]) if _motion.side_only else ""
	return "soft: %s  swing: %s  dir: %s  hits: %s  grip: (%.0f, %.0f)  ghosts: %d  slash: %s %s" % ["on" if soft_on() else "off", _phase, "first" if _flip > 0.0 else "reversed", "follow blade" if weapon and weapon.hit_follows_blade else "snap", _art_grip.x, _art_grip.y, ghosts.count(), _motion.slash_mode, ribbon.status() if _motion.slash_mode == "ribbon" else slash.status()] + side + "  " + _hit_status + "\n" + _fit_status()
