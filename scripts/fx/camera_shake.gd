extends Node
class_name CameraShake
## Trauma shake (Squirrel Eiserloh's GDC talk): hits add trauma (0..1), trauma drains linearly, and the
## shake size is trauma SQUARED, so small hits whisper and big hits roar. Smooth noise, not random jitter.
## Writes ONLY Camera2D.offset (never position, so the follow camera and its map limits are untouched).
## Runs on unscaled time: the shake keeps moving through a hit-stop.

## Multiplies the shake. 0 = off (the accessibility switch).
@export_range(0.0, 2.0, 0.01, "or_greater", "or_less") var shake_strength := 1.0
## Trauma lost per second.
@export_range(0.0, 5.0, 0.02, "or_greater", "or_less") var decay := 1.6
## Pixels of offset at full trauma and strength 1.
@export_range(0.0, 30.0, 0.1, "or_greater", "or_less") var max_offset := 8.0
## How fast the noise moves (cycles per second).
@export_range(1.0, 80.0, 0.5, "or_greater", "or_less") var noise_speed := 30.0
## Camera2D limits are applied BEFORE offset, so at the map edge a shake would show the empty area outside
## the map. On = the offset is squeezed so the view never leaves the limits (the shake just goes quiet there).
@export var keep_inside_limits := true

var trauma := 0.0
var offset := Vector2.ZERO   ## what is applied now
var _t := 0.0
var _noise := FastNoiseLite.new()

func _ready() -> void:
	# The player's setting is the starting value; after that THIS node is the one live owner (F3 edits it too).
	GameSettings.ensure_loaded()
	shake_strength = GameSettings.shake_strength

func _exit_tree() -> void:
	GameSettings.shake_strength = shake_strength   # carries an F3 tune over a restart / quit to title

func _init() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

## Moves the clock `dt` seconds and returns the offset for now. Pure maths, so tests can call it directly.
func advance(dt: float) -> Vector2:
	_t += dt
	trauma = maxf(0.0, trauma - decay * dt)
	var s := trauma * trauma * shake_strength
	var raw := Vector2(_noise.get_noise_2d(_t * noise_speed, 0.0), _noise.get_noise_2d(_t * noise_speed, 100.0))
	offset = raw.limit_length(1.0) * max_offset * s
	return offset

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if trauma <= 0.0 and offset == Vector2.ZERO:
		return
	advance(delta / maxf(Engine.time_scale, 0.0001))
	cam.offset = _inside_limits(cam, offset) if keep_inside_limits else offset

func _inside_limits(cam: Camera2D, want: Vector2) -> Vector2:
	var half := get_viewport().get_visible_rect().size / cam.zoom * 0.5
	var centre := cam.get_screen_center_position() - cam.offset   # where the camera sits without our offset
	var lo := Vector2(cam.limit_left, cam.limit_top) + half - centre
	var hi := Vector2(cam.limit_right, cam.limit_bottom) - half - centre
	return Vector2(clampf(want.x, minf(lo.x, 0.0), maxf(hi.x, 0.0)), clampf(want.y, minf(lo.y, 0.0), maxf(hi.y, 0.0)))
