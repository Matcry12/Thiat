# Soul Knight hit feedback and game feel ("juice")

Research verdict: web search found almost NO citable, Soul Knight-specific numbers (frames, pixels, seconds). The Fandom wiki returned HTTP 402 to the fetch tool; the gcores article 208724 is about Monster Hunter/Sifu, not Soul Knight; several search hits (itch.io posts) were about other jam games and were discarded. Everything Soul-Knight-specific below is therefore either from one review or is INFERENCE from general knowledge of the game and comparable games. Treat numbers as starting values to tune, not as Soul Knight facts.

## Hit feedback on enemies (flash, knockback, hit-stop, damage numbers, particles)

### Takeaway
No citable Soul Knight numbers found. The best documented reference for the same genre and feel is Vlambeer (Nuclear Throne), whose recipe Soul Knight is widely compared to; use it as the numeric baseline.

### Cited Findings
- Reviewer positions Soul Knight as made for fans of Nuclear Throne / Enter the Gungeon; also says it "lacks polish", has "no zing", and weapon upgrades "often have minimal impact" (i.e. a negative view on feedback) — [TouchArcade review](https://toucharcade.com/2017/03/10/soul-knight-review/)
- Soul Knight auto-aims and auto-fires at the nearest target on mobile, so the player focuses on dodging — [TouchArcade review](https://toucharcade.com/2017/03/10/soul-knight-review/)
- Vlambeer baseline (Nuclear Throne pistol), useful as reference numbers: camera kick 6 px opposite... "6 pixels from where you are aiming"; screenshake +4 per shot, decaying quickly; hit-stop about 10-20 ms on hit; weapon recoil kick 2; bullet speed 16 px/frame; muzzle flash circular on first frame then bullet-shaped; shell eject 2-4 px/frame; bullet angle jitter 0-4 degrees; enemy knockback 3 px/frame along bullet direction; enemy hit anim = 1 white frame then 2 frames "big eyes"; material-specific hit sounds (meat, plant, rock, metal) — [infovore.org summary of "Art of Screenshake"](https://infovore.org/?p=5275)
- General guidance: hit-stop 50-100 ms on heavy melee hits; shake 2-3 px light vs 8-10 px heavy, duration 50-100 ms, paired with white flash — [Wayline](https://www.wayline.io/blog/shake-spark-sound-level-up-your-game-feel) (generic, not Soul Knight)

### Inferences (from gameplay memory, NOT verified by a source)
- Enemies flash white (about 0.05-0.1 s) on damage; small red/white hit spark at impact point; no strong hit-stop on bullets (a shooter with many bullets per second cannot freeze per hit); melee weapons feel heavier due to swing arc + knockback.
- Damage numbers exist as small floating text; crit shown with a different (larger/yellow-ish) style. Color unconfirmed.
- Light knockback on small enemies, none or little on bosses.

### Gaps
- Exact flash duration, knockback distance, hit-stop existence, crit number color: no source found. Wiki blocked (402). Best next step: frame-step a gameplay video (YouTube/bilibili) at 60 fps and count frames yourself.

## Screen shake and camera

### Takeaway
Players report Soul Knight has noticeable screen shake on strong weapons; no numeric values found.

### Cited Findings
- None Soul-Knight-specific and verifiable. (A search-engine summary attributed "shake too intense with grenades" quotes to Soul Knight, but the hits were itch.io jam-game posts; discarded as unreliable.)
- Shake is scaled by attack intensity in Vlambeer's approach (+4 for pistol) — [infovore.org](https://infovore.org/?p=5275)

### Inferences
- Shake on firing big weapons (shotgun, cannon, rocket/grenade) and on explosions and boss slams; none or tiny on rapid small guns. Camera follows player smoothly, no zoom in normal play. Unverified.
- Suggest a shake-strength multiplier setting; shake trauma with quick decay.

### Gaps
- Camera lead toward aim, zoom on boss kill, shake values: not found.

## Player getting hit (armor, i-frames, flash, sound)

### Takeaway
Nothing citable found. From memory: Soul Knight has an armor bar that absorbs damage before HP and recharges when not hit; brief invincibility after a hit.

### Cited Findings
- None found (Fandom Armor page returned 402).

### Inferences (unverified)
- Armor absorbs hit first, armor bar drops, sprite flickers/flashes during short i-frames (~1 s?), a hit sound plays; armor regenerates after several seconds without damage. Exact values unknown.

### Gaps
- Recharge delay, i-frame length, vignette/screen flash: unknown. Check wiki in a browser.

## Death effects, drops, slow-motion

### Takeaway
No citable data.

### Cited Findings
- None found.

### Inferences (unverified)
- Enemies pop with a small burst and drop energy orbs / coins that fly to the player (magnet). Bosses die with bigger explosion; possible brief slow-mo. Not verified.

### Gaps
- All specifics.

## Bullet feel (size, glow, trails, cancel, wall sparks)

### Takeaway
Nothing citable. Vlambeer's muzzle-flash and bullet recipe is the reference.

### Cited Findings
- Muzzle flash: circular first frame, then bullet-shaped; bullet speed 16 px/frame in Nuclear Throne — [infovore.org](https://infovore.org/?p=5275)

### Inferences
- Soul Knight bullets are chunky, brightly colored simple sprites with bullet-cancel by melee swings; wall hits give small spark puffs. Unverified.

### Gaps
- Sizes, trails, cancel effect specifics.

## Sound design

### Takeaway
No source on Soul Knight audio specifics.

### Cited Findings
- Material-specific impact sounds recommended by Vlambeer approach — [infovore.org](https://infovore.org/?p=5275)

### Inferences
- Short punchy chiptune-ish SFX with pitch variation per shot. Unverified.

### Gaps
- Any dev comment or analysis.

## Why it "feels good" / comparisons

### Takeaway
Only weak evidence. The one review found is lukewarm on feel; Chinese search surfaced no dev interview on 打击感 for 元气骑士.

### Cited Findings
- TouchArcade: comparable to Nuclear Throne/Gungeon but "no zing", lacks polish — [TouchArcade](https://toucharcade.com/2017/03/10/soul-knight-review/)
- Company context: Soul Knight (2017) is ChillyRoom's top earner — [search summary of gcores/jiemian, not fetched; low confidence](https://www.gcores.com/articles/105816)

### Inferences
- Soul Knight shares with Nuclear Throne: chunky bullets, recoil/shake tied to weapon power, flash-on-hit. Its feel likely comes more from volume of feedback (many weapons, many bullets) than from per-hit heavy juice.

### Gaps
- No game-feel essay specifically about Soul Knight found; no zhihu/bilibili/reddit content retrieved.

## Practical Godot baseline (my suggestion, not Soul Knight fact)
Start from Vlambeer numbers scaled to your resolution: hit flash 1-3 frames, knockback ~3 px/frame for a few frames, hit-stop 10-20 ms (0 on rapid guns), shake +4 px light / 8-10 px heavy with fast decay, camera kick 6 px opposite aim on heavy guns. Expose all as @export.
