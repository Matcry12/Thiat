extends Node2D
class_name NodeReactionFx
## Chop and break feedback for gatherable nodes (trees): wood chips + leaves in ONE pooled world-space drawer (like
## HitSparks, so a tree freed mid-effect leaks nothing), and it tells the tree's NodeHitReaction to sway / pop.
## HitFx calls `react()` from a HitFxProfile's `reaction` name ("chop" | "pop"); combat code never calls it (CLAUDE.md §5).
## Hit strength grows as HP falls (B2): sway size, chip + leaf count (and the sound pitch, via HitFxProfile.pitch_gain).

class Bit:
	var is_leaf := false
	var delay := 0.0
	var age := 0.0
	var life := 0.6
	var pos := Vector2.ZERO   ## ground position
	var vel := Vector2.ZERO
	var z := 0.0              ## chips: height above the ground
	var vz := 0.0
	var bounced := false
	var grav := 0.0           ## leaves
	var floor_y := 0.0
	var amp := 0.0
	var freq := 1.0
	var phase := 0.0
	var size := Vector2(4, 4)
	var color := Color.WHITE

@export_group("ChopSway")
## Peak lean of the tree top on the first hit, degrees (foot stays planted). Away from the hitter.
@export_range(0.0, 30.0, 0.1, "or_greater", "or_less") var sway_deg := 6.0
## Last hit before the break leans this many times more.
@export_range(1.0, 5.0, 0.05, "or_greater", "or_less") var sway_max_mult := 2.2
@export_range(0.5, 12.0, 0.1, "or_greater", "or_less") var sway_freq := 4.5
@export_range(0.5, 20.0, 0.1, "or_greater", "or_less") var sway_damping := 5.5
@export_range(0.005, 0.2, 0.005, "or_greater", "or_less") var sway_attack := 0.03
## Sway is cut (and the picture snapped to rest) this long after a hit.
@export_range(0.2, 2.0, 0.05, "or_greater", "or_less") var sway_settle := 0.7
## 1 = counts grow straight with damage taken; above 1 = the big hits come late.
@export_range(0.2, 4.0, 0.05, "or_greater", "or_less") var grow_power := 1.0
@export_group("ChopDebris")
@export_range(0, 30) var chips_min := 4
@export_range(0, 40) var chips_max := 12
@export_range(0, 20) var leaves_min := 2
@export_range(0, 30) var leaves_max := 6
@export var chip_colors := PackedColorArray([Color8(255, 206, 145), Color8(255, 174, 112), Color8(189, 106, 98), Color8(82, 51, 63)])
@export_range(1.0, 12.0, 0.5, "or_greater", "or_less") var chip_size := 4.0
@export_range(1.0, 12.0, 0.5, "or_greater", "or_less") var chip_big_size := 6.0
@export_range(0.0, 1.0, 0.01) var chip_big_chance := 0.35
@export_range(0.0, 300.0, 1.0, "or_greater", "or_less") var chip_speed_min := 32.0
@export_range(0.0, 300.0, 1.0, "or_greater", "or_less") var chip_speed_max := 92.0
## Start height above the ground, px (where on the trunk the hit lands).
@export_range(0.0, 60.0, 0.5, "or_greater", "or_less") var chip_pop_height := 12.0
## Upward speed range, px/s: the pop height of the arc.
@export_range(0.0, 400.0, 1.0, "or_greater", "or_less") var chip_up_min := 96.0
@export_range(0.0, 400.0, 1.0, "or_greater", "or_less") var chip_up_max := 168.0
@export_range(0.0, 2000.0, 10.0, "or_greater", "or_less") var chip_gravity := 600.0
## Share of the fall speed kept at the one bounce.
@export_range(0.0, 1.0, 0.01) var chip_bounce := 0.38
@export_range(0.0, 90.0, 1.0) var chip_spread_deg := 40.0
@export_range(0.1, 3.0, 0.05, "or_greater", "or_less") var chip_life := 0.6
@export_range(0.05, 1.0, 0.01, "or_greater", "or_less") var fade_time := 0.25
@export_range(1.0, 8.0, 0.5, "or_greater", "or_less") var leaf_width := 4.0
@export_range(1.0, 8.0, 0.5, "or_greater", "or_less") var leaf_height := 2.0
## Chop leaves drift down at this speed range, px/s, swaying side to side.
@export_range(0.0, 100.0, 1.0, "or_greater", "or_less") var leaf_fall_min := 22.0
@export_range(0.0, 100.0, 1.0, "or_greater", "or_less") var leaf_fall_max := 34.0
@export_range(0.0, 20.0, 0.5, "or_greater", "or_less") var leaf_sway_px := 8.0
@export_range(0.2, 4.0, 0.05, "or_greater", "or_less") var leaf_sway_freq := 1.5
@export_range(0.1, 4.0, 0.05, "or_greater", "or_less") var leaf_life := 1.2
## Where leaves start in the crown: sideways share of the picture width, and the band of picture height above the foot.
@export_range(0.0, 0.5, 0.01) var crown_width_share := 0.3
## Picture pixels darker than this (brightest channel, 0..1) are the outline and are not used for leaves / stone chips.
@export_range(0.0, 1.0, 0.01) var crown_min_brightness := 0.22
@export_range(0.0, 1.0, 0.01) var chop_crown_lo := 0.45
@export_range(0.0, 1.0, 0.01) var chop_crown_hi := 0.9
## Leaves land this far below the foot (+ up to the jitter), px.
@export_range(0.0, 40.0, 0.5, "or_greater", "or_less") var leaf_floor_below := 10.0
@export_range(0.0, 20.0, 0.5, "or_greater", "or_less") var leaf_floor_jitter := 6.0
## Chop leaves start up to this late after the hit, s (they detach one by one).
@export_range(0.0, 0.5, 0.01, "or_greater", "or_less") var leaf_start_delay_max := 0.12
## Speed kept sideways at the chips' one bounce.
@export_range(0.0, 1.0, 0.01) var chip_bounce_drag := 0.3
@export_group("TreePop")
## The tree grows this much (0.1 = 10%) just before it breaks.
@export_range(0.0, 0.5, 0.01, "or_greater", "or_less") var pop_scale := 0.10
@export_range(0.01, 0.5, 0.01, "or_greater", "or_less") var pop_up_time := 0.1
## After this long the tree is replaced by the stump and the burst starts (~0.3 s feel in total).
@export_range(0.02, 0.6, 0.01, "or_greater", "or_less") var pop_hold := 0.12
@export_range(0.0, 0.8, 0.01) var pop_crown_lo := 0.35
@export_range(0.0, 1.0, 0.01) var pop_crown_hi := 0.8
## Upward kick of the burst leaves, px/s.
@export_range(0.0, 300.0, 1.0, "or_greater", "or_less") var pop_leaf_kick := 50.0
## Burst chips fly at this share of the leaf speed range.
@export_range(0.0, 2.0, 0.01) var pop_chip_speed_lo := 0.5
@export_range(0.0, 2.0, 0.01) var pop_chip_speed_hi := 0.6
@export_range(0, 60) var pop_leaves := 16
@export_range(0, 40) var pop_chips := 10
@export_range(0.0, 400.0, 1.0, "or_greater", "or_less") var pop_speed_min := 60.0
@export_range(0.0, 400.0, 1.0, "or_greater", "or_less") var pop_speed_max := 150.0
@export_range(0.0, 600.0, 5.0, "or_greater", "or_less") var pop_leaf_gravity := 140.0
@export_range(0.0, 600.0, 5.0, "or_greater", "or_less") var pop_chip_up_min := 100.0
@export_range(0.0, 600.0, 5.0, "or_greater", "or_less") var pop_chip_up_max := 200.0
@export_group("")
@export_range(32, 800) var max_bits := 300

var last_text := "-"
var _pool: Array[Bit] = []
var _next := 0
var _test_frac := 1.0

func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = 10
	add_to_group("node_reaction_fx")
	set_process(false)

func live_count() -> int:
	var n := 0
	for b in _pool:
		if b.age < b.life:
			n += 1
	return n

## True = the victim has a NodeHitReaction and it played.
func react(kind: StringName, victim: Node2D, dir: Vector2, hp_fraction: float, prof: HitFxProfile = null) -> bool:
	var r := victim.get_node_or_null("Visual/Reaction") as NodeHitReaction
	if r == null:
		return false
	match kind:
		&"chop":
			_chop(r, victim, dir, hp_fraction, prof)
		&"pop":
			_pop(r, victim, prof)
		_:
			return false
	return true

func _chop(r: NodeHitReaction, victim: Node2D, dir: Vector2, hp_fraction: float, prof: HitFxProfile) -> void:
	if hp_fraction <= 0.0:
		return   # the breaking hit: the pop plays instead of a sway
	var k := pow(clampf(1.0 - hp_fraction, 0.0, 1.0), grow_power)
	var strength := lerpf(1.0, sway_max_mult, k)
	var sgn := 1.0 if dir.x >= 0.0 else -1.0
	r.sway(sgn * sway_deg * strength * (prof.sway_scale if prof else 1.0), sway_freq, sway_damping, sway_attack, sway_settle)
	var foot := _foot(victim)
	var d := dir if dir != Vector2.ZERO else Vector2.RIGHT
	var chips := roundi(lerpf(chips_min, chips_max, k) * (prof.chip_scale if prof else 1.0))
	var leaves := roundi(lerpf(leaves_min, leaves_max, k) * (prof.leaf_scale if prof else 1.0))
	var cols := r.crown_colors(crown_min_brightness)
	var chip_cols := cols if prof and prof.picture_chips else chip_colors
	for i in chips:
		_add_chip(foot + Vector2(0, randf_range(-2, 2)), d.rotated(deg_to_rad(randf_range(-chip_spread_deg, chip_spread_deg))) * randf_range(chip_speed_min, chip_speed_max),
				chip_pop_height + randf_range(0, 3), randf_range(chip_up_min, chip_up_max), 0.0, chip_cols)
	var pic := r.picture_size()
	for i in leaves:
		var b := _slot()
		var crown := foot + Vector2(randf_range(-crown_width_share, crown_width_share) * pic.x, -randf_range(chop_crown_lo, chop_crown_hi) * pic.y)
		_leaf(b, crown, Vector2(0, randf_range(leaf_fall_min, leaf_fall_max)), 0.0, foot.y + leaf_floor_below + randf_range(0, leaf_floor_jitter), cols, randf() * leaf_start_delay_max)
	last_text = "chop  hp %d%%  sway %.1f deg  chips %d  leaves %d" % [roundi(hp_fraction * 100.0), strength * sway_deg, chips, leaves]
	set_process(true)

func _pop(r: NodeHitReaction, victim: Node2D, prof: HitFxProfile) -> void:
	r.pop(pop_scale, pop_up_time, pop_hold)
	var foot := _foot(victim)
	var pic := r.picture_size()
	var cols := r.crown_colors(crown_min_brightness)
	var chip_cols := cols if prof and prof.picture_chips else chip_colors
	var n_leaves := roundi(pop_leaves * (prof.leaf_scale if prof else 1.0))
	for i in n_leaves:
		var b := _slot()
		var crown := foot + Vector2(randf_range(-crown_width_share, crown_width_share) * pic.x, -randf_range(pop_crown_lo, pop_crown_hi) * pic.y)
		_leaf(b, crown, Vector2.from_angle(randf() * TAU) * randf_range(pop_speed_min, pop_speed_max) + Vector2(0, -pop_leaf_kick), pop_leaf_gravity,
				foot.y + leaf_floor_below + randf_range(0, leaf_floor_jitter), cols, pop_hold)
	for i in pop_chips:
		_add_chip(foot + Vector2(randf_range(-3, 3), randf_range(-2, 3)), Vector2.from_angle(randf() * TAU) * randf_range(pop_speed_min * pop_chip_speed_lo, pop_speed_max * pop_chip_speed_hi),
				chip_pop_height + randf_range(0, 6), randf_range(pop_chip_up_min, pop_chip_up_max), pop_hold, chip_cols)
	last_text = "pop  leaves %d  chips %d" % [n_leaves, pop_chips]
	set_process(true)

## Bottom of the trunk (the foot) in world px.
func _foot(victim: Node2D) -> Vector2:
	return victim.global_position + (victim.foot_local() if victim.has_method("foot_local") else Vector2.ZERO)

func _slot() -> Bit:
	if _pool.size() < max_bits:
		var b := Bit.new()
		_pool.append(b)
		return b
	var o := _pool[_next % _pool.size()]
	_next += 1
	return o

func _add_chip(pos: Vector2, vel: Vector2, z: float, vz: float, delay: float, colors: PackedColorArray) -> void:
	var b := _slot()
	b.is_leaf = false
	b.delay = delay
	b.age = 0.0
	b.life = chip_life
	b.pos = pos
	b.vel = vel
	b.z = z
	b.vz = vz
	b.bounced = false
	var s := chip_big_size if randf() < chip_big_chance else chip_size
	b.size = Vector2(s, chip_size)
	b.color = colors[randi() % colors.size()] if not colors.is_empty() else Color(0.7, 0.45, 0.25)

func _leaf(b: Bit, pos: Vector2, vel: Vector2, grav: float, floor_y: float, cols: PackedColorArray, delay: float) -> void:
	b.is_leaf = true
	b.delay = delay
	b.age = 0.0
	b.life = leaf_life
	b.pos = pos
	b.vel = vel
	b.grav = grav
	b.floor_y = floor_y
	b.amp = leaf_sway_px * randf_range(0.6, 1.0)
	b.freq = leaf_sway_freq * randf_range(0.8, 1.2)
	b.phase = randf() * TAU
	b.size = Vector2(leaf_width, leaf_height)
	b.color = cols[randi() % cols.size()]

func _process(delta: float) -> void:
	var any := false
	for b in _pool:
		if b.age >= b.life:
			continue
		any = true
		if b.delay > 0.0:
			b.delay -= delta
			continue
		b.age += delta
		if b.is_leaf:
			b.vel.y += b.grav * delta
			b.pos += b.vel * delta
			b.pos.y = minf(b.pos.y, b.floor_y)
		else:
			b.pos += b.vel * delta
			b.z += b.vz * delta
			b.vz -= chip_gravity * delta
			if b.z <= 0.0:
				b.z = 0.0
				if not b.bounced:
					b.bounced = true
					b.vz = -b.vz * chip_bounce
					b.vel *= chip_bounce_drag
				else:
					b.vz = 0.0
					b.vel = Vector2.ZERO
	queue_redraw()
	if not any:
		set_process(false)

func _draw() -> void:
	for b in _pool:
		if b.age >= b.life or b.delay > 0.0:
			continue
		var c := b.color
		c.a *= clampf((b.life - b.age) / fade_time, 0.0, 1.0)
		var p := b.pos
		if b.is_leaf:
			p.x += b.amp * sin(TAU * b.freq * b.age + b.phase)
		else:
			p.y -= b.z
		draw_rect(Rect2((p - b.size * 0.5).round(), b.size), c)

## F3 buttons: effects only on the nearest unbroken tree / rock / copper / station, no HP change. `Test node hit` steps the hp
## fraction down on each press. `profiles` = HitFx's profiles by hit_type (a node uses its own numbers).
func test(kind: StringName, from: Vector2, profiles: Dictionary = {}) -> void:
	var best: Node2D
	for g in [&"resource_node", &"station"]:
		for n: Node2D in get_tree().get_nodes_in_group(g):
			if (n.has_method("is_broken") and n.is_broken()) or n.get_node_or_null("Visual/Reaction") == null:
				continue
			if best == null or n.global_position.distance_to(from) < best.global_position.distance_to(from):
				best = n
	if best == null:
		last_text = "test: no node around"
		return
	var dir := (best.global_position - from).normalized()
	var hit_t: StringName = best.data.hit_type if best is ResourceNode else best.knock_type
	var break_t: StringName = best.data.break_type if best is ResourceNode else best.pickup_type
	if kind == &"pop":
		react(&"pop", best, dir, 0.0, profiles.get(break_t))
	else:
		_test_frac = 1.0 if _test_frac <= 0.25 else _test_frac - 0.25
		react(&"chop", best, dir, _test_frac, profiles.get(hit_t))
