# Terraria — Game Design Reference

Source game: Terraria (Re-Logic, PC 2011, ongoing updates). 2D sandbox action-adventure,
side-view (not top-down) with free-aim melee/ranged/magic/summon combat and heavy boss-rush
progression. Captured here for BossFight (Godot 4, top-down 2D, hard/RL-driven bosses) so we
don't have to re-research it.

## 1. Overview

- Genre: sandbox survival-crafting + action-RPG combat, side-on 2D with physics (gravity, jump, dig).
- Core loop: mine/gather → craft better gear → fight a gated boss → boss drop unlocks new
  biome/tier/ore → repeat, alternating exploration and boss-rush checkpoints.
- ~18 major bosses form a strict gear-check spine from early game to endgame; almost all
  progression items are boss-gated rather than level-gated (no player XP/levels at all).

## 2. Combat system

- **Movement**: run + jump + double jump (via accessories), grappling hooks for vertical
  traversal, no innate dodge/roll — dodging is purely positional (walking/flying out of the
  telegraph) plus movement-speed and mobility accessories (wings, boots).
- **I-frames**: every hit grants a short window of "immunity frames" (~2/3 second base,
  can be reduced with the Bezoar/Obsidian debuff-avoidance items or increased with certain
  armor); i-frames are shared across all damage sources, so you can't be combo'd by two
  hits landing in the same instant, but rapid multi-hit weapons only land one tick of damage
  in that window.
- **Attack classes**: four parallel build paths — Melee (swords/spears, short i-frame-punish
  range, highest defense/life-steal support), Ranged (bows/guns, ammo consumption, highest
  DPS ceiling), Magic (staffs/spell tomes, consumes mana, hit-scan and homing options), Summon
  (minions/sentries that auto-attack, frees the player to kite while minions deal damage —
  closest analog to a "pet build"). Each class has dedicated armor sets and damage-type-specific
  accessory/buff stacking, encouraging (not forcing) single-class specialization.
- **Damage formula** (per terraria.wiki.gg/wiki/Damage):
  - `Weapon damage = Base weapon damage × Modifier multiplier`
  - `Final damage = Weapon damage × class damage multiplier (+ additive bonuses) × Archery/other buffs`
  - Damage variance: actual hit = `damage × random(0.85–1.15)`.
  - **Defense reduction is flat, not percentage**: `reduction = ceil(enemy defense / 2)` in
    Classic Mode (i.e., defense subtracts roughly half its value from incoming damage per hit),
    a stronger flat-subtraction effect in Expert/Master (~0.75×). This means defense is far more
    valuable against high-frequency low-damage attacks than against rare big hits — a deliberate
    diminishing-returns curve that keeps glass-cannon builds viable.
  - **Crit**: flat crit-chance stat (base 4%), crit hits deal ×2 damage, no crit-damage-scaling
    stat exists (keeps crit build-around simple: just accumulate chance).
- **Knockback**: attacks impart velocity on hit; if a hit deals more than 1/10 of the target's
  max HP, knockback is roughly doubled ("execution" knockback on low-HP/weak enemies), otherwise
  knockback is scaled by `knockback × (1 - target knockback resistance)`. Most bosses and many
  late-game enemies have 100% knockback resistance (immune) so knockback is a pure crowd-control
  tool for early/mid game, not a boss mechanic.
- **Debuffs**: on-hit status effects (Poisoned, On Fire, Confused, Weak, Cursed Inferno, etc.)
  from specific weapons/accessories act as sustained DoT or utility (Confused reverses enemy
  controls) layers independent of the base damage formula — a secondary build axis.
- **Buffs/banners**: standing near an enemy banner (unlocked by killing 50 of that enemy type)
  gives +10–20% damage vs that enemy type — a soft "farming reward" that also fights repetition
  fatigue in grind zones.

## 3. Boss design

Progression order and highlights (pre-Hardmode → Hardmode split by Wall of Flesh):

- **King Slime** — giant slime, teleports when cornered, spawns baby slimes; the "boss 0"
  tutorial fight, low threat, teaches the summon-item ritual.
- **Eye of Cthulhu** — night-only flying eye; phase 2 (below ~50% HP) grows a mouth and does
  fast erratic dash chains. First real DPS/dodge check.
- **Eater of Worlds** (Corruption) — giant segmented worm; each body segment is independently
  damageable and splits into new worms when cut, so poor targeting multiplies the fight instead
  of shortening it. Purely horizontal-tunneling AI.
- **Brain of Cthulhu** (Crimson) — flying brain shielded by orbiting "Creeper" adds; must clear
  adds before the brain itself becomes vulnerable — a phase-gate via minion clear rather than a
  health-percent phase.
- **Queen Bee** — alternates dash-charge and hover-and-summon-bee-swarm states; first "stance
  cycling" boss (distinct discrete behavior modes rather than one continuous pattern).
- **Deerclops** (seasonal/snow) — melee smash + rock-throw projectile; leashes to spawn point and
  goes immune if the player kites too far, an explicit anti-kiting rule.
- **Skeletron** — two rotating hands (must be damaged or dodged) guard a head; head periodically
  does a fast homing spin-charge. Time-gated (must be beaten by dawn or it enrages/despawns) —
  first hard-enrage-timer boss, and gates access to the Dungeon.
- **Wall of Flesh** — screen-filling horizontal wall in the Underworld that is pushed forward by
  the player fleeing from it; fires lasers/summons Hungries; dies if it reaches the level edge
  before the player kills it (a forced-scroll shooter fight, unique traversal-based structure).
  Beating it flips the entire world into Hardmode (new ores, biomes, enemy tier).
- **Queen Slime** (early Hardmode, optional) — flight + teleport-slam combo, summons crystal
  minions; a soft "practice boss" before the mechanical trio.
- **The Twins** (Retinazer/Spazmatism) — two independent mechanical eyes with different attack
  styles (laser beam vs. fireball spray) fought simultaneously; each transforms into an armored
  "true" form at 40% HP with faster/stronger attacks. Two-boss-at-once forces split attention.
- **The Destroyer** — huge mechanical worm, doesn't split (unlike Eater of Worlds), fires lasers
  from body segments; primarily a DPS-race/movement fight in open sky.
- **Skeletron Prime** — four independently-attacking mechanical limbs (chainsaw, drill, laser
  cannon, hook/spin) around a head; only the head needs to die, limbs are damage-sponge threats
  you can choose to ignore or clear — build-your-own-difficulty via targeting choice.
- **Plantera** — jungle boss with grapple-hook tentacle attacks and seed/spore projectiles;
  sheds petals as a visible HP-phase indicator, spawns extra tentacles in Expert; critically,
  **enrages (huge damage/speed buff) if the player leaves the Jungle biome during the fight** —
  an explicit arena-lock mechanic enforced by biome checks, not walls.
- **Golem** — stone construct in two phases: body+head grounded (limited attacks), then head
  detaches and flies independently with a laser-eye barrage — a literal "second boss" spawned
  from the first.
- **Duke Fishron** — three-stage fight (charge-ram → shark-tornado/bubble spam → enraged final
  stage with fast homing sharknados); widely cited as the first "you need real i-frame/dodge
  skill, not just gear" pre-Moon Lord boss. Summoned by fishing with a rare bait in the ocean,
  not a craftable item — a soft-gated "optional superboss."
- **Empress of Light** — daytime-only Hallow fairy; extremely high mobility with dense
  bullet-hell projectile patterns and a devastating night-mode/aggro-timer variant; widely
  considered the hardest "clean bullet-hell" boss and a favorite reference for attack-pattern
  readability at high difficulty.
- **Lunatic Cultist** — spawns illusory copies of itself (only one is real), summons Phantasm
  Dragons; final gate before Moon Lord, teaches "identify the real target among decoys."
- **Moon Lord** — final boss: a floating head plus two independently-targetable hands (True Eyes
  of Cthulhu on each hand) and phase-based eye-laser attacks from the core; combined HP over
  100k; the culmination fight that expects the player to have mastered dodging dense multi-part
  attacks simultaneously from several hostile body parts.

**Expert/Master Mode changes** (terraria.wiki.gg/wiki/Expert_Mode):
- Boss HP scales by a per-boss multiplier (roughly 1.4–2.0× in Expert; Master adds a further
  flat +27.5% HP / +50% damage on top of Expert values).
- Most bosses gain an **entirely new attack or phase** in Expert Mode (not just bigger numbers) —
  e.g., Duke Fishron gains an extra combat stage. This is the key lesson: difficulty modes add
  new *behaviors*, not just stat multipliers.
- General enemies roughly double damage output; players get defense effectiveness bumped ~50%
  to partially compensate, keeping "gear up defense" viable at higher difficulty.
- Debuff durations on the player double in Expert.
- Treasure Bags replace normal boss loot in Expert/Master and guarantee rare "rainbow" items
  (permanent movement/utility accessories) that work in all difficulty modes — the reward for
  opting into harder fights is account-wide QoL, not just cosmetic flex.

## 4. Enemy AI patterns (reusable archetypes, per terraria.wiki.gg/wiki/AI)

- **Fighter AI**: ground-based, directly chases the player, jumps over obstacles/gaps and when
  the player is above it, navigates one-way platforms. The default "dumb melee rusher."
- **Flying AI**: hovers/chases in open air, ignores gravity and terrain, usually maintains some
  standoff distance before diving.
- **Caster AI**: does not chase by walking — teleports near the player periodically, then fires
  slow-moving projectiles that travel through solid blocks (so cover doesn't fully protect you).
  Ranged-pressure archetype that punishes standing still.
- **Worm AI**: multi-segment body, passes through all solid blocks, immune to knockback and
  unaffected by liquids/lava; used for burrowing enemies (Eater of Worlds, Wyverns, Digger).
  Each segment can be an independent hitbox.
- General pattern across all archetypes: enemies are built from a small set of composable AI
  "modules" (movement style + attack style + target-acquisition rule) reused across dozens of
  reskinned enemies — a cheap way to generate large enemy variety from few actual behavior trees.

## 5. Progression

- No player levels/XP. Power comes entirely from **gear tiers gated by boss kills and biome
  access** — ore unlocked by a boss often can only be mined with a pickaxe from that same or a
  prior tier, creating soft lockstep pacing.
- Two-era split: **pre-Hardmode** (Copper→Tin→Silver→Gold ore tiers, culminating in Molten
  armor from the Underworld) then **Wall of Flesh** flips the world into **Hardmode** (new ores:
  Cobalt/Palladium → Mythril/Orichalcum → Adamantite/Titanium, then post-mechanical-bosses
  Hallowed armor, then Chlorophyte-based class-specific armors: Turtle/Beetle for melee,
  Shroomite for ranged, Spectre for magic, Spooky/summon sets).
- Difficulty modes are chosen at world creation (Classic / Expert / Master / Journey), not
  mid-run — a structural commitment rather than a toggle, which lets encounter design assume a
  fixed baseline instead of solving for a slider.
- Loadout axis is **accessories**, not just weapon/armor: up to 7+ equip slots (movement, combat
  utility, defensive) stack independently of class choice, so build identity comes from
  accessory combos (mobility set vs. tank set vs. glass-cannon crit set) as much as from weapon.
- Class specialization is emergent, not forced: armor set bonuses and accessory damage bonuses
  are class-typed, nudging players toward single-class builds without a hard class-lock system.

## 6. Feel / juice

- Every hit produces: white damage-number popup (color/scale varies for crit — crit numbers are
  larger and yellow), a brief hit-stun/knockback flinch on the target, and a punchy short sound
  cued to weapon type.
- Screen shake is minimal/absent for most hits, reserved mostly for explosions and a few boss
  ultimate attacks — Terraria relies more on hit-pause-free rapid numbers + particle bursts than
  camera shake, keeping the game readable during dense bullet-hell boss phases.
- Tile destruction (mining, explosions) uses particle debris matching the block's texture/color,
  reinforcing material identity even in VFX.
- Boss telegraphs are almost entirely **visual read + audio cue** (a screen-wide roar sound,
  a visible wind-up animation) rather than UI indicators — attacks are dodgeable by pattern
  recognition, not reaction-testing a health bar.
- Death/damage-taken feedback: player sprite flashes red and knocks back; a "Killed by X" ×
  Discord-share-friendly death message reinforces boss lethality as part of the social loop.
- Music stings on boss spawn (distinct theme per boss) plus a "boss intro" screen-lock beat are a
  strong, cheap way to mark stakes rising.

## 7. Takeaways for BossFight

- **Flat, not percentage, defense reduction** (`ceil(def/2)`) is a good pattern to steal: it
  keeps armor meaningful against chip damage while not trivializing big boss hits — avoids the
  "stack defense, ignore boss mechanics" failure mode percentage-reduction systems can fall into.
- **New attacks per difficulty tier, not just bigger numbers.** Terraria's Expert/Master design
  is explicit about this — worth enforcing for any RL-driven boss difficulty scaling in
  BossFight: don't just crank the RL reward/aggression, unlock genuinely new move patterns.
- **Enrage via explicit rule, not vague "if losing"**: Plantera's "leave the biome = enrage" and
  Skeletron's "not dead by dawn = enrage" are clean, telegraphable, leash-style anti-stalling
  mechanics. Cheap and legible — good template for keeping bosses from being cheesed by running
  away or turtling forever.
- **Multi-part bosses (independently targetable limbs/hands) create emergent difficulty** without
  new attack design — Skeletron Prime and Moon Lord get more threat from "multiple simultaneous
  attackers sharing one fight" than from raw numbers. Cheap complexity lever for a top-down game
  too (spawn adds/limbs the RL boss controls in parallel).
- **AI built from a small reusable module set** (movement style × attack style) is how Terraria
  gets huge enemy variety cheaply — directly applicable to BossFight's trash-mob layer even if
  bosses are bespoke/RL-driven.
- **I-frames are short and universal**, not per-attack-type — simplifies both player fairness and
  boss attack design (no need to hand-tune iframe interactions per move).
- **Visual/audio telegraph over UI telegraph**: bosses are readable through animation wind-up +
  sound cue, keeping the frame free of intrusive indicators during dense patterns — worth holding
  as a north star if BossFight's RL bosses produce non-human-designed attack timing that still
  needs to be fair.
- **Boss loot is the entire progression currency** — no XP curve to balance in parallel; simpler
  to design around if BossFight also wants boss-gated (not grind-gated) power growth.
- **Caution**: Terraria's flat/no-percentage damage growth and gear-check pacing works because
  fights are short (minutes) and death has low cost (respawn nearby, keep items). A single very
  hard, long RL boss fight (BossFight's stated design) doesn't get the same "just re-gear and
  retry quickly" safety net — don't copy Terraria's punishing early-game one-shot potential
  without also copying its cheap-retry loop.
- **Caution**: side-view physics (gravity, jump-arcs, platform navigation) is core to how Terraria
  telegraphs and how players dodge; none of the movement-based dodge techs translate directly to
  a top-down, no-gravity control scheme — treat the attack-pattern/telegraph lessons as portable,
  not the specific dodge mechanics.

## 8. Sources

- [Damage — Official Terraria Wiki](https://terraria.wiki.gg/wiki/Damage)
- [Defense — Official Terraria Wiki](https://terraria.wiki.gg/wiki/Defense)
- [Knockback — Official Terraria Wiki](https://terraria.wiki.gg/wiki/Knockback)
- [Bosses — Official Terraria Wiki](https://terraria.wiki.gg/wiki/Bosses)
- [Expert Mode — Official Terraria Wiki](https://terraria.wiki.gg/wiki/Expert_Mode)
- [Master Mode — Official Terraria Wiki](https://terraria.wiki.gg/wiki/Master_Mode)
- [Expert-exclusive content — Official Terraria Wiki](https://terraria.wiki.gg/wiki/Expert-exclusive_content)
- [Fighter AI — Official Terraria Wiki](https://terraria.wiki.gg/wiki/Fighter_AI)
- [Caster AI — Official Terraria Wiki](https://terraria.wiki.gg/wiki/Caster_AI)
- [Worm AI — Official Terraria Wiki](https://terraria.wiki.gg/wiki/Worm_AI)
- [AI — Official Terraria Wiki](https://terraria.wiki.gg/wiki/AI)
- [Guide:Armor progression — Official Terraria Wiki](https://terraria.wiki.gg/wiki/Guide:Armor_progression)
- [Guide:Game progression — Official Terraria Wiki](https://terraria.wiki.gg/wiki/Guide:Game_progression)
