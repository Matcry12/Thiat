extends SceneTree
# Hit area measured from the weapon picture (0061), in the real arena + player scene.
# Exact numbers come from GENERATED pictures; real art is only checked as "tip > 0, length = tip + margin", so a redrawn sword stays green.
const Fit = preload("res://scripts/weapons/weapon_hit_fit.gd")
var _fail := 0

func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fail += 1

func _hb(wv: WeaponVisual) -> Hitbox:
	return wv.get_model().get_node("Hitbox") as Hitbox

func _shape(wv: WeaponVisual) -> RectangleShape2D:
	return wv.get_model().get_node("Hitbox/CollisionShape2D").shape as RectangleShape2D

func _tipx(wv: WeaponVisual) -> float:
	return (wv.get_model().get_node("Tip") as Node2D).position.x

## farthest corner (from the origin) over every pose the swing tries
func _reach(hb: Hitbox, origin: Vector2) -> float:
	var best := 0.0
	for p in hb.motion_poses(0.0, 1.0, 8):
		var sz: Vector2 = (p[0] as RectangleShape2D).size
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			best = maxf(best, ((p[1] as Transform2D) * (sz * 0.5 * c)).distance_to(origin))
	return best

## a test model: the wooden sword scene with `tex` laid along +x (scale 2) at `rot` radians
func _model(tex: Texture2D, rot := 0.0, region := Rect2()) -> PackedScene:
	var m: Node2D = load("res://scenes/weapons/wooden_sword_model.tscn").instantiate()
	var art := m.get_node("Art") as Sprite2D
	art.texture = tex
	art.rotation = rot
	art.offset = Vector2(0, -1.5)
	if region.size.x > 0.0:
		art.region_enabled = true
		art.region_rect = region
	for c in m.get_children():
		c.owner = m
	var ps := PackedScene.new()
	ps.pack(m)
	return ps

func _bar(len_px: int, h := 3) -> ImageTexture:
	var img := Image.create(len_px, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)

func _data(base: WeaponData, ps: PackedScene) -> WeaponData:
	var d: WeaponData = base.duplicate()
	d.model = ps
	return d

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	for i in 5:
		await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	wv.set_process(false)
	var panel: TuningPanel = arena.get_node("TuningPanel")
	var wood: WeaponData = load("res://data/weapons/wooden_sword.tres").duplicate()

	# --- real art: no pinned picture sizes ---
	for n in ["sword1", "wooden_sword", "copper_sword", "stone_axe", "stone_pickaxe"]:
		var d: WeaponData = load("res://data/weapons/%s.tres" % n).duplicate()
		wv.weapon = d
		var tp := _tipx(wv)
		_check(tp > 20.0 and absf(_shape(wv).size.x - (tp + d.hit_tip_margin)) < 0.01 and wv.status_text().contains("hit: auto"), "%s: tip %.1f, length %.1f = tip + margin" % [n, tp, _shape(wv).size.x])
		_check(absf(wv._tip.x - tp) < 0.01 or wv._motion == null, n + ": swing effects' _tip follows the fit")
	# tool: the median keeps the width on the head/handle, never below the minimum
	var axe: WeaponData = load("res://data/weapons/stone_axe.tres").duplicate()
	wv.weapon = axe
	_check(_shape(wv).size.y >= axe.hit_min_width and _shape(wv).size.y > 12.0, "axe width %.1f (head is wide)" % _shape(wv).size.y)

	# --- generated bar: exact numbers (30 px picture, scale 2: tip pixel centre 59, thickness 6) ---
	var d30 := _data(wood, _model(_bar(30)))
	wv.weapon = d30
	_check(absf(_tipx(wv) - 59.0) < 0.01 and absf(_shape(wv).size.x - 67.0) < 0.01, "bar 30: tip %.2f length %.2f (want 59 / 67)" % [_tipx(wv), _shape(wv).size.x])
	_check(absf(_shape(wv).size.y - 9.0) < 0.01, "bar 30: width %.2f = min width 9 (6 + 2.5 < 9)" % _shape(wv).size.y)
	wv.weapon = _data(wood, _model(_bar(30, 8)))
	_check(absf(_shape(wv).size.y - 18.5) < 0.01, "bar 8 tall: width %.2f (want 16 + 2.5)" % _shape(wv).size.y)

	# --- longer picture reaches farther through motion_poses ---
	var reach: Array[float] = []
	for n in [20, 40]:
		var d := _data(wood, _model(_bar(n)))
		wv.weapon = d
		var hb := _hb(wv)
		hb.weapon = d
		reach.append(_reach(hb, wv.global_position))
	_check(reach[1] > reach[0] + 10.0, "longer picture = longer reach (%.1f -> %.1f)" % [reach[0], reach[1]])

	# --- atlas picture and region_rect: only the region counts ---
	var img := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 12, 32, 3), Color.WHITE)    # outside the region, far to the... it must not count
	img.fill_rect(Rect2i(32, 6, 28, 3), Color.WHITE)    # the region's blade: 28 px wide
	var big := ImageTexture.create_from_image(img)
	var at := AtlasTexture.new()
	at.atlas = big
	at.region = Rect2(32, 0, 32, 16)
	wv.weapon = _data(wood, _model(at))
	var tip_atlas := _tipx(wv)
	wv.weapon = _data(wood, _model(big, 0.0, Rect2(32, 0, 32, 16)))
	var tip_region := _tipx(wv)
	_check(absf(tip_atlas - 55.0) < 0.01 and absf(tip_region - 55.0) < 0.01, "atlas tip %.2f, region_rect tip %.2f (want 55)" % [tip_atlas, tip_region])

	# --- stray faint pixel: alpha_min ignores it, 0 does not; part of the cache key ---
	var simg := Image.create(60, 3, false, Image.FORMAT_RGBA8)
	simg.fill_rect(Rect2i(0, 0, 30, 3), Color.WHITE)
	simg.set_pixel(59, 1, Color(1, 1, 1, 1.0 / 255.0))
	var dst := _data(wood, _model(ImageTexture.create_from_image(simg)))
	wv.weapon = dst
	_check(absf(_tipx(wv) - 59.0) < 0.01, "stray alpha 1/255 pixel ignored (tip %.1f)" % _tipx(wv))
	dst.hit_alpha_min = 0.0
	_check(_tipx(wv) > 100.0, "hit_alpha_min 0 counts it (tip %.1f)" % _tipx(wv))
	dst.hit_alpha_min = 0.5
	_check(absf(_tipx(wv) - 59.0) < 0.01, "back to 0.5: same picture, different cache key, tip %.1f" % _tipx(wv))

	# --- off axis ---
	wv.weapon = _data(wood, _model(_bar(30), 0.5))
	_check(wv.status_text().contains("OFF AXIS"), "tilted picture: status says OFF AXIS")
	wv.weapon = d30
	_check(not wv.status_text().contains("OFF AXIS"), "straight picture: no OFF AXIS")
	wv.weapon = load("res://data/weapons/copper_sword.tres").duplicate()
	_check(not wv.status_text().contains("OFF AXIS"), "copper sword (2.4 px off) does not warn")

	# --- rig visual_scale leaves the shape and the fitted Tip alone ---
	wv.weapon = d30
	var size0 := _shape(wv).size
	var pos0: Vector2 = wv.get_model().get_node("Hitbox/CollisionShape2D").global_position
	var rig: BodyRig = load("res://data/body_rigs/soft_body.tres").duplicate()
	rig.visual_scale = 1.5
	wv.apply_rig(rig)
	_check(_shape(wv).size == size0 and wv.get_model().get_node("Hitbox/CollisionShape2D").global_position.distance_to(pos0) < 0.01, "visual_scale 1.5: shape + world position unchanged")
	_check(absf(_tipx(wv) - 59.0) < 0.01, "visual_scale 1.5: Tip keeps the fitted x")
	d30.hit_tip_margin = 30.0   # live refit while scaled: still unchanged scale logic
	_check(absf(_shape(wv).size.x - 89.0) < 0.01 and absf(_tipx(wv) - 59.0) < 0.01, "refit at rig scale 1.5: length %.1f" % _shape(wv).size.x)
	d30.hit_tip_margin = 8.0
	rig.visual_scale = 1.0
	wv.apply_rig(rig)

	# --- shared SubResource untouched; second use unaffected ---
	var sw: WeaponData = load("res://data/weapons/sword1.tres").duplicate()
	sw.hit_tip_margin = 20.0
	wv.weapon = sw
	var l20 := _shape(wv).size.x
	var ref: Node = load("res://scenes/weapons/sword1_model.tscn").instantiate()
	_check(Vector2((ref.get_node("Hitbox/CollisionShape2D") as CollisionShape2D).shape.size) == Vector2(50, 9.562761), "scene's shared shape not mutated")
	ref.free()
	sw.hit_tip_margin = 8.0
	_check(absf(l20 - _shape(wv).size.x - 12.0) < 0.01, "margin 20 -> 8 live: %.1f -> %.1f" % [l20, _shape(wv).size.x])

	# --- auto off puts the hand-set shape AND Tip back, auto on measures again ---
	var tip_auto := _tipx(wv)
	sw.hit_auto_fit = false
	_check(_shape(wv).size == Vector2(50, 9.562761) and _tipx(wv) == 42.0 and wv.status_text().contains("hit: manual"), "auto off: hand shape 50 x 9.56 and Tip 42 back")
	sw.hit_auto_fit = true
	_check(absf(_tipx(wv) - tip_auto) < 0.01 and wv.status_text().contains("hit: auto"), "auto on again")

	# --- the real F3 path: apply_value on the held weapon's own section ---
	var held: WeaponData = player.get_node("Loadout").active_weapon()
	wv.weapon = held
	var key := held.debug_name() + ".hit_tip_margin"
	_check(panel.settings.has(key), "F3 has the row " + key)
	var before := _shape(wv).size.x
	panel.apply_value(key, held.hit_tip_margin + 10.0)
	_check(absf(_shape(wv).size.x - before - 10.0) < 0.01, "F3 apply_value refits at once (%.1f -> %.1f)" % [before, _shape(wv).size.x])
	panel.apply_value(held.debug_name() + ".hit_auto_fit", false)
	_check(wv.status_text().contains("hit: manual"), "F3 hit_auto_fit off: manual")
	panel.apply_value(held.debug_name() + ".hit_auto_fit", true)
	panel.apply_value(key, held.hit_tip_margin - 10.0)

	# --- swap disconnects: the old weapon's numbers do not touch the new model ---
	wv.weapon = sw
	_check(not held.changed.is_connected(wv._refit_hit), "swap disconnects the old weapon")
	_check(sw.changed.is_connected(wv._refit_hit), "swap connects the new weapon")

	# --- nothing to fit ---
	for n in ["bow", "fists"]:
		wv.weapon = load("res://data/weapons/%s.tres" % n).duplicate()
		_check(wv.get_model() != null and wv.status_text().contains("hit: manual"), n + " loads, hit: manual")
	var bare := Node2D.new()
	_check(Fit.apply(bare, sw) == "hit: manual", "model without Art / Hitbox stays manual")
	bare.free()
	wv.weapon = null
	_check(wv.status_text().contains("hit: -") and not wv.status_text().contains("hit: auto"), "no weapon: hit: -")

	print("DONE fail=%d" % _fail)
	quit(1 if _fail > 0 else 0)
