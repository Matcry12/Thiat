# Soul Knight player kit and ChillyRoom studio/tech

Research caveat: the Soul Knight Fandom wiki (main source for numbers) returned HTTP 402 / Cloudflare block to direct fetch, so numbers below come only from search-result snippets of wiki pages (not full pages). Namu wiki, TV Tropes, Medium analysis were also unreachable. Numbers are therefore partial; treat each as "snippet-level, verify on wiki before tuning".

## Characters and their skills

### Takeaway
Every character has one active skill on a cooldown (later versions: 3 skills per character, 2nd/3rd unlocked via skill books). Knight = "Dual Wield" (current weapon in both hands, 10 s CD, 8 s upgraded). Rogue = "Dodge" (roll, ignore all hostile damage 0.5 s, CD 2.5 s, 0.5 s upgraded per snippet). Full cooldown table for the rest was not retrievable.

### Cited Findings
- Knight skill 1 "Dual Wield": wield the current weapon in both hands for a short duration; cooldown 10 s (8 s with upgrades) — [Wiki Skills page (search snippet)](https://soul-knight.fandom.com/wiki/Skills)
- Patch 3.2.3: Dual Wield "can no longer double the effects of modifiers" (i.e. it doubled weapon modifiers before; nerfed) — [APKMirror changelog 3.2.3](https://www.apkmirror.com/?p=2464317)
- Rogue skill "Dodge": roll forward, evade and ignore all hostile damage for 0.5 s; cooldown 2.5 s (0.5 s with upgrades) — [Wiki Skills / Rogue (search snippet)](https://soul-knight.fandom.com/wiki/Rogue)
- Alchemist skill 1: throws poison bottles (area damage + poison, stacks x3 for bonus damage/spread), CD 6 s (4 s upgraded); skill 2: gas/fire/ice potions, CD 4 s (3 s) — [Wiki Skills (snippet)](https://soul-knight.fandom.com/wiki/Skills)
- Berserker skill 1: briefly triples attack speed; skill 2 "Blood Thirst", skill 3 "Leap" — [Wiki Skills (snippet)](https://soul-knight.fandom.com/wiki/Skills)
- Assassin: skill 2 "Doppelganger", skill 3 "Invisibility"; described as a mobile character that slashes through enemies — [Wiki Skills (snippet)](https://soul-knight.fandom.com/wiki/Skills), [PocketGamer](https://www.pocketgamer.com/soul-knight/tier-list/)
- Engineer: skill 2 "Armor Mount", skill 3 "Interceptor". Priest: healing zone (heals armor at level 5), skill 3 "Moon Shadow". Wizard: skill 2 "Witch's Firestorm"; Wizard skill 1 is a chain lightning that also stuns (Thunder Sword copies it) — [Wiki Skills (snippet)](https://soul-knight.fandom.com/wiki/Skills)
- Three skills per character; 2nd and 3rd obtained by buying/developing a skill book — [Wiki Skills (snippet)](https://soul-knight.fandom.com/wiki/Skills)
- Design intent: developers deliberately did NOT give every hero a roll; the ranger/rogue-type dodge was inspired by Overwatch's McCree, then in development (per Li Zeyang) — [GameRes interview digest](https://www.gameres.com/747517.html)

### Inferences
- Model for Godot: skill = short-lived state modifier (dual-wield flag, i-frame flag, attack-speed x3) plus a cooldown timer; cheap to data-drive as a Resource with `duration`, `cooldown`, `cooldown_upgraded`.
- Dodge design: 0.5 s i-frames vs 2.5 s CD gives ~20% uptime baseline; upgraded 0.5 s CD gives near-spam (snippet says 0.5 s, may be wrong or a wiki typo - flag).

### Gaps
- Visuals (animation, pose, effect) for each skill: no source found. Wiki pages not fetchable.
- Cooldowns/durations for Wizard, Assassin, Engineer, Priest, Berserker skill 1 etc.: not retrieved.
- Dual Wield duration (seconds) not found.
- Per-character base stats (HP/armor/energy/speed/crit): not retrieved.

## Resources: HP, armor, energy

### Takeaway
Armor is a regenerating shield that must be depleted before HP is hit; it starts regenerating at 1 point/second after 5 s without damage. Energy is ammo spent by most weapons. HP does not regenerate on its own.

### Cited Findings
- Armor regenerates 1 point per second after 5 s of not being damaged — [Wiki Game Mechanics (search snippet)](https://soul-knight.fandom.com/wiki/Game_Mechanics)
- Armor is reduced first by enemy hits and must be fully depleted before HP takes damage — [Wiki Game Mechanics (snippet)](https://soul-knight.fandom.com/wiki/Game_Mechanics)
- Energy is consumed by most weapons and works as an ammo supply — [Wiki Game Mechanics (snippet)](https://soul-knight.fandom.com/wiki/Game_Mechanics)
- "Armor Boost" status: +1 armor instantly then +1 per 1.1 s, lasts 6 s — [Wiki Status Effects (snippet)](https://soul-knight.fandom.com/wiki/Armor_Boost)
- Talent/buff examples: "Armor regenerates instantly by 50% when depleted, triggerable once every 60 s"; "Armor takes 1 extra point of damage, but armor regenerates instantly by 50% when broken" — [Instant Armor Buff](https://soul-knight.fandom.com/wiki/Armor_regenerates_instantly_by_50%25_when_it_is_depleted._The_effect_can_be_triggered_once_every_60_seconds), [Armor buff variant](https://soul-knight.fandom.com/wiki/Armor_takes_1_extra_point_of_damage._But_armor_regenerates_instantly_by_50%25_when_it_is_broken)

### Inferences
- Because armor is drained before HP and refills in ~5 s + 1 s/point, the loop is "hit-and-run": clean dodging = free health. Good fit for a boss-fight game (reward not-being-hit for 5 s).
- Armor absorbs one hit as one point regardless of damage size (common understanding of the game; NOT confirmed by a source I fetched).

### Gaps
- Energy cost per shot per weapon, energy regen (there is none by default except pickups/blue potions): not sourced.
- Whether damage larger than remaining armor overflows to HP: not confirmed.
- Post-hit invincibility frames duration: not found (search explicitly returned none).

## Weapon slots, swapping, melee/ranged, aiming

### Takeaway
Two weapons carried; free instant switching; a third pickup drops the equipped one. Auto-aim was built as an accessibility feature and is a core part of the mobile control design.

### Cited Findings
- All characters hold up to two weapons unless the Extra Weapon buff is active; picking up a third drops the current weapon — [Wiki Game Mechanics (snippet)](https://soul-knight.fandom.com/wiki/Game_Mechanics)
- Players can switch freely between two weapons; the fire button fires only the equipped one — [Wiki Game Mechanics (snippet)](https://soul-knight.fandom.com/wiki/Game_Mechanics)
- Auto-aim: team built it after a disabled US player was thrilled that he could play with assistive devices — [GameRes](https://www.gameres.com/747517.html)
- Patch 3.2.3 buffed bow attack power and shortened bow charge time; added special attack effects to sword guards and staff handles — [APKMirror 3.2.3](https://www.apkmirror.com/?p=2464317)

### Inferences
- Swap has no stated cost/cooldown in sources -> treat as instant (unconfirmed).
- Melee weapons in Soul Knight also auto-target and reflect/destroy bullets (common knowledge, unsourced here).

### Gaps
- Swap animation time, PC (manual mouse aim) vs mobile details: no source retrieved.
- Melee vs ranged balance numbers: none.

## Movement, dodge, i-frames

### Takeaway
Only Rogue's Dodge (and similar skill-based dashes like Assassin/Berserker Leap) give evasion; there is no universal dodge. Base movement speed and hit i-frames not sourced.

### Cited Findings
- Team explicitly chose not to give every hero a roll — [GameRes](https://www.gameres.com/747517.html)
- Rogue dodge = 0.5 s ignore-all-damage window — [Wiki Rogue (snippet)](https://soul-knight.fandom.com/wiki/Rogue)

### Gaps
- Player speed (units/s), post-hit invulnerability time: not found.

## Buffs and talents

### Takeaway
Per-run buffs (picked from statues/shops) rewrite combat rules, several armor-related. Meta talents exist too.

### Cited Findings
- Extra Weapon buff (third weapon slot), instant-armor-refill buffs (above), Serenity, Arms Alignment, Cooldown Rush exist as named buffs/pages — [Wiki search hits: Cooldown Rush](https://soul-knight.fandom.com/wiki/Cooldown_Rush), [Serenity](https://soul-knight.fandom.com/wiki/Serenity), [Arms Alignment](https://soul-knight.fandom.com/wiki/Arms_Alignment)
- Buff-system inspiration: Wasteland Kings; dungeon structure: Enter the Gungeon; statues: Rune Keeper; pets: Torchlight — [GameRes](https://www.gameres.com/747517.html)

### Gaps
- Effects of Serenity/Arms Alignment/Cooldown Rush: titles only, contents not fetched.

## Studio and tech

### Takeaway
ChillyRoom (凉屋游戏, Shenzhen) was founded 2015 by Stanford/CMU-trained Li Zeyang and Cao Kan. Soul Knight shipped Feb 2017 after ~1 year of development by a tiny team, built in Unity3D, prototyped by a floor-painting idea that was cut. Very lean 2-person-per-project model early; ~100+ staff now.

### Cited Findings
- Unity3D engine — [Search-result summary of Baidu Baike entry](https://baike.baidu.com/item/%E5%85%83%E6%B0%94%E9%AA%91%E5%A3%AB/20446586) (snippet; a Jiemian article states no engine)
- Release 17 Feb 2017 (Baike snippet); Jiemian article says April 2017 — conflict; App Store/Baike date more likely right. [Jiemian](https://www.jiemian.com/article/1652804.html)
- Original concept: top-down game where guns paint the floor (Splatoon / Wasteland Kings inspired); dropped as weak, pivoted to pixel dungeon shooter — [GameRes](https://www.gameres.com/747517.html), [GCores](https://www.gcores.com/articles/196573)
- ~1 year of development; long Google Play beta test with 90%+ positive feedback; dev fatigue from constant playtesting — [GameRes](https://www.gameres.com/747517.html)
- Team size (sources disagree by date): 10 people, 2-person project model, "artists can animate, programmers can design" ([GameRes](https://www.gameres.com/747517.html)); 13 people ([Jiemian](https://www.jiemian.com/article/1652804.html)); 100+ now ([Baijing](https://www.baijing.cn/article/47238), [GCores](https://www.gcores.com/articles/196573))
- Philosophy: creative-led not market-research-led; adjust post-launch from player feedback; Li: lightweight staffing avoids too many opinions diluting ideas — [Jiemian](https://www.jiemian.com/article/1652804.html)
- Sales: 4M downloads first week and 10M users, >10M RMB early ([Jiemian](https://www.jiemian.com/article/1652804.html)); 40M downloads ([Tencent Game Institute](https://gameinstitute.qq.com/course/detail/10087)); 200M+ users, monetization "a few cents per user" ([GCores](https://www.gcores.com/articles/196573)); >$30M cumulative revenue, ~95% of studio income ([Baijing](https://www.baijing.cn/article/47238)). Numbers span different dates.
- Three producers over time: Zeying (programmer, framework), Abo (network/cloud save/maintenance), Wang Wandou (ex-art director, from late 2019) — [GCores](https://www.gcores.com/articles/196573)
- Update cadence: "We don't demand revenue targets, but content volume must be maintained"; continuous updates (versions 2.x through 6.x seen on APKMirror) — [GCores](https://www.gcores.com/articles/196573), [APKMirror](https://apkmirror.com/apk/chillyroom/soul-knight/soul-knight-6-8-0-release)
- Sequel: Soul Knight Prequel (22 Nov 2023), 4.7M downloads in ~10 days, ARPG, 6 base classes — [Baijing](https://www.baijing.cn/article/47238)

### Inferences
- The floor-painting-to-shooter pivot plus a 1-year cycle suggests they prototype cheaply and cut fast; combat "feel" came from beta feedback rather than a formal spec (no postmortem/GDC talk found).

### Gaps
- No GDC talk or written postmortem found. Tencent Game Institute talk (18 min, Li Zeyang) exists but content not accessible.
- Bilibili/zhihu/indienova interviews not reached; a Zhihu Unity clone tutorial exists (https://zhuanlan.zhihu.com/p/181670532) but is not official.
- Exact team size and date-to-headcount mapping unresolved.
