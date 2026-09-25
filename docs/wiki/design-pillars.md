# BossFight — Design Pillars

*Design only. What v0 actually builds is [prototype-v0.md](prototype-v0.md);
implementation patterns are in [docs/reference/godot/](../reference/godot/).*

Single durable design synthesis. See [decision 0001](../decision/0001-design-reference-games.md) for why these three games are the references: [Necesse](../reference/game-design/necesse.md) (combat/controls), [Terraria](../reference/game-design/terraria.md) (bosses/items), [Soul Knight](../reference/game-design/soul-knight.md) (mobile ergonomics).

## 1. Pillars

- Combat is the product. Story/world/meta come later and never constrain the fight.
- Top-down combat that reads clearly at a glance, human or RL boss.
- Bosses are puzzles with phases and rules, not HP sponges with a damage slider.
- Progression is boss-gated, not grind-gated — gear tier = kill order, not playtime.
- PC first (mouse aim + keyboard); mobile is a later port, not a current constraint ([decision 0002](../decision/0002-pc-first.md)).
- Difficulty adds new moves, never just bigger numbers.

## 2. Combat (from Necesse)

Combat is the game. Story, world and meta systems are specced later — nothing in them may
constrain the moment-to-moment fight.

- **Movement**: free 8-directional. Aim is decoupled from movement — you strafe and reposition
  while still facing the boss.
  - Non-negotiable: this is what makes a top-down RL boss's attacks readable while repositioning.
- **Dodge** ([decision 0004](../decision/0004-dodge.md)): baseline ability, always available,
  gated by a **cooldown, not stamina**. Not a Souls-style roll economy.
  - Starting values, tune: **0.3s i-frames**, ~2.5 tile burst, **2s cooldown**, HUD-visible.
  - Cancels a weapon swap in progress (the swap fails, per [0003](../decision/0003-loadout-and-swapping.md)).
  - Gear tunes it (shorter cooldown, longer i-frames, extra charge); never grants or removes it.
  - Boss pacing is authored against this: two unavoidable hits inside 2s are unfair by construction.
- **Parry / block** ([0006](../decision/0006-controls-and-parry.md), revised by
  [0013](../decision/0013-parry-and-block-on-one-key.md)): `F`. **Tap** = parry, a 0.25s timing
  window. **Hold** = block: always works, but 30% chip damage, 40% move speed, and you cannot
  attack. Both only stop what comes from the half you face (`parry_arc_degrees`, 180 default).
  Starting values, tune: 0.25s window, 0.5s recovery on miss, 0.8s stagger on success.
  - Success: negate the hit, **stagger the attacker ~0.8s**, refund ~25% shield. Failure: take the
    hit *and* the recovery — strictly worse than not pressing it.
  - Does not move you; dodge does. Dodge = avoid (safe, works on AoE), parry = punish (greedy,
    single hits only). Two defensive buttons must answer different questions.
  - **Not every attack is parryable.** Unparryable attacks need their own tell (proposed: telegraph
    pulses purple instead of orange->red) or parry is a guess.
  - An RL boss may bait it with feints — that is intended pressure, and the reason this is a window
    and not a hold-block (which a policy would simply learn to ignore).
- **Controls** (PC): WASD move, mouse aim, LMB attack, `Q` dodge, `E` weapon skill, `F` parry,
  `1`/`2` weapons, `3`-`9` items.
- **Mobility items** (teleport rod, dash gem, grapple) are separate hotbar items — longer range,
  longer cooldown, **no i-frames**. They must stay clearly distinct from dodge or they replace it.
- **Melee**: swing-arc hitbox (not raycast), windup + recovery gate attack speed.
  - Starting values, tune: windup 0.15s, active arc 0.1s, recovery 0.2s, arc 90 deg, reach 1.2 tiles.
  - Attack speed shortens windup/recovery, never the active arc (keeps hit confirmation legible).
- **Damage & armor**: flat reduction, crit applied after.
  - Formula, starting value, tune: `final = max(1, damage - armor*0.5)`, then `xCrit` (2x, ~4% base chance).
  - Flat (not %) reduction keeps armor meaningful against chip damage without trivializing a boss's big hit.
- **Health**: two layers — a regenerating shield in front of non-regenerating HP.
  - Starting values, tune: shield regen begins 5s after the last hit taken, ~1/sec.
  - Swapping armor **does not** refill or reset the shield (closes the second swap-tank exploit;
    the 10s armor cooldown closes the first).
  - Rewards disengaging to reset without turning fights into attrition.
- **Knockback**: a first-class stat, not cosmetic. Most late bosses are knockback-immune (Terraria
  pattern) so it stays crowd control against trash rather than a way to cheese a hard fight.
- **Buffs/debuffs**: consumables and accessories grant damage%/crit/attack-speed; status effects
  (burn/poison/slow) are a separate DoT/utility axis outside the base damage formula.
- **Cooldown HUD**: dodge, weapon swap, armor swap and healing must all show their timer. A gated
  action with no visible timer reads as a broken game, not as a rule — doubly so when an RL boss is
  timing its punishes around those windows.
- **Combat state**: flagged while dealing/taking hostile damage, drops after a few seconds idle.
  Gates fast travel and out-of-combat regen; pacing only, not a core mechanic.

## 3. Bosses (from Terraria)

Every boss must follow these rules:

- **New attacks per phase, not stat ramps.**
  - HP-threshold or scripted phase transitions unlock genuinely new moves (Twins' true forms, Golem's detached head), never just a faster/harder version of the same move.
  - Death-and-rebirth transitions (boss "dies," revives stronger — Ascended Wizard) are a valid phase type: a discrete, legible reset beat, easy for a human to read as "new fight starting."
- **Explicit enrage rule, stated up front.**
  - A named condition (leave the arena, exceed a timer, ignore an add too long) triggers a clear, telegraphed punish — never a vague "if losing, get stronger."
  - Examples to steal directly: Plantera's "leave the biome = enrage," Skeletron's "not dead by dawn = enrage." Both are cheap and anti-stalling.
- **Multi-part/targetable bosses are a cheap complexity lever.**
  - Independently damageable limbs/hands/escorts (Skeletron Prime, Moon Lord, Zulan's drones) create emergent difficulty without new move design.
  - Each part needs its own telegraph — no single global tell for a multi-part boss (Soul Knight's Baby Dragon Bros shared-bar confusion is the failure mode to avoid).
- **Difficulty tiers unlock new moves**, matching Terraria's Expert/Master pattern.
  - Never just HP/damage multipliers on the same kit — that is the Soul Knight Badass Mode trap, explicitly rejected as "attrition, not a new puzzle."
- **Telegraph before every big hit.**
  - Visual wind-up + audio cue minimum (Terraria: animation + sound, no UI reticle).
  - Red-ground AoE warning (Soul Knight grammar, see §5) for anything screen-filling or instant-onset.
  - No UI-only telegraphs that clutter the frame during dense multi-attack patterns.

What an RL-driven boss must still obey:

- **Telegraphs stay legible.** An RL policy cannot learn attack timing/tells a human can't read within the same fixed windup/telegraph budget as a hand-authored boss — the telegraph system is a hard constraint on training, not just on hand-authored movesets.
- **No exploiting summon/ally leash gaps.** Necesse's Sage and Grit (dragons outrunning Summoner minions) and Fallen Wizard (summons losing tracking at range) are cautionary: test that any player-ally AI can track the trained boss's mobility, since RL will find and abuse a leash-range or speed gap if one exists.
- **Resist single-build overfitting.** Necesse's Mother Slime (trivialized by ranged) is the failure mode; training/eval must cover melee, ranged, and caster-equivalent player archetypes so the policy can't collapse to "beatable by only one strategy" or, symmetrically, overfit to counter only one and be unfairly hard against the others.

## 4. Items & progression (from Terraria)

- Gear tiers are boss-gated.
  - A boss kill drops the material/unlock for the next tier, not a grind quota.
  - No player XP/levels — power comes entirely from gear + accessories, so progression is boss-order, not playtime.
- **Hotbar & swapping** ([decision 0003](../decision/0003-loadout-and-swapping.md)): Minecraft-style ~9-slot hotbar; max 2 weapons, rest are items (potions, mobility tools, throwables).
  - Two knobs, both apply (Terraria potion-sickness pattern): a **swap cast** (vulnerable, interruptible) and a **swap cooldown** (can't swap back).
  - Starting values, tune: **weapon 0.6s cast / 5s cooldown** (dodge cancels the cast); **armor 1.5s cast / 10s cooldown**; **healing potion 30s** personal cooldown.
  - Bag locked, potions otherwise free. All cooldowns must be visible on the HUD.
  - Bag is locked in combat — only hotbar contents exist during a fight.
  - Skills come from the equipped weapon, so 2 weapons = 2 kits; switching between them is a skill expression, not a menu.
- Accessories/loadout slots are a separate axis from weapon/armor.
  - Build identity (mobility set, tank set, crit set) comes from stacking accessories independently of class/weapon choice.
  - Target slot count, starting value, tune: 5-7 accessory slots alongside weapon + armor, mirroring Terraria's 7+.
- Flat-vs-% stats.
  - Defense reduction is flat per point, not percentage: `reduction = ceil(defense/2)` (Terraria formula, starting value, tune) or the Necesse-equivalent in §2 — pick one, see §6.
  - Flat reduction keeps armor meaningful against chip damage without trivializing a boss's one big hit; percentage reduction risks a "stack defense, ignore mechanics" failure mode.
  - Crit is a flat chance stat (~4% base, starting value, tune), no crit-damage-scaling stat — keeps the crit build-around simple (just accumulate chance).
- Caution carried from Terraria: a cheap-retry loop matters if fights are long/hard — don't copy punishing gear-check pacing without also copying fast re-gear/retry (Terraria's fights are minutes long with low death cost; a single hard RL boss fight doesn't get that safety net for free).

## 5. Mobile ergonomics (from Soul Knight) — DEFERRED

> **Deferred by [decision 0002](../decision/0002-pc-first.md).** PC (mouse + keyboard) is the target. Everything below is reference for a future mobile port, EXCEPT the two platform-neutral items kept live: the **red-ground AoE telegraph grammar** and the **two-layer shield + HP defense**. The input budget and auto-aim do not constrain design now.

- ~~Auto-aim as a selectable option~~ — out of scope until a mobile decision doc exists. PC uses mouse aim, full stop.
  - Auto-target nearest enemy; player skill expressed through positioning rather than a second analog stick.
  - Manual aim stays available and is the default per §6 — auto-aim is an accessibility/mobile layer on top.
- Two-layer defense: regenerating armor/shield absorbs first, non-regenerating HP behind it.
  - Starting value, tune: armor regen begins 5s after last hit taken, ~1 point/sec.
  - Rewards disengaging ("poke tax, not death spiral") without being a bullet sponge.
- Red-ground AoE telegraph is the universal grammar for "damage lands here."
  - One consistent visual language across every boss and every add — scales to arbitrarily complex kits without new UI per boss.
  - This is the primary fairness contract for RL-authored attack timing (§3) — if the RL boss can act outside this grammar, the grammar has failed, not the player.
- Input budget: collapse to the smallest touch surface that still supports full play.
  - Move stick, one primary fire, one context action (interact/dodge), one skill button with a visible cooldown sweep.
  - Target **max 4 distinct inputs** on mobile.
  - Desktop/gamepad may expose more (manual aim stick, weapon swap, hotbar) but the mobile subset must remain fully playable with 4.

## 6. Conflicts & resolutions

- **Necesse (no i-frames, armor+kiting) vs Terraria/Soul Knight (i-frame dodge or regen armor).**
  - Resolution: **settled by [decision 0004](../decision/0004-dodge.md)** — baseline dodge, 0.3s i-frames, 2s cooldown, no stamina.
  - Why: decision 0001 names Necesse primary for "how we play" (movement/aim feel), not the survivability model. A fixed, visible cooldown is legible to the player and trainable against by an RL boss — fair pressure, not a gotcha.
- **Terraria boss complexity (multi-part, many attacks, side-view dodge techs) vs mobile input budget.**
  - Resolution (updated by [decision 0002](../decision/0002-pc-first.md)): keep multi-part/phase/enrage *rules*; drop only what assumes jump-arcs or platform-based dodging (we are top-down). The mobile input budget no longer filters boss complexity.
  - Why: decision 0001 scopes Terraria to bosses/items, not controls; decision 0002 removes the touch-input filter until a mobile port is specced.
- **Necesse's difficulty-as-slider (knockback/damage-taken sliders) vs Terraria's "new moves per tier" mandate.**
  - Resolution: Terraria wins as the primary difficulty lever (§3).
  - Why: decision 0001 makes Terraria the boss/difficulty reference; Necesse-style numeric sliders are a fallback dial only if RL-boss tuning can't hit a target difficulty in time, never the first choice.
- **Soul Knight's fully-automatic aim vs Necesse's cursor-aim-as-baseline-feel.**
  - Resolution: **settled by [decision 0002](../decision/0002-pc-first.md)** — mouse aim is the control scheme. Auto-aim is not a shipped option until mobile is specced.
- **Terraria's flat percentage-free defense curve vs Necesse's crit-interacts-with-armor formula.**
  - Resolution: no real conflict in intent (both are flat-per-point), but pick one implementation — use Necesse's `damage - armor*0.5, crit after` since BossFight already commits to a crit stat that this formula makes meaningful.
  - Why: document Terraria's `ceil(def/2)` as a literature alternative in case tuning needs a steeper reduction curve later.
- **Soul Knight's energy-as-ammo (no passive regen) vs Necesse's stat-driven attack speed with no resource gate.**
  - Resolution: keep Necesse's model (no universal energy resource) for the core kit; treat energy-gating as an optional per-weapon/per-class mechanic, not a baseline system.
  - Why: decision 0001 only pulls Soul Knight for mobile *ergonomics* (input/telegraph), not its resource economy — importing energy wholesale would be scope creep beyond the decision.

## 7. Open questions

- Does the 2s dodge cooldown hold up against a policy that learns to bait it, or does it need per-boss tuning / a second charge?
- Do RL bosses train against a fixed roster of player archetypes/builds, or does training itself need to rotate builds to prevent overfitting (§3)?
- Should knockback immunity be boss-wide or per-attack, given knockback is a first-class stat in §2 but most late bosses should resist it?
- Do bosses also get a regenerating shield layer, and if so how are phase/enrage thresholds calculated over it?
- What is the actual boss roster size and pacing target (Terraria: ~18 gating bosses) — has this been scoped for BossFight, or does it need its own decision doc?
- Multi-part bosses (§3) and shared-HP swarm bosses both read as "many bodies" — does BossFight need both patterns, or does one subsume the other for a top-down RL-controlled boss?
- Does the "resist single-build overfitting" requirement (§3) need a formal eval harness (automated playtests per archetype) before a boss ships, or is manual playtesting sufficient?
- (Deferred to the mobile decision doc: touch input mapping, whether 5-7 accessory slots fit a phone UI.)
