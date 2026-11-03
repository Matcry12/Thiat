extends SceneTree
# W5 (decision 0052): slime. Takes sword damage and dies, drops gel the Collector picks up, hops at a player in range and
# deals contact damage, does nothing outside aggro, goes home past the leash (and heals), never hurts a dead player.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _until(cond: Callable, timeout: float) -> bool:
	var left := timeout
	while not cond.call():
		await physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second
		if left <= 0.0:
			return false
	return true

func _slime(arena: Node, at: Vector2) -> Enemy:
	var d: EnemyData = load("res://data/enemies/slime.tres")
	var e: Enemy = d.scene.instantiate()
	e.data = d.duplicate()
	arena.add_child(e)
	e.global_position = at
	return e

func _init() -> void:
	var arena = await World.make(self)
	var player: Node2D = arena.get_node("Player")
	var ph: Health = player.get_node("Health")
	var spot: Vector2 = player.global_position
	player.global_position = spot

	# --- outside aggro: wanders near home, no windup, no damage
	var far := _slime(arena, spot + Vector2(1000, 0))
	far.data.wander_pause = 0.2
	var states := {}
	far.state_changed.connect(func(s: String): states[s] = true)
	for i in 120:
		await physics_frame
	_check(not states.has("windup") and not states.has("hop"), "outside aggro: no windup, no hop")
	_check(far.global_position.distance_to(far.home) <= far.data.wander_radius + 5.0, "wanders only near home")
	_check(far.is_in_group("enemy") and far.status_text().begins_with("slime"), "group enemy + status line")
	far.free()

	# --- hops at the player in range, deals contact damage once per hop
	var s := _slime(arena, spot + Vector2(100, 0))
	s.data.hop_windup = 0.2
	s.data.hop_cooldown = 5.0
	var seq: Array[String] = []
	s.state_changed.connect(func(st: String): seq.append(st))
	var hp0 := ph.hp
	await _until(func(): return ph.hp < hp0, 2.0)
	_check(ph.hp < hp0, "contact damage landed (hp %.0f -> %.0f)" % [hp0, ph.hp])
	_check(seq.size() >= 2 and seq[0] == "windup" and seq[1] == "hop", "windup then hop: %s" % [seq])
	_check(not s.hitbox.is_active() or s.state == Enemy.State.HOP, "hitbox only active during the hop")
	await _until(func(): return s.state == Enemy.State.IDLE, 2.0)
	_check(not s.hitbox.is_active(), "hitbox off after the hop")
	var hp1 := ph.hp
	for i in 30:
		await physics_frame
	_check(ph.hp == hp1, "no more damage while resting (cooldown)")

	# --- a dead player is not hurt again
	s._cooldown = 0.0
	s.global_position = spot + Vector2(60, 0)
	player.dead = true
	var hp2 := ph.hp
	for i in 90:
		await physics_frame
	_check(ph.hp == hp2 and not s.state == Enemy.State.WINDUP, "dead player: no windup, no damage")
	player.dead = false

	# --- sword damage kills, gel drops, Collector picks it up
	s.global_position = spot + Vector2(40, 0)
	s.health.take_damage(s.health.max_hp - 1.0, player, true, &"melee")
	_check(s.state == Enemy.State.HIT, "hit state after damage")
	var gel0 := _count_gel(player)
	s.health.take_damage(5.0, player, true, &"melee")
	_check(s.state == Enemy.State.DIE, "dies at 0 hp")
	await physics_frame
	var drops := get_nodes_in_group("pickup").filter(func(p): return p.item.id == &"gel")
	_check(drops.size() >= 1 and drops.size() <= 3, "gel pickups spawned (%d)" % drops.size())
	player.global_position = s.global_position
	await _until(func(): return _count_gel(player) > gel0, 3.0)
	_check(_count_gel(player) > gel0, "Collector picked up gel")
	var sid := s.get_instance_id()
	await _until(func(): return not is_instance_id_valid(sid), 2.0)
	_check(not is_instance_id_valid(sid), "corpse removed after the fade")

	# --- leash: dragged out, walks home, heals
	var l := _slime(arena, spot + Vector2(-300, 0))
	await physics_frame   # home is fixed on the first physics frame
	l.health.hp = 5.0
	l.global_position = l.home + Vector2(l.data.leash_radius + 50.0, 0)
	player.global_position = spot + Vector2(0, 420)
	await physics_frame
	_check(l.returning, "past the leash: returning")
	await _until(func(): return not l.returning, 15.0)
	_check(l.global_position.distance_to(l.home) < 10.0, "walked back home past the leash")
	_check(l.health.hp == l.health.max_hp and not l.returning, "healed on arrival")

	# --- own shapes: two slimes with different radii keep their own
	player.global_position = spot + Vector2(0, 420)
	var a := _slime(arena, spot + Vector2(-200, 100))
	var b := _slime(arena, spot + Vector2(-200, 160))
	b.data.body_radius = 20.0
	b.data.contact_radius = 30.0
	await physics_frame
	var ra: float = (a.get_node("CollisionShape2D").shape as CircleShape2D).radius
	var rb: float = (b.get_node("CollisionShape2D").shape as CircleShape2D).radius
	_check(ra == a.data.body_radius and rb == 20.0 and (b.get_node("Hitbox/CollisionShape2D").shape as CircleShape2D).radius == 30.0, "each slime keeps its own shape sizes (%.0f / %.0f)" % [ra, rb])
	# data edits reach live slimes, max hp has one owner
	b.data.max_hp = 80.0
	await physics_frame
	_check(b.health.max_hp == 80.0 and a.health.max_hp == 40.0, "data max_hp reaches the live slime's Health")
	_check(b.debug_children().all(func(c): return c["object"] != b.health), "no per-instance Health section")

	# --- hitbox is dangerous only in the hop: player stands on the slime
	var h := _slime(arena, spot + Vector2(300, 100))
	h.data.hop_windup = 0.3
	h.data.hop_cooldown = 0.0
	player.global_position = h.global_position + Vector2(10, 0)
	var hpx := ph.hp
	var bad := false
	var saw_hop := false
	for i in 60:
		await physics_frame
		if h.state != Enemy.State.HOP and h.hitbox.is_active():
			bad = true
		if h.state == Enemy.State.HOP and h.hitbox.is_active():
			saw_hop = true
		if h.state == Enemy.State.WINDUP:
			_check(ph.hp == hpx, "no damage during windup") if i % 20 == 0 else null
	_check(not bad and saw_hop, "hitbox active in the hop only")
	h.free()

	# --- sprite art: animation = state, windup length matches data
	var sp := _slime(arena, spot + Vector2(-300, -100))
	sp.data.hop_windup = 0.25
	await physics_frame
	var vis := sp.get_node("Visual") as EnemyVisual
	var spr := vis.get_node_or_null("Sprite") as AnimatedSprite2D
	_check(spr != null, "real art: AnimatedSprite2D present (data.sprite_frames set)")
	if spr:
		sp.state_changed.emit("windup")
		var f := spr.sprite_frames
		var len := f.get_frame_count(&"windup") / f.get_animation_speed(&"windup")
		_check(spr.animation == &"windup" and is_equal_approx(len / spr.speed_scale, 0.25), "windup anim plays, stretched to hop_windup (%.3f s)" % (len / spr.speed_scale))
		sp.state_changed.emit("idle")
		_check(spr.animation == &"idle" and f.get_animation_loop(&"idle") and not f.get_animation_loop(&"hop"), "idle loops, hop does not")
	# shared visual data: one edit reaches both live slimes, killing the first keeps it
	var sp2 := _slime(arena, spot + Vector2(-300, -220))
	await physics_frame
	var vd: EnemyVisualData = sp.data.visual
	_check(sp2.data.visual == vd or sp2.data.visual != null, "slimes have visual data")
	sp2.data.visual = vd
	vd.pixel_scale = 2
	await physics_frame
	await physics_frame
	var s1 := sp.get_node("Visual/Sprite") as AnimatedSprite2D
	_check(s1.scale == Vector2(2, 2) and s1.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "visual data edit reaches the live slime, nearest filter")
	sp.free()
	await physics_frame
	_check(vd.pixel_scale == 2 and (sp2.get_node("Visual/Sprite") as AnimatedSprite2D).scale == Vector2(2, 2), "edit survives the first slime dying")
	# every slime type: loads, has biome rates, tint reaches the sprite, ids/visuals are not shared
	var ids := {}
	var visuals := {}
	for k in ["slime", "swamp_slime", "sand_slime", "ice_slime", "rock_slime"]:
		var kd: EnemyData = load("res://data/enemies/%s.tres" % k)
		var ok := kd != null and kd.id == StringName(k) and kd.rate_for("forest") + kd.rate_for("plains") + kd.rate_for("swamp") + kd.rate_for("beach_sand") + kd.rate_for("snowy") + kd.rate_for("rocky") > 0.0 and kd.scene != null and kd.visual != null
		_check(ok, "%s loads with biome rates" % k)
		ids[kd.id] = true
		visuals[kd.visual] = true
		var ke: Enemy = kd.scene.instantiate()
		ke.data = kd
		arena.add_child(ke)
		ke.global_position = spot + Vector2(-350, 150)
		await physics_frame
		await physics_frame
		var ksp := ke.get_node("Visual/Sprite") as AnimatedSprite2D
		_check(ksp.modulate.is_equal_approx(kd.visual.tint) and ke.health.max_hp == kd.max_hp, "%s: tint on the sprite, hp %.0f" % [k, ke.health.max_hp])
		ke.free()
	var g: EnemyData = load("res://data/enemies/slime.tres")
	_check(g.rate_for("taiga") == 0.6 and g.rate_for("swamp") == 0.0 and g.rate_for("nowhere") == 0.0 and (load("res://data/enemies/sand_slime.tres") as EnemyData).rate_for("beach (sand)") == 0.4 and (load("res://data/enemies/rock_slime.tres") as EnemyData).rate_for("rocky") == 0.25, "rate_for: values, 0 for unlisted / unknown")
	_check(ids.size() == 5 and visuals.size() == 5, "5 kinds, 5 own visual resources")
	# placeholder fallback
	var fd: EnemyData = (load("res://data/enemies/slime.tres") as EnemyData).duplicate()
	fd.sprite_frames = null
	var fb: Enemy = fd.scene.instantiate()
	fb.data = fd
	arena.add_child(fb)
	fb.global_position = spot + Vector2(-300, -160)
	await physics_frame
	_check(fb.get_node("Visual").get_node_or_null("Sprite") == null, "sprite_frames null: blob fallback")

	print("ALL PASS" if _ok else "SOME FAILED")
	quit(0 if _ok else 1)

func _count_gel(player: Node) -> int:
	var inv: Inventory = player.get_node("Inventory")
	var n := 0
	for i in Inventory.SIZE:
		if inv.slot_item(i) != null and inv.slot_item(i).id == &"gel":
			n += inv.slot_count(i)
	return n
