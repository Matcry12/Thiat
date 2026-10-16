extends BossAttack
class_name RingAttack
## Phase-2 move. A slam at the player's spot, then a bigger second blast on the
## same spot after a short warning. Dodging the first is not enough: you must
## also leave the centre. Both are purple (dodge). Radii = the two Hitbox shapes.

## Gap between the first blast and the second warning finishing.
@export var second_telegraph_time := 0.8
@export var faint_alpha := 0.35

@onready var _hitbox1: Hitbox = $Hitbox1
@onready var _hitbox2: Hitbox = $Hitbox2
@onready var _telegraph1: Telegraph = $Telegraph1
@onready var _telegraph2: Telegraph = $Telegraph2

var _stage := 0

func _ready() -> void:
	super._ready()
	top_level = true
	for pair in [[_hitbox1, _telegraph1], [_hitbox2, _telegraph2]]:
		_hook(pair[0])
		pair[1].set_shape(_shape_of(pair[0]))

func _on_telegraph() -> void:
	global_position = target.global_position
	_telegraph1.show_for(telegraph_time, parryable)
	# The bigger second blast is shown (faint) from the start, so the escape
	# can be planned. It fills until the moment it lands.
	_telegraph2.modulate.a = faint_alpha
	_telegraph2.show_for(telegraph_time + active_time + second_telegraph_time, parryable)

func _on_active() -> void:
	_stage = 0
	_hitbox1.start_swing()

func _active_tick(_delta: float) -> bool:
	match _stage:
		0:
			if _t >= active_time:
				_hitbox1.end_swing()
				_telegraph2.modulate.a = 1.0   # the second warning is now live
				_stage = 1
				_t = 0.0
				phase_changed.emit(get_action_name(), int(Phase.TELEGRAPH), second_telegraph_time)   # the body winds up again
		1:
			if _t >= second_telegraph_time:
				_hitbox2.start_swing()
				_stage = 2
				_t = 0.0
				phase_changed.emit(get_action_name(), int(Phase.ACTIVE), active_time)   # ... and strikes again
		2:
			if _t >= active_time:
				_hitbox2.end_swing()
				return true
	return false

func _on_cancel() -> void:
	_hitbox1.end_swing()
	_hitbox2.end_swing()
	_telegraph1.hide_now()
	_telegraph2.hide_now()

func debug_areas() -> Array:
	var out: Array = []
	if phase == Phase.TELEGRAPH:
		out.append({"shape": _shape_of(_hitbox1), "xform": _hitbox1.global_transform, "color": _warn_color()})
		out.append({"shape": _shape_of(_hitbox2), "xform": _hitbox2.global_transform, "color": _warn_color().darkened(0.3)})
	if phase == Phase.ACTIVE and _stage == 1:
		out.append({"shape": _shape_of(_hitbox2), "xform": _hitbox2.global_transform, "color": _warn_color()})
	return out
