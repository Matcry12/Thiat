class_name SwingMotion
extends Resource
## How a melee swing LOOKS and where it HITS (decisions 0049 + 0050). Timing stays in WeaponData.
## Since 0050 the active part of this path (`swing_path`) is also what the Hitbox sweeps, so grip points, aim_bias_deg and
## screen_offset move the hit area too (the picture and the hit area read the same function).
## The grip (hand) travels on curves and the blade's angle lags it (wrist), then settles with a wobble.
## Points are in the AIM frame, game px: x toward the aim, y toward the side the swing ends on (mirrors itself when aiming left).
## Angles are degrees relative to the aim. The arc itself (start / end) still comes from WeaponData.arc_degrees.
## Swap note: a real sprite animation replaces WeaponVisual's use of pose(); these numbers then stretch it to the tuned timing.

@export_group("Grip path")
@export var rest_grip := Vector2(4, -6)
@export var back_grip := Vector2(-8, -18)          ## end of the windup
@export var windup_ctrl := Vector2(-4, -14)        ## curve control rest -> back
@export var front_grip := Vector2(22, 0)           ## curve control back -> end: the arm reaches forward mid-swing
@export var end_grip := Vector2(6, 16)             ## end of the active part
@export var recovery_ctrl := Vector2(10, 8)        ## curve control end -> rest
@export var aim_bias_deg := 0.0                    ## turns the whole swing picture back toward its START side, so the slash centres on the mouse (the hand ends to the side)
@export var screen_offset := Vector2.ZERO          ## SCREEN px (y+ = lower), not aim frame: shifts the whole sword picture, any aim
@export var top_lift_px := 0.0                     ## SCREEN px: grip rises by this * (how far the blade points up on screen, 0..1), any aim. Picture + slash + hit path (one shared function)
@export_group("Blade angle")
@export var windup_angle_pad := 10.0               ## blade goes this far BEHIND the start of the arc
@export var end_angle_pad := 12.0                  ## ...and this far PAST the end of the arc
@export_range(1.0, 4.0, 0.05) var wrist_lag_power := 1.6   ## above 1 = blade trails the arm, then whips through
@export var overshoot_deg := 14.0                  ## wobble after the swing
@export var overshoot_decay := 14.0
@export var overshoot_freq := 38.0
@export_group("Alternate")
@export var alternate := true                      ## every other swing goes the other way (mirrored across the aim line)
@export var alternate_reset_time := 0.8            ## seconds without swinging before the next swing goes the first way again
@export var alternate_return_time := 0.25          ## seconds the resting blade takes to swing back to the first side after that
@export_group("Afterimages")
@export var ghost_count := 8
@export var ghost_alpha_min := 0.15                ## oldest copy
@export var ghost_alpha_max := 0.47                ## newest copy
@export var ghost_interval := 0.016                ## seconds between copies
@export var ghost_copies_on := false              ## the faded sword copies (off: the pixel smear alone)
@export var ghost_color := Color.WHITE             ## the copies are painted this colour...
@export_range(0.0, 1.0, 0.01) var ghost_white := 0.85   ## ...this much (0 = the sword's own colours, 1 = flat silhouette)
@export var smear_on := false                      ## a filled band swept by the blade between the copies
@export var smear_color := Color(0.96, 0.99, 1.0, 0.95)   ## head: the newest part, right behind the blade
@export var smear_tail_color := Color(0.55, 0.82, 0.95, 0.85)   ## the older part
@export var smear_edge_color := Color(0.33, 0.66, 0.88, 0.9)    ## outer rim + falling pixels
@export_range(0.0, 0.5, 0.01) var smear_edge := 0.12   ## rim thickness, share of the blade length
@export var smear_pixel := 3.0                     ## screen-px size of one smear pixel (match the art's pixel size)
@export_range(0.0, 1.0, 0.01) var smear_dissolve_start := 0.45   ## older than this (0 new .. 1 oldest) starts breaking up
@export var smear_drip_px := 14.0                  ## how far pixels may hang below the old end
@export_range(0.0, 0.95, 0.01) var smear_inner := 0.3  ## band starts this far along the blade (0 = from the hand)
@export_group("Slash art")
@export_enum("ribbon", "sprite") var slash_mode := "ribbon"   ## ribbon = a band built from the real blade path each frame (always on the blade); sprite = the fixed crescent picture
@export var ribbon_textures: Array[Texture2D] = [preload("res://assets/fx/slash/ribbon_f1.png"), preload("res://assets/fx/slash/ribbon_f2.png"), preload("res://assets/fx/slash/ribbon_f3.png"), preload("res://assets/fx/slash/ribbon_f4.png")]   ## unwrapped crescents: x = along the arc (newest end at x=0), y = inner -> outer
@export_range(10.0, 360.0, 1.0) var ribbon_tail_deg := 110.0   ## the band covers at most this many degrees behind the blade, never before active start
@export_range(0.0, 1.0, 0.01) var ribbon_f2_at := 0.2      ## share of active after which the big frame (f2) replaces the thin one (f1)
@export_range(0.1, 3.0, 0.05) var ribbon_taper_power := 0.4   ## crescent shape: higher = thinner tail, point at the tail
@export_range(0.0, 120.0, 1.0) var ribbon_tail_taper_deg := 40.0   ## the tail narrows to a needle point over at least this many degrees of arc (from the tail end), even on a short band; 0 = off
@export_range(0.3, 4.0, 0.05) var ribbon_tail_power := 1.25   ## shape of that narrowing: 1 = straight needle, >1 = thinner, longer point, <1 = rounder
@export_range(0.2, 1.5, 0.05) var ribbon_taper_skew := 0.75   ## <1 moves the widest part toward the blade (peak near u 0.3)
@export_range(0.0, 1.0, 0.05) var ribbon_pivot_lock := 0.0   ## 1 = every band sample uses the hand as it is now (a clean C around the hand); 0 = the hand as it slid
@export_range(0.0, 1.0, 0.05) var ribbon_pivot_anchor := 1.0   ## where the lock pulls the band to: 0 = the hand at the active start (the band stays put), 1 = the hand as it is now (band follows the sword); in between = a mix
@export_range(0.0, 1.0, 0.05) var ribbon_head_fill := 1.0   ## how full the blade end of the band is while swinging: 1 = full width right up to the blade (a broad edge), 0 = tapers to a point at the blade
@export_range(0.0, 1.0, 0.01) var ribbon_head_fill_release := 1.0   ## share of active at which the head eases from full to pointed (finished by the end of active); 1 = stays full all active, pointed only in the fade frames
@export var ribbon_px_per_deg := 0.5                       ## strip pixels per degree (tools/art_tests/slash_smear/unwrap_ribbon.py PPD)
@export_range(4, 64, 1) var ribbon_steps := 32            ## samples along the band (more = smoother)
@export_range(0.0, 0.95, 0.01) var ribbon_inner := 0.5   ## band starts this far along the blade (share of the Tip length; 0 = from the hand)
@export var slash_on := true                       ## the drawn slash (assets/fx/slash): on the live grip during active, frozen after
@export var slash_textures: Array[Texture2D] = [preload("res://assets/fx/slash/slash_f1.png"), preload("res://assets/fx/slash/slash_f2.png"), preload("res://assets/fx/slash/slash_f3.png"), preload("res://assets/fx/slash/slash_f4.png")]
@export var slash_scale := 2.2                     ## art px -> blade px (times the rig scale): the art's outer edge reaches the blade tip
@export var slash_inner_cut := 12.2                ## art px: everything closer to the hand than this is cut away
@export var slash_head_f1_deg := -23.2             ## per frame: art angle (0 = right, clockwise) of the NEWEST end; it is put on the blade
@export var slash_head_f2_deg := 60.3
@export var slash_head_f3_deg := 60.3
@export var slash_head_f4_deg := 70.3
@export var slash_show_f1_deg := 66.8              ## f1 shows once the blade has turned this far since active began (= f1's arc span)
@export var slash_show_f2_deg := 150.3             ## same for f2
@export var slash_fade_time := 0.08                ## after active: f3 for half, then f4 fading out for the other half
@export var slash_freeze_after_active := true      ## after active the slash stays where the swing ended (off: follows the blade back)
@export_group("Old crescent")
@export var crescent_on := false                   ## the old SwingFx crescent slash

func head_deg(frame: int) -> float:
	return [slash_head_f1_deg, slash_head_f2_deg, slash_head_f3_deg, slash_head_f4_deg][frame]

static func _eo(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

static func _eio(x: float) -> float:
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0

static func _bez(p0: Vector2, p1: Vector2, p2: Vector2, k: float) -> Vector2:
	return p0.lerp(p1, k).lerp(p1.lerp(p2, k), k)

## `from_*` = where the windup starts if not at rest (the blade stays where the last swing left it).
## [grip Vector2 (aim frame, unscaled), blade angle deg]. `t` = 0..1 through the phase, `secs` = seconds into it.
func pose(phase: String, t: float, secs: float, start_deg: float, end_deg: float, rest_deg: float, from_grip := Vector2.INF, from_deg := INF) -> Array:
	var g0 := rest_grip if from_grip == Vector2.INF else from_grip
	var a0 := rest_deg if is_inf(from_deg) else from_deg
	match phase:
		"windup":
			var k := _eo(t)
			return [_bez(g0, windup_ctrl, back_grip, k), lerpf(a0, start_deg - windup_angle_pad, k)]
		"active":
			var kw := _eio(minf(1.0, pow(t, wrist_lag_power)))
			return [_bez(back_grip, front_grip, end_grip, _eio(t)), lerpf(start_deg - windup_angle_pad, end_deg + end_angle_pad, kw)]
		"recovery":
			var a := lerpf(end_deg + end_angle_pad, rest_deg, _eo(t)) + overshoot_deg * exp(-secs * overshoot_decay) * sin(secs * overshoot_freq)
			return [_bez(end_grip, recovery_ctrl, rest_grip, _eo(t)), a]
	return [rest_grip, rest_deg]

## Turns the whole swing picture back toward its start side (aim_bias_deg). `bw` 0..1: 0 at rest, ramps in over windup,
## 1 through active, ramps out over recovery. `grip` / `deg` are already flipped. Returns [grip, blade angle deg].
func biased(grip: Vector2, deg: float, flip: float, bw: float) -> Array:
	var bias := -aim_bias_deg * flip * bw
	return [grip.rotated(deg_to_rad(bias)), deg + bias]

## THE shared swing path (0050): the ACTIVE part at t 0..1, for a swing that goes `-half_deg .. +half_deg` (WeaponData.arc_degrees / 2),
## on side `flip` (1 first way, -1 reversed). [grip in the AIM frame (game px, unscaled, aim_bias included), blade angle deg incl. aim_bias].
## screen_offset is NOT included (screen px): callers convert it into their own frame. WeaponVisual draws with this, Hitbox sweeps with this.
func swing_path(t: float, half_deg: float, flip: float) -> Array:
	var p := pose("active", t, 0.0, -half_deg, half_deg, 0.0)
	return biased(Vector2(p[0].x, p[0].y * flip), p[1] * flip, flip, 1.0)

## Total SCREEN-px shift of the grip: screen_offset + the top lift (hand rises only while the blade points up on screen).
## `aim_xf` = the aim node's global transform (aim rotation + mirror), `blade_deg` = blade angle in that frame. Used by picture, slash and hit path.
## `lift_w` 0..1: the lift is a SWING thing (1 during active); at rest it is 0 so the resting sword does not slide with the aim.
func screen_shift(aim_xf: Transform2D, blade_deg: float, lift_w := 1.0) -> Vector2:
	if top_lift_px == 0.0 or lift_w <= 0.0:
		return screen_offset
	var d := aim_xf.basis_xform(Vector2.from_angle(deg_to_rad(blade_deg))).normalized()
	return screen_offset + Vector2(0.0, -top_lift_px * lift_w * maxf(0.0, -d.y))

## Which side the NEXT swing goes (alternate). `since` = seconds since the last swing ended. Owned by WeaponHolder (combat), followed by the picture.
func next_flip(prev: float, since: float) -> float:
	return -prev if alternate and since < alternate_reset_time else 1.0

func debug_name() -> String:
	return "Swing Motion" if resource_path == "" else "Swing " + resource_path.get_file().get_basename().capitalize()
