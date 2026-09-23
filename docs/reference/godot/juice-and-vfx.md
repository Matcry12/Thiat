# Juice & VFX (code-only, no sprites needed)

Every technique here runs on a bare `Polygon2D`, `ColorRect`, or `_draw()` shape.
None require an imported texture. When sprites arrive later, swap the node's
visual (texture/AnimatedSprite2D) in — the juice code (tween/shader/camera/
particle calls) keeps working unchanged because it targets the *node*
(`modulate`, `scale`, `position`), not pixel content.

Core references: Martin Jonasson & Petri Purho, "Juice it or lose it" (GDC 2012);
Vlambeer, "The Art of Screenshake" (GDC 2013); Chris Zukowski's summaries of
Nuclear Throne / Hades feel postmortems. URLs in Sources.

---

## 1. Hit-stop / freeze frames

Freeze the game (or just the two combatants) for a few ms on impact. Sells
that a hit *landed* — the single highest-value trick per line of code.

Two options:

**A. Global `Engine.time_scale`** — cheapest, but freezes UI, timers,
animations, everything.

```gdscript
func hit_stop(duration := 0.05, scale := 0.02) -> void:
    Engine.time_scale = scale
    await get_tree().create_timer(duration * scale, true, false, true).timeout
    Engine.time_scale = 1.0
```

`true, false, true` = process_always, process_in_physics, ignore_time_scale —
that last flag is what lets the timer itself count down in *real* time
despite `time_scale` being tiny. Gotcha: any `AnimationPlayer`, `Tween`,
particle emitter, or `_process` delta-based UI countdown will also crawl
unless it uses `Engine.get_process_frames()`-independent timers or you flag
it to ignore time scale. Test menus/HUD during a hit-stop before shipping it.

**B. Local freeze** — pause only attacker + victim via `set_process`/
`set_physics_process(false)`. More code, but the rest of the game (particles,
camera, other enemies) keeps moving, which usually reads *better* in a
crowded fight.

```gdscript
func local_hit_stop(actors: Array[Node], duration := 0.05) -> void:
    for a in actors:
        a.set_physics_process(false)
    await get_tree().create_timer(duration).timeout
    for a in actors:
        a.set_physics_process(true)
```

Start value: **0.04–0.08s**. Longer reads as lag, not weight.

---

## 2. Screen shake (trauma-based)

Naive `position += Vector2(randf_range(-a,a), randf_range(-a,a))` looks
jittery and doesn't decay smoothly. Use **trauma** (0–1 float), square it for
the actual shake amount — this gives a sharp punch that tapers off instead of
linear falloff, per Vlambeer's talk.

```gdscript
extends Camera2D

var trauma := 0.0
var trauma_decay := 1.4          # per second
var max_offset := 16.0           # px
var max_roll := 0.05             # radians
var noise := FastNoiseLite.new()
var noise_t := 0.0

func _ready() -> void:
    noise.seed = randi()
    noise.frequency = 4.0

func add_trauma(amount: float) -> void:
    trauma = clampf(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
    trauma = maxf(trauma - trauma_decay * delta, 0.0)
    var shake := trauma * trauma          # trauma squared
    if shake > 0.0:
        noise_t += delta * 30.0
        offset = Vector2(
            max_offset * shake * noise.get_noise_2d(noise_t, 0.0),
            max_offset * shake * noise.get_noise_2d(0.0, noise_t)
        )
        rotation = max_roll * shake * noise.get_noise_2d(noise_t, noise_t)
    else:
        offset = Vector2.ZERO
        rotation = 0.0
```

Use `FastNoiseLite` sampled over time instead of `randf()` per frame —
Perlin/simplex noise shakes smoothly instead of teleporting between random
points, which looks far less epileptic at low trauma.

Start values: light hit `add_trauma(0.3)`, big hit/boss slam `add_trauma(0.6)`,
death/ultimate `add_trauma(1.0)`. `trauma_decay = 1.4`.

Directional shake for a big hit: bias the noise offset along the hit normal
instead of both axes equally (`offset = hit_dir * max_offset * shake` mixed
with the noise term) so a shove reads as "pushed that way" not generic jitter.

---

## 3. Hit flash

**Cheap version — `modulate`,** works on any `CanvasItem` including
`Polygon2D`:

```gdscript
func hit_flash(node: CanvasItem, duration := 0.08) -> void:
    var orig := node.modulate
    node.modulate = Color(4, 4, 4, 1)   # overbright white via >1 values
    var t := create_tween()
    t.tween_property(node, "modulate", orig, duration)
```

`Color(4,4,4,1)` works because Godot's default (non-HDR) canvas blending
still clamps to white-ish at >1 multiply against most base colors; if your
shape's base color is pale, use straight `Color.WHITE` instead.

**Shader version — mixes toward white without touching modulate,** so it
composes with color tints and survives the sprite swap (works identically on
`Polygon2D` and `Sprite2D` since both are `CanvasItem`):

```glsl
// hit_flash.gdshader
shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    COLOR = mix(tex, vec4(flash_color.rgb, tex.a), flash_amount);
}
```

```gdscript
func hit_flash_shader(node: CanvasItem, mat: ShaderMaterial, duration := 0.08) -> void:
    mat.set_shader_parameter("flash_amount", 1.0)
    var t := create_tween()
    t.tween_method(
        func(v): mat.set_shader_parameter("flash_amount", v),
        1.0, 0.0, duration
    )
```

Assign `mat` as the node's `material`. On a plain `Polygon2D` it flashes the
fill color; drop in a `Sprite2D` later with the same material and it flashes
the texture the same way. Start value: 0.06–0.1s, full white.

---

## 4. Squash & stretch / scale punch

Godot 4 tweens: `create_tween()` on the node (auto-freed, no manual node
needed).

```gdscript
func scale_punch(node: Node2D, amount := Vector2(1.3, 0.7), duration := 0.25) -> void:
    node.scale = amount
    var t := create_tween()
    t.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    t.tween_property(node, "scale", Vector2.ONE, duration)
```

- **On dash start**: stretch along move direction, `Vector2(1.4, 0.75)`,
  `TRANS_BACK`/`EASE_OUT`, ~0.15s — sells acceleration.
- **On landing a hit** (attacker): quick punch `Vector2(1.2, 1.2)` → 1.0,
  `TRANS_ELASTIC`, 0.2s.
- **On taking a hit** (victim): squash perpendicular to the hit normal,
  `Vector2(0.8, 1.2)` → 1.0, `TRANS_BACK`, 0.15s — reads as absorbing impact.

`TRANS_ELASTIC` overshoots and wobbles (good for punchy hits), `TRANS_BACK`
overshoots once then settles (good for weightier squash). Try both, pick by
eye.

---

## 5. Knockback & recoil

Two separate motions, both cheap tweens on `position`:

```gdscript
# Attacker recoils backward on their own swing — sells that the weapon has mass.
func attack_recoil(attacker: Node2D, dir: Vector2, amount := 6.0, duration := 0.12) -> void:
    var start := attacker.position
    var t := create_tween()
    t.tween_property(attacker, "position", start - dir * amount, duration * 0.3)
    t.tween_property(attacker, "position", start, duration * 0.7)

# Victim gets pushed — actual gameplay knockback, not just cosmetic.
func apply_knockback(victim: CharacterBody2D, dir: Vector2, force := 300.0) -> void:
    victim.velocity += dir * force   # let existing move_and_slide() consume it
```

The attacker-recoil is *purely cosmetic* (tween, not physics) and is the
cheap surprise win here — most devs only push the victim and the attack
still feels weightless because the swinger itself never reacts. 4–8px recoil,
0.1–0.15s total, is enough; more reads as stagger.

---

## 6. Particles

`GPUParticles2D` (GPU, needs `one_shot` for bursts) vs `CPUParticles2D`
(CPU, no compute-shader requirement, works on old/software renderers,
easier to inspect per-particle in code). Use CPU particles when: targeting
mobile/low-end GPUs, running headless-ish tests, or you need to read/mutate
particle state from GDScript (GPU particles are opaque, computed on GPU).
Otherwise prefer GPU particles for count/performance.

One-shot burst pattern (works for both — swap the class name):

```gdscript
func spawn_burst(scene_root: Node, pos: Vector2, count := 12) -> void:
    var p := CPUParticles2D.new()
    scene_root.add_child(p)
    p.global_position = pos
    p.emitting = false
    p.one_shot = true
    p.amount = count
    p.lifetime = 0.4
    p.explosiveness = 1.0            # all particles fire at once, not streamed
    p.direction = Vector2.UP
    p.spread = 180.0
    p.initial_velocity_min = 80.0
    p.initial_velocity_max = 220.0
    p.gravity = Vector2(0, 400)
    p.scale_amount_min = 2.0
    p.scale_amount_max = 4.0
    p.color = Color(1, 0.9, 0.3)     # spark yellow; dust would be gray, low alpha
    p.emitting = true
    p.finished.connect(p.queue_free)  # GPUParticles2D has the same `finished` signal
```

Even with primitive art, `CPUParticles2D`'s default point/square draw mode
gives visible sparks/dust with zero texture. Use:
- **Dust on dash**: gray, low velocity, `gravity ~200`, spawn at feet.
- **Sparks on parry**: bright yellow/white, high velocity, `spread 60`
  aimed away from the blocked hit, short lifetime (0.2s).
- **Impact burst**: color-matched to the hit (red for damage, white for
  block), `explosiveness = 1.0`, `amount 8–16`.

`explosiveness = 1.0` is the key one-shot setting — without it particles
trickle out over `lifetime` instead of firing together.

---

## 7. Trails

`Line2D` following recent positions, points culled/faded over time.

```gdscript
extends Line2D
class_name Trail2D

@export var target: Node2D
@export var max_points := 20
@export var point_lifetime := 0.3

var _ages: Array[float] = []

func _ready() -> void:
    # Alpha 1 -> 0 along the strip; set once, never touched per-frame.
    gradient = Gradient.new()
    gradient.set_color(0, Color(1, 1, 1, 1))
    gradient.set_color(1, Color(1, 1, 1, 0))
    width_curve = Curve.new()
    width_curve.add_point(Vector2(0, 1.0))
    width_curve.add_point(Vector2(1, 0.0))

func _process(delta: float) -> void:
    add_point(target.global_position)
    _ages.append(0.0)
    for i in _ages.size():
        _ages[i] += delta
    while _ages.size() > 0 and _ages[0] > point_lifetime:
        _ages.pop_front()
        remove_point(0)
```

The `gradient`/`width_curve` are set once in `_ready()` — Godot maps them
across the strip (point 0 = newest = opaque/wide, last point = oldest =
transparent/thin) automatically, no per-point loop needed. For a
dash trail, attach `Trail2D` to the player and enable it for the dash
duration + `point_lifetime` after. For a sword arc, spawn a short-lived
`Trail2D` on the weapon tip, active only during the swing animation window,
`queue_free()` after `point_lifetime` past swing end.

Start values: `max_points ~20`, `point_lifetime 0.2–0.3s`, `width ~8px`
tapering to 0 via `width_curve`.

---

## 8. Telegraph rendering

Ground indicator that fills/expands to read as a countdown timer — critical
for boss attacks being fair. Two approaches, same visual goal:

**`_draw()` version** (works with zero shader knowledge):

```gdscript
extends Node2D
class_name Telegraph

@export var radius := 80.0
@export var duration := 1.0
var _t := 0.0
var _active := false

func start() -> void:
    _t = 0.0
    _active = true
    show()

func _process(delta: float) -> void:
    if not _active:
        return
    _t += delta
    queue_redraw()
    if _t >= duration:
        _active = false
        hide()
        # emit_signal telegraph finished -> apply damage here

func _draw() -> void:
    var frac := clampf(_t / duration, 0.0, 1.0)
    var color := Color.ORANGE.lerp(Color.RED, frac)
    color.a = 0.35 + 0.35 * frac              # more opaque as it fills
    draw_circle(Vector2.ZERO, radius, color)
    draw_arc(Vector2.ZERO, radius, 0, TAU * frac, 32, Color.WHITE, 3.0)
```

**Shader version** (radial fill, offloads the wedge math to GPU, reusable
across any telegraph shape by feeding `fill_amount`):

```glsl
// telegraph.gdshader
shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color_start : source_color = vec4(1.0, 0.55, 0.0, 0.4); // orange
uniform vec4 color_end : source_color = vec4(1.0, 0.1, 0.1, 0.7);    // red

void fragment() {
    vec2 centered = UV - vec2(0.5);
    float dist = length(centered) * 2.0;
    float angle = atan(centered.y, centered.x) + 3.14159265;
    float wedge = step(angle / 6.2831853, fill_amount);
    float ring = smoothstep(1.0, 0.95, dist);
    vec4 col = mix(color_start, color_end, fill_amount);
    COLOR = vec4(col.rgb, col.a * ring * wedge);
}
```

Apply to a `ColorRect` sized to the telegraph's bounding box, tween
`fill_amount` 0→1 over the warning duration with `create_tween().tween_property`.

Orange→red lerp keyed on `fill_amount`/`frac` is what makes it read as "time
running out" — pure alpha fade doesn't communicate urgency as clearly as a
color-temperature shift.

---

## 9. Camera feel

```gdscript
extends Camera2D

@export var follow_target: Node2D
@export var follow_speed := 6.0
@export var lead_amount := 60.0

func _physics_process(delta: float) -> void:
    var aim_dir := (get_global_mouse_position() - follow_target.global_position).normalized()
    var target_pos := follow_target.global_position + aim_dir * lead_amount
    global_position = global_position.lerp(target_pos, 1.0 - exp(-follow_speed * delta))

func zoom_punch(amount := 0.85, duration := 0.3) -> void:
    var orig := zoom
    zoom = orig * (1.0 / amount)   # snap in
    var t := create_tween()
    t.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    t.tween_property(self, "zoom", orig, duration)
```

`1.0 - exp(-speed * delta)` is frame-rate-independent lerp (exponential
decay) — plain `lerp(pos, target, follow_speed * delta)` drifts at high/low
FPS, this doesn't. Set `limit_left/top/right/bottom` (Camera2D properties in
the inspector or via code) to the arena bounds so the camera never shows
outside the play area — do this even with placeholder art, it's free and
players notice immediately if it's missing.

`zoom_punch` on boss phase transitions: snap zoom in ~15%, elastic-ease back
out over 0.3s. Reads as "something big just happened" for near-zero cost.

---

## 10. Damage numbers

Pooled `Label` nodes, arc via tween, recycled instead of `queue_free`/
instantiate every hit (hit-spam is the case that makes pooling worth it).

```gdscript
extends Node2D
class_name DamageNumberPool

const POOL_SIZE := 24
var _pool: Array[Label] = []
var _next := 0

func _ready() -> void:
    for i in POOL_SIZE:
        var l := Label.new()
        l.visible = false
        l.z_index = 100
        add_child(l)
        _pool.append(l)

func pop(pos: Vector2, amount: int, crit := false) -> void:
    var l := _pool[_next]
    _next = (_next + 1) % POOL_SIZE
    l.text = str(amount)
    l.modulate = (Color.YELLOW if crit else Color.WHITE)
    l.scale = Vector2.ONE * (1.4 if crit else 1.0)
    l.global_position = pos
    l.visible = true

    var t := create_tween()
    t.set_parallel(true)
    t.tween_property(l, "global_position", pos + Vector2(randf_range(-20,20), -60), 0.6) \
     .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    t.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.2)
    t.set_parallel(false)
    t.tween_callback(func(): l.visible = false)
```

Arc reads better than straight-up motion: bias the horizontal offset by hit
direction, and use `EASE_OUT` on the Y so it decelerates like it's arcing
under gravity rather than flying at constant speed.

---

## 11. Audio placeholder juice

Even one generic `AudioStreamPlayer.play()` on hit changes perceived feel
more than most visual work — sound confirms the hit registered before the
eye finishes processing the flash/shake. Don't skip audio because sprites
aren't done; a sine-wave blip beats silence.

```gdscript
@onready var hit_sfx: AudioStreamPlayer = $HitSFX

func play_hit_sound() -> void:
    hit_sfx.pitch_scale = randf_range(0.92, 1.08)
    hit_sfx.play()
```

Randomizing `pitch_scale` ±5–10% avoids "machine-gun" ear fatigue from the
exact same sample repeating on every hit in a combo — the single cheapest
audio-feel fix that exists. Do this from the start even with a placeholder
blip; swapping the real SFX in later doesn't require touching this code.

---

## 12. Priority order — best feel per line of code

If you can only build a handful of these, in order:

1. **Hit-stop** (#1) — ~5 lines, single biggest "did that land" signal.
2. **Hit flash via `modulate`** (#3, cheap version) — ~4 lines, instant
   visual confirmation, works on any `CanvasItem` day one.
3. **Screen shake, trauma-based** (#2) — one `Camera2D` script, reused for
   every impact in the game afterward.
4. **Audio pitch randomization** (#11) — ~2 lines, disproportionate return,
   often skipped because "no real SFX yet" — wrong reasoning, use a blip.
5. **Scale punch / squash & stretch** (#4) — one reusable tween helper,
   covers dash, hit-landed, and hit-taken with the same function.

Everything else (particles, trails, telegraphs, damage numbers, camera lead/
zoom) is real value but higher setup cost or narrower scope (telegraphs only
matter once bosses exist, trails only matter once dash/sword arcs exist) —
add them once the core loop already feels good.

---

## Sources

- Jonasson, M. & Purho, P., "Juice it or lose it" (GDC 2012) — https://www.youtube.com/watch?v=Fy0aCDmgnxg
- Vlambeer, "The Art of Screenshake" (GDC 2013) — https://www.youtube.com/watch?v=AJdEqssNZ-U
- Godot Docs, `Camera2D` — https://docs.godotengine.org/en/stable/classes/class_camera2d.html
- Godot Docs, `Tween` — https://docs.godotengine.org/en/stable/classes/class_tween.html
- Godot Docs, `Tween.TransitionType` / `EaseType` — https://docs.godotengine.org/en/stable/classes/class_tween.html#enumerations
- Godot Docs, `Engine` (`time_scale`) — https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-time-scale
- Godot Docs, `SceneTreeTimer` / `create_timer` — https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-method-create-timer
- Godot Docs, `GPUParticles2D` — https://docs.godotengine.org/en/stable/classes/class_gpuparticles2d.html
- Godot Docs, `CPUParticles2D` — https://docs.godotengine.org/en/stable/classes/class_cpuparticles2d.html
- Godot Docs, `Line2D` — https://docs.godotengine.org/en/stable/classes/class_line2d.html
- Godot Docs, `CanvasItem` (`_draw`, `draw_circle`, `draw_arc`, `modulate`) — https://docs.godotengine.org/en/stable/classes/class_canvasitem.html
- Godot Docs, canvas_item shader — https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html
- Godot Docs, `FastNoiseLite` — https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html
- Godot Docs, `AudioStreamPlayer` (`pitch_scale`) — https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html
- Chris Zukowski, "How juicy should your game be?" (design notes referencing Vlambeer/Nuclear Throne feel) — https://howtomarketagame.com/2022/03/07/how-juicy-should-your-indie-game-be/
