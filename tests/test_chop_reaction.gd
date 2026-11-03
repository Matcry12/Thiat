extends SceneTree
# Tree chop feel: a hit sways the picture from the foot (foot planted) and it settles back to rest;
# the break pops, then the stump stays. Rocks keep the old path.
const ClassicArena = preload("res://tests/support/classic_arena.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var arena = ClassicArena.make()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var fx: HitFx = arena.get_node("HitFx")
	var player = arena.get_node("Player")
	var tree: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	tree.setup(load("res://data/resource_nodes/tree.tres"), 0)
	tree.position = player.global_position + Vector2(40, 160)
	arena.add_child(tree)
	await physics_frame
	var vis := tree.get_node("Visual")
	var body0: Vector2 = vis.get_node("Body").scale
	var body: Sprite2D = vis.get_node("Body")
	var r: NodeHitReaction = vis.get_node("Reaction")
	var foot := Vector2(0, tree.data.radius)
	var w := WeaponData.new()
	w.gather_damage = 1.0
	w.tool_power = 9
	w.tool_kind = tree.data.preferred_tool
	tree.data.max_hp = 20.0
	tree.hp = 20.0
	tree.take_gather_hit(w, player)
	await process_frame
	await process_frame
	_check(r.is_swaying(), "hit starts the sway")
	var moved := false
	for i in 12:
		await process_frame
		moved = moved or absf(body.skew) > 0.01
	_check(moved, "picture leans")
	_check(fx.node_fx.live_count() > 0, "chips + leaves alive")
	_check(fx.layer_counts["reaction"] == 1, "reaction layer counted")
	# foot stays planted at an arbitrary phase
	r.sway(8.0, 4.5, 0.0, 0.01, 0.9)
	for i in 7:
		await process_frame
	var base_sc := body0
	var p := body.transform * (Vector2(0, tree.data.radius / base_sc.y))
	_check(absf(body.skew) > 0.01 and p.distance_to(foot) < 0.5, "foot stays planted while leaning (%.3f px off)" % p.distance_to(foot))
	await create_timer(1.2).timeout
	_check(not r.is_swaying() and body.skew == 0.0 and body.position == Vector2.ZERO and body.scale == base_sc, "settles back to rest")
	# bigger as hp falls
	var low := fx.node_fx.sway_deg * lerpf(1.0, fx.node_fx.sway_max_mult, 0.9)
	tree.hp = 2.0
	fx.node_fx.react(&"chop", tree, Vector2.RIGHT, 0.1)
	_check(fx.node_fx.last_text.contains("sway %.1f" % low), "last hit before break is the biggest: " + fx.node_fx.last_text)
	await create_timer(1.0).timeout
	# break: pop, then the stump stays
	tree.hp = 1.0
	tree.take_gather_hit(w, player)
	await process_frame
	await process_frame
	_check(tree.is_broken() and r.is_popping(), "break starts the pop")
	var grown := body.scale.y > base_sc.y
	await create_timer(0.5).timeout
	_check(grown and not r.is_popping() and body.scale == base_sc and body.skew == 0.0, "pop grew then settled")
	_check(tree.data.remains_region.has_area() == (body.region_rect == tree.data.remains_region) or not tree.data.remains_region.has_area(), "stump shown after pop")
	# freed mid-effect: no crash
	var t2: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	t2.setup(load("res://data/resource_nodes/tree.tres"), 0)
	t2.position = tree.position + Vector2(80, 0)
	arena.add_child(t2)
	await physics_frame
	fx.test_hit(&"sword")
	fx.node_fx.test(&"chop", t2.position - Vector2(40, 0))
	fx.node_fx.test(&"pop", t2.position - Vector2(40, 0))
	t2.queue_free()
	await create_timer(0.5).timeout
	_check(true, "tree freed mid-effect: no crash")
	# rocks / copper still work
	var rock: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	rock.setup(load("res://data/resource_nodes/rock.tres"), 0)
	rock.position = tree.position + Vector2(-80, 0)
	arena.add_child(rock)
	await physics_frame
	w.tool_kind = rock.data.preferred_tool
	var rr: NodeHitReaction = rock.get_node("Visual/Reaction")
	rock.data = rock.data.duplicate()
	rock.data.max_hp = 20.0
	rock.hp = 20.0
	var dark := 0
	for c in rr.crown_colors(fx.node_fx.crown_min_brightness):
		dark += 1 if maxf(c.r, maxf(c.g, c.b)) < fx.node_fx.crown_min_brightness else 0
	_check(dark == 0, "rock chip colours skip the dark outline")
	var tc: PackedColorArray = tree.get_node("Visual/Reaction").crown_colors(fx.node_fx.crown_min_brightness)
	_check(tc.size() > 0 and tc[0].g > tc[0].r, "tree crown stays green")
	var rc: int = fx.layer_counts["reaction"]
	rock.take_gather_hit(w, player)
	await process_frame
	await process_frame
	_check(fx.layer_counts["reaction"] == rc + 1 and rr.is_swaying(), "rock sways on a hit")
	rock.hp = 0.5
	rock.take_gather_hit(w, player)
	await process_frame
	await process_frame
	_check(rock.is_broken() and is_instance_valid(rock) and rr.is_popping(), "rock break pops before it is freed")
	await create_timer(0.5).timeout
	_check(not is_instance_valid(rock), "rock gone after the pop")
	print("PASS" if _ok else "FAILED")
	quit(0 if _ok else 1)
