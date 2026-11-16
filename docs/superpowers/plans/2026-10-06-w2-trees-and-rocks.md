# W2 Trees and Rocks Implementation Plan

**Status:** Done plan (built as slice W1 / W2, see [v1-design.md §13](../../wiki/v1-design.md)), kept for history

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trees and rocks on the island are resource nodes: you punch them with bare hands, they shake
and throw chips, break, and drop wood / stone that flies to you when you walk near. A small counter shows
what you carry. Copper rocks exist but are too hard: "clink", no damage.

**Architecture:**
- **Hands are a weapon.** `fists.tres` is a `WeaponData` with an invisible model and a short hitbox, so the existing swing pipeline (WeaponHolder → Hitbox sweep → HitFx) does the punch. `Loadout` gets an instant holster toggle (`hands` key) that never charges the swap cast or cooldown, because it always returns to the same weapon.
- **Resource nodes** are one scene (`ResourceNode`) driven by a `ResourceNodeData` resource (tree / rock / copper rock). It has no `Health`: the shared `Hitbox._try_hit` sends gather hits to `take_gather_hit(weapon, source)`. Its hurtbox sits on a new layer 32 that only fists (and later tools) can reach, so swords, arrows and boss attacks never chop trees.
- **Items** are `ItemData` resources. A `Pickup` flies to the player's `Collector`, which adds to an `Inventory`. The `Inventory` API (`add`, `count`, `changed`) is the one W3 keeps when it becomes slot-based.
- **Map:** `MapGen` places nodes by area density into `Result.obstacles` (same legality rules as rocks, so reachability still holds). On the island, every rock is a resource node; the flat test map is unchanged.

**Tech Stack:** Godot 4.7, GDScript. Tests: `extends SceneTree` scripts, run by `tools/run_tests.sh`.

**Spec:** [docs/wiki/v1-design.md](../../wiki/v1-design.md) §4 Gathering, §5 Items, §11 row W2; decision [0025](../../decision/0025-v1-open-world.md); hit pipeline [0023](../../decision/0023-hit-feel.md); swap rule [0003](../../decision/0003-loadout-and-swapping.md); island [0026](../../decision/0026-island-generator.md).

## Global Constraints

- User choices (2026-10-06): **bare hands** gather in W2 (no tools until W3); **copper rocks appear in W2 but are too hard** (clink, grey sparks, no damage).
- §4: nodes have HP, take hits, shake and throw chips (the hit-feel system), break at 0 HP, drop items on the ground. Walk over to pick up (small magnet range). Wrong tool = "clink" and no damage, so the player sees *why*.
- §3: resources do not respawn in v1.
- §5: everything is data (`ItemData`, `ResourceNodeData`). New node kind = new `.tres`, no code.
- 0003: max 2 weapons; swapping weapons keeps its cast and cooldown. The holster toggle must never let you change weapon without paying the swap.
- Collision bits (hitbox.gd:12-15): 1 world, 2 player hurtbox, 4 enemy hurtbox, 8 player hitbox, 16 enemy hitbox. **New: 32 = gatherable.**
- CLAUDE.md §5: art lives in `.tres` (`ResourceNodeData`, `ItemData`) or `Visual` nodes. Placeholder look when no art. §7: every number `@export`, shown in F3; new state in F3 status; F1 draws new areas; on-demand triggers.
- Never edit `.godot/`, `*.import`, `*.uid`, or `assets/source/third_party/` (copy art to `assets/` first). New `.png` under `assets/` → run `godot --headless --import` and commit the `.png.import` (the repo tracks them).
- Full suite stays green: `tools/run_tests.sh` → `0 failing`; `godot --headless --quit` boots clean; island rebuild stays under 2000 ms at 200 x 120.

## Review Focus

1. **Swap exploit via hands:** sword → hands → bow must cost the normal swap cast + cooldown. Test in Task 2.
2. **Arrow or boss attack hits a tree** → nothing breaks, no crash (a node has no `Health`; `Hurtbox.get_health()` returns null). Test in Task 3.
3. **Two hits in one frame / overlap polling** (the hitbox polls every physics frame while active) → one gather hit per swing per node. Test in Task 3.
4. **Breaking a node next to the water or the map edge** → pickups never land in water out of reach. Test in Task 4.
5. **Hundreds of nodes on the island** → build time stays under budget, home and boss stay reachable, and nothing is placed in the fight zone. Test in Task 5.

---

## File structure

| File | Change | Responsibility |
|---|---|---|
| `scripts/items/item_data.gd` | create | `ItemData` resource |
| `data/items/wood.tres`, `stone.tres`, `copper_ore.tres` | create | the 3 W2 items |
| `scripts/components/inventory.gd` | create | counts per item, `changed` signal |
| `scripts/weapons/weapon_data.gd` | modify | `gather_damage`, `tool_power` |
| `data/weapons/fists.tres`, `scenes/weapons/fists_model.tscn` | create | bare hands |
| `scripts/components/loadout.gd` | modify | holster toggle |
| `scripts/player.gd`, `scenes/player.tscn`, `project.godot` | modify | `hands` key, Inventory, Collector |
| `scripts/world/resource_node_data.gd` | create | node kind data |
| `scripts/world/resource_node.gd`, `scenes/world/resource_node.tscn` | create | the node: HP, gather hit, break, drops |
| `data/resource_nodes/tree.tres`, `rock.tres`, `copper_rock.tres` | create | 3 node kinds |
| `data/hit_fx/chop.tres`, `mine.tres`, `clink.tres`, `node_break.tres` | create | gather hit feel |
| `scripts/components/hitbox.gd` | modify | gather branch in `_try_hit` |
| `scripts/world/pickup.gd`, `scenes/world/pickup.tscn` | create | item on the ground |
| `scripts/components/collector.gd` | create | magnet + pick up, on the player |
| `scripts/ui/item_counter.gd`, `scripts/hud.gd` | create / modify | counter under the hotbar |
| `scripts/map/map_style.gd`, `data/maps/grass.tres`, `scripts/map/map_gen.gd`, `scripts/map/arena_map.gd` | modify | place nodes by area |
| `scripts/debug/tuning_panel.gd`, `scripts/debug_overlay.gd` | modify | F3 / F1 |
| `scenes/arena.tscn` | modify | new HitFx profiles |
| tests: `test_inventory.gd`, `test_hands.gd` (extend), `test_resource_node.gd`, `test_pickup.gd`, `test_island_nodes.gd` | create / modify | |

---

### Task 1: Items, Inventory, gather fields on WeaponData

**Files:**
- Create: `scripts/items/item_data.gd`, `data/items/wood.tres`, `data/items/stone.tres`, `data/items/copper_ore.tres`, `scripts/components/inventory.gd`
- Modify: `scripts/weapons/weapon_data.gd`
- Test: `tests/test_inventory.gd`

**Interfaces:**
- Produces:
  - `class_name ItemData extends Resource`: `@export var id: StringName`, `@export var display_name := ""`, `@export var icon: Texture2D`, `@export var color := Color.WHITE` (placeholder tint when `icon` is null).
  - `class_name Inventory extends Node`: `signal changed`; `func add(item: ItemData, amount: int) -> int` (returns the amount NOT taken; W2 takes all → 0; amount ≤ 0 → returns 0 and changes nothing); `func count(item_id: StringName) -> int`; `func items() -> Dictionary` (id → count, copy); `func clear() -> void`; `func item(id: StringName) -> ItemData` (the resource last added under that id, or null).
  - `WeaponData`: `@export var gather_damage := 0.0` (HP taken from a resource node per hit; 0 = can't gather), `@export var tool_power := 0` (must be ≥ the node's `required_power`).

- [ ] **Step 1: Failing test** — `tests/test_inventory.gd`

```gdscript
extends SceneTree
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var wood: ItemData = load("res://data/items/wood.tres")
	var stone: ItemData = load("res://data/items/stone.tres")
	var ore: ItemData = load("res://data/items/copper_ore.tres")
	_check(wood.id == &"wood" and stone.id == &"stone" and ore.id == &"copper_ore", "3 items with ids")
	var inv := Inventory.new()
	root.add_child(inv)
	var fired := [0]
	inv.changed.connect(func(): fired[0] += 1)
	_check(inv.add(wood, 3) == 0 and inv.count(&"wood") == 3, "add 3 wood")
	inv.add(wood, 2)
	_check(inv.count(&"wood") == 5 and fired[0] == 2, "stacks, changed fires per add")
	_check(inv.add(stone, 0) == 0 and inv.count(&"stone") == 0 and fired[0] == 2, "add 0 does nothing")
	_check(inv.add(stone, -4) == 0 and inv.count(&"stone") == 0, "negative does nothing")
	_check(inv.item(&"wood") == wood, "item lookup by id")
	inv.clear()
	_check(inv.items().is_empty() and fired[0] == 3, "clear empties and fires")
	var w := WeaponData.new()
	_check(w.gather_damage == 0.0 and w.tool_power == 0, "weapons can't gather by default")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
```

- [ ] **Step 2: Run, expect FAIL** — `godot --headless --script tests/test_inventory.gd`

- [ ] **Step 3: Implement**

`scripts/items/item_data.gd`:

```gdscript
class_name ItemData
extends Resource
## One kind of item (wood, stone, ...). Data only: a new item is a new .tres (v1-design §5).

@export var id: StringName
@export var display_name := ""
@export var icon: Texture2D
## Placeholder tint (pickup and counter) while `icon` is empty.
@export var color := Color.WHITE
```

`scripts/components/inventory.gd`:

```gdscript
class_name Inventory
extends Node
## What the player carries. W2: unlimited counts per item. W3 makes it slot-based behind the same
## add / count / changed API.
## ponytail: no stack limit yet, W3 adds slots and max stacks.

signal changed

var _counts := {}   # StringName -> int
var _items := {}    # StringName -> ItemData

func add(item: ItemData, amount: int) -> int:
	if item == null or amount <= 0:
		return 0
	_counts[item.id] = _counts.get(item.id, 0) + amount
	_items[item.id] = item
	changed.emit()
	return 0

func count(item_id: StringName) -> int:
	return _counts.get(item_id, 0)

func items() -> Dictionary:
	return _counts.duplicate()

func item(id: StringName) -> ItemData:
	return _items.get(id)

func clear() -> void:
	_counts.clear()
	changed.emit()
```

`.tres` files (`[gd_resource type="Resource" script_class="ItemData" format=3]`, script ext_resource to `item_data.gd`):
- wood: `id = &"wood"`, `display_name = "Wood"`, `color = Color(0.55, 0.36, 0.2)`
- stone: `id = &"stone"`, `display_name = "Stone"`, `color = Color(0.6, 0.6, 0.62)`
- copper_ore: `id = &"copper_ore"`, `display_name = "Copper ore"`, `color = Color(0.85, 0.5, 0.3)`
- Icons: open `assets/source/third_party/pixel_crawler/Environment/Props/Static/Resources.png` with the Read tool. If it holds clear log / stone / ore pictures, copy the png to `assets/items/resources.png`, run `godot --headless --import`, and give each item an `AtlasTexture` sub-resource (`atlas` = that png, `region` = the picture). Otherwise leave `icon` empty.

`weapon_data.gd` — add near `damage`:

```gdscript
## Gathering (v1 §4). HP taken from a tree/rock per hit; 0 = this weapon can't gather.
@export var gather_damage := 0.0
## Must be >= the node's required_power, or the hit only clinks.
@export var tool_power := 0
```

- [ ] **Step 4: Run, expect PASS**, then `tools/run_tests.sh` → `0 failing`.

- [ ] **Step 5: Commit**

```bash
git add scripts/items/ data/items/ scripts/components/inventory.gd scripts/weapons/weapon_data.gd tests/test_inventory.gd assets/items/
git commit -m "feat(items): ItemData, Inventory, gather fields on WeaponData (W2)"
```

---

### Task 2: Bare hands — fists weapon and the holster toggle

**Files:**
- Create: `data/weapons/fists.tres`, `scenes/weapons/fists_model.tscn`
- Modify: `scripts/components/loadout.gd`, `scripts/player.gd`, `scenes/player.tscn`, `project.godot`, `scripts/ui/hotbar.gd`
- Test: `tests/test_hands.gd` (extend, keep its existing checks)

**Interfaces:**
- Consumes: `WeaponData.gather_damage`, `tool_power` (Task 1).
- Produces:
  - `Loadout`: `@export var unarmed: WeaponData` (player.tscn sets `fists.tres`); `func is_holstered() -> bool`; `func toggle_hands() -> bool` (instant; refused while casting or when `unarmed` is null; emits `swap_finished(unarmed)` when holstering and `swap_finished(weapons[active])` when drawing again; never touches the cooldown). `active_weapon()` returns `unarmed` while holstered. `try_swap(index)` while holstered: `index == active_index()` → same as `toggle_hands()` (instant draw); another index → normal cast + cooldown, and `_holstered = false` when the cast finishes.
  - Input action `hands` (key `3`, physical keycode 51). Player: `if Input.is_action_just_pressed("hands"): loadout.toggle_hands()` next to the `weapon_1`/`weapon_2` handling.
  - `fists.tres`: `display_name = "Hands"`, `behavior = "arc"`, `damage = 6.0`, `windup = 0.08`, `active = 0.08`, `recovery = 0.15`, `arc_degrees = 60.0`, `sweep_samples = 6`, `step_distance = 4.0`, `parryable = true`, `gather_damage = 1.0`, `tool_power = 0`, `model = fists_model.tscn`, `skill` = none.
  - `fists_model.tscn`: root `FistsModel` (Node2D), no Art sprite; `HandMain` Marker2D at `(16, 3)`, `HandOff` at `(10, -3)`; `Hitbox` Area2D (`hitbox.gd`, `collision_layer = 8`, `collision_mask = 36` (= 4 | 32)) with a `CollisionShape2D` `RectangleShape2D` size `(18, 14)` at `(22, 0)`.
  - Hotbar: while `loadout.is_holstered()`, no weapon slot shows as selected and the name label reads `unarmed.display_name`.

- [ ] **Step 1: Failing test** — append to `tests/test_hands.gd` before its final `print` (reuse its arena / player variables; read the file first and adapt names):

```gdscript
	var lo: Loadout = player.get_node("Loadout")
	var wh: WeaponHolder = player.get_node("WeaponHolder")
	var first: WeaponData = lo.active_weapon()
	_check(lo.toggle_hands() and lo.is_holstered() and wh.weapon == lo.unarmed, "hands: instant holster")
	_check(lo.cooldown_left() == 0.0 and not lo.is_casting(), "holster costs no cast and no cooldown")
	_check(lo.toggle_hands() and not lo.is_holstered() and wh.weapon == first, "hands again: same weapon back, instant")
	lo.toggle_hands()
	var other := 1 - lo.active_index()
	_check(lo.try_swap(other) and lo.is_casting(), "from hands to the OTHER weapon = a normal swap cast")
	for i in 60:
		await physics_frame
	_check(not lo.is_holstered() and wh.weapon == lo.weapons[other] and lo.cooldown_left() > 0.0, "...and it charges the cooldown")
	# Holster is allowed during the cooldown: no exploit, it always returns to the same weapon.
	_check(lo.toggle_hands() and lo.is_holstered(), "holster allowed during the swap cooldown")
	# Punch the dummy (still holstered): fists deal damage like any weapon.
	var dummy = arena.get_node("Dummy")
	var dh: Health = dummy.get_node("Health")
	player.set_physics_process(false)
	player.global_position = dummy.global_position - Vector2(24, 0)
	player.get_node("WeaponVisual").set_aim_angle(0.0)
	await physics_frame
	var before := dh.hp
	wh.try_attack()
	for i in 30:
		await physics_frame
	_check(dh.hp < before, "a punch hurts the dummy (%.0f -> %.0f)" % [before, dh.hp])
```

(If the punch check fails because of the dummy's armor or the reach, fix the model's hitbox position, not the assertion.)

- [ ] **Step 2: Run, expect FAIL** — `godot --headless --script tests/test_hands.gd`

- [ ] **Step 3: Implement** — in `loadout.gd` add:

```gdscript
## Bare hands (v1 W2). Holstering is instant and free: it always returns to the same weapon, so it can
## never skip the swap cast/cooldown of decision 0003.
@export var unarmed: WeaponData

var _holstered := false

func is_holstered() -> bool:
	return _holstered

func toggle_hands() -> bool:
	if unarmed == null or _casting:
		return false
	_holstered = not _holstered
	if _weapon_holder:
		_weapon_holder.cancel()
	swap_finished.emit(active_weapon())
	return true
```

- `active_weapon()`: `if _holstered: return unarmed` first.
- `try_swap(index)`: at the top, `if _holstered and index == _active_index: return toggle_hands()`. The existing `index == _active_index` refusal stays for the non-holstered case.
- In `_physics_process`, where the cast finishes, set `_holstered = false` before `swap_finished.emit`.
- `project.godot`: add the `hands` action, copying the `weapon_2` block with `physical_keycode = 51`. First check that key 3 is not bound elsewhere (`grep -n "physical_keycode\":51" project.godot`).
- `player.tscn`: set `Loadout.unarmed = fists.tres`. `player.gd`: read the action next to weapon_1/2.
- `hotbar.gd`: in `_process`, highlight no slot and show `unarmed.display_name` while holstered.
- Hands visual: `fists_model.tscn` has `HandMain`/`HandOff`, so `HandsVisual` binds to them the way it does for the sword. Check in the Task 6 video that the fists swing.

- [ ] **Step 4: Run, expect PASS**. Then run `tests/test_hud_hotbar.gd`, the full suite (`0 failing`) and `godot --headless --quit`.

- [ ] **Step 5: Commit**

```bash
git add data/weapons/fists.tres scenes/weapons/fists_model.tscn scripts/components/loadout.gd scripts/player.gd scenes/player.tscn project.godot scripts/ui/hotbar.gd tests/test_hands.gd
git commit -m "feat(hands): bare-hands punch with an instant holster toggle on key 3 (W2)"
```

---

### Task 3: ResourceNode — HP, gather hit, clink, break

**Files:**
- Create: `scripts/world/resource_node_data.gd`, `scripts/world/resource_node.gd`, `scenes/world/resource_node.tscn`, `data/resource_nodes/tree.tres`, `rock.tres`, `copper_rock.tres`, `data/hit_fx/chop.tres`, `mine.tres`, `clink.tres`, `node_break.tres`
- Modify: `scripts/components/hitbox.gd` (`_try_hit` l.132), `scenes/arena.tscn` (`HitFx.profiles`, l.91), `scripts/fx/hit_fx.gd` (only `add_to_group("hit_fx")` in `_ready`)
- Test: `tests/test_resource_node.gd`

**Interfaces:**
- Consumes: `WeaponData.gather_damage / tool_power`, `ItemData`, `HitFx.fire(type, victim, source, info)`.
- Produces:
  - `class_name ResourceNodeData extends Resource`:
    - `id: StringName`, `display_name`, `max_hp := 6.0`, `required_power := 0`
    - `drop_item: ItemData`, `drop_min := 2`, `drop_max := 3`
    - `radius := 14.0` (collision circle, screen px)
    - `density_forest := 0.0`, `density_rocky := 0.0`, `density_boss := 0.0` (nodes per 100 land cells of that area)
    - art: `texture: Texture2D`, `regions: Array[Rect2]` (look variants), `remains_region := Rect2()` (stump; empty = nothing stays)
    - `pixel_scale := 2`, `color := Color.WHITE` (placeholder when no texture)
    - hit feel: `hit_type := &"chop"`, `clink_type := &"clink"`, `break_type := &"node_break"`
  - `class_name ResourceNode extends StaticBody2D`:
    - `signal broken(node: ResourceNode)`
    - `var data: ResourceNodeData`, `var hp: float`, `var variant := 0`
    - `func setup(d: ResourceNodeData, v: int) -> void` (call before `add_child`)
    - `func take_gather_hit(weapon: WeaponData, source: Node2D) -> bool` (true = it took damage)
    - `func is_broken() -> bool`
    - `func status_text() -> String`
    - Children: `CollisionShape2D` (circle, `data.radius`, layer 1), `Hurtbox` (Area2D, `hurtbox.gd`, `collision_layer = 32`, mask 0, circle `data.radius + 6`), `Visual` (Node2D, `actor_visual.gd` or a subclass, with a `Sprite2D` `Body`; feet at `(0, data.radius)`), group `map_obstacle` and `resource_node`.
    - Drops: spawns `pickup.tscn` instances if that scene exists (Task 4). Until then: `print` the drops. Task 4 wires it.
  - `Hitbox._try_hit`: after the per-swing dedup, `if target.has_method("take_gather_hit"): target.take_gather_hit(weapon, owner); return` (before `get_health`).

- [ ] **Step 1: Failing test** — `tests/test_resource_node.gd`

```gdscript
extends SceneTree
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _node(arena: Node, path: String, at: Vector2) -> ResourceNode:
	var n: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	n.setup(load(path), 0)
	n.position = at
	arena.add_child(n)
	return n

func _swing(wh: WeaponHolder) -> void:
	wh.try_attack()
	for i in 30:
		await physics_frame

func _init() -> void:
	var arena = ClassicArena.make()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	var lo: Loadout = player.get_node("Loadout")
	var wh: WeaponHolder = player.get_node("WeaponHolder")
	player.set_physics_process(false)
	player.get_node("WeaponVisual").set_aim_angle(0.0)
	var spot: Vector2 = player.global_position + Vector2(0, 160)
	player.global_position = spot
	var tree := _node(arena, "res://data/resource_nodes/tree.tres", spot + Vector2(40, 0))
	await physics_frame
	var fx_seen: Array[StringName] = []
	arena.get_node("HitFx").hit_fx.connect(func(t): fx_seen.append(t))

	# Sword: the swing passes through (sword hitbox does not see layer 32).
	await _swing(wh)
	_check(tree.hp == tree.data.max_hp, "sword does not chop (hp %.0f)" % tree.hp)

	lo.toggle_hands()
	await physics_frame
	await _swing(wh)
	_check(tree.hp == tree.data.max_hp - 1.0, "one punch = one gather hit, not one per polled frame")
	_check(fx_seen.has(&"chop"), "chop hit feel fired")
	var hits := 1
	while not tree.is_broken() and hits < 20:
		await _swing(wh)
		hits += 1
	_check(tree.is_broken() and hits == int(tree.data.max_hp), "tree breaks after max_hp punches (%d)" % hits)
	_check(fx_seen.has(&"node_break"), "break hit feel fired")
	await physics_frame
	_check(not is_instance_valid(tree) or tree.get_node("CollisionShape2D").disabled, "a broken tree no longer blocks")

	var ore := _node(arena, "res://data/resource_nodes/copper_rock.tres", spot + Vector2(40, 0))
	await physics_frame
	await _swing(wh)
	_check(ore.hp == ore.data.max_hp and fx_seen.has(&"clink"), "copper: clink, no damage with hands")

	# An arrow at a node: no crash, no damage (layer 32 is not in the arrow mask; the body stops it).
	var proj: Projectile = load("res://scenes/weapons/arrow.tscn").instantiate() if ResourceLoader.exists("res://scenes/weapons/arrow.tscn") else null
	if proj:
		arena.add_child(proj)
		proj.global_position = ore.global_position - Vector2(120, 0)
		proj.setup(Vector2.RIGHT, 700.0, 520.0, 18.0, true, player)
		for i in 30:
			await physics_frame
		_check(ore.hp == ore.data.max_hp, "an arrow does not mine")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
```

(Check the real arrow scene path in `data/weapons/bow.tres` → `projectile_scene` and use it; drop the `if` guard once it's known.)

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement**

`scripts/world/resource_node.gd` (core):

```gdscript
class_name ResourceNode
extends StaticBody2D
## A tree / rock you gather (v1 §4). No Health: Hitbox._try_hit calls take_gather_hit. Kind and art come
## from ResourceNodeData; the look lives in the Visual child (swap = no code change).

signal broken(node: ResourceNode)

var data: ResourceNodeData
var hp := 0.0
var variant := 0
var _hit_fx: Node

func setup(d: ResourceNodeData, v: int) -> void:
	data = d
	variant = v
	hp = d.max_hp

func _ready() -> void:
	add_to_group("map_obstacle")
	add_to_group("resource_node")
	collision_mask = 0
	(get_node("CollisionShape2D").shape as CircleShape2D).radius = data.radius
	(get_node("Hurtbox/CollisionShape2D").shape as CircleShape2D).radius = data.radius + 6.0
	_hit_fx = get_tree().get_first_node_in_group("hit_fx")
	get_node("Visual").show_variant(data, variant)

func is_broken() -> bool:
	return hp <= 0.0

func take_gather_hit(weapon: WeaponData, source: Node2D) -> bool:
	if is_broken() or weapon == null:
		return false
	var info := {"source": source, "direction": (global_position - source.global_position).normalized()}
	if weapon.gather_damage <= 0.0 or weapon.tool_power < data.required_power:
		_fx(data.clink_type, source, info)
		return false
	hp = maxf(hp - weapon.gather_damage, 0.0)
	_fx(data.hit_type, source, info)
	if is_broken():
		_break(source)
	return true

func _fx(type: StringName, source: Node, info: Dictionary) -> void:
	if _hit_fx:
		_hit_fx.fire(type, self, source, info)

func _break(source: Node) -> void:
	_fx(data.break_type, source, {"source": source})
	get_node("CollisionShape2D").set_deferred("disabled", true)
	get_node("Hurtbox").set_deferred("monitorable", false)
	broken.emit(self)
	_drop()
	if data.remains_region.has_area():
		get_node("Visual").show_remains(data)
	else:
		queue_free()

func _drop() -> void:
	pass   # Task 4 spawns pickups here

func status_text() -> String:
	return "%s %.0f/%.0f hp, needs power %d" % [data.display_name, hp, data.max_hp, data.required_power]
```

- `Visual`: a small script (`scripts/world/resource_node_visual.gd`, `extends ActorVisual`) with `show_variant(d, v)` and `show_remains(d)`. It sets the `Body` Sprite2D: `texture`, `region_enabled`, `region_rect = d.regions[v]`, `scale = Vector2.ONE * d.pixel_scale`, `offset` so the bottom of the picture sits at the circle's bottom. With no texture, it draws a placeholder in `_draw()`: a `d.color` circle for rocks, a green triangle on a brown trunk for `id == &"tree"`. It overrides `flash_target()` to return `Body`. HitFx's recoil layer then shakes it with no extra code.
- **Tree look-through:** add `@export var fade_alpha := 0.45` on the visual. In `_process`, if the player (group `player`; check that the player is in that group, else use `get_tree().get_first_node_in_group("player")` after adding it) is inside the sprite's rect and above the trunk (`player.y < global_position.y`), set `Body.modulate.a = fade_alpha`, else 1. A tree should never hide the player.
- `ResourceNodeData` script: the fields listed under Interfaces.
- `.tres` values:

| Kind | max_hp | required_power | drop | radius | forest / rocky / boss density | colour | hit_type |
|---|---|---|---|---|---|---|---|
| tree | 6 | 0 | wood 2–4 | 14 | 2.5 / 0.3 / 0.6 | (0.25, 0.55, 0.25) | chop |
| rock | 8 | 0 | stone 2–3 | 16 | 0.4 / 2.0 / 0.5 | (0.55, 0.55, 0.58) | mine |
| copper_rock | 10 | 1 | copper_ore 2–3 | 16 | 0 / 0.6 / 0 | (0.8, 0.5, 0.3) | mine |

  - Tree art: open `assets/source/third_party/pixel_crawler/Environment/Props/Static/Trees/Model_01/Size_02.png` and `Model_02/Size_02.png` with Read. Copy the one with clear single trees to `assets/game/world/trees.png`, import, and set 2–3 `regions` plus a stump `remains_region` if the sheet has one.
  - Rock art: the current map rocks (`assets/game/map/Rocks.png`, the regions and radii in `data/maps/grass.tres` obstacles) become the `rock.tres` regions.
  - Copper: if `Rocks.png` / `Resources.png` has an ore-coloured rock, use it; else the placeholder colour.
- HitFx profiles: copy `data/hit_fx/sword.tres` and change:
  - `chop`: `stop_frames 1`, `shake 0.05`, `knockback 0`, `recoil_px 3`, `spark_count 5`, `spark_color` brown, `number_size 0` (if 0 does not hide numbers, set `numbers_on` false in the profile, or skip numbers for these types)
  - `mine`: like chop, `spark_color` grey, `pitch 0.8`
  - `clink`: `stop_frames 0`, `shake 0`, `recoil_px 1`, `spark_count 3`, `spark_color` light grey, `pitch 1.6`, no number
  - `node_break`: `stop_frames 2`, `shake 0.12`, `spark_count 12`
  - Add all 4 to `HitFx.profiles` in `arena.tscn` (l.91). In `hit_fx.gd` `_ready`, add `add_to_group("hit_fx")`.
- `hitbox.gd` `_try_hit`: the gather branch from Interfaces.

- [ ] **Step 4: Run, expect PASS**, then the full suite and `godot --headless --quit`.

- [ ] **Step 5: Commit**

```bash
git add scripts/world/ scenes/world/resource_node.tscn data/resource_nodes/ data/hit_fx/ scripts/components/hitbox.gd scripts/fx/hit_fx.gd scenes/arena.tscn assets/game/world/ tests/test_resource_node.gd
git commit -m "feat(world): resource nodes - punch trees and rocks, copper clinks (W2)"
```

---

### Task 4: Pickups, Collector, item counter

**Files:**
- Create: `scripts/world/pickup.gd`, `scenes/world/pickup.tscn`, `scripts/components/collector.gd`, `scripts/ui/item_counter.gd`
- Modify: `scripts/world/resource_node.gd` (`_drop`), `scenes/player.tscn` (add `Inventory`, `Collector`), `scripts/hud.gd` (`_build_top_right`)
- Test: `tests/test_pickup.gd`

**Interfaces:**
- Consumes: `Inventory` (Task 1), `ResourceNode._drop` (Task 3), `ArenaMap.area_at(pos)` (W1, `-1` = water / off the map).
- Produces:
  - `class_name Pickup extends Node2D`: `var item: ItemData`, `var amount := 1`. Placeholder look: a `_draw()` diamond in `item.color`, 7 px, or a `Sprite2D` `Icon` with `item.icon`. On spawn it hops out (tween up and out to `target`) and only then can be collected (`@export var settle_time := 0.35`).
  - `static func Pickup.spawn(parent: Node, item: ItemData, amount: int, from: Vector2, to: Vector2) -> Pickup`.
  - `class_name Collector extends Node` (child of Player):
    - `@export var magnet_radius := 70.0`, `magnet_speed := 420.0`, `pickup_radius := 14.0`, `inventory_path: NodePath = ^"../Inventory"`, `scatter_radius := 26.0` (used by ResourceNode for drop spread)
    - `func inventory() -> Inventory`, `var last_pickup := ""` (for F3)
    - `_physics_process`: for each node in group `pickup` that is settled: inside `magnet_radius` → move toward the player at `magnet_speed`; inside `pickup_radius` → `inventory.add` and `queue_free`
    - Group `collector`.
  - `ResourceNode._drop()`: `amount = randi_range(drop_min, drop_max)`, one Pickup per unit. Spread: `to` = node position + a random offset inside `scatter_radius` (read from the collector, or a default of 26 if none). If `ArenaMap.area_at(to) == -1` (water), use the node position. The ArenaMap is found via group `arena_map` (add that group in `ArenaMap._ready`). Parent = the node's parent.
  - `ItemCounter` (`extends HBoxContainer`): `bind(inv: Inventory)`; one `Label` per item with count > 0, reading `"%s %d" % [display_name, count]` (icon `TextureRect` in front if the item has one). Rebuilt on `changed`. It sits in the HUD top-right `_block` under the Hotbar (`SIZE_SHRINK_END`), and is hidden while empty.

- [ ] **Step 1: Failing test** — `tests/test_pickup.gd`

```gdscript
extends SceneTree
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
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var inv: Inventory = player.get_node("Inventory")
	var col: Collector = player.get_node("Collector")
	var wood: ItemData = load("res://data/items/wood.tres")
	var far := Pickup.spawn(arena, wood, 1, player.global_position + Vector2(300, 0), player.global_position + Vector2(300, 0))
	var near := Pickup.spawn(arena, wood, 1, player.global_position + Vector2(col.magnet_radius - 10, 0), player.global_position + Vector2(col.magnet_radius - 10, 0))
	for i in 90:
		await physics_frame
	_check(inv.count(&"wood") == 1, "the near pickup flew in, the far one stayed (%d)" % inv.count(&"wood"))
	_check(is_instance_valid(far) and not is_instance_valid(near), "far still on the ground")

	# Break a tree: its drops land on the ground and end up in the inventory when you walk over.
	var tree: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	tree.setup(load("res://data/resource_nodes/tree.tres"), 0)
	tree.position = player.global_position + Vector2(40, 0)
	arena.add_child(tree)
	await physics_frame
	var fists: WeaponData = load("res://data/weapons/fists.tres")
	while not tree.is_broken():
		tree.take_gather_hit(fists, player)
	await physics_frame
	var dropped := get_nodes_in_group_count(arena) - 1   # minus the far pickup
	_check(dropped >= 2 and dropped <= 4, "tree dropped 2-4 wood pickups (%d)" % dropped)
	for i in 120:
		await physics_frame
	_check(inv.count(&"wood") >= 3, "walking next to the drops collects them (%d)" % inv.count(&"wood"))

	var hud = arena.get_node("HUD")
	_check(hud.get_node_or_null("%ItemCounter") != null or _find_counter(hud) != null, "HUD has an item counter")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)

func get_nodes_in_group_count(_a) -> int:
	return root.get_tree().get_nodes_in_group("pickup").size()

func _find_counter(n: Node) -> Node:
	if n is ItemCounter:
		return n
	for c in n.get_children():
		var f := _find_counter(c)
		if f:
			return f
	return null
```

Also add one **water-edge test** (Review Focus 4). Load the island arena (`scenes/arena.tscn`, `map_seed = 11`) and find a land cell next to water (copy the coast search from `tests/test_island_arena.gd`). Put a tree there with `setup` + `add_child`, break it with `take_gather_hit` in a loop, then assert that every pickup in group `pickup` has `m.area_at(p.global_position) != -1` after it settles. Write it as a second function in this file, called from `_init` before the final print.

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** as in Interfaces.
  - Pickup and Collector exports follow the CLAUDE.md §7 rule (all `@export`).
  - The ArenaMap gets `add_to_group("arena_map")` in `_ready`.
  - `hud.gd`: after the Hotbar block, `if player has Inventory: add ItemCounter, bind`.

- [ ] **Step 4: Run, expect PASS**, then `tests/test_hud_hotbar.gd`, the full suite and the boot.

- [ ] **Step 5: Commit**

```bash
git add scripts/world/pickup.gd scenes/world/pickup.tscn scripts/components/collector.gd scripts/ui/item_counter.gd scripts/world/resource_node.gd scenes/player.tscn scripts/hud.gd scripts/map/arena_map.gd tests/test_pickup.gd
git commit -m "feat(items): drops fly to the player, item counter on the HUD (W2)"
```

---

### Task 5: Place trees and rocks on the island

**Files:**
- Modify: `scripts/map/map_style.gd` (`@export var resource_nodes: Array[ResourceNodeData] = []`), `data/maps/grass.tres` (tree, rock, copper_rock), `scripts/map/map_gen.gd`, `scripts/map/arena_map.gd` (`_build` obstacle loop, l.562-584)
- Test: `tests/test_island_nodes.gd` (create); `tests/test_island_gen.gd`, `tests/test_island_arena.gd` must stay green

**Interfaces:**
- Consumes: `ResourceNodeData.density_*`, `.radius`, `.regions` (Task 3); `MapGen._obstacle_legal`, `rock_clearance`, `Area` (W1).
- Produces:
  - `Result.obstacles` entries get a `"node"` key: an index into `style.resource_nodes`, or `-1` for a plain cover rock (the flat map). `"region"` is the variant index for nodes.
  - `MapGen._place_nodes(res, style, p, rng)` runs **only when `p.island_on`**. On the island, `_place_obstacles` is skipped (every rock is a resource node). For each kind and each area, target = `round(density * land_cells_in_area / 100)`. Candidate positions are random cells of that area (build the per-area cell lists once), with a random offset inside the cell. Each candidate must pass `_obstacle_legal` with `r = kind.radius`.
  - `_obstacle_legal` spacing check uses a bucket grid (cell size = largest radius*2 + spacing) instead of the loop over all obstacles. Keep it as one shared helper so `_place_obstacles` uses it too.
  - `ArenaMap._build`: `o["node"] >= 0` → instantiate `resource_node.tscn`, `setup(style.resource_nodes[o["node"]], o["region"])`, position `o["pos"]`, add it to `_obstacles`, and give the boss `add_collision_exception_with` it. `-1` → the old Rock code, unchanged.
  - `ArenaMap.status_text()` adds `nodes %d` (count, cached at build like `land_pct`).

- [ ] **Step 1: Failing test** — `tests/test_island_nodes.gd`

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
	var style := m.style
	var by_kind := {}
	var by_area := {}
	for n in get_nodes_in_group("resource_node"):
		var k: StringName = n.data.id
		by_kind[k] = by_kind.get(k, 0) + 1
		var key := "%s@%d" % [k, m.area_at(n.global_position)]
		by_area[key] = by_area.get(key, 0) + 1
	print("  nodes: %s" % [by_area])
	_check(by_kind.get(&"tree", 0) > 100 and by_kind.get(&"rock", 0) > 50 and by_kind.get(&"copper_rock", 0) > 10, "trees, rocks and copper on the island %s" % [by_kind])
	_check(by_area.get("tree@0", 0) > by_area.get("tree@1", 0) * 3, "trees mostly in the forest")
	_check(by_area.get("copper_rock@0", 0) == 0 and by_area.get("copper_rock@2", 0) == 0, "copper only in the rocky area")
	_check(get_nodes_in_group("map_obstacle").size() == get_nodes_in_group("resource_node").size(), "no plain cover rocks left on the island")
	var zone: Rect2 = m.layout()["zone"]
	var in_zone := 0
	for n in get_nodes_in_group("resource_node"):
		if zone.has_point(n.global_position):
			in_zone += 1
	_check(in_zone == 0, "nothing in the fight zone")
	var p := m.make_params()
	_check(MapGen.floor_reachable(p, m.result.obstacles, m.result.land), "all walkable land still reachable from home")
	var a := MapGen.generate(style, p, 11)
	var b := MapGen.generate(style, p, 11)
	_check(a.obstacles == b.obstacles, "same seed = same trees and rocks")
	_check(m.build_ms < 2000, "build with nodes under budget (%d ms)" % m.build_ms)
	var flat := MapGen.Params.new()
	var fr := MapGen.generate(style, flat, 11)
	var plain := true
	for o in fr.obstacles:
		plain = plain and o["node"] == -1
	_check(plain and not fr.obstacles.is_empty(), "flat map keeps its plain rocks")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)

func get_nodes_in_group(g: String) -> Array:
	return root.get_tree().get_nodes_in_group(g)
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** as in Interfaces. If the densities give fewer nodes than the test's floors because the area is small, tune the `.tres` densities, not the test.
- [ ] **Step 4: Run, expect PASS.** Also run `test_island_gen.gd` (its "rocks on land, clear of water" check now covers nodes too), `test_island_arena.gd`, `test_map_gen.gd`, the full suite and the boot. Write the build ms and the node counts in the report.
- [ ] **Step 5: Commit**

```bash
git add scripts/map/ data/maps/grass.tres tests/test_island_nodes.gd
git commit -m "feat(map): trees, rocks and copper placed by area on the island (W2)"
```

---

### Task 6: F3, F1, demo video, docs

**Files:**
- Modify: `scripts/debug/tuning_panel.gd`, `scripts/debug_overlay.gd`, `tools/demo/demo_bot.gd`, `CLAUDE.md` (§7 F3 row, F1 row, debug keys table: add `3` = hands), `docs/wiki/v1-design.md` (slice log)
- Create: `docs/decision/0027-gathering.md`, `docs/demo/w2_gather.mp4`

- [ ] **Step 1: F3**
  - Targets (sections):
    - `Collector`: the player's Collector
    - `Node tree`, `Node rock`, `Node copper`: the three `ResourceNodeData` (density changes apply on the next `New map`; say so in the status line)
    - `Hands`: `fists.tres`
  - Status line `[Gather]`:
    - holstered yes/no
    - the active weapon's `gather_damage` / `tool_power`
    - the last gather hit (`ResourceNode.status_text()` of the last node hit; keep it in a static var or on the collector)
    - the inventory counts
    - pickups on the ground
  - Buttons:
    - `Break nearest node`: calls `take_gather_hit` with a temp weapon that has `gather_damage = 999`, `tool_power = 9`
    - `Give 10 each`: adds 10 of each item
    - `Clear items`
- [ ] **Step 2: F1** — draw the Collector's `magnet_radius` (thin cyan circle) and `pickup_radius` around the player. Resource nodes are in `map_obstacle`, so they are already drawn as yellow collision circles. Check that, and if needed also draw their Hurtbox circle (layer 32) in a different colour.
- [ ] **Step 3: Demo** — scenario `gather` (big-map list + match):
  - teleport next to a forest tree
  - `_say("Bare hands: press 3")` → toggle hands
  - punch until the tree breaks; the wood flies in and the counter rises
  - walk to a rock and break it
  - teleport into the rocky area and punch copper: `_say("Too hard: needs a pickaxe (W3/W4)")`
  - show the counter

  Record `FPS=30 tools/demo/record.sh w2_gather --scenario=gather --seed=11` and extract 2 frames. Look at them with Read. Report honestly whether the fists are visible, whether the tree shakes, and whether chips and the counter are visible.
- [ ] **Step 4: Docs**
  - `0027-gathering.md`: Context / Decision / Why / Consequences. Cover:
    - hands as a weapon plus the free holster toggle (and why there's no 0003 exploit)
    - layer 32 gatherable
    - no `Health` on nodes
    - nodes in `Result.obstacles` with a `node` key
    - Inventory API kept for W3
    - known limits: no respawn, no stack limit, key 3 is temporary until W3 slots
  - Slice log line in `v1-design.md` §13. CLAUDE.md §7 rows.
- [ ] **Step 5:** run the full suite and the boot, then commit:

```bash
git add scripts/debug/ tools/demo/demo_bot.gd docs/ CLAUDE.md
git commit -m "docs(world): W2 gather demo, decision 0027, F3/F1 test mode"
```

---

## After the tasks (main loop)

1. Opus judge, fresh context, on the whole W2 diff. Fix wave, then a scoped re-review.
2. Show the user the video and the frames. Ask them to playtest: press 3, punch a tree, pick up wood, try copper.
