extends SceneTree
# Hit feel slice 2, gameplay half: real knockback on normal enemies, none on the boss (visual jolt only),
# the player's shove and block slide, the swing step, and the two separate switches. (decision 0023)
var _ok := true
var arena: Node
var player: CharacterBody2D
var dummy: CharacterBody2D
var boss: Boss
var fx: HitFx
var kb: Knockback

func check(name: String, cond: bool) -> void:
	print("%s: %s" % [name, "ok" if cond else "FAIL"])
	if not cond:
		_ok = false

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func settle(k: Knockback) -> void:
	await physics_frame   # a deferred (block) shove starts after this frame
	var guard := 0
	while k.is_pushing() and guard < 240:
		await physics_frame
		guard += 1
	await frames(2)

## Puts `body` at a spot where `dist` px along `dir` is free, searching a ring of candidates.
func place_clear(body: CharacterBody2D, dir: Vector2, dist: float) -> void:
	var base := body.global_position
	for r: float in [0.0, 120.0, 240.0, 360.0]:
		for a in 8:
			var c: Vector2 = base + Vector2.from_angle(a * TAU / 8.0) * r
			var t := Transform2D(0.0, c - dir * 70.0)
			if not body.test_move(t, dir * (dist + 140.0)) and not body.test_move(Transform2D(0.0, c), -dir * 60.0):
				body.global_position = c
				return

func _init():
	OS.set_environment("BOSSFIGHT_TEST_MAP_CELLS", "192")   # small island: this test does not need the full map
	arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	boss = arena.get_node("Boss")
	boss.passive = true
	await process_frame
	player = arena.get_node("Player")
	dummy = arena.get_node("Dummy")
	fx = arena.get_node("HitFx")
	kb = dummy.get_node("Knockback")
	fx.stop_on = false   # real hit-stop would slow the physics clock this test counts
	player.set_physics_process(false)
	dummy.attacker.set_physics_process(false)
	dummy.set_physics_process(false)   # home return is tested in section 7
	var dh: Health = dummy.get_node("Health")
	dh.immortal = true

	# 1. the dummy slides along the hit direction by about the profile distance
	place_clear(dummy, Vector2.RIGHT, 100.0)
	for row in [[&"melee", 30.0], [&"lunge", 70.0], [&"arrow", 10.0], [&"charged_arrow", 40.0]]:
		await settle(kb)
		var p0 := dummy.global_position
		player.global_position = p0 - Vector2(60, 0)
		await physics_frame
		dh.take_damage(10.0, player, true, row[0])
		await settle(kb)
		var moved := dummy.global_position - p0
		check("dummy %s: moved %.1f along +x (want ~%.0f)" % [row[0], moved.x, row[1]], absf(moved.x - row[1]) <= 2.0 and absf(moved.y) < 0.5)
		dummy.global_position = p0
	check("dummy has no velocity left over", dummy.velocity == Vector2.ZERO)

	# 2. never through a wall
	await settle(kb)
	var p0 := dummy.global_position
	var wall := StaticBody2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(10, 300)
	var cs := CollisionShape2D.new()
	cs.shape = rs
	wall.add_child(cs)
	root.add_child(wall)
	wall.global_position = p0 + Vector2(45, 0)   # lunge is 70 px: the wall is in the way
	player.global_position = p0 - Vector2(60, 0)
	await physics_frame
	dh.take_damage(10.0, player, true, &"lunge")
	var worst := -1e9
	var g := 0
	while (kb.is_pushing() or g < 3) and g < 240:
		await physics_frame
		worst = maxf(worst, dummy.global_position.x)
		g += 1
	var body_r := ((dummy.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	check("dummy stopped by the wall (right edge %.1f, wall face %.1f)" % [worst + body_r, wall.global_position.x - 5.0], worst + body_r <= wall.global_position.x - 5.0 + 0.5)
	check("dummy still moved a little before the wall", worst > p0.x)
	wall.queue_free()
	dummy.global_position = p0
	await frames(2)

	# 3. the boss body never moves; its Visual jolts and returns to exactly where it was
	check("boss has no Knockback component", boss.get_node_or_null("Knockback") == null)
	var bpos := boss.global_position
	var vpos := boss.visual.position
	var bh: Health = boss.health
	bh.immortal = true
	player.global_position = bpos - Vector2(90, 0)
	dummy.global_position = bpos + Vector2(0, 400)
	var guard_p: Guard = player.get_node("Guard")
	var peak := 0.0
	for tag in [&"melee", &"lunge", &"charged_arrow", &"parry"]:
		var recoil_before: int = fx.layer_counts["recoil"]
		if tag == &"parry":
			guard_p.aim_direction = Vector2.RIGHT
			guard_p.try_guard()
			player.get_node("Health").take_damage(10.0, boss, true)
		else:
			bh.take_damage(30.0, player, true, tag)
		peak = 0.0
		for i in 12:
			await physics_frame
			var r := boss.visual.get_node_or_null("HitRecoil") as HitRecoil
			if r:
				peak = maxf(peak, r.offset().length())
		await frames(10)
		check("boss %s: body unchanged (%s)" % [tag, boss.global_position - bpos], boss.global_position == bpos)
		check("boss %s: Visual jolted (peak %.2f px) and is back at zero" % [tag, peak], peak > 0.5 and boss.visual.position == vpos and fx.layer_counts["recoil"] == recoil_before + 1)
		guard_p.release()
		await frames(20)
		guard_p = player.get_node("Guard")
	boss.passive = true

	# 4. the swing step: sword about 8 px, bow 0, never into the boss
	var holder: WeaponHolder = player.get_node("WeaponHolder")
	var sword: WeaponData = holder.weapon
	check("sword step_distance is 8, bow is 0", sword.step_distance == 8.0 and (load("res://data/weapons/bow.tres") as WeaponData).step_distance == 0.0)
	player.global_position = Vector2(bpos.x - 400, bpos.y)
	place_clear(player, Vector2.RIGHT, 40.0)
	holder.aim_direction = Vector2.RIGHT
	var s0 := player.global_position
	holder.try_attack()
	g = 0
	while holder.phase != WeaponHolder.Phase.IDLE and g < 300:
		await physics_frame
		g += 1
	var stepped := (player.global_position - s0)
	check("sword swing stepped %.2f px forward (want ~8)" % stepped.x, absf(stepped.x - 8.0) <= 1.0 and absf(stepped.y) < 0.1)
	holder.weapon = load("res://data/weapons/bow.tres")
	s0 = player.global_position
	holder.try_attack()
	g = 0
	while holder.phase != WeaponHolder.Phase.IDLE and g < 300:
		await physics_frame
		g += 1
	check("bow stepped 0 px", player.global_position.distance_to(s0) < 0.01)
	holder.weapon = sword
	# a dodge cancels the swing, so the step stops with it
	holder.try_attack()
	await frames(3)
	holder.cancel()
	s0 = player.global_position
	await frames(10)
	check("cancelled swing does not keep stepping", player.global_position.distance_to(s0) < 0.01)
	await frames(30)
	var pr := ((player.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	var br := ((boss.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	player.global_position = bpos - Vector2(pr + br + 3.0, 0)
	await physics_frame
	holder.try_attack()
	g = 0
	while holder.phase != WeaponHolder.Phase.IDLE and g < 300:
		await physics_frame
		g += 1
	var gap := player.global_position.distance_to(bpos)
	check("swing step stops at the boss body (centre gap %.2f, bodies touch at %.0f)" % [gap, pr + br], gap >= pr + br - 0.1 and boss.global_position == bpos)
	await frames(30)

	# 5. the player's shove: small, does not cancel a dodge
	var pk: Knockback = player.get_node("Knockback")
	var ph: Health = player.get_node("Health")
	ph.immortal = true
	place_clear(player, Vector2.RIGHT, 300.0)
	dummy.global_position = player.global_position + Vector2(80, 0)
	await frames(3)
	var q0 := player.global_position
	ph.take_damage(10.0, dummy, true, &"melee")
	await settle(pk)
	var shove := player.global_position - q0
	check("player hit: shoved %.1f px away from the hitter (want ~20)" % shove.x, absf(shove.x + 20.0) <= 2.0)
	ph.invulnerable = false
	dummy.global_position = player.global_position + Vector2(0, 90)
	var dodge: Dodge = player.get_node("Dodge")
	await frames(3)
	var d0 := player.global_position
	check("dodge started", dodge.try_dodge(Vector2.RIGHT, Vector2.RIGHT))
	await frames(3)
	var pushes: int = pk.total_pushes
	ph.take_damage(10.0, dummy, true, &"melee")   # i-frames: no hit, no shove
	check("i-frames: no shove, dodge goes on", pk.total_pushes == pushes and dodge.is_dashing())
	pk.apply(Vector2.LEFT, 20.0)                  # a shove arriving mid-dash (e.g. from a lunge hit)
	g = 0
	await physics_frame
	check("shove mid-dash: dodge not cancelled", dodge.is_dashing())
	g = 1
	while dodge.is_dashing() and g < 60:
		await physics_frame
		g += 1
	check("dodge ran its full course (i-frames %s)" % dodge.iframes_active(), g > 2 and player.global_position.x - d0.x > 120.0)
	await settle(pk)
	# guard: a block slides the player back 12 px
	await frames(40)
	ph.invulnerable = false
	dodge._iframe_remaining = 0.0
	dummy.global_position = player.global_position + Vector2(60, 0)
	guard_p.aim_direction = Vector2.RIGHT
	guard_p.try_guard()
	g = 0
	while guard_p.state != Guard.State.BLOCK and g < 120:
		await physics_frame
		g += 1
	await frames(3)
	var b0 := player.global_position
	ph.take_damage(10.0, dummy, true, &"melee")
	await settle(pk)
	check("block slid the player back %.1f px (want ~12)" % (b0.x - player.global_position.x), absf((b0.x - player.global_position.x) - 12.0) <= 2.0)
	guard_p.release()
	await frames(5)

	# 6. the switches: knockback off = no movement but the effects still play; Hit FX off = still moves
	await settle(kb)
	place_clear(dummy, Vector2.RIGHT, 100.0)
	var e0 := dummy.global_position
	player.global_position = e0 - Vector2(60, 0)
	kb.enabled = false
	var sparks: int = fx.layer_counts["sparks"]
	dh.take_damage(10.0, player, true, &"lunge")
	await frames(40)
	check("knockback off: dummy did not move, effects still played", dummy.global_position == e0 and fx.layer_counts["sparks"] == sparks + 1)
	kb.enabled = true
	fx.enabled = false
	var f0: int = fx.layer_counts["sparks"]
	dh.take_damage(10.0, player, true, &"lunge")
	await settle(kb)
	check("Hit FX off: dummy still moved %.1f, no effects" % (dummy.global_position.x - e0.x), absf(dummy.global_position.x - e0.x - 70.0) <= 2.0 and fx.layer_counts["sparks"] == f0)
	fx.enabled = true

	# 7. knockback off: the dummy still gets the visual jolt (like the boss)
	kb.enabled = false
	var rc: int = fx.layer_counts["recoil"]
	dh.take_damage(10.0, player, true, &"lunge")
	await frames(2)
	check("knockback off: dummy Visual jolts", fx.layer_counts["recoil"] == rc + 1 and dummy.visual.get_node_or_null("HitRecoil") != null)
	kb.enabled = true
	await frames(20)
	rc = fx.layer_counts["recoil"]
	dh.take_damage(10.0, player, true, &"lunge")
	await frames(2)
	check("knockback on: dummy is shoved, no jolt", fx.layer_counts["recoil"] == rc)
	await settle(kb)

	# 8. a guard break shoves the player once (20 px hit), a plain block slides 12 px
	ph.immortal = false
	ph.hp = ph.max_hp
	ph.shield = ph.shield_max
	place_clear(player, Vector2.RIGHT, 300.0)
	dummy.global_position = player.global_position + Vector2(60, 0)
	await frames(60)
	guard_p.aim_direction = Vector2.RIGHT
	guard_p.tank = 5.0
	guard_p.try_guard()
	g = 0
	while guard_p.state != Guard.State.BLOCK and g < 120:
		await physics_frame
		g += 1
	await frames(3)
	var k0 := player.global_position
	var pk0: int = pk.total_pushes
	ph.take_damage(30.0, dummy, true, &"melee")   # tank 5: the guard breaks and the rest goes through
	await settle(pk)
	check("guard break: guard broken", guard_p.state == Guard.State.BROKEN)
	check("guard break: one shove only (%d), %.1f px (want ~20)" % [pk.total_pushes - pk0, k0.x - player.global_position.x], pk.total_pushes - pk0 == 1 and absf((k0.x - player.global_position.x) - 20.0) <= 2.0)
	ph.immortal = true
	await frames(120)

	# 9. a player who dies mid-shove stops sliding
	place_clear(player, Vector2.RIGHT, 300.0)
	ph.immortal = false
	ph.hp = 1.0
	ph.shield = 0.0
	await frames(3)
	var x0 := player.global_position
	pk.apply(Vector2.LEFT, 40.0)
	await frames(1)
	ph.take_damage(50.0, dummy, true, &"melee")
	await frames(30)
	check("dead player: hp %.0f, shove cleared, moved %.1f px" % [ph.hp, absf(player.global_position.x - x0.x)], ph.hp <= 0.0 and not pk.is_pushing() and absf(player.global_position.x - x0.x) < 25.0)
	ph.hp = ph.max_hp
	ph.immortal = true

	# 10. dummy home return: waits, slides back at home_return_speed, stops at a rock
	var dm: Node = dummy
	dummy.set_physics_process(true)
	dummy.home_return_delay = 1.0
	dummy.home_return_speed = 120.0
	place_clear(dummy, Vector2.RIGHT, 100.0)
	await frames(2)
	dummy.home = dummy.global_position
	player.global_position = dummy.home - Vector2(60, 0)
	await physics_frame
	dh.take_damage(10.0, player, true, &"lunge")
	await settle(kb)
	var away := dummy.global_position.distance_to(dummy.home)
	check("dummy was shoved away %.1f px" % away, away > 50.0)
	await frames(10)
	check("dummy waits during the delay", dummy.global_position.distance_to(dummy.home) > away - 1.0 and not dummy.is_returning())
	g = 0
	while dummy.global_position.distance_to(dummy.home) > 0.6 and g < 400:
		await physics_frame
		g += 1
	check("dummy slid back home (%.2f px off, %d frames)" % [dummy.global_position.distance_to(dummy.home), g], dummy.global_position.distance_to(dummy.home) <= 0.6 and g > 10)
	# a hit resets the timer
	dh.take_damage(10.0, player, true, &"lunge")
	await settle(kb)
	await frames(10)
	check("hit resets the idle timer (not returning)", not dummy.is_returning())
	dummy.global_position = dummy.home

	# 11. a real rock stops the shoved dummy
	var rock: Node2D = null
	for n in get_nodes_in_group("map_obstacle"):
		rock = n
		break
	check("found a rock/static obstacle", rock != null)
	if rock:
		dummy.set_physics_process(false)
		var rr := 0.0
		# the body's own shape only: a resource node also has a bigger Hurtbox shape one level down
		for c in rock.get_children():
			if c is CollisionShape2D and (c as CollisionShape2D).shape is CircleShape2D:
				rr = ((c as CollisionShape2D).shape as CircleShape2D).radius
		var rpos := rock.global_position
		var dr := ((dummy.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
		dummy.global_position = rpos - Vector2(rr + dr + 30.0, 0)
		player.global_position = dummy.global_position - Vector2(60, 0)
		await frames(3)
		dh.take_damage(10.0, player, true, &"lunge")   # 70 px: 30 free, then the rock
		await settle(kb)
		var gap2 := dummy.global_position.distance_to(rpos)
		check("rock stops the dummy (centre gap %.1f, touch at %.1f, rock r %.1f)" % [gap2, rr + dr, rr], gap2 >= rr + dr - 0.5 and dummy.global_position.x < rpos.x and dummy.global_position.x > rpos.x - rr - dr - 31.0)

	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
