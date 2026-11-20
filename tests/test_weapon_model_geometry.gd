extends SceneTree
const ClassicArena = preload("res://tests/support/classic_arena.gd")
# The Step 1 model-scene refactor (moving Blade/Hitbox out of player.tscn into
# scenes/weapons/sword_model.tscn) must not move the hand-tuned sword by even
# one pixel/radian. These numbers were captured from the PRE-refactor scene
# (Player/WeaponVisual/SwingPivot/Blade + .../Hitbox/CollisionShape2D) and must
# still match to 0.01px / 0.001rad now that the same nodes live inside the
# model instance at Player/WeaponVisual/SwingPivot/SwordModel/{Art,Hitbox}.

const EXPECTED := {
	"right": {
		"blade_pos": Vector2(417.63, 315.244), "blade_rot": 1.221730, "blade_scale_y": 1.339816,
		"hit_pos": Vector2(435.3114, 302.4234), "hit_rot": -0.349066, "hit_scale_y": 1.0,
	},
	"up-left": {
		"blade_pos": Vector2(400.6038, 308.1916), "blade_rot": 2.705260, "blade_scale_y": -1.339816,
		"hit_pos": Vector2(397.1667, 286.6234), "hit_rot": -2.007129, "hit_scale_y": -1.0,
	},
	"down": {
		"blade_pos": Vector2(412.244, 320.63), "blade_rot": 0.349066, "blade_scale_y": -1.339816,
		"hit_pos": Vector2(399.4234, 338.3114), "hit_rot": 1.919862, "hit_scale_y": -1.0,
	},
}
const EXPECTED_SHAPE_SIZE := Vector2(56.0, 14.0)   # 0061: measured from the picture (tip 48 + 8 margin; median thickness 11.5 + 2.5). Artist redraw 2026-11-20 (was 56.08 x 9.5)
const POS_TOL := 0.01
const ROT_TOL := 0.001

func _init():
	var arena = ClassicArena.make()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)          # headless mouse sits at (0,0)
	# These numbers pin the sword MODEL at scale 1 (the hand-tuned original). A character's BodyRig only shrinks the picture
	# (hitbox world transform is unchanged, see tests/test_body_rig.gd), so measure with the unscaled rig.
	player.get_node("Visual").rig = load("res://data/body_rigs/pixel_plains.tres")
	player.get_node("MainHandHold").position = Vector2(0, -9)   # these numbers were measured with the hand at (0,-9); the scene's Hand may be dragged elsewhere
	await process_frame
	var wv = arena.get_node("Player/WeaponVisual")
	# these numbers were measured with the Grip at 0,0; the scene's Grip may be dragged, so test a copy of the model with Grip 0
	var wd: WeaponData = wv.weapon.duplicate()
	var txt := FileAccess.get_file_as_string(wd.model.resource_path)
	var gi := txt.find('[node name="MainHandGrip"')
	var pi := txt.find("position = Vector2(", gi)
	if gi >= 0 and pi >= 0:
		var f := FileAccess.open("user://geo_grip0.tscn", FileAccess.WRITE)
		f.store_string(txt.substr(0, pi) + "position = Vector2(0, 0)" + txt.substr(txt.find("\n", pi)))
		f.close()
		wd.model = ResourceLoader.load("user://geo_grip0.tscn", "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		wv.weapon = wd
		await process_frame
	var blade = wv.get_model().get_node("Art")
	var hb_shape = wv.get_model().get_node("Hitbox/CollisionShape2D")

	var ok := true
	var shape_ok: bool = hb_shape.shape.size.is_equal_approx(EXPECTED_SHAPE_SIZE)
	print("hitbox shape size: %s (want %s): %s" % [hb_shape.shape.size, EXPECTED_SHAPE_SIZE, shape_ok])
	ok = ok and shape_ok

	for dir_name in ["right", "up-left", "down"]:
		var dir: Vector2
		match dir_name:
			"right": dir = Vector2.RIGHT
			"up-left": dir = Vector2(-1, -1).normalized()
			"down": dir = Vector2.DOWN
		wv.set_aim_angle(dir.angle())
		await physics_frame
		await process_frame
		var bt = blade.global_transform
		var ht = hb_shape.global_transform
		var want: Dictionary = EXPECTED[dir_name]

		# 0049+: the PICTURE was replaced (new art, grip on the origin), so only the Hitbox is pinned now.
		var blade_pos_ok := true
		var blade_rot_ok := true
		var blade_scale_ok := true
		var hit_pos_ok: bool = ht.origin.distance_to(want["hit_pos"]) <= POS_TOL
		var hit_rot_ok: bool = absf(angle_difference(ht.get_rotation(), want["hit_rot"])) <= ROT_TOL
		var hit_scale_ok: bool = is_equal_approx(ht.get_scale().y, want["hit_scale_y"])

		var dir_ok: bool = blade_pos_ok and blade_rot_ok and blade_scale_ok and hit_pos_ok and hit_rot_ok and hit_scale_ok
		print("[%s] blade pos %s rot %.6f scale.y %.6f | hitbox pos %s rot %.6f scale.y %.6f : %s" % [
			dir_name, bt.origin, bt.get_rotation(), bt.get_scale().y,
			ht.origin, ht.get_rotation(), ht.get_scale().y, dir_ok])
		ok = ok and dir_ok

	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
