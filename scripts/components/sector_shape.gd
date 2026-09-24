@tool
extends CollisionPolygon2D
class_name SectorShape
## Generates a pie-slice (sector) polygon from an arc angle + a radius,
## instead of a hand-dragged rectangle (decision 0011 amendment). The sector
## is centred on local +X — the direction its parent points — and spans
## `-arc_degrees/2 .. +arc_degrees/2`. Flat 2D, no perspective squashing
## (.claude/memory/mistakes.md).
##
## ONE OWNER (.claude/memory/mistakes.md): if `weapon` is set, `arc_degrees`
## and `radius` are OVERWRITTEN from it on every rebuild — WeaponData is the
## source of truth and these two exports become read-only mirrors, kept
## exported only so a) they show the current value in the inspector and
## b) the shape still works standalone (no weapon) for a one-off sector.
## Never hand-edit them on a weapon-driven sector; edit the .tres instead.

@export var weapon: WeaponData: set = _set_weapon
@export var arc_degrees := 90.0: set = _set_arc_degrees
@export var radius := 50.0: set = _set_radius
@export var inner_radius := 0.0: set = _set_inner_radius  ## hole near the hand, for polearms that don't hit at the grip
@export var segments := 16: set = _set_segments           ## polygon smoothness

var _last_weapon_arc := 0.0
var _last_weapon_radius := 0.0
## Guards against infinite recursion: _rebuild() mirrors weapon values back
## into arc_degrees/radius, and those setters call _rebuild() too — without
## this flag that write-back would re-trigger itself forever.
var _syncing := false

func _ready() -> void:
	_rebuild()

func _set_weapon(v: WeaponData) -> void:
	weapon = v
	_rebuild()

func _set_arc_degrees(v: float) -> void:
	arc_degrees = v
	if not _syncing:
		_rebuild()

func _set_radius(v: float) -> void:
	radius = v
	if not _syncing:
		_rebuild()

func _set_inner_radius(v: float) -> void:
	inner_radius = maxf(v, 0.0)
	_rebuild()

func _set_segments(v: int) -> void:
	segments = maxi(v, 3)
	_rebuild()

## F3 writes straight to the WeaponData resource (it's a registered tuning
## target), not to this node, so there is no setter/signal to hook. Polling
## two floats per physics frame is cheap; rebuild only when they actually
## changed since last frame.
func _physics_process(_delta: float) -> void:
	if weapon != null and weapon.arc_degrees != _last_weapon_arc:
		_rebuild()

func _rebuild() -> void:
	var arc := arc_degrees
	var r := radius
	if weapon != null:
		arc = weapon.arc_degrees
		r = radius
		_syncing = true
		arc_degrees = arc
		radius = r
		_syncing = false
	_last_weapon_arc = arc
	_last_weapon_radius = r
	polygon = build_sector_polygon(arc, r, inner_radius, segments)

## Static so tests can build a polygon without a live node in the tree.
static func build_sector_polygon(arc_deg: float, r: float, inner_r: float, segs: int) -> PackedVector2Array:
	var half := deg_to_rad(maxf(arc_deg, 0.001)) / 2.0
	var points := PackedVector2Array()
	if inner_r <= 0.0:
		points.append(Vector2.ZERO)
	else:
		for i in segs + 1:
			var t: float = lerpf(-half, half, float(i) / segs)
			points.append(Vector2.RIGHT.rotated(t) * inner_r)
	for i in segs + 1:
		var t: float = lerpf(half, -half, float(i) / segs)
		points.append(Vector2.RIGHT.rotated(t) * r)
	return points
