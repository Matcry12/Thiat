extends SceneTree
# Aggro + leash (decision 0022): the boss waits idle at its spawn until the player enters the zone;
# it fights while they are in; when they leave for more than leash_delay it drops the attack, heals,
# resets to phase 1 and walks home without taking damage. Coming back inside the delay changes nothing.
const StubBrain = preload("res://tests/support/stub_brain.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()   # the real big-map layout
	root.add_child(arena)
	var boss: Boss = arena.get_node("Boss")
	await process_frame
	var stub = StubBrain.new()
	boss.set_brain(stub)
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	player.get_node("Health").immortal = true
	var zone: Area2D = arena.get_node("FightZone")
	var inside: Vector2 = zone.global_position
	var outside: Vector2 = Vector2(300, 640)
	var home: Vector2 = boss.home
	var started: Array = []
	boss.action_started.connect(func(a: String): started.append(a))
	boss.leash_delay = 0.5

	# --- idle while the player is outside ---
	stub.answer = "slam"
	player.global_position = outside
	await _frames(90)
	_check(boss.aggro == Boss.Aggro.IDLE and started.is_empty() and boss.global_position == home, "idle at its spawn, no attacks, player outside (started %s)" % [started])
	_check(stub.calls == 0, "idle boss does not even ask its brain")

	# --- a forced attack while idle runs once and does not engage ---
	boss.force_next("spread")
	await _until(func(): return not started.is_empty(), 1.0)
	_check(started == ["spread"] and boss.aggro == Boss.Aggro.IDLE, "force_next while idle runs the attack, boss stays idle")
	await _until(func(): return boss.mode == Boss.Mode.IDLE, 4.0)
	await _until(func(): return get_nodes_in_group("projectile").is_empty(), 4.0)
	started.clear()

	# --- engages on entry ---
	player.global_position = inside
	await _until(func(): return boss.aggro == Boss.Aggro.ENGAGED, 1.0)
	_check(boss.aggro == Boss.Aggro.ENGAGED, "engages when the player enters the zone")
	await _until(func(): return not started.is_empty(), 2.0)
	_check(started.size() > 0 and started[0] == "slam", "fights once engaged (started %s)" % [started])

	# --- leave and come back INSIDE the delay: nothing changes ---
	boss.health.hp = boss.health.max_hp * 0.5
	boss.force_phase_2()
	await _frames(2)
	var hp_before := boss.health.hp
	player.global_position = outside
	await _frames(15)   # 0.25 s < 0.5 s
	player.global_position = inside
	await _frames(60)
	_check(boss.aggro == Boss.Aggro.ENGAGED and boss.health.hp == hp_before and boss.phase == 2, "re-entering inside the delay keeps it engaged (hp %.0f phase %d)" % [boss.health.hp, boss.phase])

	# --- leave for good: drops a half-built attack, bolts keep flying ---
	boss.passive = false
	stub.answer = "idle"
	await _until(func(): return boss.mode == Boss.Mode.IDLE, 4.0)
	var spread: BossAttack = boss.get_attack("spread")
	stub.answer = "spread"
	await _until(func(): return spread.phase != BossAttack.Phase.IDLE, 3.0)
	await _until(func(): return spread.phase == BossAttack.Phase.ACTIVE, 3.0)
	await _frames(2)
	var bolts_flying := get_nodes_in_group("projectile").size()
	stub.answer = "slam"
	await _until(func(): return boss.mode == Boss.Mode.IDLE, 4.0)
	var slam: BossAttack = boss.get_attack("slam")
	await _until(func(): return slam.phase == BossAttack.Phase.TELEGRAPH, 3.0)
	boss.global_position = home + Vector2(-250, 0)   # pulled away, so the walk home is real
	player.global_position = outside
	await _until(func(): return boss.aggro == Boss.Aggro.RETURNING, 2.0)
	_check(boss.aggro == Boss.Aggro.RETURNING, "gives up after leash_delay")
	_check(boss.outside_time > boss.leash_delay - 0.01, "only after the delay (%.2fs)" % boss.outside_time)
	_check(slam.phase == BossAttack.Phase.IDLE and boss.current_action == "" and boss.mode == Boss.Mode.IDLE, "windup cancelled: attack idle, no action")
	_check(not slam.get_node("Telegraph").visible, "no telegraph left on screen")
	_check(bolts_flying > 0, "bolts were in the air (%d)" % bolts_flying)
	_check(boss.health.hp == boss.health.max_hp and boss.phase == 1, "healed to full and back to phase 1 (hp %.0f phase %d)" % [boss.health.hp, boss.phase])
	var hp_ret := boss.health.hp
	boss.health.take_damage(200.0)
	_check(boss.health.hp == hp_ret, "no damage while returning")
	started.clear()
	await _until(func(): return boss.aggro == Boss.Aggro.IDLE, 6.0)
	_check(boss.aggro == Boss.Aggro.IDLE and boss.global_position == home, "walked back to its spawn and is idle there")
	_check(started.is_empty(), "no attacks on the way home")
	boss.health.take_damage(50.0)
	_check(boss.health.hp < hp_ret, "damage works again once home")

	# --- reset_heals = false keeps the hp (and invulnerable flag still guards the walk) ---
	boss.reset_heals = false
	boss.health.hp = 300.0
	player.global_position = inside
	await _until(func(): return boss.aggro == Boss.Aggro.ENGAGED, 1.0)
	boss.global_position = home + Vector2(-250, 0)   # away from home, so the walk takes time
	player.global_position = outside
	await _until(func(): return boss.aggro == Boss.Aggro.RETURNING, 2.0)
	boss.health.take_damage(100.0)
	_check(boss.health.hp == 300.0, "reset_heals off: hp stays 300, still no damage while returning (hp %.0f, inv %s)" % [boss.health.hp, boss.health.invulnerable])
	# --- re-entering while walking home engages again ---
	player.global_position = inside
	await _frames(3)
	_check(boss.aggro == Boss.Aggro.ENGAGED and not boss.health.invulnerable, "entering while returning engages and ends the invulnerability")

	# --- passive boss still finishes its walk home (it must not freeze half-reset) ---
	boss.reset_heals = true
	boss.passive = true
	boss.global_position = home + Vector2(-250, 0)
	await _frames(3)
	boss.passive = false
	player.global_position = outside
	await _until(func(): return boss.aggro == Boss.Aggro.RETURNING, 2.0)
	boss.passive = true
	await _until(func(): return boss.aggro == Boss.Aggro.IDLE, 6.0)
	_check(boss.aggro == Boss.Aggro.IDLE and boss.global_position == home and not boss.health.invulnerable, "passive boss still walks home and ends vulnerable")
	boss.passive = false

	# --- a forced charge from idle leaves it away from home: it walks back ---
	boss.force_next("charge")
	await _until(func(): return boss.current_action == "charge", 2.0)
	await _until(func(): return boss.mode == Boss.Mode.IDLE, 6.0)
	_check(boss.global_position.distance_to(home) > 50.0, "the forced charge moved it away from home")
	await _until(func(): return boss.global_position == home, 6.0)
	_check(boss.global_position == home and boss.aggro == Boss.Aggro.IDLE, "idle boss walks back home after a forced attack")

	# --- sniped from outside: a hit wakes it, then the leash heals it (no free damage) ---
	await _frames(5)
	boss.health.take_damage(80.0)
	await _frames(2)
	_check(boss.aggro == Boss.Aggro.ENGAGED, "a hit from outside engages the idle boss")
	await _until(func(): return boss.aggro == Boss.Aggro.RETURNING, 2.0)
	_check(boss.health.hp == boss.health.max_hp, "shooter stayed outside: leash resets it to full hp")

	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _until(cond: Callable, timeout: float) -> bool:
	var left := timeout
	while not cond.call():
		await physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second
		if left <= 0.0:
			return false
	return true
