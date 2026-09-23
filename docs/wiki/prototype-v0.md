# Prototype v0 — Combat Scratch Build

**Goal:** one room, one player, one boss, combat that feels good. Nothing else.

Judged by a single question: *is the fight fun with zero art?* If yes, the design is
right and everything after is production. If no, no amount of sprites fixes it.

Design source: [design-pillars.md](design-pillars.md). Decisions:
[0002 PC-first](../decision/0002-pc-first.md),
[0003 loadout](../decision/0003-loadout-and-swapping.md),
[0004 dodge](../decision/0004-dodge.md).

---

## 1. Art: primitives only

No sprites, no pixel art, no animation frames. Everything is a circle or a rectangle
drawn in code (`Polygon2D` / `_draw()`), flat color, no outline art.

| Thing | Shape | Color |
|---|---|---|
| Player | circle, r=16 | white |
| Player facing | short line from center to cursor | white |
| Melee swing | 90 deg arc wedge, 1 frame | white, fades in 0.1s |
| Projectile | small circle r=4 | cyan (player) / magenta (enemy) |
| Trash enemy | circle r=14 | red |
| Boss | circle r=48 | dark red |
| Boss part (fist/add) | circle r=20 | dark red, lighter outline |
| AoE telegraph | ground circle/rect outline, fills over the windup | orange -> red |
| Wall / arena | rectangle | grey |
| Hit feedback | flash the shape white for 0.05s | — |

Rules:
- **Color is the only visual language.** Orange-to-red fill = "damage lands here, now."
  Same grammar for every attack, every enemy. Never a second telegraph style.
- **Readable silhouettes beat detail.** If a fight is confusing as circles, it is a
  design problem, not an art problem. Fix it here.
- Placeholder art is *permanent* for v0. No "quick sprite pass" — it hides bad feel.
- The drawn shape **is** the collision shape (see 1b). Never draw one size and collide another.

Reference for the target look: Zombs Royale (flat geometric, high contrast), minus the
polish — we want its readability, not its vector art.

## 1b. Hitboxes are the visuals — debug view is a feature

Because everything is a primitive, **the drawn shape and the collision shape are the same shape**.
A white circle r=16 has a `CircleShape2D` r=16. What you see is what collides — the "why did that
hit me?" class of bug cannot exist by construction.

On top of that, v0 ships a **debug overlay** (`F1` toggles, on by default in v0):

| Overlay | Shows |
|---|---|
| Hurtboxes | green outline — what can be hit |
| Hitboxes | red outline, only while **active** — what is currently dealing damage |
| Attack phase | the attacker tints by state: yellow = windup, red = active, grey = recovery |
| i-frames | player outline flashes blue for the 0.3s dodge window |
| Parry window | player outline flashes white for the 0.25s window |
| Telegraph bounds | the exact area the attack will hit, matching the orange->red fill |
| Numbers | damage dealt floats up; current cooldowns printed top-left |

`F3` opens the live tuning panel (see 1c). `F2` is slow motion.

Rules:
- **Never a sprite-vs-hitbox mismatch.** If an attack looks like it should hit, it hits.
  When tuning says otherwise, change the shape, not a hidden offset.
- **Reach and arc are drawn.** The sword's 90 deg / 1.2-tile wedge is visible on every swing,
  so "did I whiff or did the hitbox lie?" is answerable at a glance.
- Godot's built-in *Debug > Visible Collision Shapes* covers the basics; the overlay adds the
  **timing** information (windup/active/recovery, i-frames, parry window), which is what combat
  tuning actually needs and the built-in view does not show.
- A **slow-motion key** (`F2`, 0.25x) is worth the five lines — it is the only practical way to
  eyeball whether a 0.1s active frame and a 0.25s parry window really line up.

This is not throwaway debug scaffolding: it stays in development builds forever. Every future
weapon and every boss attack gets verified through it before it is called done.

## 1c. Live tuning panel — change values while playing

Two layers. Use the free one first.

### Free: Godot's Remote inspector
Run from the editor, then Scene dock -> **Remote** tab. The live node tree appears; editing any
`@export` in the inspector applies **instantly to the running game**. No code, works today.
Limitation: you alt-tab to the editor, and it lists every property rather than the ones that matter.

### Ours: an in-game panel (`F3`)
A `CanvasLayer` with a scrolling list of sliders over the running game. Not a menu — you keep
playing while dragging.

| Group | Values |
|---|---|
| Dodge | i-frame duration, burst distance, cooldown |
| Parry | window, miss recovery, cooldown, stagger duration, shield refund % |
| Weapon (current) | damage, windup, active, recovery, arc degrees, reach, projectile speed |
| Swap | weapon cast + cooldown, armor cast + cooldown |
| Defence | armor value, shield max, shield regen delay + rate, HP |
| Juice | hit-stop duration, shake trauma, knockback force, flash duration |
| Boss | HP, damage per attack, attack interval, phase-2 threshold, move speed |

Requirements:
- **Generic, not hand-written per value.** The panel reflects over `@export` properties
  (`get_property_list()` + `PROPERTY_USAGE_EDITOR`) on registered nodes/Resources, so a new
  `@export` shows up automatically. Never a hardcoded slider list to maintain.
- **Live** — no apply button, no restart. Drag and the next swing uses the new number.
- **Save / Load / Reset.** Dump the current set to `user://tuning.json`, load it back, reset to the
  `.tres` defaults. This is how an A/B comparison survives a restart and how a good set gets kept.
- **Print on change** — one line to the console per edit (`dodge.cooldown: 2.0 -> 1.6`), so a
  tuning session has a readable log instead of vanishing into memory.
- Dev builds only. Never shipped.

Why it matters here: every feel number in this design is a guess with "starting value, tune" next
to it. The panel is how those guesses get resolved — in one sitting, mid-fight, instead of one
edit-rebuild-replay cycle per number.

## 2. What is IN v0

**Player**
- 8-directional movement, mouse aim (aim decoupled from movement).
- Dodge: `Q`. 0.3s i-frames, ~2.5 tile burst, 2s cooldown. No stamina.
- Parry: `F`. 0.25s window, 0.5s recovery on miss, 3s cooldown. Success = negate + stagger the
  attacker ~0.8s + refund ~25% shield. Does not move you. ([0006](../decision/0006-controls-and-parry.md))
- Two weapon slots (`1`, `2`). Swap: 0.6s cast, vulnerable, 5s cooldown; dodge cancels it.
- Shield (regens 5s after last hit, ~1/sec) in front of HP (no regen).
- Damage: `final = max(1, damage - armor*0.5)`, then x2 on crit (~4% base).

**Two weapons, to prove the 2-slot kit works**
- **Sword** — arc hitbox, windup 0.15s / active 0.1s / recovery 0.2s, 90 deg, reach 1.2 tiles.
- **Bow** — projectile, slower, longer range, must lead a moving target.
- Each has **one skill** on `E` with its own cooldown (sword: short lunge-slash;
  bow: piercing charged shot). Skill comes from the weapon, not the character.

**One boss, scripted (not RL yet)**
- 3 attacks: a telegraphed slam (ground circle, **unparryable** — purple tell), a ranged spread,
  a charge (**parryable** — orange tell). At least one of each so both defensive options matter.
- 2 phases: at 60% HP it gains a 4th attack. New move, not bigger numbers.
- One enrage rule: leave the arena >3s -> it charges at 2x speed until you return.
- Knockback-immune.

**HUD (ugly is fine, must exist)**
- HP bar, shield bar, boss HP bar.
- Cooldown timers for: dodge, parry, weapon swap, weapon skill. Visible or it reads as broken.

**Controls** ([0006](../decision/0006-controls-and-parry.md))

| WASD | Mouse | LMB | `Q` | `E` | `F` | `1`/`2` |
|---|---|---|---|---|---|---|
| move | aim | attack | dodge | weapon skill | parry | weapon slots |

**One room**
- A grey rectangle arena with walls. No level generation, no doors, no biome.

## 3. What is OUT of v0

Explicitly deferred. Do not build these, even if they seem quick:

- Story, NPCs, dialogue, world building, biomes, day/night.
- Inventory UI, loot, crafting, item drops, gear tiers, accessories.
- Armor swapping (the 10s-cooldown system) — v0 has one fixed armor value.
- Potions and consumables.
- Mobile controls, touch input, auto-aim.
- RL boss. v0's boss is hand-scripted; RL comes only after the fight is fun.
- Multiplayer, saves, settings menus, audio beyond basic hit/swing blips.
- Any sprite, animation, shader or particle system beyond a white flash.

## 4. Architecture — built to grow

Three rules. They cost nothing now and are what let 30 weapons and an RL boss land later
without a rewrite. Everything else stays as dumb as possible.

### Rule 1 — Weapons are DATA, not scripts

A `WeaponData` Resource holds the numbers; a handful of **behavior** scripts hold the logic.
A new bow/sword/gun is a `.tres` file created in the editor: **zero new code**.

```gdscript
# scripts/weapons/weapon_data.gd
extends Resource
class_name WeaponData
@export_enum("arc", "projectile", "hitscan") var behavior := "projectile"
@export var damage := 30
@export var windup := 0.15
@export var active := 0.1
@export var recovery := 0.2
@export var arc_degrees := 90.0      # arc only
@export var reach := 1.2             # arc only
@export var projectile_speed := 600.0  # projectile only
@export var projectile_count := 1
@export var spread_degrees := 0.0
@export var skill: PackedScene        # the Q ability, see Rule 2
@export var skill_cooldown := 6.0
@export var color := Color.CYAN
```

- Shortbow / longbow / crossbow / shotgun are all `behavior: projectile` with different numbers.
- Greatsword is `behavior: arc` with a long windup and a 140 deg arc.
- A genuinely new mechanic (boomerang, chain lightning) earns a **new behavior script** —
  expect ~5 total, ever. Not one per weapon.
- Balance passes edit `.tres` files in the editor. No rebuild, no code review.

**Why this and not a `Sword extends Weapon` hierarchy:** a class per weapon means the same
damage/windup logic copy-pasted N times, and changing the formula means editing N files.
Data-driven keeps exactly one copy of the logic.

### Rule 2 — Composition over inheritance (Godot idiom)

Shared behavior lives in **component nodes**, attached to whatever needs them. A boss is not
`Boss extends Enemy extends Entity`; it is a node with the same components the player has.

| Component | Job | Used by |
|---|---|---|
| `Health` | shield + HP, damage formula, i-frames, `died` signal | player, trash, boss, boss parts |
| `Hurtbox` / `Hitbox` | Area2D pair, one collision convention | everything that deals or takes damage |
| `Telegraph` | the orange->red ground warning | every attack in the game |
| `WeaponHolder` | equips a `WeaponData`, runs windup/active/recovery, swap cast + cooldown | player (later: enemies) |
| `Brain` | decides what to do next | trash, boss (see Rule 3) |

One damage path, one telegraph grammar, one place to fix a bug. Deep inheritance trees are the
thing that makes a prototype unextendable — avoid them here specifically.

Abilities (the `E` skill) are scenes, not a match statement: `skill: PackedScene` on the weapon
data. A new skill is a new small scene, nothing else changes.

### Rule 3 — The boss's decision-making is swappable

`boss.gd` handles bodies, phases, animation and hitboxes. It asks a separate **Brain** object
one question: *given this state, what do I do next?*

```gdscript
# scripts/brains/brain.gd  — interface
extends Node
class_name Brain
func choose_action(state: Dictionary) -> String: return "idle"
```

- v0 ships `ScriptedBrain` — a state machine with the 3 attacks and the phase-2 move.
- Later, `RLBrain` answers the same question from a policy trained in Python and shipped as JSON
  weights + a ~40-line GDScript forward pass ([0008](../decision/0008-rl-inference.md) — the official
  ONNX node is .NET-only, which we are not). **Nothing else changes.**
- `state` is a plain Dictionary from the start (hp, player distance/angle, player weapon type,
  cooldowns) — this doubles as the RL observation vector, so it is worth keeping honest.
- Bonus: `ScriptedBrain` stays forever as the baseline opponent to train and regression-test against.

### File layout

```
scenes/
  arena.tscn            # throwaway: one grey rectangle
  player.tscn           # circle + Health + WeaponHolder + camera
  boss.tscn             # circle + Health + Brain + phase state machine
  projectile.tscn
  telegraph.tscn
  skills/               # one scene per Q ability
scripts/
  components/           # health.gd, hitbox.gd, telegraph.gd, weapon_holder.gd
  weapons/              # weapon_data.gd + behavior_arc.gd, behavior_projectile.gd, behavior_hitscan.gd
  brains/               # brain.gd (interface), scripted_brain.gd  [rl_brain.gd later]
  player.gd
  boss.gd
  hud.gd
data/
  weapons/              # sword.tres, bow.tres, ... (the growing part)
```

### What is deliberately throwaway

Honest about the parts that do NOT survive — do not polish them:

- **Arena** — one hardcoded rectangle; real levels replace it wholesale.
- **HUD** — ugly bars, rewritten when there is real UI.
- **Placeholder shapes** — replaced by art, but only after the fight is fun.

The **combat core** (weapons, `Health`, `Telegraph`, dodge, `Brain` boundary) is what you keep
and build on. That is why these three rules go in before the first line of gameplay code, and
why nothing else gets an abstraction until a second use case actually exists.

## 5. Milestones — vertical slices

Worked per [decision 0007](../decision/0007-working-agreement.md): each slice is playable, answers
ONE question, and is playtested by the human before the next one starts. No stacking unverified
slices. Any slice may send us back to the design — that is expected, not failure.

1. **Move & hit** — player circle, mouse aim, sword arc, one dummy enemy that takes damage.
   *Does swinging feel good?*
2. **Dodge, parry & get hit** — enemy attacks with a telegraph, shield+HP, dodge i-frames,
   parry window + stagger reward, and the parryable/unparryable tell.
   *Is the dodge window trustworthy? Is parry worth the risk over just dodging?*
3. **Two weapons** — bow added, swap with cast+cooldown, one skill each.
   *Is the 5s swap cooldown interesting or annoying?*
4. **The boss** — 3 attacks, phase 2, enrage rule, HUD cooldowns.
   *Is losing to it fair?*
5. **Tune** — adjust only the numbers in §2 until it feels right. No new features.

## 6. Done when

- A fight lasts 60-120s and you lose the first few times.
- Every death is explainable in one sentence ("I dodged too early").
- You want to immediately retry.
- Changing one number (dodge cooldown, swap cooldown, boss damage) visibly changes
  how the fight plays — proof the knobs are real.

Only then: RL boss, items, world.

## 7. Open for review

- Two weapons enough to prove the kit, or does v0 need a third (gun) to show variety?
- Should trash enemies exist in v0 at all, or boss-only until the boss is fun?
- Is 2s the right dodge cooldown to start tuning from, or start looser (1.5s) and tighten?
- Do trash enemies get `WeaponHolder` too (uniform), or their own simpler attack path (less code now)?
- Does a successful parry refund the dodge cooldown, or is that too forgiving?
