class_name ArenaMapBuild
extends RefCounted
## ArenaMap helper: world-wide build steps (coast water bodies, island terrain hookup). Moved out of arena_map.gd unchanged.


static func _build_water_body(m: ArenaMap) -> void:
	for c in m._water_body.get_children():
		m._water_body.remove_child(c)
		c.queue_free()
	# One rectangle per run of coast water (water touching land, 8 neighbours) in a row.
	var cols := m.result.cols
	var rows := m.result.rows
	var land := m.result.walk_land   # walkable ground (dry + shallow): only the deep water blocks
	var cell := m.cell_px()
	# land spread by one cell sideways, then up and down (the 3 x 3 neighbourhood); coast = that, where there is no land
	var wide := PackedByteArray()
	wide.resize(cols * rows)
	for y in rows:
		for i in range(y * cols, y * cols + cols):
			if land[i] == 1:
				wide[i] = 1
				if i % cols > 0:
					wide[i - 1] = 1
				if i % cols < cols - 1:
					wide[i + 1] = 1
	for y in rows:
		var x0 := -1
		for x in cols + 1:
			var i := y * cols + x
			var coast := false
			if x < cols and land[i] == 0:
				coast = wide[i] == 1 or (y > 0 and wide[i - cols] == 1) or (y < rows - 1 and wide[i + cols] == 1)
			if coast and x0 < 0:
				x0 = x
			elif not coast and x0 >= 0:
				var shape := RectangleShape2D.new()
				shape.size = Vector2((x - x0) * cell, cell)
				var cs := CollisionShape2D.new()
				cs.shape = shape
				cs.position = Vector2((x0 + x) * 0.5 * cell, (y + 0.5) * cell)
				m._water_body.add_child(cs)
				x0 = -1


## The island ground, once per map: the water under everything and the style hooks. The ground pictures themselves are made per
## chunk (ChunkStreamer -> GroundBaker.bake_region -> TerrainVisual.set_chunk).
static func _setup_island_terrain(m: ArenaMap) -> void:
	if m.style.pixel_plains != null and not m.style.pixel_plains.changed.is_connected(m._on_pp_changed):
		m.style.pixel_plains.changed.connect(m._on_pp_changed)
	for b in m.style.biomes:   # an edited BiomeData (F3): climate / ground / tree fields rebuild the map, look fields only re-tint
		if not b.changed.is_connected(m._changed):
			b.changed.connect(m._changed)
			b.look_changed.connect(m._on_biome_look)
	var t := float(GroundBaker.tile_of(m.style))
	var shallow_img: Image = null
	if not m.result.shallow.is_empty():
		var mask := m.result.shallow.duplicate()   # 255 = shallow: full precision for the linear filter
		var at := mask.find(1)
		while at >= 0:
			mask[at] = 255
			at = mask.find(1, at + 1)
		shallow_img = Image.create_from_data(m.result.cols, m.result.rows, false, Image.FORMAT_L8, mask)
	m._terrain.begin_island(null, Vector2(m.result.cols + 1, m.result.rows + 1) * t, float(m.style.pixel_scale), shallow_img, t,
		m.style.pixel_plains.shader_params() if m.style.pixel_plains != null else {})
	m._apply_terrain_look()
