# Hit feel plan

**Status:** Done plan (built in HitFx slices, decisions 0057 and later), kept for history

*Design only. Nothing is built yet. Research and sources: [hit-feel-research.md](../reference/game-feel/hit-feel-research.md).*

**Goal:** when the sword or an arrow hits, the player should *feel* it. "Good, smooth, satisfying."

**The problem today.** A hit only makes the boss flash white for 0.05 s. That is all.
It is like knocking on a door that makes no sound. The hit counted, but nothing tells you so.
Also: when the *player* gets hit, nothing happens on screen at all.

## What we have now

| Piece | State |
|---|---|
| Boss flash | `BossVisual.on_hit()`, 0.05 s, white circle |
| Dummy flash | `dummy.gd` `_on_damaged` |
| Player gets hit | **No feedback** (no one listens to `damaged`) |
| Hit-stop, shake, knockback, damage numbers, sparks | **None** |
| Parry / block | Guard shows its own flash (`GuardVisual`) |
| Signals we can use | `Health.damaged(amount)`, `died`, `dodged`; `Guard.parried`, `blocked`, `broke`; `Boss.phase_changed`, `defeated` |
| Camera | Created in code by `arena_map.gd`, child of the player, smoothing on |

**Missing piece:** `Health.damaged` only gives the *amount*. We do not know where the hit was, which way it came,
or if it was a crit. Effects need that. (See "Architecture".)

## Hit types and starting numbers

All numbers are *starting values, tune in F3*. Frames are at 60 fps (1 frame = 0.0167 s).
"Stop" = hit-stop (a tiny pause). "Shake" = trauma added (0 to 1, see below).

| Hit | Stop | Flash | Knockback | Shake | Sparks / FX | Number | Sound |
|---|---|---|---|---|---|---|---|
| Sword hit (normal) | 3 frames (0.05 s), attacker + victim | 0.08 s white | small shove on small enemies; 0 on boss | 0.20 | 6 sparks along swing direction | white | thud, pitch +/-8% |
| Sword hit on boss | 4 frames | 0.08 s white | none (boss is immune); boss "recoils" 3 px visual only | 0.25 | 8 sparks + slash mark | white | deeper thud |
| Lunge (E skill) | 5 frames on first hit only | 0.10 s | 40 px shove | 0.35 | 10 sparks, short trail | yellow | heavy hit |
| Arrow | 1 frame (0.02 s), none if many hit per second | 0.06 s | none | 0.08 | 3 sparks at the hit point | white small | light tick |
| Charged arrow | 5 frames | 0.10 s | none | 0.30 | 10 sparks + ring | yellow | crack |
| Parry (success) | 6 frames, **both** freeze | white on boss + player shield | boss staggers (exists, 0.8 s) | 0.30, sharp | big bright sparks, ring | "PARRY" text | clear chime |
| Guard block | 2 frames | none | player slides back 12 px | 0.12 | dull small sparks | grey, chip amount | dull clunk |
| Player gets hit | **0 frames** (never freeze the player) | 0.12 s red on player | 20 px shove | 0.25 | few red bits | red | hurt sound |
| Boss phase change | 10 frames, whole game | boss white 0.2 s | none | 0.5 | ring burst, zoom punch 8% | none | roar |
| Kill (boss defeated) | 12 frames, then slow-mo 0.3x for 0.8 s | long white | none | 0.8 | big burst | big | big boom |

**Example, a sword hit on the boss.** You swing. The blade snaps. At the moment of contact: the game pauses 4 frames,
the boss goes white, sparks fly out along the swing, the camera nudges once, and you hear a thud.
All in the same frame. That is what makes it "land."

**Rule of thumb:** *the stronger the hit, the more of every layer.* A light arrow gets a tick. A kill gets everything.

## Build order (best result for the least work)

| # | Build | Why first | Effort |
|---|---|---|---|
| 1 | **Hit flash for all actors** (player too) via a small shader | The player-gets-hit gap is the biggest hole. Easy | small |
| 2 | **Hit-stop** (local, attacker + victim) | Biggest "it landed" feeling for ~20 lines | small |
| 3 | **Sound hook** with pitch randomization (blip is fine) | Ears feel it before eyes | tiny |
| 4 | **Trauma shake** + strength slider + off switch | Needs the camera; reusable by every later effect | small |
| 5 | **Sparks** (CPU particles, pixel squares) | Shows hit direction | medium |
| 6 | **Damage numbers** (pooled) | Helps tuning too | medium |
| 7 | Knockback on small enemies, boss visual recoil | Only matters once there are trash enemies | medium |
| 8 | Parry / phase / kill specials: slow-mo, zoom punch | Polish for the big moments | medium |
| 9 | Chromatic or blur effects | Last, risky for readability | later |

Slices: slice one = #1 to #4, then you play. If it already feels good, the rest is polish.

## How it fits our architecture (CLAUDE.md §5 and §7)

**Rule:** combat code does not know about effects. Effects listen. This keeps "swap the placeholder for real art" cheap.

**Design: one hub node + small effect nodes.**

| Node | Job |
|---|---|
| `HitFx` (one, autoload or child of the arena) | Listens to signals, decides "what kind of hit," sends one `hit(info)` message to the effect nodes. The only place that knows strength. |
| `HitStop` | Freezes the **whole game** for N frames (see "Opus review" below) |
| `HitFlash` (on each actor visual) | Flash shader |
| `CameraShake` (child of the camera) | Trauma + noise on `offset` |
| `HitSparks` | Pooled particles |
| `DamageNumbers` | Pooled labels |

`HitFx` is the *only* node that maps hit types to numbers. Each effect node has its own `@export`s. A new hit type
is a new row of data, not new code (put the table in a `HitFxProfile` Resource, one per hit type).

**Signals it uses (all exist):** `Health.damaged`, `died`; `Guard.parried`, `blocked`;
`Boss.phase_changed`, `defeated`.

**One small change to existing code is needed (later, when we build):** `Health.damaged` should also carry
`source` and `hit_direction` (or a new signal `hit_taken(info)`). Without this, sparks and shake cannot point the right way.
`Health.take_damage` already receives `source`. This is an addition, not a rewrite; old connections keep working.

**F3 panel (all `@export`, appear automatically):**

| Control | What it does |
|---|---|
| `Hit FX on/off` | Master switch, to compare "with" and "without" |
| `Shake strength` 0 to 2 | Multiplies all shake; **0 = off** (also an accessibility option) |
| `Hit-stop scale` 0 to 2 | Multiplies all freezes; 0 = off |
| `Flash on/off`, `Sparks on/off`, `Numbers on/off` | Per-layer switches |
| Per hit type: stop frames, shake, flash time | The table above, live |
| F3 status lines | `trauma: 0.31`, `hit-stop: 3f left`, `last hit: sword/boss` |
| Trigger buttons | `Test sword hit`, `Test parry`, `Test kill`, `Test player hit` |

**F1:** nothing new (no hitboxes added). The hit point can show as a small cross for 0.3 s.

## Risks for our game

| Risk | What the player would see | How we handle it |
|---|---|---|
| **Hit-stop vs the snap swing** | The swing already snaps in ~1 frame. A freeze right after may feel like the sword "sticks." | Freeze starts on contact, not on swing start. Keep it at 3-4 frames. Tune first. |
| **Hit-stop vs the parry window (0.25 s)** | Parry window runs on game time. A *global* freeze stops it too, which is fair. A *local* freeze of the player would eat the window. | **Never freeze the player when hit.** On parry both freeze together, so the window and the stagger stay in sync. Check in test. |
| **Local freeze and timers** | Boss freezes but its attack timer keeps running, then it "jumps" | Freeze by one flag inside each actor's own `_physics_process`, so timers pause too. Or use `time_scale` for the big moments only. |
| **`Engine.time_scale` vs F2 slow-mo** | F2 sets `time_scale` to 0.25. A hit-stop that sets it back to 1.0 would cancel F2. | Hit-stop must **not write `time_scale`** for small hits. For slow-mo-on-kill, multiply by the current value and restore it. Keep F2 as an override: while F2 is on, hit-stop still works but scaled. |
| **Stacked hits** | Sword + arrow on the same frame add up to a long freeze | Use the **longest** one, with a hard cap (about 12 frames). |
| **Shake vs the follow camera on the big map** | Camera smoothing + shake together can feel floaty. Shake near the map edge may show outside the camera limits. | Shake `offset` only, never `position`. Test at all four map edges. |
| **Readability with boss bullets** | Sparks and flashes hide bullets; shake makes them hard to track | Cap particles per frame. Keep sparks small and short. Boss bullets stay on a higher draw layer. Shake from small hits is near zero. |
| **Motion sickness / flashing** | Headache, dizzy | Shake slider + off switch. Flash is 0.08 s only. No full-screen flash. |
| **Pixel art blur** | Squash/stretch makes pixels uneven | Skip scale squash for now; use flash + shove. |

## Opus review (2026-10-02) — changes to the draft above

1. **Hit-stop is global, not per actor.** A per-actor freeze needs a "frozen" flag inside the player,
   boss, dummy and every attack timer — combat code would have to know about effects (breaks CLAUDE.md §5).
   A global freeze (`Engine.time_scale` near 0 for 2–6 frames, timed on a real-time timer, restored to the
   *previous* value so F2 survives) is what Nuclear Throne does ("sleep") and needs zero changes in actors.
   Bullets freeze too, which is fair. The player is still never frozen by *getting* hit.
2. **Inputs pressed during a freeze must not be lost.** Check that attack/dodge pressed inside the freeze
   still fire after it (test + playtest). If not, buffer them.
3. **Sound needs a source.** We have no audio files. Slice one uses free CC0 sounds (e.g. Kenney "Impact
   Sounds") or generated blips (jsfxr), in `assets/game/audio/`, behind one `HitSound` node so they swap later.

## How we'll test it

| Check | Can run headless? |
|---|---|
| Project boots with the new nodes (`godot --headless --quit`) | Yes |
| Parse check of every new script (`--check-only`) | Yes |
| Unit checks on pure maths: trauma decays to 0, shake stays inside the max, stacking uses the max, strength 0 gives zero offset | Yes (small script test) |
| Load the arena, emit `Health.damaged` by script, assert `HitFx` called each effect once and hit-stop ended | Yes |
| After hit-stop ends, `Engine.time_scale` is back to what it was (including F2 on) | Yes |
| Parry still works with a hit-stop in the middle (scripted timing) | Yes, but only the logic |
| **Does it feel good? Is the freeze too long? Is shake too strong?** | **No, needs your playtest** |
| **Can you still see boss bullets during sparks?** | **No, playtest** |
| Does the swing feel "stuck" after the freeze? | **No, playtest** |

Per CLAUDE.md §2.4, after building, a second model reviews the diff with fresh context.
We do slice one (#1 to #4), you play it, then the rest.
