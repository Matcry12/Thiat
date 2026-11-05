extends SceneTree
# Decision 0060: item pictures are cropped to their visible pixels and centred in the icon box; their size does not change.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

## `size` x `size` transparent picture with an opaque w x h block at `at`.
func _tex(size: int, at: Vector2i, w: int, h: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(at, Vector2i(w, h)), Color.WHITE)
	return ImageTexture.create_from_image(img)

func _item(tex: Texture2D, id: String) -> ItemData:
	var it := ItemData.new()
	it.id = StringName(id)
	it.display_name = id
	it.icon = tex
	return it

func _init() -> void:
	var t := _tex(32, Vector2i(20, 3), 8, 6)
	var c := ItemIcon.crop(t)
	_check(c.get_size() == Vector2(8, 6) and c is AtlasTexture and (c as AtlasTexture).filter_clip, "crop: 8x6 AtlasTexture, filter_clip")
	_check(ItemIcon.crop(t) == c, "crop is cached")
	var at := AtlasTexture.new()
	at.atlas = _tex(64, Vector2i(40, 36), 5, 7)   # block sits inside the region (32,32)-(64,64)
	at.region = Rect2(32, 32, 32, 32)
	var ca := ItemIcon.crop(at) as AtlasTexture
	_check(ca.get_size() == Vector2(5, 7) and ca.atlas == at.atlas and ca.region.position == Vector2(40, 36), "crop of an AtlasTexture: no nesting, region offset")
	_check(ItemIcon.crop(null) == null, "null stays null")
	var blank := _tex(16, Vector2i.ZERO, 0, 0)
	_check(ItemIcon.crop(blank) == blank, "fully transparent: unchanged")

	var skin := load("res://data/ui/inventory_skin.tres") as InventorySkin
	var slot: ItemSlot = load("res://scenes/ui/item_slot.tscn").instantiate()
	root.add_child(slot)
	slot.skin = skin
	await process_frame
	slot.set_item(_item(t, "a"), 1)
	slot.refresh()
	await process_frame
	var ic: TextureRect = slot.get_node("Icon")
	var box := Rect2(slot.global_position + Vector2(slot._box.x, slot._box.y), slot.size - Vector2(slot._box.x - slot._box.z, slot._box.y - slot._box.w))
	var rc := ic.get_global_rect()
	_check(rc.get_center().distance_to(box.get_center()) <= 1.0, "icon centred in the box (%s vs %s)" % [rc.get_center(), box.get_center()])
	_check(rc.size == Vector2(8, 6), "32 px file: 1x, size unchanged (%s)" % [rc.size])
	# 16 px file 2x, 32 px file 1x, as always; margins never move the centre
	for pair: Array in [[_tex(16, Vector2i(1, 1), 6, 7), Vector2(12, 14)], [_tex(32, Vector2i(20, 2), 12, 14), Vector2(12, 14)], [_tex(32, Vector2i(0, 0), 12, 14), Vector2(12, 14)]]:
		slot.set_item(_item(pair[0], "b%d" % pair[0].get_rid().get_id()), 1)
		slot.refresh()
		var r := ic.get_global_rect()
		_check(r.size == pair[1], "size from the file scale (%s)" % [r.size])
		_check(r.get_center().distance_to(box.get_center()) <= 1.0, "margins do not move the centre")
	# item -> symbol picture restores the full box
	slot.set_picture(t, Color.RED)
	slot.refresh()
	_check(is_equal_approx(ic.offset_left, slot._box.x) and is_equal_approx(ic.offset_right, slot._box.z) and ic.texture == t, "set_picture: full box, uncropped")
	_check(ic.anchor_right == 1.0 and ic.anchor_bottom == 1.0, "set_picture: full-rect anchors back")
	slot.set_item(_item(blank, "c"), 1)
	slot.set_item(null, 0)
	slot.refresh()
	slot.set_item(_item(blank, "d"), 1)
	slot.refresh()
	_check(ic.visible and ic.texture == blank, "blank picture: shown unchanged, no crash")
	slot.free()
	# a fresh slot refreshed right after add_child (book / tooltip ingredients): `size` is still 0 then
	var f: ItemSlot = load("res://scenes/ui/item_slot.tscn").instantiate()
	f.size_override = 32
	f.bare = true
	f.skin = skin
	f.set_item(_item(_tex(32, Vector2i(10, 8), 12, 9), "wood"), 1)
	root.add_child(f)
	f.refresh()
	await process_frame
	await process_frame
	var fi: TextureRect = f.get_node("Icon")
	var fr := fi.get_global_rect()
	_check(fr.size == Vector2(12, 9), "fresh bare slot: not stretched (%s in 32 px)" % [fr.size])
	_check(fr.get_center().distance_to(f.get_global_rect().get_center()) <= 1.0, "fresh bare slot: centred (%s vs %s)" % [fr.get_center(), f.get_global_rect().get_center()])
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
