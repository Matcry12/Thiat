# Godot 4.x Combat Patterns Reference

Top-down 2D action game: CharacterBody2D player, melee arcs, projectiles,
phased boss, dodge i-frames, parry window, data-driven weapons (Resource),
swappable brain node. Verified against Godot 4 stable docs (see Sources).

---

## 1. Hitbox / Hurtbox with Area2D

- Standard pair: attacker has a **Hitbox** (`Area2D`, `monitoring = true`),
  target has a **Hurtbox** (`Area2D`, `monitorable = true`). Don't monitor
  both ways — pick one direction to avoid double signal firing.
- Collision layers/masks: 32 layers (1-32 in editor UI → bits 0-31
  internally). Hitbox layer = e.g. `player_hitbox`, mask = `enemy_hurtbox`
  (and vice versa for enemy attacks). Set via Inspector or
  `set_collision_layer_value(n, bool)` / `set_collision_mask_value(n, bool)`.
- Connect `area_entered(area: Area2D)` — fires only if `monitoring == true`
  on the emitting area and layer/mask overlap.
- **Avoid double-hits in one swing**: keep a `hit_this_attack: Array[Node]`
  (or a `Dictionary` for O(1) lookup) on the Hitbox, cleared when the attack
  starts, checked/added on each `area_entered`.

```gdscript
# Hitbox.gd
extends Area2D
class_name Hitbox

@export var damage: int = 10
var _hit_targets: Array[Node] = []

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func start_attack() -> void:
    _hit_targets.clear()
    set_deferred("monitoring", true)

func end_attack() -> void:
    set_deferred("monitoring", false)

func _on_area_entered(area: Area2D) -> void:
    var hurtbox := area as Hurtbox
    if hurtbox == null:
        return
    var target := hurtbox.get_owner_body()
    if target in _hit_targets:
        return
    _hit_targets.append(target)
    hurtbox.take_hit(damage, self)
```

- **Enabling/disabling shapes safely**: toggle the `CollisionShape2D.disabled`
  property (or the Area2D's `monitoring`) with `set_deferred(...)`, not a
  direct assignment. Godot's physics server processes collision state changes
  between physics steps; changing `disabled` mid-callback (e.g. inside
  `area_entered`) can desync or be silently ignored until the next step.
  `set_deferred` queues the change for idle time, after the current physics
  step finishes, matching how the docs describe deferred calls avoiding
  "circular" mid-frame state changes.

```gdscript
$CollisionShape2D.set_deferred("disabled", true)
```

---

## 2. CharacterBody2D movement (top-down)

- `velocity: Vector2` — set it, then call `move_and_slide()` (no
  arguments in Godot 4; it reads `velocity` and applies gravity/slide
  based on `motion_mode`).
- For top-down (no floor concept), set `motion_mode = MOTION_MODE_FLOATING`
  so all collisions report as walls (no floor/ceiling snapping).
- Movement belongs in `_physics_process(delta)`, never `_process`.

```gdscript
# Player.gd
extends CharacterBody2D

@export var speed: float = 220.0

func _physics_process(_delta: float) -> void:
    var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = input_dir * speed
    move_and_slide()
```

- Aim toward mouse:

```gdscript
func _physics_process(_delta: float) -> void:
    var to_mouse := get_global_mouse_position()
    $WeaponPivot.look_at(to_mouse)          # rotates +X axis toward point
    # or: var angle := $WeaponPivot.get_angle_to(to_mouse)
```

`Node2D.look_at(point: Vector2)` rotates local +X toward `point` (global
coords). `get_angle_to(point) -> float` returns the angle without rotating,
useful for gating a facing check.

---

## 3. Melee arc hitbox (90° wedge)

Two practical options:

**A. `CollisionPolygon2D` wedge** — bake a pie-slice polygon (a handful of
points approximating the arc), swap it in per attack (or scale/rotate a
premade wedge). Pros: true physics shape, works with `area_entered` directly,
cheap once built. Cons: polygon must be authored/regenerated per arc size;
awkward to vary radius/angle at runtime without regenerating points.

**B. Circle Area2D + angle/dot-product filter** — use a plain
`CollisionShape2D` with a `CircleShape2D` for broad-phase, then in
`area_entered`/`body_entered` filter by facing:

```gdscript
func _on_area_entered(area: Area2D) -> void:
    var target := area.get_owner_body()
    var to_target := (target.global_position - global_position).normalized()
    var facing := Vector2.RIGHT.rotated(rotation)
    if facing.dot(to_target) < cos(deg_to_rad(45.0)):  # 90° wedge = ±45°
        return
    # ... apply damage
```

Pros: one circle shape reused for every weapon, arc angle is just a tunable
`@export` float, trivial to widen/narrow per weapon Resource. Cons: extra
per-hit math, hit test is a two-step (shape overlap + dot product) rather
than exact geometry.

**Recommendation:** circle + dot-product filter. It's data-driven-friendly
(arc angle and radius become `@export` fields on the weapon Resource, see
§6) and needs zero per-weapon polygon authoring — fits a component/resource
architecture better than baking geometry per weapon.

---

## 4. Attack timing state machine (windup / active / recovery)

Three options:

| Approach | Cancel-friendly? | Notes |
|---|---|---|
| `Timer` node + `timeout` signal | Poor | Must manually `stop()` + disconnect/guard; state lives partly in signal callbacks, awkward to interrupt mid-phase. |
| `await get_tree().create_timer(t).timeout` | Poor as written | `await` suspends the function; a dodge can't cleanly abort a suspended coroutine without extra bookkeeping (a cancel token). |
| Manual `_process`/`_physics_process` accumulator | **Best** | State lives in plain fields checked every frame; a dodge just sets `state = State.DODGE` and the accumulator loop exits/resets immediately. No suspended coroutine to unwind. |

**Recommendation: manual accumulator**, because combat needs a dodge to
interrupt an attack *mid-frame*, and a suspended `await` can't be aborted
without a cancel-token pattern that ends up reimplementing a state machine
anyway. If you do use `await create_timer`, guard every resume point with a
generation counter so a stale resume is a no-op.

```gdscript
# AttackState.gd (manual, cancel-friendly)
enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

var phase: Phase = Phase.IDLE
var _phase_time: float = 0.0

const WINDUP_TIME := 0.15
const ACTIVE_TIME := 0.10
const RECOVERY_TIME := 0.20

func start_attack() -> void:
    phase = Phase.WINDUP
    _phase_time = 0.0
    hitbox.end_attack()

func cancel_attack() -> void:  # called by dodge input
    phase = Phase.IDLE
    hitbox.end_attack()

func _physics_process(delta: float) -> void:
    if phase == Phase.IDLE:
        return
    _phase_time += delta
    match phase:
        Phase.WINDUP:
            if _phase_time >= WINDUP_TIME:
                phase = Phase.ACTIVE
                _phase_time = 0.0
                hitbox.start_attack()
        Phase.ACTIVE:
            if _phase_time >= ACTIVE_TIME:
                phase = Phase.RECOVERY
                _phase_time = 0.0
                hitbox.end_attack()
        Phase.RECOVERY:
            if _phase_time >= RECOVERY_TIME:
                phase = Phase.IDLE
```

`Timer` is fine for non-cancellable, fire-and-forget things (cooldown
display, boss phase countdown) — use its `timeout` signal there instead of
hand-rolling an accumulator.

---

## 5. i-frames and a parry window — single damage entry point

Represent both as timestamps/timers on the defender, checked in **one**
`take_damage` method — never scattered damage-application sites.

```gdscript
# Health.gd (component)
extends Node
class_name Health

signal died
signal damaged(amount: int)

@export var max_hp: int = 100
var hp: int = max_hp

var _iframes_until: float = -1.0
var _parry_until: float = -1.0

func start_iframes(duration: float) -> void:
    _iframes_until = Time.get_ticks_msec() / 1000.0 + duration

func start_parry_window(duration: float = 0.25) -> void:
    _parry_until = Time.get_ticks_msec() / 1000.0 + duration

func take_damage(amount: int, source: Node) -> void:
    var now := Time.get_ticks_msec() / 1000.0
    if now < _parry_until:
        _on_parried(source)
        return
    if now < _iframes_until:
        return
    hp -= amount
    damaged.emit(amount)
    if hp <= 0:
        died.emit()

func _on_parried(attacker: Node) -> void:
    if attacker.has_method("on_parried"):
        attacker.on_parried()
```

- Every damage path (melee hitbox, projectile, boss AoE) must call
  `Health.take_damage()` — no direct `hp -=` anywhere else. That's the "one
  entry point" the check order (parry → i-frames → apply) depends on.
- `Time.get_ticks_msec()`-based deadlines survive pausing better than
  per-frame counters and don't need a `Timer` node per instance.

---

## 6. Custom Resource for data-driven weapons

```gdscript
# WeaponData.gd
extends Resource
class_name WeaponData

@export var name: String = "Sword"
@export var damage: int = 10
@export var arc_degrees: float = 90.0
@export var arc_radius: float = 60.0
@export var windup_time: float = 0.15
@export var active_time: float = 0.10
@export var recovery_time: float = 0.20
@export var swing_scene: PackedScene   # optional VFX/hitbox scene
```

- Create instances in the editor: Inspector → new script property → "New
  Resource" → pick `WeaponData` → fill fields → **Save As** `.tres` (e.g.
  `data/weapons/sword.tres`). `.tres` is text (diff-friendly); `.res` is
  binary — prefer `.tres` for hand-tuned data.
- Load:

```gdscript
const SWORD := preload("res://data/weapons/sword.tres")  # baked at compile
var current_weapon: WeaponData = load("res://data/weapons/sword.tres")  # runtime path
```

- Reference a scene inside a Resource with `@export var x: PackedScene`, then
  `x.instantiate()` at runtime.
- **Gotcha — shared/cached instances**: `load()`/`preload()` of the same path
  returns the **same cached Resource object** everywhere it's referenced.
  Mutating a loaded `WeaponData` at runtime (e.g. a temporary buff that adds
  +5 damage) mutates it for *every* enemy/player using that `.tres`. Call
  `resource.duplicate()` (or `duplicate(true)` for a deep copy including
  nested sub-resources) before mutating per-instance state:

```gdscript
var my_weapon: WeaponData = SWORD.duplicate()
my_weapon.damage += 5   # only affects this instance
```

  Never mutate a `preload`/`load` result directly unless the change should be
  global for that data asset (e.g. a debug/cheat tool).

---

## 7. Signals

```gdscript
signal hit_landed(target: Node, amount: int)
signal died

hit_landed.emit(target, amount)
```

- Typed signal parameters (`hit_landed(target: Node, amount: int)`) give
  editor autocomplete and catch wrong-arg connects at parse time.
- Connect in code (`hit_landed.connect(_on_hit_landed)`) for combat logic:
  editor-wired connections live in `.tscn` files, are invisible in the
  script, and are easy to silently break when a scene is re-saved or a node
  is renamed. Code connections are greppable, diffable, and refactor-safe —
  important when hitbox/health/brain wiring changes frequently during combat
  tuning. Reserve editor connections for UI-only, rarely-touched wiring.

---

## 8. Composition pattern (component child nodes)

- Components (`Health`, `Hitbox`, `Hurtbox`, `MoveController`, brain nodes)
  are child nodes of the actor scene root (e.g. `Player.tscn`,
  `Boss.tscn`).
- A component finds its owning actor via `owner` (the scene root that
  "owns" it per the `.tscn` file) rather than `get_parent()`, because
  `get_parent()` breaks if the component is re-parented under an
  intermediate node (e.g. a `Components` grouping `Node`), while `owner`
  stays pointed at the actual scene root as long as the node was saved as
  part of that scene.

```gdscript
# inside a component script
func get_actor() -> Node:
    return owner   # the scene root (Player, Boss, ...), not necessarily get_parent()
```

- Use `owner` for "which actor am I attached to"; use `get_parent()` only
  when you specifically need the immediate structural parent (e.g. a
  `Components` container node).
- Groups (`add_to_group("enemies")`, `is_in_group("enemies")`,
  `get_tree().get_nodes_in_group("enemies")`) are the right tool for
  cross-cutting queries ("all enemies", "all hitboxes") that don't belong in
  the ownership hierarchy — e.g. an AoE boss attack querying all
  `"player_hurtbox"` group members instead of walking the tree.

---

## 9. Debug drawing

```gdscript
# on the node whose local space you want to draw in (e.g. Hitbox)
func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    draw_arc(Vector2.ZERO, arc_radius, -deg_to_rad(arc_degrees / 2.0),
              deg_to_rad(arc_degrees / 2.0), 24, Color.RED, 2.0)
    draw_circle(Vector2.ZERO, 4.0, Color.YELLOW)
    draw_line(Vector2.ZERO, Vector2.RIGHT * arc_radius, Color.GREEN, 1.0)
```

- `_draw()` only runs after `queue_redraw()` is called (manually, or once
  automatically on `_ready`); it does not run every frame on its own.
- Built-in: **Debug → Visible Collision Shapes** (editor Debug menu, or
  Project Settings when running from editor) overlays all
  `CollisionShape2D`/`CollisionPolygon2D` outlines at runtime — use this
  before writing custom hitbox-arc gizmos; it already shows the real
  physics shape.
- Slow-motion for readability during tuning: `Engine.time_scale = 0.3`
  (global multiplier on the in-game clock; `1.0` = normal, restore it after
  debugging). Note it scales `_process`/`_physics_process` delta but not
  real-time-based UI/audio unless those also read delta.

---

## 10. Gotchas

- **Physics vs process frame**: all movement, `move_and_slide()`, and
  physics-affecting state changes belong in `_physics_process(delta)`
  (fixed-step), not `_process(delta)` (variable, render-rate). Reading
  input for movement is fine in either, but apply it in
  `_physics_process`.
- **Deferred calls**: toggling `CollisionShape2D.disabled`, `Area2D`
  add/remove-from-tree-adjacent state, or anything read by the physics
  server mid-callback (e.g. from inside `area_entered`) should go through
  `set_deferred("property", value)` / `call_deferred("method")` so the
  change applies after the physics step completes instead of mid-step.
- **`queue_free()` timing**: `queue_free()` doesn't delete the node
  immediately — it's freed at the end of the current frame/idle time.
  Don't assume a freed node is gone or its signals disconnected the instant
  you call it; guard subsequent logic in the same frame (e.g.
  `is_instance_valid(node)`).
- **Collision layer numbering**: the editor shows layers **1-32**, but they
  map to **bits 0-31** internally. If you ever build a raw bitmask by hand
  (`collision_layer = 0b0010`), remember layer "1" in the UI is bit 0, not
  bit 1 — prefer `set_collision_layer_value(n, true)` (1-indexed, matches
  the UI) over hand-built bitmasks to avoid off-by-one layer bugs.
- **`await` + freed nodes**: an `await get_tree().create_timer(t).timeout`
  (or any `await`) resumes even if the awaiting node was freed in the
  meantime unless guarded — check `is_instance_valid(self)` after resuming
  if the node could plausibly be gone.

---

## Sources

- https://docs.godotengine.org/en/stable/classes/class_area2d.html
- https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html
- https://docs.godotengine.org/en/stable/classes/class_input.html
- https://docs.godotengine.org/en/stable/classes/class_timer.html
- https://docs.godotengine.org/en/stable/classes/class_resource.html
- https://docs.godotengine.org/en/stable/classes/class_canvasitem.html
- https://docs.godotengine.org/en/stable/classes/class_engine.html
- https://docs.godotengine.org/en/stable/classes/class_node2d.html
- https://docs.godotengine.org/en/stable/classes/class_object.html
- https://docs.godotengine.org/en/stable/classes/class_scenetree.html
- https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html
- https://docs.godotengine.org/en/stable/classes/class_node.html
