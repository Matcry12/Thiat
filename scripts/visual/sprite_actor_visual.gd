extends ActorVisual
class_name SpriteActorVisual
## Placeholder sprite implementation of ActorVisual (decision 0010).
##
## Structure: a `Body` Sprite2D (the upright character) + a separate `Shadow`
## Sprite2D. The shadow is its own node so replacing the body texture never
## loses the shadow.
##
## To swap in a real asset: set `body_texture` / `shadow_texture` to the new
## PNGs and nudge `body_offset` / `shadow_offset` in the inspector. No script
## change needed.

@export var body_texture: Texture2D
@export var shadow_texture: Texture2D
@export var body_offset := Vector2.ZERO   ## nudge so the sprite's feet sit at this node's origin
@export var shadow_offset := Vector2.ZERO
@export var flip_when_facing_left := true
@export var run_bob := 2.0                ## pixels of vertical bob while running (never rotate, decision 0009)
@export var bob_speed := 10.0             ## bob cycles per second-ish (radians/sec fed to sin())

@onready var body: Sprite2D = $Body
@onready var shadow: Sprite2D = $Shadow

var _facing_left := false
var _running := false
var _bob_t := 0.0

func _ready() -> void:
	body.texture = body_texture
	shadow.texture = shadow_texture
	body.position = body_offset
	shadow.position = shadow_offset

func _process(delta: float) -> void:
	if not _running:
		return
	_bob_t += delta * bob_speed
	body.position = body_offset + Vector2(0, sin(_bob_t) * run_bob)

func set_move_state(state: String) -> void:
	_running = state == "run"
	if not _running:
		body.position = body_offset

func set_facing(dir: Vector2) -> void:
	if not flip_when_facing_left or absf(dir.x) < 0.001:
		return
	# TODO: an 8-direction sprite set would pick an animation/frame name here
	# instead of a left/right flip.
	_facing_left = dir.x < 0.0
	body.flip_h = _facing_left

func set_weapon_state(state: String) -> void:
	match state:
		"windup": body.modulate = Color.YELLOW
		"active": body.modulate = Color.RED
		"recovery": body.modulate = Color.GRAY
		_: body.modulate = Color.WHITE

func set_aim_angle(_angle: float) -> void:
	pass  # body never rotates with aim (2.5D, decision 0009); WeaponVisual handles aim.
