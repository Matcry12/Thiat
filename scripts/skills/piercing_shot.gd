extends Skill
class_name PiercingShot
## Bow skill: a charge (slow walk, no attacking), then ONE arrow that passes
## through every target it meets, hitting each once. Walls still stop it.

@export var charge_time := 0.5
@export var charge_move_scale := 0.5
@export var damage := 40.0
@export var arrow_speed := 900.0
@export var arrow_range := 700.0
@export var parryable := true
@export var arrow_scene: PackedScene

var _user: Node2D
var _left := 0.0
var _charging := false

func activate(user: Node2D, _aim: Vector2) -> void:
	_user = user
	_left = charge_time
	_charging = true
	state_changed.emit("charge")

func cancel() -> void:
	if _charging:
		_charging = false
		state_changed.emit("idle")

func is_active() -> bool:
	return _charging

func move_scale() -> float:
	return charge_move_scale if _charging else 1.0

func debug_reach(user: Node2D, aim: Vector2) -> PackedVector2Array:
	var muzzle := weapon_holder.get_muzzle() if weapon_holder else null
	var from: Vector2 = weapon_holder.shot_start() if muzzle else user.global_position
	return PackedVector2Array([from, from + aim.normalized() * arrow_range])

func _physics_process(delta: float) -> void:
	if not _charging:
		return
	_left -= delta
	if _left <= 0.0:
		_charging = false
		_fire()
		state_changed.emit("idle")
		finished.emit()

func _fire() -> void:
	var muzzle := weapon_holder.get_muzzle() if weapon_holder else null
	if arrow_scene == null or muzzle == null:
		push_warning("PiercingShot: no arrow scene or no Muzzle on the equipped model — nothing fired.")
		return
	var p: Node2D = arrow_scene.instantiate()
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent.add_child(p)
	p.global_position = weapon_holder.shot_start()
	p.setup(aim_direction, arrow_speed, arrow_range, damage, parryable, _user, true, 1 | 4, null, &"charged_arrow")
