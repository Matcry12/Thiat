# Necesse (Fair Games / Mads Skovgaard) — Design Reference

Researched for BossFight (Godot 4, top-down 2D combat, RL-driven hard bosses). Design facts only, no marketing.

## 1. Overview

- Genre: top-down 2D survival-RPG / colony-sim hybrid (Terraria-esque combat + RimWorld-esque settlement management), Early Access on Steam.
- Perspective: fixed top-down, tile-based world, free 360° aim independent of movement direction.
- Core loop: explore procedural biomes → mine/farm materials → craft gear tier → grow a settlement of NPC settlers who defend/produce → beat a biome boss to unlock the next crafting tier and area → repeat into Deep Caves → endgame "Incursion" boss gauntlet.

## 2. Combat system

- Movement: 8-directional free movement (WASD-style), no dash/roll by default — mobility comes from gear (boots, hoverboard, grapple-type items) rather than a core dodge mechanic.
- Aiming: cursor-based, decoupled from movement — player can strafe while aiming/firing in any direction, standard for top-down shooters/ARPGs.
- No universal i-frame dodge; survivability instead comes from armor value, ranged kiting, and terrain/arena use. This is a notable contrast to games with a dedicated invincibility roll.
- Four combat classes, each with its own armor category and weapon type: **Melee** (highest defense/armor, weapons have short-range hitboxes with swing arcs), **Ranged** (needs stocked ammo, positional kiting), **Magic** (mid-range spells, mana resource), **Summoning** (deals damage passively via AI-controlled minions, lowest personal defense — playstyle becomes "kite while pets fight").
- Melee in top-down works via a swing/arc hitbox model (not raycast/hitscan) — weapon has a reach + arc, animated swing, and a windup/recovery that gates attack speed.
- Damage formula (per wiki): `finalDamage = max(0, damage - (armor - armorPenetration) * 0.5)`; if the hit crits, multiply by crit damage multiplier (base 2.0×); then multiply by a random 0.8–1.2 variance factor; final damage floored at minimum 1.
- Armor: each point of armor reduces incoming damage by 0.5 HP. Because crit multiplier is applied *after* armor subtraction, armor is proportionally more valuable against crits than normal hits.
- Average DPS estimate: `(damage - (armor - armorPen)*0.5) * (1 + (critDamage-1)*critChance) * attackSpeed`.
- Combat state: player is flagged "in combat" while dealing/taking damage from hostiles; drops out of combat after 5s of no combat activity (gates things like fast travel/regen in many survival games — same idea here).
- Buffs/debuffs: consumables (potions/food) and trinkets grant damage%, crit chance, attack speed, and similar stat modifiers; settlements can place "buff banners" that grant an aura buff before a boss fight.
- Knockback exists as a stat and is explicitly tuned per difficulty (see difficulty table below) — knockback dealt/received is a first-class balance lever, not just cosmetic.

## 3. Boss design

Roughly 13 "main" story bosses (surface → caves → deep caves → final) plus 7 "Incursion" endgame bosses reached post-story. Each main boss gates a crafting tier; most are optionally re-summonable via a craftable summon item (exceptions noted).

**Main story bosses (roughly in order):**
- **Evil's Protector** — first mandatory boss; surface arena at night, must be killed before 6:30 AM in-game or fight ends/area resets; charges at player and spawns minions. Drops the item that unlocks the "Demonic Workstation."
- **Queen Spider** — Snow Cave spider-nest boss, summoned via a Royal Egg.
- **Void Wizard** — dungeon-bottom boss, 2-phase fight: phase 1 alternates a "sniper" attack (missiles spawn around him, then home toward player), a stationary fan-burst of homing bolts, and a clone attack (destroying the wrong clone spawns a bouncing projectile hazard — a readability/misdirection mechanic). At 50% HP he transforms and adds a wave-projectile attack. Re-summonable via "Void Caller."
- **Runebound Chieftain** — Plains Caves, summoned via Bone Offering on an arena pedestal.
- **Swamp Guardian** — Swamp Caves, summoned via Spiked Fossil.
- **Ancient Vulture** — Desert/Desert Caves, summon item placed on an Ancient Statue.
- **Pirate Captain** — gatekeeper to Deep Caves; the *only* main boss with no summon item — found by exploring pirate villages instead. Design note: breaks the "always re-farmable" pattern deliberately for a mandatory story gate.
- **Reaper, Cryo Queen, The Cursed Crone, Pest Warden** — Deep Cave biome bosses (Forest/Snow/Plains/Swamp respectively), each summoned by a biome-flavored item, each unlocks a settlement utility (Hoverboard, Banner Stand, Mission Board, Portal Flask) rather than pure gear.
- **Sage and Grit** — dual-boss gatekeeper to the Deep Desert Temple; two dragons that move very fast with dashes/dives and gain endurance (speed/aggression ramps) as the fight goes on. Explicitly called out as the hardest fight for the Summoner class because minion AI can't keep pace with the bosses' mobility — a cross-class balance failure worth noting for RL/AI-driven boss design (fast erratic movement breaks slower ally AI pathing).
- **Fallen Wizard** — final main-story boss, Deep Desert Temple. Passive until attacked (idle-until-aggro boss, not a scripted-start cutscene fight). Fixed opening pattern: energy-wave wall → teleport into a laser attack → energy-ball spiral. Summoner tip from players: stay close, or summons lose tracking if the boss/player kites too far — again a minion-AI leash-range issue. Drops the item unlocking Incursions (endgame) and an extra armor-set slot.

**Incursion (endgame) bosses**, each with a wiki-documented essence drop and escalating arena modifiers at higher tiers (examples cited: +52 resistance, +29% damage, slow auras stacked on top of the boss fight itself):
- **Mother Slime** (tier 2) — telegraphed 3-stomp buildup → spawns a ring of slime spawns with gaps in the ring (a "safe lane" pattern) → periodically summons Slime Warrior adds → speeds up and gets more aggressive as HP drops (classic enrage/phase-by-threshold, not scripted phase count). Ranged weapons trivialize it — a cited balance flaw.
- **Night Swarm** (tier 3) — a swarm of bats sharing one shared HP bar (many bodies, one health pool — good pattern for "boss reads as many small threats"), cycles through ~7 formation patterns: double circles, a collapsing triangle, grid sweeps, narrowing side-rushes, four-way splits, and single-bat one-at-a-time harassment. Speeds up at low HP. Devs/players recommend AoE weapons because single-target damage drags the fight out (an anti-single-target-meta design choice).
- **Spider Empress** (tier 4), **Moonlight Dancer** (tier 5, dedicated Moon arena), **Sunlight Champion** (tier 6, dedicated Sun arena), **Crystal Dragon** (tier 7, Crystal Hollow arena) — each has a themed dedicated arena and set-piece armor/essence reward; detailed per-attack patterns not fully documented publicly.
- **Ascended Wizard** (tier 10, true final boss) — 3-phase fight where the boss "dies" and revives into a stronger form twice (phase transitions triggered by HP hitting zero, not just HP thresholds mid-health) — i.e., death-and-rebirth phase transitions rather than continuous HP-bracket phase swaps.

**Difficulty modes** (5 total: Casual, Adventure, Classic, Hard, Brutal) change combat-relevant numbers directly, not just enemy count:
- Casual: −30% damage taken by player, −20% raider damage, −15% enemy spawn rate.
- Classic: baseline, no modifiers.
- Hard: increased player damage taken, increased boss HP, slightly increased spawn rate and raider damage, reduced knockback dealt by player.
- Brutal: significantly increased damage taken, boss HP, and knockback dealt to player; increased spawn rate and raider damage.
- Difficulty is changeable mid-save via world settings/chat command — not locked at world creation.
- Separate axis: death-penalty setting (none / drop materials / drop inventory / drop full inventory / hardcore permadeath) — an orthogonal risk dial from combat difficulty itself.

## 4. Enemy AI patterns

- Pathfinding uses a cost-comparison model: hostile "raider" AI computes path cost for several route options (e.g., walk N extra tiles vs. break a wall vs. cross hazardous terrain) and picks the lowest-cost route; walking is cheap, wall-breaking and hazard-crossing have cost penalties that make the AI strongly prefer the intact path even if longer (example cited: prefers 249 extra tiles of walking over breaking one wall).
- Known weakness (from player reports): pathing between separate regions/rooms is approximate for enclosed bases — raiders default to approaching from the cardinal direction nearest their spawn flag rather than solving the true shortest path, producing predictable siege lanes around player-built walls. Useful cautionary note: cost-based pathing without full recompute can produce exploitable "AI funnels."
- Settler NPC roles: settlers are task-oriented AI (farm, log, haul, craft, defend) with only some roles gated to specific specialist NPCs (fishing→fisher, fertilizing→farmer, animal care→animal keeper). "Guards" have a wider aggro/defend radius and materially higher combat stats than regular settlers, who only fight what gets close to them — a two-tier NPC-combat-AI split (dedicated defenders vs. incidental self-defense).
- Spawn-rate control is spatial and structural, not just numeric: placing a Settlement Flag drastically suppresses ambient hostile spawns in an 80×80 tile zone around it (expandable up to 272×272 across 6 tiers); light level also gates spawns (lit areas block zombie-type spawns). This ties enemy density directly to player base-building investment.

## 5. Progression

- Boss-gated tiering: each biome boss drop unlocks the next weapon/armor material tier and often a new base-building utility (not just numbers — Reaper→Hoverboard, Cryo Queen→Banner Stand, Crone→Mission Board, Pest Warden→Portal Flask). Progression is explicitly coupled: gear tier, area access, and settlement feature unlocks all gate on the same boss kill.
- Gear tiers run roughly Iron/Gold → Ivy (swamp) → higher deep-cave materials → Crystal/Spiderite-tier endgame sets; full matching armor sets grant unique set-bonus passives, and passive bonus values double once a gear piece reaches "tier 5" upgrade level (gear can be upgraded in place, not just replaced).
- Workstations gate crafting recipes and step up alongside boss progression (basic → Advanced Workstation → Demonic Workstation after Evil's Protector).
- Settlement/happiness loop affects combat indirectly: settler happiness affects productivity and shop prices, which feeds back into how fast the player can gear up — a soft economic-progression layer sitting alongside the direct boss-loot progression.

## 6. Feel / juice

- Telegraphing is pattern-based rather than heavy VFX-based: bosses signal intent through spatial setup the player must read (spike-ring gaps to stand in, swarm formation shape changes, a fixed windup sequence like Fallen Wizard's wall→teleport→spiral opener) more than through screen shake or flash-heavy VFX (not much documented on juice/hit-feedback specifically — wiki/community coverage is combat-math and pattern-focused, not feel-focused; treat as a documentation gap, not confirmed absence).
- Boss "safe lane" design recurs: Mother Slime's landing ring has gaps, several Night Swarm formations imply dodgeable channels — top-down bosses lean on "obstacle field with a readable gap" rather than pure bullet-hell density.
- Shared-HP-pool swarm bosses (Night Swarm) are a notable feel choice: many small visible bodies instead of one large sprite, letting the boss "read" as a crowd-control puzzle rather than a single hitbox.

## 7. Takeaways for BossFight

- **No universal i-frame dodge is viable if armor + kiting substitute for it** — but Necesse's top-down melee still relies on swing-arc hitboxes with windup/recovery, not raycasts; if BossFight bosses are RL-driven and fast, consider whether the player needs an explicit dodge/i-frame window (Necesse's absence of one is called out as a difficulty-mode-tunable "damage taken" slider instead — a valid alternative to i-frames, but harder for a human to read against an RL agent optimizing to punish exactly that gap).
- **Steal the "gap in the hazard ring" pattern** (Mother Slime) — cheap, highly readable telegraph: spawn a hazard ring/field with an obvious gap the player must relocate to. Works well for top-down 2D and gives an RL boss a legible "commit" action.
- **Steal the shared-HP swarm boss** (Night Swarm) — many small bodies with one pooled health bar is a strong top-down "boss reads as a system, not a single unit" pattern; also naturally anti-single-target-camping since players must spread damage, which is a good lever against a degenerate RL policy of hugging one attack.
- **Avoid**: summon/pet AI that can't keep pace with a fast/erratic boss (Sage and Grit dragons breaking Summoner class, Fallen Wizard's minion-leash losing target) — if BossFight ever has ally/summon mechanics against an RL boss, explicitly test that ally AI can track boss mobility, since RL bosses will find and exploit any AI leash-range or speed gap.
- **Avoid**: bosses trivialized by one meta build (ranged trivializes Mother Slime) — for RL-trained bosses this is especially dangerous, since the RL policy could similarly overfit to being beaten by one dominant strategy unless training/exploitation testing covers all player archetypes (melee/ranged/caster equivalents).
- **Steal**: death-and-rebirth phase transitions (Ascended Wizard reviving twice) as distinct from HP-threshold phase swaps — gives a harder "reset the fight" beat that's easy for a player to read (HP hits zero → cutscene/telegraph → new form) versus a continuous stat ramp, and is straightforward to implement as a discrete RL-boss state machine transition.
- **Steal**: decoupling movement from aim (free strafe-and-fire) as baseline top-down combat feel — already standard, but confirm BossFight's control scheme matches this expectation rather than a move-to-face-direction model, since that changes how readable/telegraphable a top-down RL boss's attacks need to be (player can always be looking at the boss while repositioning).
- **Steal**: armor as a flat-per-point damage-reduction stat mattering *more* against crits (post-armor crit multiplier) — a simple, tunable knob for balancing "does gear counter the boss's big hits or just its chip damage," useful if BossFight has a gear/loadout layer.
- **Caution on difficulty-as-slider**: Necesse's Hard/Brutal modes reduce player knockback dealt and increase knockback taken as an explicit difficulty knob — a cheap way to raise difficulty without new boss logic, worth having as a fallback dial if RL-boss tuning alone can't hit target difficulty in time.
- **Documentation gap to note**: public sources are thin on Necesse's actual hit-feedback/juice (screen shake, hit-stop, particles) — don't assume Necesse solved top-down readability through juice; its solution leans on spatial/pattern telegraphing instead, which is the more directly transferable lesson for BossFight's readability problem.

## 8. Sources

- [Bosses - Necesse Wiki](https://necessewiki.com/Bosses)
- [Combat - Necesse Wiki](https://necessewiki.com/Combat)
- [Armor - Necesse Wiki](https://necessewiki.com/Armor)
- [Guide:Classes - Necesse Wiki](https://necessewiki.com/Guide:Classes)
- [Difficulty mode - Necesse Wiki](https://necessewiki.com/Difficulty_mode)
- [World settings - Necesse Wiki](https://necessewiki.com/World_settings)
- [Void Wizard - Necesse Wiki](https://necessewiki.com/Void_Wizard)
- [Fallen Wizard - Necesse Wiki](https://necessewiki.com/Fallen_Wizard)
- [Settlements - Necesse Wiki](https://necessewiki.com/Settlements)
- [Kill Maze For Raiders - Necesse Wiki](https://necessewiki.com/Kill_Maze_For_Raiders)
- [Necesse Bosses in Order — Complete Boss Progression Guide (1.3)](https://necesse-wiki.vercel.app/bosses)
- [Necesse Incursions Guide — All Bosses, Tiers & Rewards (1.3)](https://necesse-wiki.vercel.app/guide/incursions)
- [Necesse Boss Guide: Night Swarm](https://deilru.com/necesse-night-swarm-guide/)
- [How to Beat the Ascended Wizard in Necesse | 3-Phase Final Boss Guide](https://deilru.com/necesse-ascended-wizard-guide/)
- [Necesse Settlement & Settler Guide](https://deilru.com/necesse-settlement-guide-guide/)
- [Necesse Difficulty Modes Explained | ScalaCube](https://scalacube.com/blog/necesse/necesse-difficulty-modes-explained)
- [Necesse World Settings | ScalaCube](https://scalacube.com/blog/necesse/necesse-world-settings)
- [Necesse Crafting Progression & Gear Guide - Equipment Tiers](https://supercraft.host/wiki/necesse/crafting_progression_gear/)
- [Necesse Boss Progression Order: Strategies & Loot](https://supercraft.host/wiki/necesse/boss_progression/)
