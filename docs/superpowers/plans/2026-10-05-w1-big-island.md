# W1 Big Island Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Grow the arena generator into one big seeded island: water edge, three areas (forest near home,
rocky, boss area far away), a home point, the boss moved far away, and the camera and build time still fine
on the big map.

**Architecture:** `MapGen` (pure logic) gets two new per-cell layers in its `Result`: `land` (island mask
from radial falloff + noise, cut to the part connected to home) and `area` (forest / rocky / boss by distance
from home, with a noise wobble). Every existing step (ground, dirt patches, rocks, deco, border) reads them.
`ArenaMap` (nodes) draws water, builds water collision from the coast cells, places a `HomePoint`, and
exposes `area_at(pos)` and `home_point()` for later slices. `Params.island_on` defaults to **false**, so every
old test that builds `Params` by hand keeps the old map; `ArenaMap.island_on` defaults to **true**.

**Tech Stack:** Godot 4.7, GDScript. Tests: `extends SceneTree` scripts, run by `tools/run_tests.sh`.

**Spec:** [docs/wiki/v1-design.md](../../wiki/v1-design.md) §3 World and §11 row W1;
decision [0025](../../decision/0025-v1-open-world.md); generator decision [0021](../../decision/0021-procedural-arena.md);
leash [0022](../../decision/0022-boss-leash.md).

## Global Constraints

- Same seed + same exports = exactly the same island (v1-design §3 "same seed = same island").
- Size "~8–10x today's arena": default **200 x 120 cells** (6400 x 3840 px; 8.3x the 72 x 40 map). Starting value, tune in F3.
- Edge = water. The player can never walk into water or off the map.
- Areas, by distance from home: forest (grass, near home) → rocky (stone/dirt) → boss area (dark/special, far).
- Home point (campfire) at the player start. In W1 it is only a marker (respawn is W6).
- Resources do not exist yet (W2). Rocks in W1 are still plain obstacles.
- CLAUDE.md §5: art lives in `MapStyle` (`.tres`). No tile coordinate in GDScript. Water and area ground are style slots; empty slot = placeholder look.
- CLAUDE.md §7: every number is an `@export` on `ArenaMap` (shows in F3). New state shows in the F3 `[Map]` status. Test mode trigger: `Go home` / `Go to boss` buttons (the walk is long).
- Godot rule: never edit `.godot/`, `*.import`, `*.uid`. Hand-edited `.tscn` keeps `format=3` and node paths.
- Every `.gd` edit is parse-checked by the PostToolUse hook; also run `godot --headless --quit` to boot.
- Full suite stays green: `tools/run_tests.sh` → `0 failing`.

## Review Focus

1. **A seed where the island splits or the boss zone lands in water** → the player must still be able to walk from home to the boss. Test: seeds 1..40 all pass `floor_reachable` with water, and home and zone cells are land.
2. **F3 slider rebuild on the big map** (e.g. dragging `deco_density`) → must not freeze for seconds. Test: generate + build time printed and kept under the budget (Task 5).
3. **Walking into the coast at an angle or in a corner** → the player stops at the shore, never on a water tile. Test: drive the player into the coast in Task 3.
4. **A rock or a tree-like deco sprite placed on water or half over the coast** → never. Test: every rock circle and deco point is on land, rocks with clearance (Task 2).
5. **Turning the island off (`island_on = false`) or the old 36 x 21 / 72 x 40 maps** → behave exactly like before (old tests, demos, ClassicArena). Test: the existing suite unchanged except the tests that pinned the old defaults (Task 3).

---

## File structure

| File | Change | Responsibility |
|---|---|---|
| `scripts/map/map_gen.gd` | modify | island mask, areas, everything else respects them; water-aware `floor_reachable`; deco grid |
| `scripts/map/map_style.gd` | modify | new art slots: `rocky_fills`, `boss_fills`, `water_texture`, `water_fills` |
| `data/maps/grass.tres` | modify | fill the new slots (placeholders allowed) |
| `scripts/map/arena_map.gd` | modify | island exports, big defaults, water layer + collision, `area_at`, `home_point`, teleports, status |
| `scenes/arena.tscn` | modify | `Ground/Water` TileMapLayer, water-blue Background, `HomePoint` instance |
| `scripts/world/home_point.gd`, `scenes/world/home_point.tscn` | create | campfire marker with a swappable `Visual` |
| `scripts/debug/tuning_panel.gd` | modify | range overrides, `Go home` / `Go to boss` buttons |
| `tests/support/classic_arena.gd` | modify | `island_on = false` |
| `tests/test_island_gen.gd` | create | pure MapGen island tests |
| `tests/test_island_arena.gd` | create | scene tests: water blocks, areas, home, teleports, timing |
| `tests/test_map_size.gd`, `tests/test_arena_map.gd` | modify | pin the old 72 x 40 non-island map where they assert old numbers |
| `tools/demo/demo_bot.gd` | modify | `island` scenario |
| `docs/decision/0026-island-generator.md` | create | decision record |
| `docs/wiki/v1-design.md`, `CLAUDE.md` | modify | slice log, F3 row |

---

### Task 1: Island mask and areas in MapGen

**Files:**
- Modify: `scripts/map/map_gen.gd` (consts l.10-15, `Params` l.18-41, `Result` l.44-52, `generate` l.55)
- Test: `tests/test_island_gen.gd` (create)

**Interfaces:**
- Produces:
  - `enum MapGen.Area { FOREST, ROCKY, BOSS }`
  - `const MapGen.WATER := 3` (a fourth cell kind, used in Task 2)
  - `Params`: `island_on := false`, `island_noise_frequency := 0.035`, `island_noise := 0.3`, `island_falloff := 2.0`, `island_threshold := 0.15`, `coast_cells := 3`, `home_clear_cells := 6`, `corridor_half := 2`, `forest_end := 0.45`, `rocky_end := 0.8`, `area_wobble := 0.12`
  - `Result.land: PackedByteArray` (1 = land, 0 = water, index `y * cols + x`), `Result.area: PackedByteArray` (`Area` value; water cells hold `FOREST` and must be ignored)
  - `static func cell_index(p: Params, c: Vector2i) -> int` (-1 if off the grid)
  - `static func is_land(res: Result, p: Params, c: Vector2i) -> bool` (false off the grid)
  - `static func zone_cells(p: Params) -> Rect2i` (zone rect in cells, grown by 3)

- [ ] **Step 1: Write the failing test** — `tests/test_island_gen.gd`

```gdscript
extends SceneTree
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _params() -> MapGen.Params:
	var p := MapGen.Params.new()
	p.cols = 200
	p.rows = 120
	p.cell = 32.0
	p.world = Vector2(200, 120) * 32.0
	p.island_on = true
	p.player_spawn = Vector2(0.12 * p.world.x, 0.5 * p.world.y)
	p.zone = Rect2(Vector2(0.86 * p.world.x, 0.5 * p.world.y) - Vector2(440, 230), Vector2(880, 460))
	p.spawns = PackedVector2Array([p.player_spawn])
	p.obstacle_count = 190
	p.patch_count = 120
	return p

func _connected_land(res: MapGen.Result, p: MapGen.Params) -> bool:
	var start := Vector2i(p.player_spawn / p.cell)
	var seen := PackedByteArray()
	seen.resize(p.cols * p.rows)
	var stack: Array[Vector2i] = [start]
	seen[MapGen.cell_index(p, start)] = 1
	var reached := 1
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + d
			var i := MapGen.cell_index(p, q)
			if i >= 0 and res.land[i] == 1 and seen[i] == 0:
				seen[i] = 1
				reached += 1
				stack.append(q)
	var total := 0
	for v in res.land:
		total += v
	return reached == total

func _init() -> void:
	var style: MapStyle = load("res://data/maps/grass.tres")
	var p := _params()
	var a := MapGen.generate(style, p, 7)
	var b := MapGen.generate(style, p, 7)
	var c := MapGen.generate(style, p, 8)
	_check(a.land == b.land and a.area == b.area, "same seed = same island")
	_check(a.land != c.land, "different seed = different island")
	_check(a.land.size() == 200 * 120 and a.area.size() == 200 * 120, "one land + one area value per cell")

	var edge_water := true
	for x in p.cols:
		for y in [0, p.coast_cells - 1, p.rows - 1]:
			edge_water = edge_water and not MapGen.is_land(a, p, Vector2i(x, y))
	for y in p.rows:
		for x in [0, p.cols - 1]:
			edge_water = edge_water and not MapGen.is_land(a, p, Vector2i(x, y))
	_check(edge_water, "the map edge is water")

	var land_count := 0
	for v in a.land:
		land_count += v
	var share := float(land_count) / a.land.size()
	_check(share > 0.35 and share < 0.85, "island is most of the map but not all of it (%.2f)" % share)

	var home := Vector2i(p.player_spawn / p.cell)
	var zc := Vector2i(p.zone.get_center() / p.cell)
	var all_ok := true
	for s in range(1, 41):
		var r := MapGen.generate(style, p, s)
		var ok: bool = MapGen.is_land(r, p, home) and MapGen.is_land(r, p, zc) and _connected_land(r, p)
		if not ok:
			print("  seed %d: home/zone/connected failed" % s)
		all_ok = all_ok and ok
	_check(all_ok, "seeds 1..40: home and zone are land, all land connected to home")

	_check(a.area[MapGen.cell_index(p, home)] == MapGen.Area.FOREST, "home is in the forest")
	_check(a.area[MapGen.cell_index(p, zc)] == MapGen.Area.BOSS, "the fight zone is in the boss area")
	var counts := [0, 0, 0]
	for i in a.land.size():
		if a.land[i] == 1:
			counts[a.area[i]] += 1
	_check(counts[0] > 0 and counts[1] > 0 and counts[2] > 0, "all three areas exist %s" % [counts])

	var q := _params()
	q.island_on = false
	var flat := MapGen.generate(style, q, 7)
	var all_land := true
	for v in flat.land:
		all_land = all_land and v == 1
	_check(all_land, "island_on = false: every cell is land (old map)")

	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
```

- [ ] **Step 2: Run it, expect FAIL**

Run: `godot --headless --script tests/test_island_gen.gd`
Expected: parse error / FAIL (`island_on`, `cell_index`, `land` don't exist).

- [ ] **Step 3: Implement** — in `scripts/map/map_gen.gd`

Add next to the other consts:

```gdscript
const WATER := 3          ## fourth cell kind: no ground tile, water shows
enum Area { FOREST, ROCKY, BOSS }
```

Add to `Params` (after `player_spawn`):

```gdscript
	var island_on := false            ## false = the old flat map (every cell land, one area)
	var island_noise_frequency := 0.035
	var island_noise := 0.3           ## how ragged the coast is
	var island_falloff := 2.0         ## higher = land reaches further to the edges
	var island_threshold := 0.15      ## higher = smaller island
	var coast_cells := 3              ## this many cells at the map edge are always water
	var home_clear_cells := 6         ## land disc around home, always
	var corridor_half := 2            ## half width of the land bridge carved when home and boss are cut apart
	var forest_end := 0.45            ## area by distance home -> boss (0 = home, 1 = boss)
	var rocky_end := 0.8
	var area_wobble := 0.12           ## noise on the area borders, so they are not circles
```

Add to `Result`:

```gdscript
	var land := PackedByteArray()            ## 1 land, 0 water, per cell
	var area := PackedByteArray()            ## Area per cell (ignore on water)
```

In `generate`, call `_shape_island(res, p)` right after `res.seed = rng_seed` (before `_place_patches`).

Add this section after `_n01`:

```gdscript
# ------------------------------------------------------------------- island ---

static func cell_index(p: Params, c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= p.cols or c.y >= p.rows:
		return -1
	return c.y * p.cols + c.x


static func is_land(res: Result, p: Params, c: Vector2i) -> bool:
	var i := cell_index(p, c)
	return i >= 0 and res.land[i] == 1


static func zone_cells(p: Params) -> Rect2i:
	var a := Vector2i((p.zone.position / p.cell).floor())
	var b := Vector2i((p.zone.end / p.cell).ceil())
	return Rect2i(a, b - a).grow(3)


## Fills res.land and res.area. Shape = radial falloff + noise; then only the land connected to home
## is kept, and a bridge is carved if the boss zone is cut off.
static func _shape_island(res: Result, p: Params) -> void:
	var n := p.cols * p.rows
	res.land.resize(n)
	res.area.resize(n)
	res.area.fill(Area.FOREST)
	if not p.island_on:
		res.land.fill(1)
		return
	res.land.fill(0)
	var noise := _noise(res.seed + 3, p.island_noise_frequency)
	var home := Vector2i(p.player_spawn / p.cell)
	var zc := zone_cells(p)
	for y in p.rows:
		for x in p.cols:
			if x < p.coast_cells or y < p.coast_cells or x >= p.cols - p.coast_cells or y >= p.rows - p.coast_cells:
				continue
			var c := Vector2i(x, y)
			var d := Vector2(float(x) / (p.cols - 1) * 2.0 - 1.0, float(y) / (p.rows - 1) * 2.0 - 1.0).length()
			var v := 1.0 - pow(d, p.island_falloff) + (_n01(noise, x, y) - 0.5) * 2.0 * p.island_noise
			if v > p.island_threshold or Vector2(c).distance_to(Vector2(home)) <= p.home_clear_cells or zc.has_point(c):
				res.land[y * p.cols + x] = 1
	if not _flood_land(res, p, home).has(zc.get_center()):
		_carve(res, p, home, zc.get_center())
	var keep := _flood_land(res, p, home)
	for i in n:
		if res.land[i] == 1 and not keep.has(Vector2i(i % p.cols, i / p.cols)):
			res.land[i] = 0      # islands cut off from home: drop them
	_assign_areas(res, p, home, zc)


## Land cells reachable from `from` (4-neighbour). Returns a set (Dictionary cell -> true).
static func _flood_land(res: Result, p: Params, from: Vector2i) -> Dictionary:
	var seen := {}
	if not is_land(res, p, from):
		return seen
	var stack: Array[Vector2i] = [from]
	seen[from] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + d
			if is_land(res, p, q) and not seen.has(q):
				seen[q] = true
				stack.append(q)
	return seen


## A straight land bridge, (2 * corridor_half + 1) cells wide. Never touches the coast_cells rim.
static func _carve(res: Result, p: Params, a: Vector2i, b: Vector2i) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for s in steps + 1:
		var c := Vector2i(Vector2(a).lerp(Vector2(b), float(s) / maxf(steps, 1)).round())
		for dy in range(-p.corridor_half, p.corridor_half + 1):
			for dx in range(-p.corridor_half, p.corridor_half + 1):
				var q := c + Vector2i(dx, dy)
				if q.x >= p.coast_cells and q.y >= p.coast_cells and q.x < p.cols - p.coast_cells and q.y < p.rows - p.coast_cells:
					res.land[q.y * p.cols + q.x] = 1


static func _assign_areas(res: Result, p: Params, home: Vector2i, zc: Rect2i) -> void:
	var noise := _noise(res.seed + 4, p.island_noise_frequency * 2.0)
	var span := maxf(Vector2(home).distance_to(Vector2(zc.get_center())), 1.0)
	for y in p.rows:
		for x in p.cols:
			var i := y * p.cols + x
			if res.land[i] == 0:
				continue
			var t := Vector2(home).distance_to(Vector2(x, y)) / span + (_n01(noise, x, y) - 0.5) * 2.0 * p.area_wobble
			var a := Area.FOREST if t < p.forest_end else (Area.ROCKY if t < p.rocky_end else Area.BOSS)
			if zc.has_point(Vector2i(x, y)):
				a = Area.BOSS
			res.area[i] = a
```

Note `_shape_island` reads `res.seed`, so `res.seed = rng_seed` must be set before the call (it already is, l.57).

- [ ] **Step 4: Run, expect PASS**

Run: `godot --headless --script tests/test_island_gen.gd`
Expected: all `ok`, `PASS`. If "island share" fails, tune only the `Params` defaults (`island_threshold`, `island_falloff`), not the test bounds. Then `tools/run_tests.sh` → `0 failing` (the flat map is untouched: `island_on` defaults to false).

- [ ] **Step 5: Commit**

```bash
git add scripts/map/map_gen.gd tests/test_island_gen.gd
git commit -m "feat(map): island mask and areas in MapGen (W1)"
```

---

### Task 2: Ground, patches, rocks and deco respect the island

**Files:**
- Modify: `scripts/map/map_gen.gd` (`generate`, `_place_patches` l.83, `_assign_ground` l.107, `_place_obstacles` l.171, `_obstacle_legal` l.192, `floor_reachable` l.212, `_place_deco` l.256, `_place_border` l.301)
- Modify: `scripts/map/map_style.gd`, `data/maps/grass.tres`
- Test: `tests/test_island_gen.gd` (extend)

**Interfaces:**
- Consumes: Task 1 (`land`, `area`, `Area`, `WATER`, `is_land`, `cell_index`).
- Produces:
  - `MapStyle`: `@export var rocky_fills: Array[Vector2i] = []`, `@export var boss_fills: Array[Vector2i] = []` (empty → fall back to `dirt_fills`), `@export var water_texture: Texture2D`, `@export var water_fills: Array[Vector2i] = []` (empty → no water tiles; the water-blue Background shows).
  - `Result.water: Dictionary` (Vector2i cell → atlas coord on `water_texture`; empty when no water art).
  - `Result.kind[i] == WATER` on every water cell. `res.dirt` has **no entry** for water cells.
  - `static func floor_reachable(p: Params, obstacles: Array[Dictionary], land := PackedByteArray()) -> bool` (empty `land` = all land, old behaviour).
  - `static func rock_clearance(p: Params) -> float` = `p.agent_radius * 2.0 + 4.0`.

- [ ] **Step 1: Extend the test** — add before the final `print` in `tests/test_island_gen.gd`:

```gdscript
	# --- Task 2: everything sits on land ---
	var on_land := true
	for o in a.obstacles:
		var r: float = o["radius"] + MapGen.rock_clearance(p)
		for dy in [-r, 0.0, r]:
			for dx in [-r, 0.0, r]:
				on_land = on_land and MapGen.is_land(a, p, Vector2i((o["pos"] + Vector2(dx, dy)) / p.cell))
	_check(on_land and a.obstacles.size() > 50, "rocks on land, clear of water (%d rocks)" % a.obstacles.size())
	var deco_ok := true
	for d in a.deco:
		deco_ok = deco_ok and MapGen.is_land(a, p, Vector2i(d["pos"] / p.cell))
	_check(deco_ok and a.deco.size() > 100, "deco on land (%d)" % a.deco.size())
	var patches_ok := true
	for r in a.patches:
		for y in range(r.position.y - 1, r.end.y + 1):
			for x in range(r.position.x - 1, r.end.x + 1):
				var i := MapGen.cell_index(p, Vector2i(x, y))
				patches_ok = patches_ok and i >= 0 and a.land[i] == 1 and a.area[i] == MapGen.Area.FOREST
	_check(patches_ok, "dirt patches (and their ring) only in forest land")
	var ground_ok := true
	for i in a.land.size():
		var cell := Vector2i(i % p.cols, i / p.cols)
		if a.land[i] == 0:
			ground_ok = ground_ok and a.kind[i] == MapGen.WATER and not a.dirt.has(cell) and not a.grass.has(cell)
		elif a.area[i] != MapGen.Area.FOREST:
			ground_ok = ground_ok and a.dirt.has(cell) and not a.grass.has(cell)
	_check(ground_ok, "water cells have no ground; rocky and boss cells have no grass")
	_check(a.border.is_empty(), "no wall bushes on the island (the water is the edge)")
	var reach_ok := true
	for s in [1, 2, 3, 4, 5]:
		var r := MapGen.generate(style, p, s)
		reach_ok = reach_ok and MapGen.floor_reachable(p, r.obstacles, r.land)
	_check(reach_ok, "seeds 1..5: all walkable land reachable from home, rocks and water included")
	_check(not flat.land.is_empty() and MapGen.floor_reachable(q, flat.obstacles), "flat map still reachable (old call)")
```

- [ ] **Step 2: Run, expect FAIL** — `godot --headless --script tests/test_island_gen.gd` → FAIL (`rock_clearance` missing, ground on water).

- [ ] **Step 3: Implement**

**3a. `scripts/map/map_style.gd`** — add after `grass_dark_fills`:

```gdscript
## Island areas (v1, decision 0026). Empty = use dirt_fills (placeholder look).
@export var rocky_fills: Array[Vector2i] = []
@export var boss_fills: Array[Vector2i] = []
## Water art: its own sheet. Empty water_fills = no water tiles, the Background colour shows.
@export var water_texture: Texture2D
@export var water_fills: Array[Vector2i] = []
```

**3b. `data/maps/grass.tres`** — placeholders that need no new art:
- `boss_fills = [Vector2i(1, 11), Vector2i(2, 11), Vector2i(3, 11)]` (the dark grass, drawn on the dirt layer).
- `rocky_fills`: open `docs/wiki/img/ground-floors.png` (preview of `Floors_Tiles.png`) with the Read tool. If there is a plain grey stone / cobble fill row of 16 px tiles, put its 2–3 coords here and add the coords to the `Floors_Tiles` row in `docs/wiki/ground-tiles.md`. If unsure, leave it empty (dirt shows). Verify the choice in the Task 6 screenshot.
- `water_texture` / `water_fills`: open `docs/wiki/img/ground-water*.png`. If `Water_tiles.png` has a plain full-water 16 px tile, copy `assets/third_party/pixel_crawler/Environment/Tilesets/Water_tiles.png` to `assets/map/Water_tiles.png` (the editor imports it on the next `godot --headless --quit`), set `water_texture` to it and `water_fills` to that coord. Otherwise leave both empty.

**3c. `generate`** — same order; every step reads `res.land` / `res.area`; the border is skipped on the island:

```gdscript
	_shape_island(res, p)
	_place_patches(res, p, rng, noise)
	_assign_ground(res, style, p, rng)
	_place_obstacles(res, style, p, rng)
	_place_deco(res, style, p, rng, _noise(rng_seed + 2, p.noise_frequency))
	if not p.island_on:
		_place_border(res, style, p, rng)   # on the island the water is the edge
```

**3d. `_place_patches`** — after the noise-threshold `continue`, reject patches whose ring leaves forest land:

```gdscript
		if not _all_forest_land(res, p, r.grow(1)):
			continue
```

and add:

```gdscript
static func _all_forest_land(res: Result, p: Params, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := cell_index(p, Vector2i(x, y))
			if i < 0 or res.land[i] == 0 or res.area[i] != Area.FOREST:
				return false
	return true
```

**3e. `_assign_ground`** — water and non-forest cells get no grass, area-specific dirt, none on water:
- After `res.kind.fill(FILL)`, mark water: `for i in res.land.size(): if res.land[i] == 0: res.kind[i] = WATER`.
- In the `fills` loop, only add cells where `res.kind[i] == FILL` **and** `res.area[i] == Area.FOREST` (non-special cells of other areas get no grass).
- Replace the final dirt loop with:

```gdscript
	for y in p.rows:
		for x in p.cols:
			var i := y * p.cols + x
			if res.land[i] == 0:
				if not style.water_fills.is_empty():
					res.water[Vector2i(x, y)] = style.water_fills[rng.randi() % style.water_fills.size()]
				continue
			var pool: Array[Vector2i] = style.dirt_fills
			if res.area[i] == Area.ROCKY and not style.rocky_fills.is_empty():
				pool = style.rocky_fills
			elif res.area[i] == Area.BOSS and not style.boss_fills.is_empty():
				pool = style.boss_fills
			res.dirt[Vector2i(x, y)] = pool[rng.randi() % pool.size()]
```

- Add `var water: Dictionary = {}` to `Result` (Vector2i → atlas coord).

The RNG call order changes only on the island path; on the flat map (`land` all 1, every cell FOREST) the calls are identical, so old seeds give the old maps.

**3f. Rocks** — no flood fill per rock any more. Geometry guarantees reachability: two rock circles keep `obstacle_min_spacing` apart, and that is forced above a walker's width; every rock keeps `rock_clearance` from water and walls. So the free floor can never be cut.

```gdscript
static func rock_clearance(p: Params) -> float:
	return p.agent_radius * 2.0 + 4.0
```

In `_place_obstacles`: before the loop, `var spacing := maxf(p.obstacle_min_spacing, rock_clearance(p))`; delete the two lines that call `floor_reachable` / `pop_back`; pass `spacing` into `_obstacle_legal` (new last parameter `spacing: float`, used instead of `p.obstacle_min_spacing`). Keep pos inside `[p.cell + r + clearance, size - p.cell - r - clearance]` (walls). In `_obstacle_legal`, add first:

```gdscript
	var reach := r + rock_clearance(p)
	for dy in [-reach, 0.0, reach]:
		for dx in [-reach, 0.0, reach]:
			if not is_land(res, p, Vector2i((pos + Vector2(dx, dy)) / p.cell)):
				return false
```

`ponytail:` the 9-point check can miss a 1-cell water notch between the samples; upgrade to a full cell scan if the Task 6 video shows a rock touching water.

**3g. `floor_reachable`** — new optional `land` parameter. When `land` is not empty, a sample point is blocked if any of the 5 points (centre and centre ± `agent_radius` in x and y) is in a water cell:

```gdscript
static func floor_reachable(p: Params, obstacles: Array[Dictionary], land := PackedByteArray()) -> bool:
```

and inside the `if ok:` before the rock loop:

```gdscript
			if ok and not land.is_empty():
				for off in [Vector2.ZERO, Vector2(p.agent_radius, 0), Vector2(-p.agent_radius, 0), Vector2(0, p.agent_radius), Vector2(0, -p.agent_radius)]:
					var cc := Vector2i((c + off) / p.cell)
					if cc.x < 0 or cc.y < 0 or cc.x >= p.cols or cc.y >= p.rows or land[cc.y * p.cols + cc.x] == 0:
						ok = false
						break
```

Its rock loop is O(points × rocks): on 6400 x 3840 that is ~96k × 190. It is now called only by tests. Fine.

**3h. `_place_deco`** — skip water, and make the spacing check use a bucket grid (the old loop over all deco is O(n²): ~2400 deco × 60k attempts):

```gdscript
	var grid := {}   # Vector2i bucket -> Array of positions; bucket size = deco_min_spacing
	var bucket := maxf(p.deco_min_spacing, 1.0)
```

- After computing `cell`: `if res.land[cell.y * p.cols + cell.x] == 0: continue`.
- Replace the `for d in res.deco` spacing loop with a check of the 3x3 buckets around `Vector2i(pos / bucket)`.
- On append, also `grid.get_or_add(Vector2i(pos / bucket), []).append(pos)`.
- Rock check stays (rocks are few).

- [ ] **Step 4: Run, expect PASS**

Run: `godot --headless --script tests/test_island_gen.gd` → `PASS`.
Run: `godot --headless --script tests/test_map_gen.gd` → `PASS` (the flat map is unchanged; its "ring of rocks" test calls `floor_reachable` directly, still valid).
Run: `tools/run_tests.sh` → `0 failing`.

- [ ] **Step 5: Commit**

```bash
git add scripts/map/map_gen.gd scripts/map/map_style.gd data/maps/grass.tres tests/test_island_gen.gd docs/wiki/ground-tiles.md assets/map/
git commit -m "feat(map): ground, patches, rocks, deco follow the island; water-aware reachability (W1)"
```

---

### Task 3: ArenaMap draws the island (water, collision, big defaults, areas)

**Files:**
- Modify: `scripts/map/arena_map.gd`, `scenes/arena.tscn`, `tests/support/classic_arena.gd`, `tests/test_map_size.gd`, `tests/test_arena_map.gd` (and any other test the suite shows failing only because of the new defaults)
- Test: `tests/test_island_arena.gd` (create)

**Interfaces:**
- Consumes: Tasks 1–2 (`Result.land/area/water/kind`, `MapGen.Area`, `MapGen.is_land`, `MapGen.cell_index`).
- Produces (ArenaMap):
  - `@export var island_on := true` and `@export` copies of every new `Params` field (same names and defaults as Task 1), each with the same setter pattern as `noise_frequency` (`_changed()` → rebuild, same seed). `island_on` setter uses `_changed(false, true)`.
  - Defaults change: `map_cols = 200`, `map_rows = 120`, `zone_x = 0.86`, `player_spawn_x = 0.12`.
  - `func area_at(pos: Vector2) -> int` → `MapGen.Area` value, or `-1` on water / off the map.
  - `func home_point() -> Vector2` → the player spawn (respawn point for W6).
  - `func teleport_player(to: String) -> void` (`"home"` or `"boss"`; `"boss"` = zone left edge − 96 px, zone centre y).
  - `var build_ms := 0` (last `rebuild` time, ms).
  - Node `Ground/Water` (TileMapLayer), node `Water` (StaticBody2D, child of ArenaMap, collision layer 1, mask 0).

- [ ] **Step 1: Write the failing test** — `tests/test_island_arena.gd`

```gdscript
extends SceneTree
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").map_seed = 11
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var m: ArenaMap = arena.get_node("ArenaMap")
	var player: CharacterBody2D = arena.get_node("Player")
	var boss: Node2D = arena.get_node("Boss")
	_check(m.map_cols == 200 and m.map_rows == 120 and m.island_on, "default map is the 200 x 120 island")
	_check(m.area_at(m.home_point()) == MapGen.Area.FOREST, "home is in the forest")
	_check(m.area_at(boss.global_position) == MapGen.Area.BOSS, "the boss stands in the boss area")
	_check(m.home_point().distance_to(boss.global_position) > 3500.0, "the boss is far from home (%.0f px)" % m.home_point().distance_to(boss.global_position))
	_check(m.area_at(Vector2(5, 5)) == -1, "the map corner is water")
	var water: StaticBody2D = m.get_node("Water")
	_check(water.collision_layer == 1 and water.get_child_count() > 10, "water has collision on the wall layer (%d shapes)" % water.get_child_count())

	# Walk into the coast: find a land cell whose east neighbour is water, start 2 cells inside, push east.
	var p := m.make_params()
	var coast := Vector2i(-1, -1)
	for y in range(p.rows / 3, p.rows * 2 / 3):
		for x in range(p.cols - 2, p.cols / 2, -1):
			if MapGen.is_land(m.result, p, Vector2i(x, y)) and not MapGen.is_land(m.result, p, Vector2i(x + 1, y)):
				coast = Vector2i(x, y)
				break
		if coast.x >= 0:
			break
	_check(coast.x >= 0, "found an east coast cell")
	player.set_physics_process(false)
	player.global_position = (Vector2(coast) + Vector2(-1.5, 0.5)) * p.cell
	for i in 90:
		player.velocity = Vector2(400, 60)     # at an angle, as a player would
		player.move_and_slide()
		await physics_frame
	_check(m.area_at(player.global_position) != -1, "the player stops at the shore (never on water)")

	m.teleport_player("boss")
	_check(m.area_at(player.global_position) == MapGen.Area.BOSS, "Go to boss puts the player in the boss area")
	m.teleport_player("home")
	_check(player.global_position.distance_to(m.home_point()) < 1.0, "Go home puts the player at home")
	_check(m.build_ms > 0, "build time measured (%d ms)" % m.build_ms)
	_check(m.status_text().contains("area"), "F3 status shows the area")

	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
```

- [ ] **Step 2: Run, expect FAIL** — `godot --headless --script tests/test_island_arena.gd`.

- [ ] **Step 3: Implement**

**3a. `scenes/arena.tscn`** — add a `Water` TileMapLayer as the **first** child of `ArenaMap/Ground` (before `Dirt`, so ground draws over it). Set the `Background` ColorRect `color` to a water blue, `Color(0.18, 0.42, 0.62, 1)` (the placeholder water when `water_fills` is empty). Keep `format=3` and all node paths.

**3b. `scripts/map/arena_map.gd`**:
- `_ready`: `_water = $Ground/Water`; add it to the `pixel_scale` loop; create `_water_body := StaticBody2D.new()`, `name = "Water"`, `collision_mask = 0`, `add_child`.
- New exports listed above, plus their copy into `make_params()` (`p.island_on = island_on`, …). Add `home_clear_cells`, `coast_cells`, `corridor_half` as `int`.
- `rebuild()`: wrap the body with `var t0 := Time.get_ticks_msec()` … `build_ms = maxi(Time.get_ticks_msec() - t0, 1)`.
- `_build()`:
  - Water tiles: `_water.clear()`; if `style.water_texture` and not `result.water.is_empty()`, give `_water` its own TileSet made from `style.water_texture` (same code as `_make_tileset` but that texture: add an optional `texture` parameter to `_make_tileset`) and `set_cell` each `result.water` entry.
  - Water collision: free all children of `_water_body`. For each row, merge runs of **coast** water cells (water cells with at least one land cell among the 8 neighbours) into one `RectangleShape2D` per run, `CollisionShape2D` at the run centre in px. Inland-free deep water needs no shape (nobody can reach it).
- `area_at(pos)`: `var c := Vector2i((pos / cell_px()).floor())`; `-1` if `MapGen.cell_index` is -1 or `land == 0`; else `result.area[i]`.
- `home_point()`: `return _player_spawn`.
- `teleport_player(to)`: resolve the player from `player_path`; set `global_position`; `velocity = Vector2.ZERO`; `_camera.reset_smoothing()` if the camera exists.
- `status_text()`: append `"  area %s" % ["forest", "rocky", "boss"][a]` (or `"water"` for -1) for the player's position, plus `"  land %d%%  rocks %d  deco %d  build %d ms"`.

**3c. Old tests.** `tests/support/classic_arena.gd`: add `m.island_on = false`. In `tests/test_map_size.gd` and `tests/test_arena_map.gd`, right after `instantiate()` and before `add_child`, pin the old big map where the test asserts old numbers:

```gdscript
	var mm = arena.get_node("ArenaMap")
	mm.island_on = false
	mm.map_cols = 72
	mm.map_rows = 40
	mm.zone_x = 0.72
	mm.player_spawn_x = 0.14
```

Run the full suite; any other failure must be **only** because of the new defaults (fix it the same way) — anything else is a real bug, stop and report it. Demo scenarios that load the big arena stay as they are (the player starts next to the dummy on the island too); Task 6 checks one.

- [ ] **Step 4: Run, expect PASS**

`godot --headless --script tests/test_island_arena.gd` → `PASS`; `godot --headless --quit` boots with no errors; `tools/run_tests.sh` → `0 failing`.

- [ ] **Step 5: Commit**

```bash
git add scripts/map/arena_map.gd scenes/arena.tscn tests/
git commit -m "feat(map): ArenaMap draws the island - water, coast collision, areas, big default (W1)"
```

---

### Task 4: Home point and F3 test mode

**Files:**
- Create: `scripts/world/home_point.gd`, `scenes/world/home_point.tscn`
- Modify: `scenes/arena.tscn` (instance `HomePoint` as a sibling of `Player`), `scripts/map/arena_map.gd`, `scripts/debug/tuning_panel.gd`
- Test: `tests/test_island_arena.gd` (extend)

**Interfaces:**
- Consumes: `ArenaMap.home_point()`, `ArenaMap.teleport_player(to)`.
- Produces: `class_name HomePoint extends Node2D` with a child `Visual` (Sprite2D). ArenaMap `@export var home_offset_x := -70.0`, `@export var home_offset_y := -50.0`; the HomePoint sits at `home_point() + Vector2(home_offset_x, home_offset_y)`; that position is added to `_spawns` so rocks and deco keep clear.

- [ ] **Step 1: Extend the test** — before the final `print` in `tests/test_island_arena.gd`:

```gdscript
	var hp: Node2D = arena.get_node("HomePoint")
	_check(hp is HomePoint and hp.get_node("Visual") != null, "HomePoint with a Visual slot")
	_check(hp.global_position.distance_to(m.home_point() + Vector2(m.home_offset_x, m.home_offset_y)) < 1.0, "campfire next to the start")
	var clear := true
	for o in m.result.obstacles:
		clear = clear and o["pos"].distance_to(hp.global_position) > m.spawn_clear_radius
	_check(clear, "no rock on the campfire")
	var panel = arena.get_node("TuningPanel")
	_check(panel.range_overrides.has("Map.map_cols") and panel.range_overrides["Map.map_cols"].y >= 300, "F3 map_cols slider reaches 300")
```

(Use the key format `range_overrides` actually uses — read tuning_panel.gd l.25-60 first; adjust the two key lookups to match it.)

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**
- `scripts/world/home_point.gd`:

```gdscript
class_name HomePoint
extends Node2D
## The campfire where you start (and, from W6, respawn). Only a marker in W1.
## Art lives in the Visual child; swapping it touches no code.
```

- `scenes/world/home_point.tscn`: root `HomePoint` (Node2D, the script), child `Visual` (Sprite2D). Art: look for the Bonfire in `assets/third_party/pixel_crawler/` (`find … -iname "*fire*"`). If found, copy the png to `assets/map/` and set the Sprite2D `texture` + `region_rect` to its first frame, `scale = Vector2(2, 2)`, `offset` so its feet sit at (0, 0). If not found, leave `texture` empty and add a `Placeholder` child `Polygon2D` (orange diamond, 20 px). Never edit the pack.
- `scenes/arena.tscn`: instance it as `HomePoint`, sibling of `Player` (y-sorted with characters).
- `arena_map.gd`: `@export var home_path: NodePath = ^"../HomePoint"`; the two offset exports with `_changed(false, true)` setters; in `_place_actors`, place it and append its position to `_spawns`.
- `tuning_panel.gd`: in `range_overrides` set `map_cols` 12..300, `map_rows` 12..200, `forest_end` / `rocky_end` / `island_threshold` / `island_noise` / `area_wobble` 0..1, `island_falloff` 0.5..4, `island_noise_frequency` 0.005..0.2. Next to `New map`, add:

```gdscript
		_add_button(action_row, "Go home", func(): _map.teleport_player("home"))
		_add_button(action_row, "Go to boss", func(): _map.teleport_player("boss"))
```

- [ ] **Step 4: Run, expect PASS** — the test file, `godot --headless --quit`, then `tools/run_tests.sh` → `0 failing`.

- [ ] **Step 5: Commit**

```bash
git add scripts/world/ scenes/world/ scenes/arena.tscn scripts/map/arena_map.gd scripts/debug/tuning_panel.gd tests/test_island_arena.gd assets/map/
git commit -m "feat(map): home campfire marker, F3 island sliders and Go home / Go to boss (W1)"
```

---

### Task 5: Build time on the big map

**Files:**
- Modify: `tests/test_island_arena.gd`; `scripts/map/map_gen.gd` / `arena_map.gd` only if over budget.

- [ ] **Step 1: Add the budget check** (before the final `print`):

```gdscript
	var times: Array[int] = []
	for s in [3, 4, 5]:
		m.generate_seed(s)
		times.append(m.build_ms)
	print("  build ms per seed: %s" % [times])
	_check(times.max() < 2000, "a full island rebuild stays under 2 s headless")
```

- [ ] **Step 2: Run** — `godot --headless --script tests/test_island_arena.gd`. Write the three numbers down for the slice log.

- [ ] **Step 3: Only if over budget**: time each `MapGen` step with `Time.get_ticks_usec()` prints, fix the slowest one (likely candidates: deco attempts — lower `target * 25` to `target * 10`; `set_cell` loops; `_flood_land` Dictionary → PackedByteArray). Re-run. Remove the timing prints. If still over budget after one fix, stop and report the numbers (do not raise the budget).

- [ ] **Step 4: Commit**

```bash
git add tests/test_island_arena.gd scripts/map/
git commit -m "test(map): island rebuild time budget (W1)"
```

---

### Task 6: Demo video, decision record, docs

**Files:**
- Modify: `tools/demo/demo_bot.gd`
- Create: `docs/decision/0026-island-generator.md`, `docs/demo/w1_island.mp4`, `docs/demo/w1_island_overview.png`
- Modify: `docs/wiki/v1-design.md`, `CLAUDE.md` (§7 F3 row)

- [ ] **Step 1: `island` scenario** in `tools/demo/demo_bot.gd`: add `"island"` to the big-map scenario list (both places, l.63 and l.117) and `"island": await _run_island()` to the `match`. The scenario:

```gdscript
## FPS=30 tools/demo/record.sh w1_island --scenario=island --seed=11
func _run_island() -> void:
	_arena.get_node("Boss").passive = true
	_overlay(false)
	var m: ArenaMap = _arena.get_node("ArenaMap")
	var cam: Camera2D = _player.get_node("Camera")
	_say("The whole island", "seed %d - forest near home, rocky in the middle, boss area far right" % m.current_seed)
	cam.zoom = Vector2.ONE * (1152.0 / m.map_size().x)
	cam.position_smoothing_enabled = false
	await _wait(4.0)
	cam.zoom = Vector2.ONE
	_say("Home: the campfire", "you start (and later respawn) here")
	await _wait(2.0)
	await _walk(m.home_point() + Vector2(600, 0))
	_say("Water stops you", "walking into the coast")
	# reuse the coast search from tests/test_island_arena.gd to find a shore, teleport near it, walk into it
	await _wait(2.0)
	m.teleport_player("boss")
	_say("Boss area", "far from home; the boss waits in its zone")
	await _wait(3.0)
	get_tree().quit()
```

Fill the "Water stops you" part with the real coast search + `_walk` toward the water (copy the loop from the test; don't leave the comment). Note: `_walk` and camera limits — at zoom < 1 the limits clamp the view; the overview frame may need `cam.limit_*` removed for those 4 s and restored after.

- [ ] **Step 2: Record and check**

```bash
FPS=30 tools/demo/record.sh w1_island --scenario=island --seed=11
ffmpeg -y -ss 2 -i docs/demo/w1_island.mp4 -frames:v 1 docs/demo/w1_island_overview.png
```

Open the png with the Read tool. Check: the island is visible with a water edge, three ground looks, the campfire. If the rocky stone tiles from Task 2 look wrong, revert `rocky_fills` to empty and say so.

- [ ] **Step 3: Docs**
- `docs/decision/0026-island-generator.md` (Context / Decision / Why / Consequences): island = radial falloff + noise, cut to the part connected to home, bridge carved if needed; areas by distance home → boss with noise wobble; water collision only on coast cells; rocks: no per-rock flood fill, reachability by geometry (spacing and clearance ≥ walker width); `Params.island_on` false = the old map; known limits: area borders are hard tile edges (no transition tiles yet), arrows stop at the water edge (water is on the wall layer), the full map rebuilds on every F3 change (build ms in the log).
- `docs/wiki/v1-design.md`: add a `## 13. Slice log` section with a W1 line: who built it, judge findings, build ms, the walk time home → boss (≈ distance / 260 px/s player speed — the spec hoped for 1–2 min; say the real number).
- `CLAUDE.md` §7 F3 row: append "Island (W1, 0026): `Map` section has the island sliders (`island_on`, `island_*`, `coast_cells`, `home_clear_cells`, `corridor_half`, `forest_end`, `rocky_end`, `area_wobble`, `home_offset_*`); `[Map]` status shows the area under the player, land %, rocks, deco, build ms; buttons `Go home`, `Go to boss`."

- [ ] **Step 4: Full check and commit**

`tools/run_tests.sh` → `0 failing`; `godot --headless --quit` clean.

```bash
git add tools/demo/demo_bot.gd docs/ CLAUDE.md
git commit -m "docs(map): W1 island demo, decision 0026, slice log"
```

---

## After the tasks (main loop, not a task)

1. Opus judge, fresh context, on the whole W1 diff (CLAUDE.md rule 2.4). Fix what it confirms.
2. Show the user the video and the overview picture. Ask them to playtest: walk home → boss, try the sliders, try a few seeds.
