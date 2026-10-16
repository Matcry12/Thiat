class_name Station
extends StaticBody2D
## A placed crafting station (workbench, furnace, anvil; decision 0031): solid body + `CraftStation` +
## `Visual` (the art, or a coloured box until there is art). Placed by the Placer. A hit with a PICKAXE
## picks it back up (the item returns to the inventory, a furnace's contents too; nothing is ever lost).
## Art = `art` + `art_region` (a rect on the Pixel Crawler sheet) + `pixel_scale`; replacing it is a data
## change. The scene's CollisionShape2D is the one owner of the size (`footprint()` reads it), never the picture.

signal picked_up

@export var art: Texture2D
@export var art_region := Rect2()
@export var pixel_scale := 2
@export var color := Color(0.6, 0.45, 0.3)      ## placeholder box while `art` is empty
@export var pickup_lockout := 0.5              ## s after a pickup in which no other station can be picked up

## What you get back on pickup (set by the Placer). Plain var: code-owned.
var item: ItemData
var outline: Line2D       ## ghost only: the 1 px box the Placer colours green / red

## True = a ghost preview: no collision, no CraftStation, no Furnace (set before add_child).
var ghost := false

func _ready() -> void:
	add_to_group("station")
	var cs := get_node("CollisionShape2D") as CollisionShape2D
	_build_art()
	if ghost:
		remove_from_group("station")
		collision_layer = 0
		cs.disabled = true
		get_node("Hurtbox").monitorable = false
		for n in ["CraftStation", "Furnace"]:
			var c := get_node_or_null(n)
			if c:
				remove_child(c)
				c.queue_free()
		var fp := footprint()
		outline = Line2D.new()
		outline.name = "GhostOutline"
		outline.width = 1.0
		outline.z_index = 1
		outline.points = PackedVector2Array([-fp * 0.5, Vector2(fp.x, -fp.y) * 0.5, fp * 0.5, Vector2(-fp.x, fp.y) * 0.5, -fp * 0.5])
		add_child(outline)

## Solid body AND the area the Placer keeps free, px: the size of the scene's CollisionShape2D.
func footprint() -> Vector2:
	return ((get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size

func _build_art() -> void:
	var fp := footprint()
	var a := get_node("Visual/Art") as Sprite2D
	var ph := get_node("Visual/Placeholder") as ColorRect
	if art != null and art_region.has_area():
		var atlas := AtlasTexture.new()
		atlas.atlas = art
		atlas.region = art_region
		a.texture = atlas
		a.centered = false
		a.scale = Vector2.ONE * pixel_scale
		a.position = Vector2(-art_region.size.x * pixel_scale * 0.5, fp.y * 0.5 - art_region.size.y * pixel_scale)
		a.visible = true
		ph.visible = false
	else:
		a.visible = false
		ph.visible = true
		ph.color = color
		ph.position = -fp * 0.5
		ph.size = fp

## The picture's box relative to the station's centre (the footprint box while there is no art).
func art_rect_local() -> Rect2:
	var a := get_node("Visual/Art") as Sprite2D
	if art != null and art_region.has_area():
		return Rect2(Vector2(-art_region.size.x * pixel_scale * 0.5, footprint().y * 0.5 - art_region.size.y * pixel_scale), art_region.size * pixel_scale)
	return Rect2(-footprint() * 0.5, footprint())

## Top of the picture, local px (the furnace cue sits above it).
func art_top() -> float:
	var a := get_node("Visual/Art") as Sprite2D
	return a.position.y if a.visible else -footprint().y * 0.5

func craft_station() -> CraftStation:
	return get_node_or_null("CraftStation") as CraftStation

func furnace() -> Furnace:
	return get_node_or_null("Furnace") as Furnace

## Pickaxe hit = pick it up. Anything else does nothing (a punch must not undo your base). One swing takes
## ONE station: of everything the swing reaches in the same frame the nearest to you wins, and for
## `pickup_lockout` seconds after a pickup no other station can be taken (the swing keeps polling for 5 frames).
func take_gather_hit(weapon: WeaponData, source: Node2D) -> bool:
	if weapon == null or weapon.tool_kind != &"pickaxe" or ghost:
		return false
	var tree := get_tree()
	if Time.get_ticks_msec() < int(tree.get_meta("station_lock_msec", 0)):
		return false
	var hits: Array = tree.get_meta("station_hits", [])
	if hits.is_empty():   # a one-shot on the TREE (not on this node): a station freed before it fires cannot jam it
		tree.process_frame.connect(func(): Station._resolve_hits(tree), CONNECT_ONE_SHOT)
	hits.append([self, source])
	tree.set_meta("station_hits", hits)
	return true

static func _resolve_hits(tree: SceneTree) -> void:
	var hits: Array = tree.get_meta("station_hits", [])
	tree.set_meta("station_hits", [])
	var best: Station
	var best_src: Node2D
	for h in hits:
		if is_instance_valid(h[0]) and is_instance_valid(h[1]) and (best == null or h[0].global_position.distance_to(h[1].global_position) < best.global_position.distance_to(best_src.global_position)):
			best = h[0]
			best_src = h[1]
	if best == null:
		return
	# `source` is the weapon model (the Hitbox lives in it), not the player: bank into the player's inventory.
	var player := tree.get_first_node_in_group("player")
	var inv := player.get_node_or_null("Inventory") as Inventory if player else null
	if inv == null:
		return   # nobody to give it to: it stays standing, contents and all
	tree.set_meta("station_lock_msec", Time.get_ticks_msec() + int(best.pickup_lockout * 1000.0))
	best.pick_up(inv)

func pick_up(inv: Inventory) -> void:
	if is_queued_for_deletion():
		return   # two rebuilds in one frame must not hand the item over twice
	if inv == null:
		return   # never free a station without somewhere to put what is inside
	var f := furnace()
	if f:
		for pair in [f.take_input(), f.take_output()]:
			if pair[0] != null and pair[1] > 0:
				inv.give_or_drop(pair[0], pair[1])
	if item != null:
		inv.give_or_drop(item, 1)
	picked_up.emit()
	queue_free()
