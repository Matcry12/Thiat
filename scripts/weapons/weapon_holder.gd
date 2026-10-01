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
var _phase_time := 0.0
var _muzzle: Marker2D

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
		return
	_phase_time += delta
	match phase:
		Phase.WINDUP:
			if _phase_time >= weapon.windup:
				_set_phase(Phase.ACTIVE)
				_start_active()
		Phase.ACTIVE:
			if _phase_time >= weapon.active:
				_set_phase(Phase.RECOVERY)
				if hitbox:
					hitbox.end_swing()
		Phase.RECOVERY:
			if _phase_time >= weapon.recovery:
				_set_phase(Phase.IDLE)

func _start_attack() -> void:
	if hitbox:
		hitbox.weapon = weapon
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
	p.global_position = _muzzle.global_position
	p.setup(aim_direction, weapon.projectile_speed, weapon.projectile_range,
			weapon.damage, weapon.parryable, get_parent())

func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	_phase_time = 0.0
	state_changed.emit(Phase.keys()[phase].to_lower())

## Read-only, for the F1 overlay (draws a ranged weapon's reach from here).
func get_muzzle() -> Marker2D:
	return _muzzle
