# Soul Knight — Weapon Variety, Deep Dive

Companion to [soul-knight.md](soul-knight.md) — that file covers the whole game; this
one is weapons only, for designing BossFight's `WeaponData` model. Read
[0005-architecture.md](../../decision/0005-architecture.md) and
[0011-hitbox-lives-on-the-weapon.md](../../decision/0011-hitbox-lives-on-the-weapon.md)
first — the conclusions below are written to fit those two decisions, not against them.

Soul Knight ships **537 weapons** (per the wiki's own count, Sept 2026). That number is
the whole point of this research: how do ~5 people (ChillyRoom's original team size) ship
537 weapons without 537 scripts?

## 1. Taxonomy — what categories actually exist

The wiki's own tab grouping (Weapon Gallery) plus its category tags give the real
taxonomy — not a genre-convention guess:

| Category | Wiki subtypes seen | Attack motion |
|---|---|---|
| **Melee — Swords** | Sword | Wide swinging arc. *"Performs a wide swinging attack."* — [Broadsword](https://soul-knight.fandom.com/wiki/Broadsword) |
| **Melee — Spears/Lances** | Lance | Forward thrust, no arc. *"Thrusts forward. This does not push the player forward."* — [Spear](https://soul-knight.fandom.com/wiki/Spear). Notable: Spear *used to* swing in an arc like a sword pre-rework — the wiki's own trivia confirms arc and thrust are treated as interchangeable motion **parameters** on the same weapon, not different weapon classes. |
| **Melee — Axes/Hammers** | Axe, Hammer | Two motions on one weapon: tap = sword-like swing, hold = charging whirlwind (spin), full charge = up to 3 whirlwinds. — [Axe](https://soul-knight.fandom.com/wiki/Axe) |
| **Guns — Handguns/Rifles/SMGs/Shotguns/Sniper Rifles** | many | Hitscan-ish/projectile, single or multi-shot per trigger pull, inaccuracy cone governs spread. |
| **Guns — Laser** | Single Beam, Continuous Beam, Railguns (wiki subcategories) | Continuous Beam = sustained damage-over-contact beam, not discrete projectiles — [Category:Continuous Beam](https://soul-knight.fandom.com/wiki/Category:Continuous_Beam) lists Double Therapy, Fusion Drill, Ion Laser, Pulse, etc. as a distinct pool from single-shot lasers. |
| **Bows/Crossbows** | subcategory of Charged Weapons | Hold to charge, release to fire; charged shot has higher damage/crit than a tap-shot. |
| **Staffs** | Staff | Highly varied per-weapon: e.g. [Magic Staff](https://soul-knight.fandom.com/wiki/Magic_Staff) summons 2 orbs that **orbit the player** for a duration and re-tap extends the duration — not a "cast and forget" projectile at all. |
| **Throwables** | Throwing Only, Has Shotgun feature | Arc-thrown, some return (Boomerang: *"Launches and reaches a range of 12 tiles before returning to the user's hand. It can penetrate enemies and crates."* — [Boomerang](https://soul-knight.fandom.com/wiki/Boomerang)), some explode on impact/timer. |
| **Shields** | — | Held, blocks projectiles only (per existing `soul-knight.md` notes — not re-verified here). |
| **Combo-Hit** (cross-cutting) | — | One tap fires a multi-hit burst for one energy cost; interruptible only by switching weapons — [Category:Combo-Hit Weapons](https://soul-knight.fandom.com/wiki/Category:Combo-Hit_Weapons). This sits **on top of** guns/melee, not as its own weapon family. |
| **Charged** (cross-cutting) | 137 weapons tagged | Hold-to-charge (5-dot meter) changes projectile/damage on release; applies to bows, axes, staffs, guns alike — [Category:Charged Weapons](https://soul-knight.fandom.com/wiki/Category:Charged_Weapons). |
| **Elemental** (cross-cutting) | 95 weapons tagged | Inflicts Burn/Poison/Freeze/Stun/Electrify/unique-effect instead of double damage on crit — [Category:Elemental](https://soul-knight.fandom.com/wiki/Category:Elemental). Applies across every category above; it is a **flag**, not a weapon type. |

**Key finding:** "Continuous Beam," "Combo-Hit," "Charged," and "Elemental" are wiki
*categories* layered across the melee/gun/staff/throwable split, not siblings of them.
That is the taxonomy's own evidence that Soul Knight's real data model is
**base motion type + orthogonal modifier flags**, matching question 5's hypothesis
before even reaching the wiki's dev-pattern research.

## 2. What varies within one category — numbers vs. behaviour

Concrete pairs, both pulled from wiki stat blocks:

- **Broadsword vs. Spear** (both "original" starter melee, both Common): Broadsword
  12 dmg / -5 crit / 1.5 atk-speed / **wide arc**. Spear 8 dmg / 25 crit / 2.0 atk-speed /
  **thrust, no arc**. Same category tier, different numbers *and* different motion shape
  (arc-degrees vs. a directional lunge) — this is the one pair in the sample where the
  category label ("melee") hides a real behavioural difference, not just stats.
- **Axe** is the sharper example of *one weapon, two behaviours selected by input*: tap
  gives the same "arc swing" as a sword; hold gives an unrelated "spin, up to 3 charges"
  attack. This is not two weapons — it is one `WeaponData` entry whose fire method reads
  a hold-duration input.
- Within **guns** specifically (not directly re-verified per-pair here, but consistent
  with `soul-knight.md` section 2 and the wiki's Stats page): two rifles typically differ
  only in Damage / Energy Cost / Crit / Inaccuracy / Attack Speed — same "spawn one
  projectile, travel straight" behaviour, different numbers. This is the common case:
  most roster growth is numeric, not behavioural.

**Conclusion:** the bulk of a 500+ weapon roster is stat re-rolls on a small set of
motions. Genuine behaviour forks (Axe's tap/hold, Magic Staff's orbit) are the minority
and are visible in the wiki as one weapon having multiple named "usage" clauses, not as
separate weapons.

## 3. Minimal behaviour set (estimate, partly INFERRED)

Directly evidenced by pages read above: **arc-sweep**, **thrust**, **charge-then-release**
(bow/axe-spin), **straight projectile** (guns), **continuous beam**, **thrown/returning**
(boomerang), **orbit/summon** (Magic Staff). Not fetched directly but standard per
`soul-knight.md`'s existing notes and category names seen in the sidebar (Grenade Pistol,
Grenade SMG, Bomber, Black Hole Missile): **arced explosive throw with AoE on
land/timer**. Multi-projectile spread (shotguns) is INFERRED from "Inaccuracy" existing
as a per-weapon cone stat rather than confirmed from a shotgun page directly.

Ordered by how much of the roster each one unlocks:

1. **Straight projectile** — essential. Covers the majority of guns.
2. **Arc-sweep (melee)** — essential. Already built (existing sword).
3. **Thrust (melee)** — essential, cheap to add: same hitbox-on-blade model as arc, just
   a different motion curve for the blade's local position instead of its rotation.
4. **Multi-projectile spread / combo-hit burst** — essential. One energy cost, N spawns
   at slightly different angles or with a fixed delay between them; covers shotguns and
   SMG-style weapons without new motion code.
5. **Charge-then-release** — high value. Turns "hold vs tap" into a second free axis on
   any of the above three (a charged arc-sweep, a charged projectile) — this is how Axe
   and every bow work, and it multiplies roster variety cheaply.
6. **Continuous beam** — nice-to-have. A sustained damage-over-time line/cone instead of
   a discrete spawn; needed once, reused by every laser weapon.
7. **Thrown/returning (boomerang)** — nice-to-have. A projectile with a travel curve that
   reverses direction and re-targets the owner.
8. **AoE-on-impact (explosive/slam)** — nice-to-have. A projectile or melee hit that also
   spawns a damage-radius at its landing point — this is also the natural shape for a
   melee "slam."
9. **Orbit/summon** — nice-to-have, boss/player-utility flavor. Spawns N persistent
   child nodes that move on a fixed pattern (around the player, or standing still) and
   deal contact damage independent of the swing/fire loop.

Essential = 1–4 gets most of the roster's *count*. 5–9 gets the roster's *flavor* — the
weapons players remember by name.

## 4. Energy / ammo gating

Already documented in `soul-knight.md` §2 (energy per shot, melee free, no passive regen,
regen only from pickups). Relevant addition for the data model: energy cost is a **flat
number per weapon**, shown in the same stat block as damage/crit/inaccuracy — it is not
behaviour-specific. A charged weapon still costs one flat energy value regardless of
charge level (INFERRED from the "Charged Weapons" category page not mentioning a
variable cost, and from general roguelite-shooter convention — not directly verified on
a specific charged-weapon page).

## 5. Multi-hit / special properties — flags, not behaviours

The wiki's own category structure answers this directly: **Elemental** (95 weapons),
**Combo-Hit**, **Charged**, and per-weapon "Notable Buff Effects" sections are all
*cross-cutting tags* layered on top of a base motion, never separate weapon classes. A
weapon like Boomerang is simultaneously: throwable motion + "penetrate enemies and
crates" (piercing flag) + can-benefit-from-Shotgun-Buff (spread-compatible flag). None of
that required a new script — it required flags the base "throw" behaviour reads and
branches on.

For BossFight this means: piercing, bounce, chain, lifesteal, status-on-hit, and
knockback belong on `WeaponData` as booleans/floats read by whichever behaviour script
is active, **not** as their own behaviour scripts. Crit is already flat-`%` +
double-damage-or-status, matching our existing single `damage` field's likely evolution.

## 6. Implementation pattern for a large, data-driven roster

Research on how teams actually structure 100+ item/weapon rosters (general game-dev
practice, not Soul Knight-specific — ChillyRoom has not published their internal
architecture, so this section is INFERRED from public patterns used by comparable
shipped games and talks):

- **Enum-of-behaviour + parameter block** (what BossFight already does with
  `@export_enum("arc")`). Trade-off: adding a new behaviour still means writing a script,
  but that script is written once and reused by every weapon of that type. This is the
  cheapest pattern for a small team and is exactly what 0005 already committed to.
- **Composition of small "effect" components** (e.g. a `PierceComponent`,
  `KnockbackComponent`, `StatusOnHitComponent` attached alongside the behaviour). Used
  in Unity's ScriptableObject-driven shooters and cited repeatedly in GDC-style
  postmortems for "verb components" (a weapon *is* its list of components, not its
  class). Trade-off: more flexible recombination, more files/nodes per weapon, more
  indirection to debug. Worth adopting only once flags on `WeaponData` stop being enough
  (i.e. once two flags need to interact in a way a single script can't express cleanly).
- **Scriptable-object / Resource data-only weapons** — this is precisely Godot's
  `Resource` + `.tres` pattern BossFight already uses. It is the standard Unity/Godot
  answer to "many data variants, few classes," and is well-documented Godot practice
  (referenced already in this repo's `docs/reference/godot/melee-authoring.md`, cited by
  0011).
- **Full inheritance per weapon** (`Sword extends Melee extends Weapon`) — explicitly the
  pattern 0005 already rejected for the boss/enemy tree; same objection applies to
  weapons and is why Soul Knight's own data (numbers reused across hundreds of near-
  identical guns) argues against it too.
- **Small expression/scripting layer** (e.g. a mini DSL or Lua-like per-weapon script) —
  seen in some large modded shooters (id Tech's weapon def files, Path of Exile's skill
  gems as composable "supports"). Overkill for a small team; only pays off past roughly
  a thousand items or when non-programmers must author new combos independently. Not
  recommended here.

**Recommendation for BossFight:** stay on enum-of-behaviour (already decided), add a
flat parameter block of cross-cutting flags on `WeaponData` (section 5), and only reach
for component-composition if/when two flags need to genuinely interact (e.g. "chain
lightning that also pierces" needing shared travel state) rather than just both being
true independently.

## 7. Where art fits

Not separately re-verified from the wiki (weapon art pipeline is not documented there —
INFERRED from standard Godot/Unity practice and this repo's own decision 0011): a
sprite-per-weapon plus one shared hitbox-authoring workflow is exactly what 0011 already
established — "drop in a picture, drag the shape over the blade, type damage and
timings. No invisible numbers to guess." For 100+ weapons that means:

- One shared weapon **scene template** (`WeaponVisual/Blade` + child `Hitbox`), never a
  bespoke scene per weapon.
- Per-weapon differences are: the sprite texture, the `Hitbox`'s `CollisionShape2D` sized
  in the editor, and the `.tres` numbers. No new script, no new scene inheritance chain,
  unless the weapon needs a genuinely new *behaviour* (section 3's list), in which case
  it is still one shared script reused by every weapon of that behaviour.
- Guns/staffs/throwables with no blade sprite still work under 0011's own note: *"A
  weapon with no sprite (a spell, a shockwave) still works: give its hitbox a shape;
  nothing requires a texture."* — projectile spawn point replaces the blade transform.

## 8. Proposed data model for BossFight

Fields split into **shared** (every weapon has these, regardless of behaviour) and a
**per-behaviour parameter block** (only the active behaviour reads its block; others
stay at defaults and cost nothing at runtime).

```gdscript
extends Resource
class_name WeaponData

## ---- Shared by every weapon ----
@export_enum("arc", "thrust", "projectile", "spread", "charge", "beam") var behavior := "arc"
@export var damage := 30.0
@export var windup := 0.15
@export var active := 0.1
@export var recovery := 0.2
@export var energy_cost := 0.0          # 0 = melee, free (matches Soul Knight's "melee never gates on energy")
@export var crit_chance := 0.0          # flat %, doubles damage unless...
@export var color := Color.WHITE

## ---- Cross-cutting flags (section 5) — read by whichever behaviour is active ----
@export var pierce_count := 0           # 0 = stops on first hit, >0 = passes through N enemies
@export var knockback := 0.0
@export var status_effect := ""         # "", "burn", "freeze", "poison", "stun" — empty = no status
@export var status_chance := 1.0        # usually 1.0 on hit, <1.0 for "sometimes" effects
@export var lifesteal_pct := 0.0

## ---- "arc" / "thrust" behaviour block (melee) ----
@export var arc_degrees := 90.0         # existing field — how far the blade sweeps
@export var thrust_distance := 0.0      # 0 = pure arc, >0 = lunge distance for "thrust"

## ---- "projectile" / "spread" behaviour block ----
@export var projectile_speed := 600.0
@export var projectile_count := 1       # >1 = fan/shotgun spread from one energy cost
@export var spread_degrees := 0.0       # cone width when projectile_count > 1
@export var projectile_lifetime := 1.5

## ---- "charge" behaviour block (wraps arc/thrust/projectile) ----
@export var charge_time := 0.0          # 0 = not chargeable
@export var charged_damage_mult := 1.0
@export var charged_crit_bonus := 0.0

## ---- "beam" behaviour block ----
@export var beam_range := 300.0
@export var beam_tick_interval := 0.1   # damage applied once per tick while held
```

Notes on the split:

- `arc_degrees` + `thrust_distance` living together lets one `"arc"`/`"thrust"` script
  read whichever number is non-zero — this mirrors the wiki's own trivia that Spear used
  to be an arc weapon and became a thrust weapon by **changing a number**, not by
  becoming a different class.
- `projectile_count` + `spread_degrees` covers both single-shot guns (`count=1`) and
  shotguns (`count=8, spread=40`) with the same behaviour script — matches section 2's
  finding that most gun variety is numeric.
- Flags block is deliberately flat booleans/floats, not sub-resources, per section 5 —
  add composition only when two flags need shared state (section 6).

## 9. Minimal behaviour list to build first (ordered)

1. **`arc`** — already built. Keep as-is; it is the reference implementation the
   hitbox-on-blade contract (0011) was written against.
2. **`thrust`** — smallest possible addition: same script family as arc, blade
   translates forward by `thrust_distance` during `active` instead of rotating through
   `arc_degrees`. Unlocks spears/lances for near-zero new code.
3. **`projectile`** — spawns one traveling hitbox from a muzzle point. Unlocks every gun
   and unlocks the boss's own ranged attacks (bosses need this regardless of player
   weapon variety — dual payoff).
4. **`spread`** — same script as `projectile`, `projectile_count > 1` fans N spawns
   across `spread_degrees`. Unlocks shotguns/SMGs/multi-shot bosses without new motion
   code, only a loop.
5. **`charge`** — a hold-to-fire wrapper that delays committing to whichever of the
   above three behaviours until release, scaling `damage`/`crit_chance` by charge
   fraction. Unlocks bows, charged staffs, and the Axe-style "tap vs hold" pattern.
6. **`beam`** — sustained tick-damage line while held. Lowest priority: fewer weapons
   need it, and it is the one behaviour with no melee/gun code to share.

## 10. Migration note

**What changes for the existing sword:** nothing behaviourally. `behavior = "arc"` stays
exactly as it works today; `thrust_distance` defaults to `0.0` so the arc script's new
branch (`if thrust_distance > 0: lunge else: sweep`) never fires for it. The existing
`.tres` file needs zero edits.

**What stays:** the whole 0011 contract — hitbox lives on the blade sprite as a
hand-drawn `CollisionShape2D`, `arc_degrees` remains a motion property not a filter,
`WeaponData.reach` remains removed. Every new behaviour in section 9 follows the same
rule: the shape that hits is the shape you see, whether that shape is a blade, a bullet
sprite, or a beam's collision line.

**What's net-new:** the cross-cutting flag block (section 8) has no equivalent in the
current `weapon_data.gd` — today's file has no piercing/knockback/status fields at all,
because only one behaviour (arc) exists and nothing needed them yet. Add the flags when
the second behaviour (`thrust` or `projectile`) is built, not before — YAGNI still
applies to the flags themselves, only the *shape* of the split is worth deciding now.

## 11. Sources

- [Weapons — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Weapons)
- [Category:Weapons — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Category:Weapons)
- [Category:Continuous Beam — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Category:Continuous_Beam)
- [Category:Combo-Hit Weapons — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Category:Combo-Hit_Weapons)
- [Category:Charged Weapons — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Category:Charged_Weapons)
- [Category:Elemental — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Category:Elemental)
- [Broadsword — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Broadsword)
- [Spear — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Spear)
- [Axe — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Axe)
- [Magic Staff — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Magic_Staff)
- [Boomerang — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Boomerang)
- [Stats — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Stats)
- Existing repo notes (not re-cited per fact, read as prerequisite): `soul-knight.md`,
  `0005-architecture.md`, `0011-hitbox-lives-on-the-weapon.md`, `weapon_data.gd`.

Items marked INFERRED above (behaviour-count estimate in §3, energy-cost-flat-under-
charge in §4, art pipeline specifics in §7, industry pattern trade-offs in §6) are
reasoned from adjacent evidence or general practice, not confirmed by a directly-cited
Soul Knight wiki page — flagged inline at each occurrence.
