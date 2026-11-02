extends SceneTree
# Tool target hit (0050 addendum): a tool swing hits the gather node inside its reach + cone around the REAL aim, once, even when the (side-snapped) picture lands elsewhere.
const ClassicArena = preload("res://tests/support/classic_arena.gd")
var _fail := 0

func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fail += 1

func _node(arena: Node, at: Vector2) -> ResourceNode:
	var n: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	n.setup(load("res://data/resource_nodes/tree.tres"), 0)
	n.position = at
	arena.add_child(n)
	return n

func _swing(wh: WeaponHolder, wv: WeaponVisual, aim: Vector2) -> void:
	wh.aim_direction = aim
	wv.set_aim_angle(aim.angle())
	wh.try_attack()
	for i in 60:
		await physics_frame

func _init() -> void:
	var arena = ClassicArena.make()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	var lo: Loadout = player.get_node("Loadout")
	var wh: WeaponHolder = player.get_node("WeaponHolder")
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	player.set_physics_process(false)
	var spot: Vector2 = player.global_position + Vector2(0, 160)
	player.global_position = spot
	await physics_frame

	# Sword: no tool target, a tree straight above is not touched.
	var up := _node(arena, spot + Vector2(0, -50))
	await physics_frame
	_check(wh.find_tool_target() == null, "sword: no tool target")
	await _swing(wh, wv, Vector2.UP)
	_check(up.hp == up.data.max_hp, "sword: tree above untouched (hp %.0f)" % up.hp)

	# Axe, aim up: the picture is snapped to a side, the tree above still gets exactly one hit.
	lo.select(1)
	await physics_frame
	var axe: WeaponData = lo.active_weapon()
	var hit: float = axe.gather_damage * up.data.tool_bonus
	wh.aim_direction = Vector2.UP
	_check(wh.find_tool_target() == up, "axe: tree above is the tool target")
	_check(wh.status_text().contains("tool target: Tree"), "F3 status names the target (%s)" % wh.status_text().replace("\n", " | "))
	await _swing(wh, wv, Vector2.UP)
	_check(is_equal_approx(up.hp, up.data.max_hp - hit), "axe aim up: tree above hit exactly once (hp %.1f)" % up.hp)

	# Tree on the blade's own path too (aim right): still one hit, not blade + target.
	var right := _node(arena, spot + Vector2(40, 0))
	await physics_frame
	await _swing(wh, wv, Vector2.RIGHT)
	_check(is_equal_approx(right.hp, right.data.max_hp - hit), "axe aim right: one hit, no blade + target double (hp %.1f)" % right.hp)

	# Timing: the hit lands at tool_target_hit_t of active, not on its first frame; never later than the end of active.
	var late := _node(arena, spot + Vector2(0, 50))
	await physics_frame
	wh.aim_direction = Vector2.DOWN
	wv.set_aim_angle(PI / 2)
	wh.try_attack()
	var first_active := -1
	var hit_frame := -1
	for i in 60:
		await physics_frame
		if first_active < 0 and wh.phase == WeaponHolder.Phase.ACTIVE:
			first_active = i
			_check(late.hp == late.data.max_hp, "timing: no hit on the first active frame")
		if hit_frame < 0 and late.hp < late.data.max_hp:
			hit_frame = i
	var want := int(ceil(axe.active * axe.tool_target_hit_t * 60.0))
	_check(first_active >= 0 and hit_frame - first_active >= 2 and hit_frame - first_active <= want + 1, "timing: hit %d frames after active began (hit_t %.2f)" % [hit_frame - first_active, axe.tool_target_hit_t])
	_check(is_equal_approx(late.hp, late.data.max_hp - hit), "timing: still exactly one hit (hp %.1f)" % late.hp)

	# Outside the cone (aim left, trees up / right) and outside the reach: nothing.
	var far := _node(arena, spot + Vector2(-300, 0))
	await physics_frame
	wh.aim_direction = Vector2.LEFT
	_check(wh.find_tool_target() == null, "axe aim left: nothing in reach / cone")
	await _swing(wh, wv, Vector2.LEFT)
	_check(far.hp == far.data.max_hp, "axe aim left: the far tree is not hit")
	print("tool target: %d failures" % _fail)
	quit(1 if _fail > 0 else 0)
