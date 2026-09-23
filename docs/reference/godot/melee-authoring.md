# Melee attack authoring in Godot 4 — how real projects do it

Research for the WeaponData/WeaponVisual/Hitbox split we have today, where the
sword's drawn rotation (`rest_angle_degrees`, `art_angle_degrees`,
`hand_distance`, blade offset) and the hit test (`arc_degrees`, `reach`,
`windup`/`active`/`recovery`) are two disconnected sets of numbers.

## 1. The four approaches, compared

**(a) Pure numeric Resource + code-computed hit test — what we do now.**
`Hitbox._try_hit` does a circle distance check + `angle_to` filter against
`weapon.reach`/`weapon.arc_degrees`, while `WeaponVisual` separately lerps
`Blade.rotation` from `rest_angle_degrees` to `rest + arc_degrees` over the
same phase durations. Two independent implementations of "the swing," kept in
sync only by the human tuning both. This is common in **programmer-art
prototypes and RL/simulation-heavy projects** (state must be legible to code,
not just to an animation curve) but is explicitly called out as a source of
visual/hit mismatch everywhere it's discussed — see the GDQuest and Coding
Quests hitbox guides below, both of which react against exactly this problem
by moving the hitbox into the animation.

**(b) AnimationPlayer drives everything — sprite rotation + hitbox toggle.**
This is the mainstream answer for 2D action games in the Godot community.
GDQuest's own melee guide and the widely-cited Coding Quests / dev.to
hitbox-hurtbox tutorials all converge on: put a `CollisionShape2D` under the
hitbox `Area2D`, leave it `disabled = true` at rest, and add an
`AnimationPlayer` track that flips `disabled` to `false` for exactly the
frames the blade is drawn overlapping the target — driven by scrubbing the
same timeline that moves the sprite. WYSIWYG: what you see in the 2D editor
while scrubbing *is* what will hit.
> "the AnimationPlayer has multiple tracks... in the slash track, you
> uncheck the Disabled property on the CollisionShape2D only during the part
> of the animation that corresponds to the attack." — GDQuest,
> *Handling melee attacks and damage with hitboxes and hurtboxes*

**(c) Hand-placed Area2D + CollisionPolygon2D shaped to the art, no animation
at all** (a single static swing shape, or one shape per attack "pose").
Used for simple/fast attacks (a stab, a single fixed swipe) where there's no
real windup arc to animate — you draw a polygon once in the 2D editor over
the weapon art and toggle it on/off with a `Timer` or direct code. Rare on
its own in full action games; usually shows up as an ingredient of (b) or as
a placeholder before an artist delivers real swing frames.

**(d) Hybrids — this is what most shipped/serious hobby projects actually
land on**, and it's also the fix for us:
- Sprite rotation/position is still driven by code or a tween (so it can
  react to `aim_direction` at runtime, which a baked animation alone can't
  do for a freely-aimed top-down weapon) — **but** the hitbox shape is a
  **child of the same pivot node as the sprite**, so it inherits rotation
  for free instead of being recomputed from an angle in a second place.
- Or: the *shape and duration* come from an `AnimationPlayer`/`Tween`, and
  only the *balance numbers* (damage, cooldown, knockback) stay in a
  Resource — see §3.

Verdict: for a **top-down freely-aimed weapon** (ours — the whole
`WeaponVisual` node rotates to `aim_angle` every frame), a full baked
`AnimationPlayer` timeline for the swing *arc* fights the aiming system,
because the animation would have to be re-authored per aim angle. What
transfers cleanly from the community consensus is not "bake the whole swing
in an AnimationPlayer" but **"the hitbox must be a child of the same
transform that draws the blade, not a second independently-computed
shape."** That's approach (d), and it is compatible with keeping our
windup/active/recovery timeline in code.

## 2. Keeping sprite and hitbox in agreement — node hierarchy

The recurring pattern across every source (GDQuest, Coding Quests, the
dev.to hitbox/hurtbox writeup, kidscancode's older but still-cited Godot 3
recipe) is **the hitbox is a child of the weapon/pivot node, not a sibling
computed from angle math**:

```
WeaponVisual (Node2D)              # rotates to aim_angle — the "pivot"
└── Blade (Sprite2D)               # rest_angle/art_angle applied to THIS node
    └── HitArea (Area2D)           # child of Blade — inherits its rotation
        └── CollisionShape2D       # authored once in the 2D editor, over the art
            (disabled = true at rest)
```

Concretely: a shape sized/positioned to visually match the sword art is
drawn *once* in the editor as a child of the sprite (or of the pivot the
sprite hangs off). Because Godot 2D nodes inherit parent transforms,
whenever the pivot rotates for the swing, the child collision shape rotates
with it automatically — there is no second `arc_degrees`/`reach` computation
that can drift from what's drawn. The Area2D's `monitoring`/collision-shape
`disabled` state (whether it can currently hit something) is toggled by an
animation track or by the windup/active/recovery state machine — but *where*
it can hit is purely inherited transform, never re-derived from numbers.

This is the direct fix for our bug: `Hitbox` currently lives as its own node
computing `to_target.length() > weapon.reach` and
`angle_to(...) > arc_degrees/2` from scratch, fully decoupled from
`WeaponVisual.Blade`. If `Hitbox` (or a `CollisionShape2D` under it) were
instead parented under `WeaponVisual`/`Blade` and shaped in the editor to
match the blade texture, the "does the drawn sword agree with the hit
area" question stops being a question — they're the same transform.

## 3. Where do the balance numbers live?

Universal split, confirmed by every source that discusses data-driven combat
(and matches decision 0005 in this repo already): **shape/timing is
authored where it's visually checked (editor/animation); numbers that don't
have a visual form stay in a Resource.**

| Authored visually (scene/animation) | Data in a Resource |
|---|---|
| Hit area shape (`CollisionShape2D`/`CollisionPolygon2D`) | `damage` |
| When the hitbox is live (animation track / state timing) | `knockback_force` |
| Blade rotation/position during the swing | `cooldown` / `windup`/`active`/`recovery` (if not baked into anim length) |
| VFX/SFX trigger points (call-method tracks) | `crit_chance`, status effects, etc. |

Our `WeaponData` (`damage`, `windup`, `active`, `recovery`, `arc_degrees`,
`reach`, `color`) is already almost entirely on the right side of this
split — `damage` clearly belongs in data. The problem is only that
`arc_degrees`/`reach` are *also* trying to describe a visual shape
numerically instead of deferring to one authored on the node.

## 4. Reuse across many weapons without N AnimationPlayers

This is the part sources are least uniform on — flagged as **UNVERIFIED
where noted**, since it's closer to studio convention than documented best
practice.

- **`AnimationLibrary`** (Godot 4 proper, since 4.0): animations are stored
  in named libraries and can be shared — "Animations should first be
  imported to an AnimationLibrary, and then this library set into the
  respective players." One shared "swing" library can be attached to every
  weapon's `AnimationPlayer` instead of hand-copying keys per weapon.
  Godot docs: `AnimationLibrary`, `AnimationMixer.add_animation_library`.
- **Shared animation, different sprite**: if only the *texture* changes
  between weapons (not the swing shape/timing), don't reanimate — animate
  the pivot/blade node once, swap `Sprite2D.texture` per `WeaponData`
  (this is exactly what our `WeaponVisual.blade_texture` export already
  does — keep it).
- **`AnimationTree`**: used when weapons need *blended* states (e.g.
  movement + attack overlay, or choosing between light/heavy swing
  animations at runtime) — overkill for a single linear windup→active→
  recovery swing. Not recommended for us unless we add combo/blend states.
- **`speed_scale` to fit a tuned duration**: play one canonical swing
  animation and set `AnimationPlayer.speed_scale = base_active_duration /
  weapon.active` so fast/slow weapons reuse one timeline. This is the
  cleanest way to keep `WeaponData.windup/active/recovery` as the
  per-weapon numeric knobs while still having only one authored curve.
  UNVERIFIED as a named "industry pattern" (no single canonical source
  states it directly), but it follows straightforwardly from
  `AnimationPlayer.speed_scale`'s documented behavior and is a common
  forum-recommended technique for exactly this reuse problem.
- **Procedural tween-based swings** (what `WeaponVisual` already does —
  `lerpf` between phase angles driven by `weapon.windup/active/recovery`):
  this *is* one of the legitimate answers for "many weapons, one code path,"
  and scales better than N animations when the only per-weapon variation is
  numeric (arc width, reach, duration) rather than a genuinely different
  motion shape (stab vs. slash vs. spin). Projects with large weapon counts
  and simple, similar swing shapes (most top-down arc weapons) generally
  prefer this over N `AnimationPlayer`s per weapon. UNVERIFIED as a
  documented "20+ weapons" case study — inferred from how `AnimationLibrary`
  and `speed_scale` are discussed, not from a single confirmed source doing
  it at that scale.

Practical takeaway: **keep our tween-driven `WeaponVisual`** (it already
solves the reuse problem better than per-weapon AnimationPlayers would), but
fix §2 — hitbox must be parented to the same rotating node instead of
recomputing the arc from `weapon.arc_degrees`/`reach` a second time.

## 5. Godot 4 specifics

- **`Area2D.monitoring` vs `CollisionShape2D.disabled`**: both work; the
  community leans toward toggling `disabled` on the shape (cheaper, and
  each shape can be toggled independently if a hitbox has multiple parts),
  while `monitoring` toggles the whole Area2D's ability to report overlaps
  at once. Coding Quests: "If you don't do that, Godot will check for
  collisions even when you don't need the results and that can quickly get
  costly."
- **The deferred-call trap**: changing `monitoring`/`monitorable`/`disabled`
  from inside a physics callback (`_physics_process`, `area_entered`, etc.)
  can be silently ignored or throw an engine warning, because Godot is
  mid-physics-step. Fix: `set_deferred("disabled", true)` /
  `set_deferred("monitoring", false)` instead of a direct property write.
  Confirmed by the Godot forum thread on exactly this
  ("Changing the monitoring property on a child node via function call")
  and by open engine issues (#62506, #100421) describing inconsistent
  behavior on non-deferred changes. **Our own `Hitbox.start_swing()`/
  `end_swing()` currently set `_active` directly and poll in
  `_physics_process` rather than touching `monitoring`/`disabled` — this
  sidesteps the deferred-call trap entirely, which is fine and worth
  keeping if we move to shape-based toggling: prefer a plain bool flag
  checked in `_physics_process` over flipping `disabled` every frame from
  physics code.**
- **`Marker2D`** is the standard way to mark a hand/muzzle attach point in
  the editor (visible gizmo, zero runtime cost, no collision/rendering) —
  used for "where does the weapon attach" or "where do projectiles spawn
  from," which is what our numeric `hand_distance` is standing in for.
- **`RemoteTransform2D`**: lets one node's transform drive a *different*
  branch of the tree (e.g. a weapon scene instanced outside the character
  hierarchy but still following a hand `Marker2D`). Only worth it if the
  weapon is a separately-instanced scene rather than a child under the
  character — not obviously needed for our single `WeaponVisual` child node,
  but relevant if boss weapons ever need to be spawned/swapped as standalone
  scenes.
- **`speed_scale`**: see §4 — scales an authored animation's playback rate
  without re-keying it, the mechanism for one shared swing curve fitting
  many `WeaponData.active` durations.
- **Previewing a hitbox in the editor**: because a `CollisionShape2D` is a
  real scene node, selecting it in the 2D editor shows its shape directly
  over the sprite — this is the actual payoff of approach (b)/(d): the
  "does this match the art" check is a visual editor check, not a
  play-and-eyeball-it loop. This is the concrete answer to the numbers-only
  approach's core problem.

## 6. Designer workflow: "I want to add a new sword"

Target end state (after the migration in the recommendation below):

1. Duplicate an existing `.tres` (`WeaponData`) → set `damage`, `windup`,
   `active`, `recovery`. These stay pure numbers, no visual authoring needed.
2. Drop the new blade texture into `WeaponVisual.blade_texture` (or a new
   weapon scene that reuses `WeaponVisual`).
3. If the new blade's silhouette is a meaningfully different shape (longer,
   wider, curved) from the existing hit-shape child, open the weapon scene,
   select the `CollisionShape2D` under the blade, and drag its handles in
   the 2D editor until it visually covers the new art. Nothing to compute —
   what's drawn is what hits.
4. If it's the same silhouette as an existing weapon (just reskinned —
   most "add a new sword" cases), **skip step 3 entirely** — the inherited
   hit shape already matches because it's parented to the sprite, not
   recomputed from `arc_degrees`.
5. Press play, swing it, done. No `arc_degrees`/`reach`/`rest_angle_degrees`
   triangulation against a second set of numbers.

Compare to today: adding a weapon means picking `arc_degrees`/`reach` in
`WeaponData` *and* `hand_distance`/`rest_angle_degrees`/`art_angle_degrees`/
`blade_offset` in `WeaponVisual`, then playtesting repeatedly until the
drawn blade and the hit wedge visually agree — exactly the slow, eyeballed
loop the task description flags.

## Recommendation for BossFight

**Change:**
- Make the hitbox shape a child of `WeaponVisual`/`Blade` (or of a shared
  pivot both the sprite and the shape hang off), authored as a
  `CollisionShape2D`/`CollisionPolygon2D` in the 2D editor sized to the
  blade art — not derived from `weapon.arc_degrees`/`weapon.reach` via
  `angle_to`/distance math in `Hitbox._try_hit`.
- `Hitbox._try_hit` becomes a plain overlap check (`get_overlapping_areas()`
  already does the query) with **no angle/reach filtering** — the shape
  *is* the filter, because it's drawn where the blade actually is.
- Keep `weapon.reach`/`weapon.arc_degrees` only as inputs to the *telegraph*
  wedge draw in `WeaponVisual._draw()` (a preview aid, not a hit source of
  truth) — or drop them from `WeaponData` entirely once the shape is
  authored, and derive the telegraph wedge from the collision shape's
  bounds instead.

**Keep:**
- The tween-driven `WeaponVisual` (`_process` lerping `_blade_angle` across
  windup/active/recovery) — this is a legitimate, more-reusable alternative
  to per-weapon `AnimationPlayer`s per §4, and it already correctly reads
  all timing from `WeaponData`, never hardcoded.
- `WeaponData` as the balance-number Resource (`damage`,
  `windup`/`active`/`recovery`, `color`) — right split per §3.
- `WeaponHolder`'s phase state machine — orthogonal to this problem, no
  change needed.
- `hand_distance`/`rest_angle_degrees`/`art_angle_degrees` for positioning
  the sprite — these have no equivalent in the hit test once the hitbox
  inherits the same transform, so the "two sets of numbers disagreeing"
  problem disappears by construction rather than by tuning.

**Migration order (smallest safe steps):**
1. Add a `CollisionShape2D` as a child of `WeaponVisual/Blade` in the scene,
   shaped to the current placeholder blade art. Leave `Hitbox`'s existing
   `weapon.reach`/`arc_degrees` check in place but unused/dead for now — get
   the shape visually right first, in isolation.
2. Reparent `Hitbox` (the `Area2D`) itself under `WeaponVisual/Blade`
   instead of wherever it sits today, so its collision shape rotates for
   free. Update `hitbox_path` in the `WeaponHolder` scene wiring
   accordingly.
3. Simplify `Hitbox._try_hit` to drop the angle/reach filter now that the
   shape does that job; keep `_hit_this_swing` dedup logic as-is.
4. Remove `arc_degrees`/`reach` from `WeaponData` (or repurpose them
   *only* for the telegraph wedge, clearly commented as visual-preview-only,
   not hit-authoritative) once the shape-based hit test is verified against
   the existing arc-weapon behavior tests, if any exist.
5. Re-verify with `godot --headless --check-only` and a manual playtest
   swing against a stationary target dummy, per CLAUDE.md rule 2 (gameplay
   feel needs a human playtest either way).

## Sources

- GDQuest, *Handling mêlée attacks and damage with hitboxes and hurtboxes*
  (Godot 4) — https://www.gdquest.com/library/hitbox_hurtbox_godot4/
- Coding Quests, *Godot 4 Hitbox and Hurtbox Tutorial* —
  https://codingquests.io/blog/godot-4-hitbox-hurtbox-tutorial
- dev.to / saltmire, *Godot 4 hitbox and hurtbox the easy way (damage,
  teams, i-frames, knockback)* —
  https://dev.to/saltmire/godot-4-hitbox-and-hurtbox-the-easy-way-damage-teams-i-frames-knockback-1ccj
- kidscancode, *Melee attacks* (Godot 3 Recipes — pattern still cited/valid
  for the node-hierarchy approach) —
  https://kidscancode.org/godot_recipes/3.x/animation/melee_attacks/index.html
- Godot Forum, *Unpause $AnimationPlayer re-enables disabled
  CollisionShape2D* —
  https://forum.godotengine.org/t/unpause-animationplayer-re-enables-disabled-collisionshape2d/38723
- Godot Forum, *Changing the monitoring property on a child node via
  function call* —
  https://forum.godotengine.org/t/changing-the-monitoring-property-on-a-child-node-via-function-call/4230
- godotengine/godot issue #62506, *set_deferred() and call_deferred() on
  Area2D monitoring/monitorable reports collisions inconsistently* —
  https://github.com/godotengine/godot/issues/62506
- godotengine/godot issue #100421, *Undeferred calls in Area(2d/3d) that
  should be deferred give wrong information output to debugger error* —
  https://github.com/godotengine/godot/issues/100421
- Godot Engine docs, `Area2D` —
  https://docs.godotengine.org/en/stable/classes/class_area2d.html
- Godot Engine docs, `Marker2D` —
  https://docs.godotengine.org/en/stable/classes/class_marker2d.html
- Godot Engine docs, `RemoteTransform2D` —
  https://docs.godotengine.org/en/stable/classes/class_remotetransform2d.html
- godotengine-proposals #4296, *Implement AnimationLibrary resource and
  respective importer* (background on `AnimationLibrary`'s purpose) —
  https://github.com/godotengine/godot-proposals/issues/4296
- GDQuest, *Juicing up your game attacks* (Marker2D pivot + `look_at()` for
  weapon rotation toward aim) — https://www.gdquest.com/library/juicy_attack/
- crystal-bit/godot4-top-down-2d (example Godot 4 top-down project) —
  https://github.com/crystal-bit/godot4-top-down-2d
- jasper-flick/godot-true-top-down-2d (example Godot 4 top-down project) —
  https://github.com/jasper-flick/godot-true-top-down-2d

Local files read for context: `scripts/visual/weapon_visual.gd`,
`scripts/weapons/weapon_holder.gd`, `scripts/weapons/weapon_data.gd`,
`scripts/components/hitbox.gd`, `docs/decision/0005-architecture.md`.
