extends BossAttack
class_name SlamAttack
## Ground circle on the spot where the player stood when the slam began.
## Purple (parryable = false): dodge it. The circle is the Hitbox's shape.

@onready var _hitbox: Hitbox = $Hitbox
@onready var _telegraph: Telegraph = $Telegraph

func _ready() -> void:
	super._ready()
	top_level = true   # sits at a world point, does not follow the boss
	_hook(_hitbox)
	_telegraph.set_shape(_shape_of(_hitbox))

func _on_telegraph() -> void:
	global_position = target.global_position
	_telegraph.show_for(telegraph_time, parryable)

func _on_active() -> void:
	_hitbox.start_swing()

func _on_recovery() -> void:
	_hitbox.end_swing()

func _on_cancel() -> void:
	_hitbox.end_swing()
	_telegraph.hide_now()

func debug_areas() -> Array:
	if phase != Phase.TELEGRAPH:
		return []
	return [{"shape": _shape_of(_hitbox), "xform": _hitbox.global_transform, "color": _warn_color()}]
