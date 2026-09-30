# Soul Knight weapon handling and combat visuals

Research status: public sources are thin. No dev talk, GDC talk, postmortem or asset-rip write-up was found. Fandom wiki (402 Payment Required), Spriters Resource (403) and Steam could not be fetched. Most "how it looks" answers below are INFERENCES from general knowledge of the game and standard 2D practice, not sourced. Verify by frame-stepping gameplay video before copying numbers.

## Weapon hold: orbit, flip, grip

### Takeaway
No source describes it. Common pattern for this genre (and what Soul Knight visibly looks like): weapon pivots around the body toward the aim, and the sprite is mirrored when aiming left so it is never upside down.

### Cited Findings
- Aiming is auto-target on the nearest enemy in the mobile version; without a target you aim by moving/pointing. — [TouchArcade review](https://toucharcade.com/?p=212191)

### Inferences
- (Inferred from gameplay memory, unverified) Weapon sprite sits at a hand-offset from the character, rotates to aim angle; when aim.x < 0 the weapon (and usually the character) is flipped horizontally and the angle mirrored. Godot recipe: `Hand` Node2D at grip offset -> `Weapon` Sprite2D with grip at its origin; `rotation = aim_angle`; if cos(aim)<0: `scale.y = -1` (or `flip_v`) so it is not upside down, and flip the body sprite `flip_h`.
- Grip point = sprite origin/pivot placed on the hand, set per weapon in data (offset). Confirmed nothing; standard practice.

### Gaps
- No source for actual pivot/flip implementation.

## Melee weapons

### Takeaway
Only confirmed mechanic: melee weapons can destroy incoming enemy bullets and reach through walls with enough reach. Swing duration, smear effect, and rotation-vs-sprite method are unsourced.

### Cited Findings
- Melee weapons can destroy incoming bullets and, with enough reach, hit enemies through walls; also good for breaking destructible objects. — [TouchArcade review](https://toucharcade.com/?p=212191)

### Inferences
- (Unverified) Swings look like a short sweep of the weapon sprite plus a crescent slash effect sprite on top; bullet destruction is likely the swing hitbox overlapping bullet Areas. For Godot: Area2D swing hitbox active for swing frames that also `queue_free`s bullets in a "projectile" group; slash arc as separate AnimatedSprite2D driven by the same duration.
- Swing time likely ~0.2-0.4 s; NOT sourced. Measure from video.

### Gaps
- No frame data, no source on smear vs rotation.

## Ranged weapons: muzzle flash, recoil, casings, spread

### Takeaway
Nothing sourced on visuals. Weapons are data-driven with accuracy/spread stats per the community (not verified here).

### Cited Findings
- Fusion/combo weapons: two identical weapons dropped together merge into an upgraded variant with special effects (e.g. Snow Fox L -> XL -> XXL -> XXXL). — [Pocket Gamer](https://www.pocketgamer.com/soul-knight/combo-weapons-explained)

### Inferences
- (Unverified) Standard for the genre: small muzzle flash sprite for 1-2 frames, weapon kick-back tween on the sprite, shell casing particles/sprites for some guns, bullets as small sprites with per-weapon spread angle. Each is a cheap add-on slot; matches this project's rule 5 (effects in own nodes).

### Gaps
- No source for flash/recoil/casing details or numeric spread values.

## Character animation, resolution, pixel-perfect

### Takeaway
Classic pixel art style confirmed; frame counts and sprite size not found.

### Cited Findings
- Game is described as classic pixel-art ("经典像素风"); early code was built for fast iteration, leaving legacy bugs for years. First prototype was a gun that "painted the floor", later removed. — [Gcores interview with Cao Kan](https://www.gcores.com/articles/196573)
- Store/press descriptions: pixel top-down roguelike shooter, 20+ heroes, 400+ weapons (marketing figure). — [Search summary of App Store / press pages](https://apps.apple.com/us/app/soul-knight/id1184159988)

### Inferences
- (Unverified) Characters are small (roughly 16-24 px tall), few-frame idle/run loops, dark outlines. Do not rely on this number.

### Gaps
- Frame counts, pixel size, palette: no source. Spriters Resource could not be fetched (403); try it manually.

## Engine and tools

### Takeaway
No source found in this session confirming the engine. Widely believed to be Unity, but not confirmed here.

### Cited Findings
- ChillyRoom is a Shenzhen indie studio founded 2015 by Li Zeyang and Cao Kan; Soul Knight launched Feb 2017, 4M downloads in first week. — [ChillyRoom about](https://chillyroom.com/en/chillyroom-indie-game-studio), [Gcores](https://www.gcores.com/articles/196573)
- Prequel (2023) interviews cover design goals only, no engine or animation details. — [TaptTap interview](https://www.taptap.io/br/post/1457291)

### Inferences
- Unity is likely (unverified); a Godot port needs no engine-specific trick, since everything described is plain sprites + timers + hitboxes.

### Gaps
- Not found: GDC talk, postmortem, data-mining/modding info, sprite rips. Suggested manual leads: Gcores/Zhihu/Bilibili searches for 元气骑士 技术分享, Spriters Resource, r/SoulKnight.

## Weapon count and data-driven stats

### Takeaway
Marketing says 400+ weapons; other sources cite 270+. Stats (damage, energy cost, crit, accuracy, fire rate) exist per community knowledge, but could not be fetched from the wiki.

### Cited Findings
- 400+ weapons, "guns, swords and shovels". — [App Store listing via search summary](https://apps.apple.com/us/app/soul-knight/id1184159988)
- Some sources cite 270+ weapons (count differs by version/source). — search summary only, conflicting with the 400+ figure above; no URL fetched.

### Inferences
- Data-driven is near certain for this many weapons: one table row per weapon with stats, projectile, sprite, sound. Matches this project's WeaponData resource approach.

### Gaps
- Exact stat schema: wiki blocked (402). Try https://soul-knight.fandom.com/wiki/Weapons in a browser.
