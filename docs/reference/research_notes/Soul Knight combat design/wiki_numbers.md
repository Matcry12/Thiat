# Soul Knight wiki numbers (soul-knight.fandom.com, read via built-in browser)

All facts below were read from the full page text (not search snippets). Base URL: https://soul-knight.fandom.com/wiki/ . Values in parentheses "X (Y)" on the wiki = base (with skill/stat upgrade). Fandom is community-edited; treat as good but not official.

## Player resources: HP, armor, energy, defense, speed

### Takeaway
Armor absorbs damage before HP, regenerates 1/s after a short no-damage delay, and excess damage over the armor value spills into HP. Base speed is 6.5 tiles/s for nearly all heroes. Wiki has NO page or number for post-hit invincibility frames.

### Cited Findings
- Armor auto-regenerates after the player stops taking damage for 3 seconds, at 1 armor per second. If a hit exceeds current armor, the excess goes to HP (5 armor + 6 damage = armor 0, HP -1) — [Stats](https://soul-knight.fandom.com/wiki/Stats#Armor); contradicts the earlier note of "5 s" from a search snippet of [Game Mechanics](https://soul-knight.fandom.com/wiki/Game_Mechanics) (unresolved; Stats page text says 3 s)
- Frostbite slows armor regen; Shell Protection fully neutralizes it — [Stats](https://soul-knight.fandom.com/wiki/Stats#Armor)
- Grave Guard Scarab Archon is the only boss with an armor bar — [Stats](https://soul-knight.fandom.com/wiki/Stats#Armor)
- Movement speed: default 6.5 (tiles per second) for characters; Trap Master 6.0, Costume Prince 7.0. "Out of combat" gives +50% speed in the main game formula (Type C) — [Stats](https://soul-knight.fandom.com/wiki/Stats#Movement_Speed) (page marked as stub)
- Defense (hidden): 2 defense = 2 less damage per hit; diminishing returns table (1->1, 2->2, 3-4->3, 5-7->4 ... 100->12) — [Stats](https://soul-knight.fandom.com/wiki/Stats#Defense)
- Cooldown reduction formula: reduction % = CDR/(CDR+100); 25 CDR gives 20% (10 s skill -> 8 s). Does not affect skill duration — [Stats](https://soul-knight.fandom.com/wiki/Stats#Cooldown_Reduction)
- Energy: needed by most weapons; some weapons cost none. Restored by potions, energy orbs from enemies/bosses, etc. No natural regen listed — [Stats](https://soul-knight.fandom.com/wiki/Stats#Energy)
- Enemy inaccuracy: a stat x means each bullet is fired randomly within +/-0.5x degrees of aim (SMG M3 with 20 = +/-10 degrees) — [Stats](https://soul-knight.fandom.com/wiki/Stats#Inaccuracy)

### Inferences
- The "armor delay 3 s, +1/s" pair is small enough to tune as two @exports (delay, rate).
- Pets: health depleted -> passive 30 s then full heal ([Stats](https://soul-knight.fandom.com/wiki/Stats)); a possible pattern for a downed-companion mechanic.

### Gaps
- Post-hit invincibility time: not on the wiki. `Invincibility` page does not exist ([empty page](https://soul-knight.fandom.com/wiki/Invincibility)). Knockback pages not found either.
- 3 s vs 5 s armor delay conflict is unresolved (may differ by game version).

## Characters (base stats, skills, cooldowns)

### Takeaway
Six heroes checked. Base stats are small integers (HP 3-9, armor 3-5, energy 150-240). Skills are timed state changes with cooldowns from 2.5 s to 12 s; invulnerability windows are 0.5 s (dodge) up to about 1.5 s (Assassin dash).

### Cited Findings
Stats format: HP / Armor / Energy / Crit% / Melee dmg / Speed (upgraded value in parentheses).
- Knight: 6 (7) / 5 (6) / 180 (200) / 5 / 4 / 6.5. Passive "Strong Shield Buff". Upgrade ladder: +1 HP, +1 armor, +20 energy, -2 s skill CD, skill upgrade, passive, better starter weapon — [Knight](https://soul-knight.fandom.com/wiki/Knight)
- Knight Dual Wield: second copy of current weapon for 5 s, both fire (each copy costs energy), cooldown 10 (8) s, cooldown starts after the skill ends, switching weapons ends it; kills extend by 0.5 s up to a 5 s cap — [Knight](https://soul-knight.fandom.com/wiki/Knight)
- Knight Superior Fire (all weapons, 5 s, CD 10 (8) s); Chaotic Strike (random status effect on hits, 5 s, CD 8 (6) s) — [Knight](https://soul-knight.fandom.com/wiki/Knight)
- Rogue: 5 (6) / 3 (4) / 180 (200) / 10 / 5 / 6.5. Passive "Piercing Crit Buff". Described as one of the lowest-armor heroes — [Rogue](https://soul-knight.fandom.com/wiki/Rogue)
- Rogue Dodge: roll forward, ignore all hostile damage for 0.5 s, can still attack while rolling, CD 2.5 (0.5) s, cooldown starts when roll animation ends. Upgrade: +50% crit chance for 1 s after dodge — [Rogue](https://soul-knight.fandom.com/wiki/Rogue) (confirms the earlier 0.5 s CD snippet: it is the fully upgraded value, not a typo)
- Rogue Iaido: dash 10 tiles, 8 damage to enemies hit, invulnerable during dash, 3 charges (max 4), each charge 3 (2) s — [Rogue](https://soul-knight.fandom.com/wiki/Rogue)
- Rogue Cartwheel: invincible while rolling, cannot use weapons, 5 contact damage (10 on crit), radial slash on release that destroys enemy bullets, CD 12 (10) s; emptying the whole bar stuns Rogue 2 s — [Rogue](https://soul-knight.fandom.com/wiki/Rogue)
- Berserker: 9 (10) / 3 (4) / 150 (170) / 5 / 5 / 6.5. Passive Fire Rate Buff — [Berserker](https://soul-knight.fandom.com/wiki/Berserker)
- Berserker Rage: fast attack over 0.5 s with current weapon, +20% fire rate, CD 4 (2) s; upgrade: +25% crit chance and takes 1/3 damage (rounded down, min 1) — [Berserker](https://soul-knight.fandom.com/wiki/Berserker). Earlier note said "triples attack speed"; this page says +20% fire rate (differs; page text is the more detailed source)
- Berserker Free Style: 3 shadow mirages for 5 s; their attacks are 50% smaller and deal 50% damage (page text cut off after this), CD 10 (8) s — [Berserker](https://soul-knight.fandom.com/wiki/Berserker)
- Wizard is titled "Witch" on the wiki (redirect from /wiki/Wizard): 3 (4) / 5 (6) / 240 (260) / 0 / 3 / 6.5. Lowest crit of all heroes; passive Elemental Staff Buff — [Witch](https://soul-knight.fandom.com/wiki/Witch)
- Witch Lightning Strike: hits nearest enemy in line of sight, jumps up to 4 times, 8 damage per hit, stun about 2 s, lone target takes 8 + 16 = 24 total, CD 6 (4) s, cooldown starts 0.4 s after cast — [Witch](https://soul-knight.fandom.com/wiki/Witch)
- Witch Piercing Frost: trail of 6 ice spikes, 9 tiles long, 6 damage, lasts 1 s, blocks bullets, freezes; CD 6 (4) s — [Witch](https://soul-knight.fandom.com/wiki/Witch)
- Assassin: 4 (5) / 4 (5) / 180 (200) / 10 / 5 / 6.5. Passive Reflect Buff (Reflexive Edge) — [Assassin](https://soul-knight.fandom.com/wiki/Assassin)
- Assassin Dark Blade: dash state up to 1.5 s (or until an enemy dies), speed x2, immune to all damage, one slash for 8 damage, kills reset the cooldown up to 4 times, hitting a boss halves the cooldown, CD 10 (8) s — [Assassin](https://soul-knight.fandom.com/wiki/Assassin)
- Engineer: 5 (6) / 5 (6) / 180 (200) / 5 / 3 / 6.5. Passive Fire Buff. Gun Turret: up to 3 turrets, CD 9 (7) s — [Engineer](https://soul-knight.fandom.com/wiki/Engineer) (page text cut off; Armor Mount / Interceptor numbers not read)

### Inferences
- Sane defaults for a Godot hero: about 5-6 HP, 5 armor, 6.5 units/s, dodge = 0.5 s i-frames on a 2.5 s cooldown.
- Every invulnerability skill has a cooldown 5x to 20x its duration (Dodge 0.5/2.5, Dark Blade 1.5/10) — the pattern that keeps i-frames from being spammed.

### Gaps
- Berserker Leap, Priest/Priestess, Engineer skills 2-3 numbers not read (page truncated by my read limit).
- Wizard page is named "Witch" here; Wizard-as-hero may just be the old name (the wiki lists "Witch"). Earlier notes' "Wizard" = this hero (assumption, unconfirmed).

## Weapons: melee, deflection, crit, energy

### Takeaway
Weapons have four stats (damage, energy cost, inaccuracy, crit). Melee weapons do not spend energy in the bare-hands case; deflecting bullets is normally "destroy", and only becomes "reflect" with the Reflexive Edge (Reflect) buff.

### Cited Findings
- Each weapon has 4 main attributes: damage, energy cost, inaccuracy, critical hit chance — [Weapons](https://soul-knight.fandom.com/wiki/Weapons)
- Crit: non-elemental weapons deal double damage; elemental weapons apply their status instead; each hit of a multi-hit attack rolls its own crit — [Weapons](https://soul-knight.fandom.com/wiki/Weapons), [Stats](https://soul-knight.fandom.com/wiki/Stats#Critical_Chance)
- Total crit chance = hero native crit + weapon crit + buffs. Crit shows yellow damage numbers, larger text, slight screen shake and a sound — [Stats](https://soul-knight.fandom.com/wiki/Stats#Critical_Chance)
- Area/explosive damage, continuous lasers and melee-area hits do not double on crit — [Stats](https://soul-knight.fandom.com/wiki/Stats#Critical_Chance)
- Some weapons change the player's speed while used — [Weapons](https://soul-knight.fandom.com/wiki/Weapons); weapon speed modifiers apply while the attack button is held — [Stats](https://soul-knight.fandom.com/wiki/Stats#Movement_Speed)
- Bare Hands ("Hand-Knife"): 3-5 damage by character, energy cost 0, crit 0. In ranged combat it can be used only once per second; in melee range no cooldown. Most melee weapons disable it — [Hand-Knife](https://soul-knight.fandom.com/wiki/Hand-Knife)
- Reflexive Edge (Reflect Buff): melee weapons bounce bullets instead of only destroying them; reflected bullets turn gold, keep speed and damage (Void upgrade: +50% speed, +50% damage). Non-melee such as Magic Staff and Shield can also reflect. Projectiles like bouncy or explosive rounds cannot be returned — [Reflexive Edge](https://soul-knight.fandom.com/wiki/Reflexive_Edge)
- Weapon pages "Melee Weapons" and "Bullet deflection" as standalone pages do not exist (empty) — [Melee Weapons](https://soul-knight.fandom.com/wiki/Melee_Weapons)
- Boss tactics pages repeatedly say melee weapons "destroy" bullets and are "a must" against bullet-spam bosses — [Goblin Priest Tactics](https://soul-knight.fandom.com/wiki/Goblin_Priest/Tactics), [Skeleton King Tactics](https://soul-knight.fandom.com/wiki/Skeleton_King/Tactics)

### Inferences
- Design hook: melee = bullet-clearing tool by default, reflect only with an upgrade. This is a cheap, readable "melee is defense" mechanic for BossFight.

### Gaps
- Per-weapon numbers (energy per shot, fire rate, knockback) were not read: the Weapons page is a table with no stats in the text I got. Fire rate has no dedicated page text. Knockback: nothing found.

## Bosses: HP, attacks, phases

### Takeaway
Boss HP is small (480-960 in Normal, 1.25x in Champion, 1.5x in Badass Rush). All bosses go "enraged" under 50% HP: faster attacks, faster projectiles, sometimes new attacks. Attacks are randomized bullet-pattern menus of 4-9 moves.

### Cited Findings
- Bosses sit on level x-5; chosen randomly by biome. Enraged at less than half HP: more powerful or new attacks, faster and more aggressive, projectiles faster, recover from status effects faster; drops 10 energy orbs at half HP and on death. Some bosses (Crystal Crab etc.) heal while enraged — [Bosses](https://soul-knight.fandom.com/wiki/Bosses)
- Room entrance for a boss is marked red in some versions; a "Boss inside" banner appears before the fight — [Bosses](https://soul-knight.fandom.com/wiki/Bosses)
- Goblin Priest: HP 480 (Normal) / 600 (Champion) / 720 (Badass Rush), floor 1-5 — [Goblin Priest](https://soul-knight.fandom.com/wiki/Goblin_Priest). Attacks: 3 meteors targeted near the player; 2 orbiting orbs (4 damage when near); a projectile leaving a line of turrets firing perpendicular bullets; one wave of 6 star bullets that each split into 3. Enraged: shorter interval between attacks and 4 meteors instead of 3 — [Goblin Priest Tactics](https://soul-knight.fandom.com/wiki/Goblin_Priest/Tactics). Room: teepee and 2 totems as cover, 6 crates that bullets destroy — [Goblin Priest](https://soul-knight.fandom.com/wiki/Goblin_Priest)
- Skeleton King: HP 720 / 900 / 1080, 5 unique attacks: leap-slam with a circle of triangular bullets; two-arc blade slashes; 8 delayed homing missiles (cannot be reflected); summons Skeleton (Sword) minions; dash then fast explosive shot, "can be predicted when the player hears a loud, metallic sword chime". Enraged: bullets much faster. Room: 4 gargoyle statues and barrels — [Skeleton King](https://soul-knight.fandom.com/wiki/Skeleton_King), [Skeleton King Tactics](https://soul-knight.fandom.com/wiki/Skeleton_King/Tactics)
- Grand Wizard: HP 600 / 750 / 900, 4 unique attacks: sweeping laser (5 damage); rotating geometric bullet formations; two rings of slow bouncing projectiles (4 damage); loose bullet spray that may adjust if the target moves. Room: one block in each corner, desk, pots. Screams when enraged and briefly when casting — [Grand Wizard](https://soul-knight.fandom.com/wiki/Grand_Wizard), [Grand Wizard Tactics](https://soul-knight.fandom.com/wiki/Grand_Wizard/Tactics)
- Zulan The Colossus: HP 960 / 1200 / 1440, 9 unique attacks with 5 floating drone guns. Floating Guns chase the player then fire lasers ("given away with a warmup sound and a warning beam") or bullet spreads; radial burst of large bullets; drone lines/cones/rotation firing spreads or lasers; drones swing as a "sword" with gaps; spiral of small bullets; big bullet emitting a spiral that leaves 4-direction smaller bullets. Enraged: attacks much faster, adds an arrowhead radial burst with floating bullet trails, attacks itself while drones chase. Visual enrage cue: blue body stripes turn red, drones turn red, side plates curve into spikes — [Zulan Tactics](https://soul-knight.fandom.com/wiki/Zulan_The_Colossus/Tactics), [Zulan The Colossus](https://soul-knight.fandom.com/wiki/Zulan_The_Colossus)
- Zulan tactics page says most bosses have a "randomized attack pattern", so difficulty depends on which attacks come up — [Zulan Tactics](https://soul-knight.fandom.com/wiki/Zulan_The_Colossus/Tactics)

### Inferences
- Design numbers to copy: boss HP about 100-160x a starter weapon hit; enrage at 50% with (a) shorter attack interval, (b) +1 projectile count, (c) faster bullets, (d) one visual cue (color change). This matches BossFight slice 4 (phase 2 + enrage) already built.
- Telegraph types the wiki actually records: sound (sword chime), warm-up sound + warning beam (laser), targeted ground meteors. No numeric wind-up durations given.

### Gaps
- Exact telegraph durations, bullet speeds, attack cooldowns, arena sizes: not on the pages read.
- Colossus is listed at floor 3 (Spaceship) with a separate "Zulan In Ruins" variant; only the Spaceship one was read.
- "Post-hit invincibility" and "knockback": no wiki text found (pages empty/nonexistent). biligame mirror not tried (Fandom worked in the browser, no CAPTCHA seen).
