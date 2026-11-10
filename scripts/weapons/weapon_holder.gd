extends Node
class_name WeaponHolder
## windup -> active -> recovery state machine. Manual accumulator (not await),
## so a future dodge can cancel mid-swing. See combat-patterns.md §4.
##
## Since Step 1 the hitbox (melee) / muzzle (ranged) come from the weapon's
## MODEL scene, not a NodePath into this scene — `bind_model()` is called by
## the owner whenever WeaponVisual swaps models (weapon equip or swap).

signal state_changed(state: String)

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

## Loadout is the one owner of "current weapon" — set by player.gd from
## loadout.active_weapon() (in _ready and on swap_finished), never by the
## editor: an @export here could silently disagree with what Loadout says.
var weapon: WeaponData

var hitbox: Hitbox            # null for a weapon with no melee hitbox (e.g. a bow)
## Written by the owner every frame (like Guard.aim_direction) — the holder
## never reads Input itself, that is what makes it reusable.
var aim_direction := Vector2.RIGHT

var phase: Phase = Phase.IDLE
## Side of the current / last swing for a weapon with a SwingMotion (1 first way, -1 reversed, alternate). THE one owner (0050):
## the Hitbox reads it from here, WeaponVisual is told through player.gd (set_swing_flip). Decided at the start of every swing.
var swing_flip := 1.0
var _since_swing := 99.0   ## seconds idle since the last swing ended
var _phase_time := 0.0
var _muzzle: Marker2D
var _tool_hit_done := false
var tool_target: ResourceNode   ## tool swing (WeaponData.tool_target_reach): the node picked at the start of this swing, hit once when active begins; for F3 / F1

## Called whenever the equipped weapon's model changes (WeaponVisual.model_changed).
## Finds the model's optional `Hitbox` / `Muzzle` children — either may be null.
func bind_model(model: Node2D) -> void:
	hitbox = null
	_muzzle = null
	if model == null:
		return
	hitbox = model.get_node_or_null("Hitbox") as Hitbox
	_muzzle = model.get_node_or_null("Muzzle") as Marker2D

## Called by whoever owns this holder (player input, or a boss Brain later).
func try_attack() -> bool:
	if phase != Phase.IDLE or weapon == null:
		return false
	_start_attack()
	return true

## Cancels an in-progress swing (dodge does this): stops the hitbox dealing
## any further damage and returns to idle immediately. No-op if already idle.
func cancel() -> void:
	if phase == Phase.IDLE:
		return
	if hitbox:
		hitbox.end_swing()
	_set_phase(Phase.IDLE)

func _physics_process(delta: float) -> void:
	if phase == Phase.IDLE:
		_since_swing += delta
		return
	_since_swing = 0.0
	_phase_time += delta
	_step(delta)
	match phase:
		Phase.WINDUP:
			if _phase_time >= weapon.windup:
				_set_phase(Phase.ACTIVE)
				_start_active()
		Phase.ACTIVE:
			_tool_target_tick(_phase_time >= weapon.active)
			if hitbox and weapon.hit_follows_blade:
				hitbox.advance_sweep(minf(1.0, _phase_time / maxf(weapon.active, 0.0001)))   # no gaps: every pose between last frame and now
			if _phase_time >= weapon.active:
				_set_phase(Phase.RECOVERY)
				if hitbox:
					hitbox.end_swing()
		Phase.RECOVERY:
			if _phase_time >= weapon.recovery:
				_set_phase(Phase.IDLE)

## Tool target hit (0050 addendum): the unbroken ResourceNode a tool swing aimed at `aim` would hit, or null. Reach is from the user to the node's edge;
## the node must be inside the cone around the REAL aim. A node that likes this tool wins over a closer one that does not, then the nearest.
func find_tool_target() -> ResourceNode:
	var me := get_parent() as Node2D
	if weapon == null or me == null or weapon.tool_target_reach <= 0.0 or weapon.tool_kind == &"":
		return null
	var best: ResourceNode
	var best_key := Vector2(2.0, INF)
	for n: ResourceNode in get_tree().get_nodes_in_group("resource_node"):
		if n.is_broken():
			continue
		var to := n.global_position - me.global_position
		var edge := to.length() - n.data.radius - n.data.hurtbox_pad
		if edge > weapon.tool_target_reach or (to != Vector2.ZERO and absf(aim_direction.angle_to(to)) > deg_to_rad(weapon.tool_target_cone_deg) * 0.5):
			continue
		var key := Vector2(0.0 if n.data.preferred_tool == weapon.tool_kind else 1.0, edge)
		if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
			best = n
			best_key = key
	return best

## Swing step: a melee swing leans forward `step_distance` px over windup + active. move_and_collide, so it
## never pushes the user into a wall or a body. Dodge/guard/skills cancel the swing first, so they never overlap.
func _step(delta: float) -> void:
	if weapon == null or weapon.step_distance <= 0.0 or weapon.behavior != "arc":
		return
	if phase != Phase.WINDUP and phase != Phase.ACTIVE:
		return
	var body := get_parent() as CharacterBody2D
	if body:
		var dir := aim_direction
		if is_instance_valid(tool_target):   # a tool leans toward the node it will hit, not along the (snapped) picture
			dir = (tool_target.global_position - body.global_position).normalized()
		body.move_and_collide(dir * weapon.step_distance * delta / maxf(weapon.windup + weapon.active, 0.001))

## Tool target hit: fires ONCE when the share of active passed reaches WeaponData.tool_target_hit_t (or when active ends, whichever is first), so the number drops when the tool lands, not while it is still raised.
func _tool_target_tick(ending: bool) -> void:
	if _tool_hit_done or hitbox == null:
		return
	if not ending and _phase_time < weapon.active * weapon.tool_target_hit_t:
		return
	_tool_hit_done = true
	if is_instance_valid(tool_target):
		hitbox.hit_gather_target(tool_target)

func _start_attack() -> void:
	_tool_hit_done = false
	var m := weapon.swing_motion
	swing_flip = m.next_flip(swing_flip, _since_swing) if m else 1.0
	if hitbox:
		hitbox.weapon = weapon
		hitbox.swing_flip = swing_flip
	tool_target = find_tool_target() if weapon.behavior == "arc" else null
	_set_phase(Phase.WINDUP)

## behavior == "arc" -> start the melee swing (hitbox turns on for `active`).
## behavior == "projectile" -> fire once, right as ACTIVE begins.
## A small match on two behaviours is fine here.
## ponytail: extract behaviour scripts at the third behaviour.
func _start_active() -> void:
	match weapon.behavior:
		"arc":
			if hitbox:
				hitbox.start_swing()
				_tool_target_tick(false)
				if weapon.swing_motion and weapon.hit_follows_blade:
					hitbox.advance_sweep(0.0)   # progressive (0050): the rest follows each physics frame
				else:
					hitbox.sweep_arc()   # the blade snaps, so it hits the whole arc now (decision 0020)
		"projectile":
			_spawn_projectile()

func _spawn_projectile() -> void:
	if weapon.projectile_scene == null:
		return
	if _muzzle == null:
		push_warning("WeaponHolder: %s has no Muzzle marker in its model — nothing fired." % (weapon.resource_path.get_file() if weapon.resource_path != "" else "(unsaved weapon)"))
		return
	var p: Node2D = weapon.projectile_scene.instantiate()
	# Added to the scene tree, not to us: an arrow must not move with the archer.
	# current_scene is null in a headless test that adds its scene straight
	# under `root` rather than through change_scene_to_*() — fall back to root.
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent.add_child(p)
	p.global_position = shot_start()
	p.setup(aim_direction, weapon.projectile_speed, weapon.projectile_range,
			weapon.damage, weapon.parryable, get_parent())
	p.weapon = weapon

func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	if new_phase == Phase.IDLE:
		tool_target = null
	_phase_time = 0.0
	state_changed.emit(Phase.keys()[phase].to_lower())

## Read-only, for the F1 overlay (draws a ranged weapon's reach from here).
## Where a shot starts: as far out as the muzzle, but on the aim line through the owner, so it flies through the cursor wherever the Hand point sits (0065).
func shot_start() -> Vector2:
	var me := (get_parent() as Node2D).global_position
	return me + aim_direction * (_muzzle.global_position - me).dot(aim_direction)

func get_muzzle() -> Marker2D:
	return _muzzle

func _ready() -> void:
	add_to_group("debug")


# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")
func debug_name() -> String:
	return "Weapon"

func debug_category() -> String:
	return "Combat"

func status_text() -> String:
	var wname := "(none)"
	var dur := 0.0
	if weapon != null:
		wname = weapon.resource_path.get_file().get_basename() if weapon.resource_path != "" else "(unsaved)"
		match phase:
			Phase.WINDUP: dur = weapon.windup
			Phase.ACTIVE: dur = weapon.active
			Phase.RECOVERY: dur = weapon.recovery
	var tgt := ""
	if weapon != null and weapon.tool_target_reach > 0.0:
		var t: ResourceNode = tool_target if phase != Phase.IDLE else find_tool_target()
		tgt = "\ntool target: %s" % ("none" if not is_instance_valid(t) else "%s  %.0f px" % [t.data.display_name, t.global_position.distance_to((get_parent() as Node2D).global_position)])
	return "%s\nphase: %s  left: %.2fs%s" % [wname, Phase.keys()[phase].to_lower(), maxf(0.0, dur - _phase_time), tgt]
