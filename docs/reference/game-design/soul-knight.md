# Soul Knight — Game Design Reference

Source game: Soul Knight (ChillyRoom, mobile/Switch/PC, 2017–ongoing). Top-down 2D
roguelite dungeon-crawler shooter with twin-stick combat, designed mobile-first
(virtual joystick + auto-aim). Captured here for BossFight (Godot 4, top-down 2D,
hard/RL-driven bosses) so we don't have to re-research it.

## 1. Overview

- Genre: roguelite twin-stick shooter/dungeon-crawler with RPG-lite meta-progression
  (gacha-adjacent character/weapon unlocks).
- Perspective: top-down 2D, room-based levels connected by doors, camera fixed per room.
- Core loop: enter room → clear all enemies (door locks until cleared) → loot weapons/gold
  → reach level x-5 boss room → beat boss → portal to next floor; die and lose the run
  (roguelite), but keep meta-currency (gold→gems, unlocks) between runs.

## 2. Combat system

- **Movement**: single virtual joystick (mobile) or WASD; 8-directional free movement,
  no physics/momentum. No innate dodge-roll or i-frames — survival is 100% positional
  (kiting, using cover, LOS-breaking) plus a handful of character skills that grant brief
  invincibility/blink (e.g. Rogue's dodge skill).
- **Aiming**: fully automatic. Weapons always auto-target the *closest* enemy (shown by a
  red circle at its feet) — the player's only aiming input is movement/positioning to
  control which enemy is closest and to control bullet-avoidance. This is the single
  biggest mobile-control accommodation: no aim stick, no manual reticle.
- **Weapon slots**: 2 weapon slots (3 with a buff), swap freely, no reload — energy is the
  resource gate instead of ammo count.
- **Energy (mana/ammo hybrid)**: every non-melee weapon costs Energy per shot; if energy
  is below the weapon's cost, the weapon can't fire or fires in a crippled fallback mode.
  Energy regenerates from pickups (orbs, potions, Statue of the Priest), some skills/buffs,
  not passively over time — this is what stops "hold trigger forever" spam and forces
  weapon-swap/melee fallback under pressure.
- **Armor (shield) vs HP**: two-layer defense. Armor absorbs all hits first and must be
  fully depleted before HP loss; armor auto-regens ~1/sec after 5s without taking damage
  (faster with buffs). HP has no natural regen (only potions/heals). This creates a
  "poke tax, not death spiral" rhythm — chip damage is free if you disengage for 5s,
  but sustained pressure burns into the un-regenerating HP pool.
- **Crit chance**: flat % stat, adds to every weapon's own crit stat; normally crit = 2×
  damage, but on weapons that can't multiply damage a crit instead applies a status effect.
- **Melee fallback**: pressing fire near an enemy while holding a non-melee weapon does a
  free melee swipe (Melee Damage stat) — always-available backup when energy is empty.
- **Weapon categories**: pistols/SMGs/rifles/shotguns/sniper rifles/rocket launchers
  (physical, hitscan-ish or projectile), magic staffs/wands (elemental, often
  homing/piercing/charge-based), melee (swords/blades/hammers/spears — some with
  swing arcs, some with dash-thrust), throwables (grenades, mines). Stats shown per
  weapon: Damage, Energy Cost, Crit Chance, Inaccuracy (bullet spread cone — high on
  shotguns, ~0 on snipers). Charge weapons show two damage/crit values (min~max).
- **Status effects**: Burn (DoT), Freeze (root/slow), Poison (DoT, stacks), Weary
  (debuff), stun/knockback — inflicted by both player weapons and enemy/boss attacks;
  countered by dedicated Buffs (Fire Buff, Poison Buff, etc.) that grant immunity/resist.
- **Shield item** (distinct from Armor stat): a deployable barrier that blocks projectiles
  only — explicitly does *not* stop AoE (lasers, explosions), melee, floor hazards
  (spikes, fire/poison pools) or status effects. Good example of a defensive tool with a
  hard, legible exception list rather than a blanket "block everything" button.
- **Room-based encounter design**: door locks on room entry, all enemies must die to
  unlock it; rooms are small enough that most fights become a single held "arena" rather
  than continuous scrolling combat — this is what lets bullet-hell boss patterns work
  without an off-screen problem.
- **Elites/Champions**: bigger, purple-glowing enemy variants with more HP/damage and
  sometimes different behavior, seeded into normal rooms as a difficulty/loot lever
  (separate from bosses).

## 3. Character/skill design

- 40+ playable heroes, each with: unique base stats (HP/Armor/Energy/Crit/Melee/Move
  Speed), a unique starter weapon, and 2–3 unique skills (first free on unlock, others
  gem-purchased) on a cooldown (lightning-bolt icon). Leveling a character (gem sink)
  gives flat stat bumps plus a level-5 skill upgrade and level-7 starter-weapon upgrade.
- Skills are the differentiator, not weapon access — any hero can pick up and use any
  weapon on the floor, but skills bias playstyle: e.g. Rogue's short dash/blink (mobility
  + pseudo-i-frame), Berserker's melee-damage rage mode, Priestess's party heal/shield,
  Elf's vine wall that also refunds energy/HP on enemy kill (build-around for
  minion-heavy bosses), Wizard-type stun/lightning to interrupt boss attacks, Engineer's
  turret/sentry (a temporary "second gun" independent of weapon slots), Robot's
  self-shield.
- Skill-weapon synergy is explicit in wiki tactics write-ups (e.g. "Elf is recommended
  against Skeleton King because Focus-mode kills refund vines, letting the player
  facetank while an AoE gun clears his skeleton summons") — skills are framed as boss
  counters, not just generic power.
- Net effect: character choice = a passive kit (stat profile + 2-3 cooldown skills)
  layered on top of a shared, run-randomized weapon pool — decouples "who you are" from
  "what you're currently holding," which lets loot stay exciting without ever locking a
  hero out of using it.

## 4. Boss design

General boss rules (from the Bosses wiki page): 1 boss per floor's level x-5, chosen
randomly from that biome's boss pool; room has a distinct hazard layout (cover blocks,
statues, pits); on dropping below 50% HP a boss enters an **Enraged Phase** — faster
attacks, more aggressive patterns, faster projectiles, faster status-effect recovery,
sometimes wholly new attacks — and drops energy orbs both at the 50% threshold and on
death. A few bosses instead *heal* in their enraged phase (Crystal/Golden Crab, Cave Ice
Bug, Anubis), which does not cancel the enraged behavior change. Bosses always telegraph
big attacks with a red ground-warning silhouette (circle/cone) before the hit lands —
the one universal "read this, then dodge" language across every boss.

Representative bosses (attack counts/HP from wiki Tactics pages):

- **Skeleton King** (Dungeon, 5 unique attacks): ground-slam bullet ring; twin sword-slash
  bullet arcs; 8 delayed-start homing missiles (unreflectable); summons expendable
  skeleton adds; a *audibly telegraphed* (sword-chime SFX) dash + explosive shot — sound
  cue as telegraph channel, not just visual. High mobility voids static cover; countered
  by control/slow effects.
- **Grand Wizard** (Knight Kingdom, 4 attacks): room-sweeping laser (highest single
  source of damage), rotating geometric bullet formations, dual expanding bouncing-bullet
  rings, adaptive bullet spray that re-aims if the target moves. Minimal cover forces
  constant repositioning — a "no safe spot, must always be reading the telegraph" boss.
- **Zulan the Colossus** (Spaceship, 9 attacks, has explicit Normal/Enraged attack lists):
  floating drone escort that independently fires lasers or bullet-spreads (each
  telegraphed by its own warm-up sound + warning beam); drone "sword" attack that swings
  a ring of drones around itself (dodge by ducking into the gaps — spacing puzzle, not
  reflex-only); reflectable bullet spiral. Multi-body boss = multiple simultaneous
  telegraphs the player must triage.
- **Anubis** (Volcano, 4 attacks, has Normal/Enraged split): rotating ground laser staff;
  helix-pattern homing orb triplets; a destructible turret that zigzag-fires; a two-part
  summon (falling obelisk that leaves a damage+debuff pool, and a headstone that spawns
  waves of mummy adds). Heals during enrage instead of just hitting harder — punishes
  slow/passive DPS checks.
- **Ultimate Weapon: Code 01** (final Ancient Battleground boss, 9 attacks): melee combo
  chain (two swings + a shockwave slam), AoE slam on a targeted red-circle zone, a
  vacuum/grab attack that also *absorbs incoming player damage* (a "don't shoot during
  this window" mechanic), triple rippling-ring lightning strike with a forced
  3-second exhaustion window afterward (a designed DPS-race opening). Also has a
  separately-tuned, much higher HP curve in the game's endless "Three Kingdoms" mode —
  same kit reused as a scaling-difficulty gate rather than redesigned per tier.
- **Baby Dragon Bros**: two bosses sharing one displayed health bar but independent
  thresholds — either twin can enrage on its own below 50%, an easy-to-miss shared-bar UI
  trick worth noting for co-op/multi-add boss fights.
- **Badass/hard-mode changes** (Badass Mode, unlocked via Living Room Magic Stone):
  enemies spawn and attack more frequently; champion (elite) spawn rate increases; *all
  bosses are forced into their Champion form* (flat HP multiplier, no new moves); player
  Defense is lowered by 1 flat point (more damage taken from everything, including
  status/environmental). Difficulty scaling here is almost entirely numeric (HP/damage/
  spawn-rate multipliers), not new boss movesets — cheap to build, but leaves "hard mode"
  feeling more like attrition than a new puzzle.

## 5. Enemy AI patterns

- **Melee rushers**: close distance in a straight line, no ranged threat, exist to
  punish standing still / force movement uptime.
- **Ranged skirmishers**: keep mid-range, strafe while firing, break LOS behind cover —
  basic "kite the player" archetype filling most rooms.
- **Snipers/turrets**: stationary or slow, long-range high-damage single shots, often
  require the player to close distance or break sightline rather than out-heal.
- **Suicide/bomber units**: rush to point-blank then self-destruct in an AoE — a
  soft time-pressure mechanic inside normal rooms (kill at range or reposition).
- **Casters/summoners**: low personal threat, spawn or buff other enemies (mirrors the
  boss "summon" attack pattern at trash scale) — priority-kill target in a mixed room.
- **Shielded/armored variants**: require breaking a damage-reduction layer or hitting a
  specific angle/weak point before taking normal damage.
- **Champions (elites)**: same base AI as their normal counterpart, just higher HP/damage
  and occasionally a bonus behavior — the game's cheapest difficulty knob, same pattern
  reused at boss scale via "all bosses are Champions" in Badass Mode.
- Enemies almost never combine unpredictable movement with unpredictable attacks at once
  — an enemy that moves erratically usually has a simple/telegraphed attack, and a
  heavy-hitting enemy is usually stationary or slow — keeping the room's total "things to
  track" bounded even as enemy count scales.

## 6. Progression

- **Run structure**: Level Mode = reach the floor-4 Magic Stone by clearing a minimum of
  3 floors × 5 levels each (some modes extend further); level x-5 (and x-3 on floor 4) is
  always a boss room, marked distinctly (red-visored helmet icon) so the player always
  knows a boss is next before walking in.
  - Boss Duo challenge variant: 2 bosses spawn simultaneously in a shared arena (from
    potentially different biomes), arena centered on whichever boss spawned first.
- **In-run buffs**: picked up from chests/shops/altars mid-run, stack for the run only —
  classic roguelite build-you-run-as-you-go layer independent of weapons.
- **Meta-progression**: gold earned in-run converts to gems at run end; gems buy new
  playable characters, character level-ups (flat stat/skill/weapon upgrades), pets,
  Living Room (hub) upgrades, and Gashapon (gacha) pulls for cosmetics/extra content.
  Permanent power growth is character-slot-based (more heroes, each hero stronger), not
  a single shared account level.
  Living Room room-upgrades (once unlocked) can grant small universal bonuses (e.g. a
  fully upgraded Book Pile + Plant gives +5% crit and +1 move speed to every character).
- **Difficulty scaling**: primarily Badass Mode toggle (flat multipliers on spawn rate,
  champion odds, boss HP via forced Champion form, and player defense) rather than a
  granular numeric slider; separate structured "endless"/gunfight modes reuse the same
  boss kits at explicitly listed, steeply-increasing HP tiers per difficulty (see
  Ultimate Weapon: Code 01 D1→D5+ HP above) instead of hand-authoring new fights.

## 7. Feel / juice

- **Hit feedback**: enemies flash on hit, small hitstop/knockback on heavier weapons,
  distinct SFX per weapon category (shotgun boom vs. laser zap vs. sword clang) so the
  player identifies "what just hit me" by ear as much as by sight.
- **Screen shake / impact**: used on heavy player weapons (rocket launchers, melee
  hammers) and select boss attacks (ground slams), kept short so it doesn't blind the
  player mid-bullet-hell — juice is dosed, not constant.
- **Bullet readability**: strong color/shape coding per bullet type (size, color, and
  trail distinguish "chip damage," "status," and "big hit" bullets at a glance); AoE
  attacks get an explicit red ground-warning shape before they resolve, giving a fixed
  reaction window regardless of bullet speed — this is the game's core readability
  contract and the reason bullet-hell density stays fair on a small mobile screen.
  Sound is a secondary telegraph channel for some attacks (Skeleton King's dash chime),
  useful when the screen is already visually saturated.
- **Mobile control ergonomics**: single joystick for movement, auto-aim removes the need
  for a second analog stick, one primary fire button + one interact/pickup button that
  contextually relabels itself (targeting reticle ↔ exclamation mark), skill button is a
  single tap with a visible cooldown sweep. The entire control scheme collapses to
  "3 touch zones" — this is the design result of choosing auto-aim, and it's the reason
  the genre works at all on a phone.

## 8. Takeaways for BossFight

1. **Auto-aim + full manual movement is legitimate, not a crutch.** Decoupling "where to
   stand" from "where to shoot" (auto-target nearest) simplifies the action space while
   keeping combat skill-expressive through spacing — relevant for mobile controls and for
   bounding an RL agent's action space.
2. **Steal the red-ground-warning telegraph as a universal grammar.** One consistent
   visual language for "AoE about to land here" scales to arbitrarily complex boss kits
   without new UI per boss, and keeps an RL boss's attack timing legible to a human.
3. **Two-layer defense (regenerating armor + non-regenerating HP) rewards disengagement
   without being a bullet sponge** — makes "reset and re-peek" valid against a hard boss.
4. **Energy-as-ammo (regen only from pickups/skills, not passive) beats per-weapon
   cooldowns as a DPS throttle** — weapons stay snappy, spam is still prevented, and it
   creates natural "go melee" beats under pressure.
5. **Enrage-at-50%-HP is a cheap, legible phase trigger** — but the wiki flags healing
   bosses as an exception worth calling out explicitly; a boss that heals through its own
   "you're winning" transition reads as unfair unless clearly telegraphed.
6. **Avoid the Badass Mode trap**: don't make "hard mode" purely HP/damage multipliers on
   the same moveset — cheapest lever, least interesting. For RL-driven bosses especially,
   prefer new emergent behavior over stat inflation; the agent can generate variety for free.
7. **Multi-part bosses need per-part telegraphs, not one global tell** (Zulan's escort
   drones each warn independently) — give every add/summon its own legible warning.
8. **Shared-health-bar multi-boss fights (Baby Dragon Bros) are a UI trap** — if two
   entities share a displayed bar but enrage independently, players misread it; show
   separate bars or make the shared behavior consistent.
9. **Skills-as-boss-counters gives replay reasons to swap loadouts per boss** — worth
   mirroring with build choices explicitly good/bad against specific bosses, documented.
10. **Room-lock encounter design (clear-to-unlock-door) is what makes bullet-hell density
    readable** — guarantees a bounded arena, which matters for an RL boss too.

## 9. Sources

- [Game Mechanics — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Game_Mechanics)
- [Bosses — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Bosses)
- [Characters — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Characters)
- [Enemies — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Enemies)
- [Skeleton King/Tactics — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Skeleton_King/Tactics)
- [Grand Wizard/Tactics — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Grand_Wizard/Tactics)
- [Zulan The Colossus/Tactics — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Zulan_The_Colossus/Tactics)
- [Anubis/Tactics — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Anubis/Tactics)
- [Ultimate Weapon- Code 01/Tactics — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Ultimate_Weapon-_Code_01/Tactics)
- [Badass Mode — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Badass_Mode)
- [Levels — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Levels)
- [Living Room — Soul Knight Wiki](https://soul-knight.fandom.com/wiki/Living_Room)
- [Soul Knight Review — TouchArcade](https://toucharcade.com/2017/03/10/soul-knight-review/)
