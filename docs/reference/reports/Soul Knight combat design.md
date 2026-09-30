# Soul Knight teaches BossFight cheap, readable combat

**Soul Knight (made by ChillyRoom) builds its combat from very simple parts: a small health pool with a refilling armor shield, one timed skill per hero, weapons that are rows of numbers, and bosses that pick from a menu of bullet patterns.** The best-sourced numbers come from the community wiki. The wiki says armor refills 1 point per second after a short pause, and Rogue's dodge gives 0.5 s of safety on a 2.5 s cooldown. Bosses have only 480 to 1,200 HP and get angry under 50% HP. BossFight already matches this design in many places (shield in front of HP, timed dodge, enrage). The main gaps are in bullet patterns, warning signals and hit feedback. Sources here are thin for those: no dev talk, no postmortem (a write-up after release) and no sprite rips were found. So this report separates **CONFIRMED** (a source says it) from **INFERRED** (my guess from the genre; verify before you copy). The top advice: copy the boss "menu of patterns", the enrage recipe and the dodge-to-cooldown ratio. Do not copy free weapon swapping or auto-aim, because BossFight chose a different path on purpose.

How to read tags: **[C]** = confirmed by a source. **[I]** = inferred, not confirmed. **[?]** = unknown, sources conflict.

## The player kit is a small shield, one skill and a slow dodge

Soul Knight gives each hero three numbers: HP, armor and energy. Armor is a shield that takes damage first. Energy is ammo for guns. Here is what the wiki says.

| Part | What Soul Knight does | Tag |
|---|---|---|
| Armor | Takes hits before HP. Refills 1 point per second after no damage. Delay is **3 s** on the Stats page ([Stats](https://soul-knight.fandom.com/wiki/Stats#Armor)) but a search snippet said 5 s ([Game Mechanics](https://soul-knight.fandom.com/wiki/Game_Mechanics)) | [C], delay [?] |
| Overflow | A hit bigger than the armor spills into HP. Example: 5 armor and a 6 damage hit leaves armor 0 and HP -1 ([Stats](https://soul-knight.fandom.com/wiki/Stats#Armor)) | [C] |
| HP | Does not refill by itself | [C] ([Game Mechanics](https://soul-knight.fandom.com/wiki/Game_Mechanics)) |
| Energy | Ammo for most guns. No natural refill. Orbs and potions refill it ([Stats](https://soul-knight.fandom.com/wiki/Stats#Energy)) | [C] |
| Speed | 6.5 tiles per second for almost all heroes ([Stats](https://soul-knight.fandom.com/wiki/Stats#Movement_Speed)) | [C] |
| Defense | Hidden stat. Each point cuts damage per hit, with less gain each time ([Stats](https://soul-knight.fandom.com/wiki/Stats#Defense)) | [C] |
| Cooldown cut | Percent = CDR / (CDR + 100). 25 CDR gives 20% ([Stats](https://soul-knight.fandom.com/wiki/Stats#Cooldown_Reduction)) | [C] |
| Hit invincibility | No number on the wiki. The `Invincibility` page does not exist | [?] |

Hero base stats are small whole numbers. Knight has 6 HP, 5 armor, 180 energy. Rogue has 5 HP, 3 armor. Witch has 3 HP, 5 armor ([Knight](https://soul-knight.fandom.com/wiki/Knight), [Rogue](https://soul-knight.fandom.com/wiki/Rogue), [Witch](https://soul-knight.fandom.com/wiki/Witch)). Small numbers mean every hit is easy to see and count.

**Skills are timed state changes with a cooldown.** Example: Knight's Dual Wield gives a second copy of your weapon for 5 s. Its cooldown is 10 s (8 s upgraded), and it starts after the skill ends ([Knight](https://soul-knight.fandom.com/wiki/Knight)). Every hero has 3 skills, and the 2nd and 3rd come from skill books ([Wiki Skills, search snippet](https://soul-knight.fandom.com/wiki/Skills)).

| Skill | Safe time | Cooldown | Note |
|---|---|---|---|
| Rogue Dodge | 0.5 s no damage | 2.5 s (0.5 s fully upgraded) | Can still shoot while rolling. Cooldown starts when the roll ends ([Rogue](https://soul-knight.fandom.com/wiki/Rogue)) |
| Assassin Dark Blade | up to 1.5 s | 10 s (8 s) | Kills reset the cooldown, up to 4 times ([Assassin](https://soul-knight.fandom.com/wiki/Assassin)) |
| Witch Lightning | none | 6 s (4 s) | Jumps to 4 enemies, stuns about 2 s ([Witch](https://soul-knight.fandom.com/wiki/Witch)) |
| Berserker Rage | none | 4 s (2 s) | +20% fire rate for 0.5 s ([Berserker](https://soul-knight.fandom.com/wiki/Berserker)) |

**There is no dodge for everyone.** The team chose not to give every hero a roll. The Rogue dodge was inspired by Overwatch's McCree ([GameRes interview](https://www.gameres.com/747517.html)). This is a design choice, not a missing feature. **[C]**

A pattern I see in the numbers **[I]**: each safe window is 5 to 20 times shorter than its cooldown (0.5 s / 2.5 s, 1.5 s / 10 s). That stops the player from being safe all the time.

**Weapon slots.** A hero holds two weapons and switches freely. A third pickup drops the current weapon ([Game Mechanics](https://soul-knight.fandom.com/wiki/Game_Mechanics)). No swap cost is listed, so swapping is probably instant **[I]**. On mobile the game auto-aims at the nearest enemy. The team built auto-aim after a disabled player loved playing with assistive devices ([GameRes](https://www.gameres.com/747517.html), [TouchArcade](https://toucharcade.com/2017/03/10/soul-knight-review/)). **[C]**

## Weapons are data rows, and melee is also a shield

Each weapon has four main numbers: damage, energy cost, inaccuracy (random spread) and crit chance ([Weapons](https://soul-knight.fandom.com/wiki/Weapons)). Inaccuracy x means each bullet flies within plus or minus x/2 degrees of your aim. Example: a value of 20 gives plus or minus 10 degrees ([Stats](https://soul-knight.fandom.com/wiki/Stats#Inaccuracy)). Store pages say 400+ weapons, while other sources say 270+, so the count depends on version ([App Store listing](https://apps.apple.com/us/app/soul-knight/id1184159988)). Two identical weapons can merge into a stronger one ([Pocket Gamer](https://www.pocketgamer.com/soul-knight/combo-weapons-explained)). With that many weapons, a table of stats is almost certain **[I]**. This matches BossFight's `WeaponData` rule.

**Melee weapons destroy enemy bullets.** They can also hit through walls if the reach is long enough ([TouchArcade](https://toucharcade.com/2017/03/10/soul-knight-review/)). Boss guides call melee "a must" against bullet-heavy bosses ([Goblin Priest Tactics](https://soul-knight.fandom.com/wiki/Goblin_Priest/Tactics)). Only the Reflexive Edge buff turns "destroy" into "bounce back": reflected bullets turn gold and keep their speed and damage ([Reflexive Edge](https://soul-knight.fandom.com/wiki/Reflexive_Edge)). Lasers and homing missiles cannot be blocked or reflected ([Xiaomi](https://game.xiaomi.com/viewpoint/1359077112_1638763783095_9), [Skeleton King](https://soul-knight.fandom.com/wiki/Skeleton_King)). **[C]** This gives melee a clear job: it is defense, not only damage.

**Crit** doubles damage for plain weapons. Area, laser and melee-area hits do not double. A crit shows a big yellow number, a small screen shake and a sound ([Stats](https://soul-knight.fandom.com/wiki/Stats#Critical_Chance)). **[C]**

**How weapons are held and swung is not documented.** No source says how the sprite is placed, rotated or flipped. What follows is my guess, based on how this genre normally works **[I]**:

| Question | Likely answer | Godot recipe |
|---|---|---|
| Where is the weapon? | At a hand offset from the body | `Hand` Node2D with a per-weapon grip offset |
| How does it aim? | The sprite turns to the aim angle | `rotation = aim_angle` |
| Aiming left? | Sprite is mirrored so it is not upside down | If cos(aim) < 0, `scale.y = -1` and flip the body |
| Swing look? | Short sweep plus a crescent slash sprite | Separate slash node timed by the same duration as the hitbox |
| Swing time? | About 0.2 to 0.4 s (not sourced) | Measure from video first |

## Hit feedback is mostly guesswork, so borrow Nuclear Throne numbers

**Almost nothing is sourced for Soul Knight feel.** A review said the game is for fans of Nuclear Throne and Enter the Gungeon, but has "no zing" and lacks polish ([TouchArcade](https://toucharcade.com/2017/03/10/soul-knight-review/)). The only sourced feedback facts are the crit cues above. Everything else below is my guess **[I]**: enemies flash white for about 0.05 to 0.1 s, small hit sparks appear, and bullets have no hit-stop (a short freeze on hit) because many bullets fly each second.

For real numbers, the closest well-documented recipe is Vlambeer's "Art of Screenshake" talk for Nuclear Throne ([infovore summary](https://infovore.org/?p=5275)). These are **not** Soul Knight facts.

| Effect | Vlambeer value | Use for BossFight |
|---|---|---|
| Screen shake | +4 per pistol shot, decays fast | Light 2-3 px, heavy 8-10 px, 50-100 ms ([Wayline](https://www.wayline.io/blog/shake-spark-sound-level-up-your-game-feel)) |
| Hit-stop | about 10-20 ms | 50-100 ms on heavy melee ([Wayline](https://www.wayline.io/blog/shake-spark-sound-level-up-your-game-feel)) |
| Enemy hit | 1 white frame, then 2 "big eyes" frames | White flash 1-3 frames |
| Knockback | 3 px/frame along the bullet | Small enemies only; boss is immune |
| Muzzle flash | Round on frame 1, then bullet-shaped | Own node, 1-2 frames |
| Camera kick | 6 px against aim | Heavy weapons only |
| Sounds | Different sound per material | Metal, flesh, stone |

Make every number an `@export`, as BossFight rule 7 says.

## Bosses are menus of bullet patterns with an enrage at half HP

Boss HP is low. Goblin Priest has 480 HP, Skeleton King 720, Grand Wizard 600, Zulan the Colossus 960 on Normal. Champion mode is 1.25x and Badass Rush 1.5x ([Bosses](https://soul-knight.fandom.com/wiki/Bosses), [Goblin Priest](https://soul-knight.fandom.com/wiki/Goblin_Priest), [Skeleton King](https://soul-knight.fandom.com/wiki/Skeleton_King), [Grand Wizard](https://soul-knight.fandom.com/wiki/Grand_Wizard), [Zulan](https://soul-knight.fandom.com/wiki/Zulan_The_Colossus)). **[C]**

| Boss | Moves | Examples |
|---|---|---|
| Goblin Priest | 4 | 3 meteors near you; orbiting orbs; star bullets that split in 3 ([Tactics](https://soul-knight.fandom.com/wiki/Goblin_Priest/Tactics)) |
| Skeleton King | 5 | Leap slam with bullet ring; blade arcs; 8 delayed homing missiles; minions; dash plus shot ([Skeleton King](https://soul-knight.fandom.com/wiki/Skeleton_King)) |
| Grand Wizard | 4 | Sweeping laser; rotating shapes; slow bouncing rings ([Grand Wizard](https://soul-knight.fandom.com/wiki/Grand_Wizard)) |
| Zulan | 9 | 5 floating drone guns: lasers, spreads, spirals ([Zulan Tactics](https://soul-knight.fandom.com/wiki/Zulan_The_Colossus/Tactics)) |
| Old King (hidden) | about 9 | 12-way spreads; a big shot that splits into 64 bullets ([Xiaomi](https://game.xiaomi.com/viewpoint/1391913026_1636934270643_100)) |

Most bosses use a **randomized attack pattern**, so how hard a fight feels depends on which attacks come up ([Zulan Tactics](https://soul-knight.fandom.com/wiki/Zulan_The_Colossus/Tactics)). Early bosses fire slow, weak bullets. Laser bosses hit hardest ([Xiaomi](https://game.xiaomi.com/viewpoint/1359077112_1638763783095_9)). **[C]**

**Enrage.** Every boss enrages under **50% HP**: faster attacks, faster bullets, sometimes new attacks. It drops 10 energy orbs at half HP and on death ([Bosses](https://soul-knight.fandom.com/wiki/Bosses)). Goblin Priest goes from 3 meteors to 4 and waits less between attacks. Zulan's stripes and drones turn from blue to red, so the player can see the change ([Zulan](https://soul-knight.fandom.com/wiki/Zulan_The_Colossus)). **[C]**

**Warnings are simple and often sound-based.** Skeleton King's dash shot is signaled by a loud metal chime. Zulan's lasers have a warm-up sound and a warning beam. Goblin Priest's meteors land near the player ([Skeleton King Tactics](https://soul-knight.fandom.com/wiki/Skeleton_King/Tactics), [Zulan Tactics](https://soul-knight.fandom.com/wiki/Zulan_The_Colossus/Tactics)). **[C]** The wiki gives no wind-up times. **[?]**

**Fairness.** A Chinese guide calls Old King's random patterns almost unavoidable in some positions ([Xiaomi](https://game.xiaomi.com/viewpoint/1391913026_1636934270643_100)). The lesson is clear: random is fine only when a safe spot always exists. Rooms have cover such as pillars, statues and crates ([Goblin Priest](https://soul-knight.fandom.com/wiki/Goblin_Priest)).

Not found at all: normal enemy AI, boss attack order rules, bullet speeds, arena sizes. **[?]**

## ChillyRoom built fast, cut fast and let players steer

| Fact | Source | Note |
|---|---|---|
| Studio founded 2015 in Shenzhen by Li Zeyang and Cao Kan | [ChillyRoom](https://chillyroom.com/en/chillyroom-indie-game-studio) | [C] |
| First idea: guns that paint the floor. Cut as weak, then pivoted to a pixel dungeon shooter | [GameRes](https://www.gameres.com/747517.html), [Gcores](https://www.gcores.com/articles/196573) | [C] |
| About 1 year of development, long Google Play beta, 90%+ positive feedback | [GameRes](https://www.gameres.com/747517.html) | [C] |
| Launch Feb 2017; 4M downloads in week one | [Gcores](https://www.gcores.com/articles/196573) | [C]; one article says April 2017 ([Jiemian](https://www.jiemian.com/article/1652804.html)) |
| Team size: 10, 13 or 100+ depending on the year | [GameRes](https://www.gameres.com/747517.html), [Jiemian](https://www.jiemian.com/article/1652804.html), [Baijing](https://www.baijing.cn/article/47238) | [?] dates unclear |
| Engine: Unity | [Baidu Baike snippet](https://baike.baidu.com/item/%E5%85%83%E6%B0%94%E9%AA%91%E5%A3%AB/20446586) | Snippet only; another article names no engine |
| Style: creative-led, not market-research-led; fix after launch from player feedback | [Jiemian](https://www.jiemian.com/article/1652804.html) | [C] |
| Updates: no revenue targets, but content volume must continue | [Gcores](https://www.gcores.com/articles/196573) | [C] |
| Inspirations: Wasteland Kings (buffs), Enter the Gungeon (dungeon), Rune Keeper (statues) | [GameRes](https://www.gameres.com/747517.html) | [C] |

Early code was written for speed, which left old bugs for years ([Gcores](https://www.gcores.com/articles/196573)). Lesson: fast prototypes are good, but write down the rules you keep. **[I]**

## What BossFight should copy, and what it should not

Compared with BossFight's v0 kit ([prototype-v0.md](../../wiki/prototype-v0.md) section 2):

| Area | Soul Knight | BossFight now | Verdict |
|---|---|---|---|
| Dodge | Rogue only: 0.5 s safe, 2.5 s cooldown | Everyone: `Q`, 0.3 s safe, 2 s cooldown | Fine. Ratio is 6.7x vs Soul Knight 5x. Playtest before changing |
| Shield | Armor first, refills 1/s after 3 s (or 5 s) | Shield first, refills about 1/s after 5 s | Same idea. Both delays are `@export` so you can test 3 s |
| Overflow damage | Extra damage spills to HP | Not stated | Copy: a big hit should not vanish into the shield |
| Damage math | Flat defense per hit, diminishing returns | `damage - armor*0.5`, min 1 | Keep yours. It is simpler |
| Crit | x2 on plain hits, yellow number, small shake | x2, about 4% | Copy the yellow number and shake |
| Parry/block | None. Melee destroys bullets instead | `F`: parry with guard bar | BossFight is bolder. Keep it. Soul Knight also shows that lasers/homing need a different answer |
| Weapon swap | Free and instant | 0.6 s cast, 5 s cooldown | Big difference. Soul Knight's fast swap suits a shooter; yours forces commitment. Playtest it; if swapping feels bad, shorten the cooldown first |
| Skills | 3 per hero, from the character | 1 per weapon on `E` | Different on purpose. Copy Soul Knight's timing shape: duration plus cooldown |
| Aim | Auto-aim (mobile) | Mouse aim | Do not copy. Auto-aim was made for accessibility on touch |
| Boss attacks | 4-9 pattern menu, random order | 3 (slam, spread, charge) + 1 in phase 2 | Add variety: a ring, a stream, a delayed laser. Keep your slam/charge tells |
| Warnings | Sound and warning beam, not fully shown | Purple and orange tells, unparryable vs parryable | Yours is clearer. Add a sound cue too |
| Enrage | Under 50% HP: faster, +1 projectile, new move, color change | Phase 2 at 60% (new move); enrage when you leave the arena 3 s | Copy the recipe: shorter gaps, +1 projectile, faster bullets, one color change |
| Boss HP | 480-1,200 | Not stated | Aim for about 100-160 starter hits **[I]** |

**Copy these first, in order:**

1. **Bullet-pattern menu.** Add ring, stream and delayed-laser attacks to the boss. Each is one geometry with its own tell.
2. **Enrage recipe.** When phase 2 starts: shorter attack gap, +1 projectile, faster bullets, one color change on the boss.
3. **Melee clears bullets.** Let the sword swing destroy weak bullets. It gives the sword a defensive job next to parry.
4. **Crit feedback.** Yellow number, larger text, small shake, sound.
5. **Safe spot rule.** Random patterns must always leave a gap. Add pillars for cover.
6. **Vlambeer feel table.** Use it as your starting numbers for F3 tuning.

**Do not copy:** free swapping, auto-aim, three skills per hero, or the 400-weapon scale. v0 has two weapons.

## Conclusion

Soul Knight shows that strong combat needs few ideas, but each idea must be easy to read: a shield you can count, a skill with one clear cooldown, a boss that flashes red when angry. The bigger lesson is what is missing. There is no public source for weapon handling, hit feel or swing timing, so the feel of Soul Knight is best measured by frame-stepping gameplay video (60 fps), not read from articles.

BossFight is already bolder than Soul Knight in defense (parry, breakable guard bar, committed weapon swap). That is a strength, but it is also the risk to test first: the 5 s swap cooldown is far from Soul Knight's free swap. Gaps worth filling by hand: the Fandom weapon table, boss wind-up times, and post-hit invincibility (not on the wiki).
