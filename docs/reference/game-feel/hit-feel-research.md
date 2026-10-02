# Hit feel research: what makes a hit feel real

Goal: attacks that feel "good, smooth and satisfying" in BossFight (Godot 4.7, top-down, Soul Knight style).
Already covered, not repeated here: code recipes in [juice-and-vfx.md](../godot/juice-and-vfx.md), the Nuclear Throne
pistol table in [hit_feedback_and_feel.md](../research_notes/Soul%20Knight%20combat%20design/hit_feedback_and_feel.md).
This file adds: the layers of a hit, scaling by hit strength, pitfalls, and Godot 4 details.

**Honesty note.** Several famous talks (GDC videos, Sakurai's videos, Hollow Knight, Hades) could not be read in this
session (video only, or the fetch was blocked). Numbers marked *(verified)* were read on the cited page. Numbers marked
*(secondary)* come from a search summary or a blog quoting the talk. Numbers marked *(memory)* are from general
knowledge and need a check. Treat all as **starting values to tune**, not facts about any one game.

---

## 1. The layers of one hit (what stacks up)

A hit feels strong when many small cues agree and fire in the same frame. No single layer does it.

| # | Layer | Who sees it | Job |
|---|---|---|---|
| 1 | Anticipation (windup) | attacker | Builds the "wait for it". Makes the hit land harder |
| 2 | Impact frame (the first frame of contact) | both | The exact moment everything below fires together |
| 3 | Hit-stop | both, or victim only | Pause that says "this had mass" |
| 4 | Flash | victim | Confirms *which* thing was hit |
| 5 | Knockback / stagger | victim | Shows force and gives space |
| 6 | Squash and stretch / scale punch | victim, attacker | Shows the body absorbing force |
| 7 | Sparks, slash, blood, dust | world | Shows where and in which direction |
| 8 | Damage numbers | UI | Gives size of the hit |
| 9 | Screen shake / camera kick / zoom punch | camera | Makes the player feel it |
| 10 | Sound | ear | Often the strongest single layer; hits register on the ear first |
| 11 | Screen effects (chromatic aberration, blur, vignette) | screen | Reserve for big moments |
| 12 | Slow-mo on kill | everything | Celebrates the finish |

Source for "stack the layers and scale them to hit strength": Wayline, shake/spark/sound article (secondary).

---

## 2. Hit-stop (freeze frames)

**What.** On contact the game pauses for a few frames. In Smash the **attacker and victim both freeze and vibrate**,
unlike older fighters where only the victim did. *(verified, Sakurai column summary)*

**Why it works.** The pause gives the eye time to read the hit and makes the strike feel like it met resistance.
Longer pause = heavier hit.

**Numbers**
| Source | Value |
|---|---|
| Nuclear Throne pistol hit | 10-20 ms *(verified, infovore summary of "Art of Screenshake")* |
| Fighting games, light / medium / heavy | about 9 / 11 / 13 frames *(secondary, search summary of SSBWiki)* |
| Generic "heavy melee" advice | 50-100 ms *(secondary, Wayline)* |
| Celeste dash | 4-frame pause and tiny shake *(secondary, GMTK transcript summary)* |
| Dead Cells critical hit | 1 frame freeze, then a slow-down of "a few tenths of a second" *(secondary, 80.lv interview summary)* |

Scaling rule (Sakurai): longer for stronger hits, with per-attack modifiers, a **hard cap** so nothing freezes
absurdly, and **less hit-stop for projectiles** than for melee. *(verified)*

**Sakurai's tips for the freeze itself** *(verified from the Source Gaming + Automaton summaries)*
- Shake the victim during the freeze. Grounded: shake sideways. Airborne: shake up/down.
- **Do not move the hurtbox** while the sprite shakes (no phantom hits).
- Shake less over time. Scale shake by camera distance so it stays visible.
- Keep the attacker moving "just a little" so the pause does not look dead.
- Problem he names: in free-for-all, frozen players are open to third parties. Same idea for us: a frozen player next to a boss bullet.

**Who freezes?** Both is the Smash/fighting approach. In action games with crowds, freezing **only attacker + victim**
(local freeze) reads better, because bullets, particles and the camera keep moving. See juice-and-vfx.md §1.

**Example games:** Smash, Street Fighter, Nuclear Throne, Dead Cells, Celeste.

---

## 3. Flash

White (or colored) sprite for 1-3 frames. Nuclear Throne: one white frame, then two "big eyes" frames
*(verified)*. Typical 0.05-0.1 s. Use a **shader that mixes toward white** (works with textures, survives art swaps)
instead of `modulate`, because `modulate` can only multiply, so it cannot reach pure white on dark sprites.
Flash color can carry meaning: white = normal, yellow = crit, red = player damaged.

---

## 4. Knockback and stagger

- Nuclear Throne: enemy pushed 3 px/frame along the bullet direction *(verified)*. At 30 fps that is about 90 px/s.
- Attacker recoil 4-8 px over 0.1-0.15 s (juice-and-vfx.md §5; cosmetic tween).
- Bosses: usually **no knockback**, hit-stop and flash carry the feel instead (Terraria pattern, already in design-pillars.md).
- Knockback ends in a short stagger. Keep knockback in the **victim's** movement code (velocity), not in the effect node.

---

## 5. Squash, stretch, scale punch

Victim squash perpendicular to the hit (e.g. 0.8 x 1.2 -> 1.0 in 0.15 s); attacker punch 1.2 -> 1.0 in 0.2 s
(juice-and-vfx.md §4). Sakurai's "interpolate into the damage pose" is the sprite version of the same idea.
Cheap, but with pixel art keep scale changes **small or snapped**, or pixels get blurry.

---

## 6. Sparks, slash and particles

- Nuclear Throne: muzzle flash round on frame 1, bullet-shaped after; shell eject 2-4 px/frame *(verified)*.
- Sparks fly **along the hit direction or the surface normal**. Count and size scale with strength.
- Wayline starting values: spread ~20 deg, initial speed ~50, no gravity *(secondary)*. Ours will be bigger.
- Permanence: leave something behind (blood decal, scorch) so the fight has history. *(verified, Nuclear Throne)*

---

## 7. Damage numbers

Small floating text, pooled, popping up and fading in about 0.6 s. Crit = bigger and yellow. Skip numbers on very
fast hits (they stack into noise). Colors: white = normal, yellow = crit, red = damage to player, grey = blocked.
Pool recipe: juice-and-vfx.md §10.

---

## 8. Screen shake and camera

**Trauma model** (Squirrel Eiserloh, GDC 2016, "Math for Game Programmers: Juicing Your Cameras With Math"):
keep a `trauma` value 0 to 1. Add to it on hits. Decay it over time. Shake amount = `trauma^2` (or `^3`).
Offset and rotation come from **smooth noise** sampled over time, not `randf()`.
The talk video could not be read here; the model is confirmed by the Godot implementation below.

**Godot reference values** (KidsCanCode recipe) *(verified)*: decay 0.8 per second, trauma power 2 (range 2-3),
max offset (100, 75) px, max roll 0.1 rad, noise period 4, 2 octaves. These are large; for a 2D pixel game start
far smaller (see plan).

**Other numbers**
- Nuclear Throne pistol: shake +4, camera kick 6 px opposite the aim *(verified)*.
- Wayline: duration 0.1 s, amount 0.1 as a start *(secondary)*.
- Light 2-3 px, heavy 8-10 px, 50-100 ms *(secondary, from the earlier project note)*.

**Camera kick** = one-shot push of the camera in the hit or aim direction that eases back. **Zoom punch** = snap zoom
in about 5-15 percent and ease out. Save both for big moments.

**Directional beats random.** A kick along the hit direction says "pushed that way". Random jitter says "something happened".

---

## 9. Sound

Pitch randomization +/- 5-10 percent (juice-and-vfx.md §11). Material-specific impact sounds (flesh, metal, wood)
*(verified, Nuclear Throne)*. Layer a low thud + a high "crack". Sound should **fire on the same frame** as the flash.
A blip beats silence even before real SFX exist.

---

## 10. Scaling with hit strength

Rule: **every layer scales together**, so the player reads strength without looking at numbers.

| Hit | Hit-stop | Shake | Flash | Particles | Sound |
|---|---|---|---|---|---|
| Light | 0-3 frames | none to tiny | 1-2 frames | few | short |
| Heavy | 4-8 frames | medium | 2-3 frames | many | deep |
| Crit | +2-4 frames | medium+ | colored | many + big | extra "ding" layer |
| Parry | 4-6 frames (both) | small, sharp | white on both | bright sparks | very clear chime |
| Kill | 6-12 frames, then slow-mo | strongest | long | burst | special |

(Frame ranges are a synthesis of the sources above at 60 fps; tune by playtest.)

**Hits the player takes vs hits the player deals.** Hits the player *deals* get the full set. Hits the player *takes*
need the **opposite priority: readability and fairness**. Short hit-stop (or none), a clear red flash and sound, a
brief invulnerability, and no long shake, because the player must keep dodging. Fighting games freeze both on any
hit; action games with bullets usually do not. *(synthesis; Sakurai's third-party problem supports it)*

---

## 11. Pitfalls

| Pitfall | What the player sees | Fix |
|---|---|---|
| Shake overdone | Screen always moving; "constantly triggered is a recipe for motion sickness" *(verified, Wayline)* | Trauma cap, fast decay, strength slider, off switch |
| Hit-stop too long | Feels like lag, not weight (juice-and-vfx.md: 0.04-0.08 s start) | Cap; keep short on light hits |
| Hit-stop eats input | Button pressed during the freeze is lost | Keep reading input during freeze, buffer it |
| Stacked hit-stops | Many hits in one frame freeze longer and longer | Take the **max**, do not add |
| Hit-stop in crowds/bullets | Everything stops while bullets keep flying or vice versa | Local freeze; player is not frozen when hit |
| Too many particles / bright flashes | "Distracting and annoying" *(verified, Wayline)*; hides boss bullets | Budget, cap per frame, keep bullets on top |
| Same sound every hit | Ear fatigue | Pitch randomization |
| Flashing | Photosensitivity | Option to reduce flash |
| No accessibility toggle | Some players cannot play | Shake strength slider + off; reduce-flash option. Real games ship this: Overwatch "Reduce screen shake", WoW "Reduce Camera Motion" *(verified, EIP search summary)* |

---

## 12. Godot 4 implementation notes

**Hit-stop: `Engine.time_scale` vs local freeze**
- `Engine.time_scale` slows physics, `_process`, tweens, animations, particles and normal timers. A tiny value like
  0.02 instead of 0 avoids divide-by-zero in some code but still runs physics ticks.
- `SceneTree.create_timer(sec, process_always, process_in_physics, ignore_time_scale)`: the 4th argument makes the timer
  count **real** time. Timers are scaled otherwise. *(verified, Godot Timer docs)*
- Local freeze (turn off `set_physics_process` / pause an `AnimationPlayer` on attacker + victim) keeps the rest alive.
  Cost: you must also stop **their** timers, tweens and weapon state machine, or they drift out of sync.
- Alternative: give each actor a `hit_stop_remaining` and have its own `_physics_process` skip when > 0. One owner, no global state.
- With either approach, a hit-stop **must not** be added while one runs; extend to max.

**Trauma shake on Camera2D**: write to `offset` (and `rotation`), never `position`, so follow/smoothing/limits keep working.
In our game the Camera2D is created in code by `arena_map.gd` as a child of the player. Note `offset` may show outside
the camera `limit_*` edges; verify on the map border.

**Flash**: shader with `flash_amount` uniform per sprite (needs a unique `ShaderMaterial` per instance or an instance
uniform), tweened with `create_tween()`. Instance uniforms avoid duplicating materials.

**Damage numbers**: pool of Labels (juice-and-vfx.md §10). Use a `CanvasLayer`-less world-space node so they stay at the hit spot.

**Particles**: both classes work. `GPUParticles2D` is the default for desktop burst effects; recycle with `restart()` and
the `finished` signal instead of making new nodes each hit *(secondary, community skill page)*. `CPUParticles2D` is fine
for tiny pixel sparks (< 20 particles), is simpler to set up in code, and behaves the same on any renderer.
For pixel art set `texture_filter` to nearest and use square 1-2 px particles, no scale animation.

---

## 13. Per-game notes (what each is known for)

| Game | Known approach | Confidence |
|---|---|---|
| Nuclear Throne | Tiny stacked cues per shot: kick 6 px, shake +4, freeze 10-20 ms, knockback 3 px/frame | verified |
| Smash / fighters | Hit-stop on both, scaled by damage, shake during freeze, cap | verified (Sakurai summary) |
| Dead Cells | Borrowed from fighters: stop frames, slow-downs, crit = 1-frame freeze + slow-mo, hit sounds | secondary |
| Celeste | 4-frame pause + tiny shake on dash; small cues, many of them | secondary |
| Hollow Knight | Hit freeze + nail recoil + soul/spark; no reliable written numbers found | not found |
| Hades / Gungeon | Strong flash, sparks, sound; no reliable written numbers found | not found |

---

## Sources

- Vlambeer / Jan Willem Nijman, "The Art of Screenshake" (GDC 2013, video): https://www.youtube.com/watch?v=AJdEqssNZ-U
- Numbers from that talk, summary: https://infovore.org/?p=5275
- Jonasson & Purho, "Juice it or lose it" (GDC 2012, video): https://www.youtube.com/watch?v=Fy0aCDmgnxg
- Squirrel Eiserloh, "Math for Game Programmers: Juicing Your Cameras With Math" (GDC 2016), listing: https://www.gamedeveloper.com/programming/video-sprucing-up-cameras-with-math
- Trauma shake in Godot (numbers above): https://kidscancode.org/godot_recipes/4.x/2d/screen_shake/index.html
- Sakurai on hitstop (Famitsu column summary): https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/
- Sakurai, hit-stop tips (summary, page blocked for us): https://nintendowire.com/news/2022/12/12/this-week-in-sakurai-12-5-12-11-fine-tuning-hit-stop-and-cheating-the-system/
- Hitlag (Smash wiki; not fetched, only the search summary): https://www.ssbwiki.com/Hitlag
- Fighting game hitstop discussion: https://forums.ultra-combo.com/t/why-isnt-hitstop-duration-standardized/24838
- Wayline, shake / spark / sound: https://www.wayline.io/blog/shake-spark-sound-level-up-your-game-feel
- Dead Cells developer interview (80.lv; detail came from a search summary): https://80.lv/articles/interview-with-the-developers-of-dead-cells
- GMTK "Why Does Celeste Feel So Good to Play?" transcript: https://amara.org/v/C3BEJ/
- Godot Timer docs (`ignore_time_scale`): https://docs.godotengine.org/en/latest/classes/class_timer.html
- Godot Engine docs (`time_scale`): https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-time-scale
- Screen shake accessibility options in shipped games: https://eip.gg/news/accessible-games-for-motion-sickness/
- Godot particle guidance (community page, low confidence): https://claudeskills.info/skills/thedivergentai/gd-agentic-skills/godot-particles/
- Steve Swink, "Game Feel" (book, not read here); Hollow Knight, Hades/Supergiant, Enter the Gungeon: no citable numbers found.
