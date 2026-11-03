# Mistakes — never repeat
<!-- format: - YYYY-MM-DD: <what went wrong> → <rule>  (fed by detect-correction hook) -->
- 2026-09-22 (seed): agents claim "scene works" without running Godot → always run `godot --headless --check-only` before reporting.
- 2026-09-23: drew debug/ground shapes squashed into ellipses to fake 3D depth → Soul Knight is
  FLAT 2D. Depth comes only from layering (draw order) + upright sprites + a simple shadow.
  Never add perspective squashing, foreshortening or fake-3D projection.
- 2026-09-24: code recomputed `Blade.position` from `hand_distance` in `_ready()`, silently
  overwriting the position the user had dragged in the editor → if a human positions something by
  dragging, NO script may write that same property. Code owns what animates (rotation); the editor
  owns placement. Never two owners for one property.
- 2026-09-28: user said "remove the shield"; I removed the icon but kept the HUD shield bar and
  asked, and they had to say it again → "remove X" means every copy of X on screen. Remove them all,
  and list what was removed; don't keep one back and ask.
- 2026-09-28: CoverArc exported `arc_degrees` although code overwrote it every frame. The user set
  100 there and "it still" did nothing → a value code writes must NOT be an @export. An Inspector
  field that silently does nothing is a bug, even if a comment warns about it. Test with
  get_property_list() that code-owned fields are not editable.
- 2026-09-28: gave the user editor steps without testing them ("did you check before giving me?")
  → before giving Inspector instructions, load the scene headless and confirm the value set there
  actually reaches the running game.
- 2026-09-29: `git commit -am` for a docs-only change swept in the open editor's save of
  player.tscn (a `preview_width_from = null` line that silently broke the arc's editor preview) →
  never `commit -a`. Stage files by name, and `git diff` every .tscn before it goes in.
- 2026-10-01: unzipped a third-party pack inside res:// with read-only dirs → Godot spammed "Cannot open .import" errors. Raw packs get a `.gdignore`; copy the sheets we use elsewhere.
- 2026-10-04: cleaned (recoloured + re-outlined) the user's drawing without asking → never alter user art beyond what was asked; ask first, keep an untouched copy in assets/characters/source/.
- Before telling the user an art piece is "missing", try to BUILD it from pieces we have (e.g. inner grass corner = alpha-AND of two straight edge tiles). Said "needs new tiles" for road turns; the user pushed back and composing worked.
- 2026-10-16: Map v2 baked dirt/grass edges with wrongly mapped autotile pieces (notches, grass holes, edges facing the wrong way) and shipped screenshots without checking them on a known shape → before any tiling goes on the map, render a labelled piece sheet + test shapes (square, plus, diagonal, 1-cell hole, thin strip) and check each one at 4x.
- 2026-10-22: Map step 1 "use the ready asset" was turned into a new noise + shader colour-zone system → when the user says use the ready asset, first show a picture made only from the pack tiles (a $0 script), then build. Smallest step first; ask before inventing new systems.
- 2026-10-22: "let's do it" after a side discussion = the main task (map), not the side topic. Ask which one when a side topic was the last thing discussed.
- 2026-10-23: used only the one tree sheet already in the game; the pack has 3 tree models x 4 sizes in assets/third_party/pixel_crawler/.../Trees → before picking sprites, list the whole pack folder, not just assets/map.
- 2026-10-23: floor props (reeds, bushes, flowers) shipped upside down and copper as a placeholder circle; screenshots were only judged at overview size → for every new draw path, zoom (crop at 4x) on a few known sprites and compare with the source sheet before reporting.
- 2026-10-29: Tile packs: assume the pack is COMPLETE for what it draws. A "missing" autotile case means I misread how pieces combine (8x8 quarters, rounded patch blocks = convex corners) or our map structure breaks the pack's layer order (e.g. dark grass must sit inside light grass, never touch dirt) - fix the reading or the map rule, do not list it as art to draw.
- 2026-10-30: user asked to "do a simple anims first to see" → I sent the other session to wire idle+run into the player; they only wanted to watch the animation → "see / look" = show a GIF or preview, no game wiring.
- 2026-10-30: mapped every strip in a pack (roll, hurt, side) when the user only wanted idle/run/death → use only the animations the user names; ask which ones are used before wiring extras
- 2026-10-30: a simple sprite swap took 15+ min (Sonnet agent + full suite + judge + shot tool) → for small asset/visual swaps do it inline, run only the touched tests, skip the judge unless logic changed
- 2026-10-30: palette swap recoloured the top row of tree ground shadows (shadow green = a leaf green; fixed 7-row guard was too short) → when a swap colour is shared by two parts (leaf vs shadow, dirt vs grass shadow), split them by position/region, never by a fixed row count; zoom 16x on each piece size vs the original.
- 2026-11-01: new item art (Shikashi pack) went only into bag icons; the in-hand sword picture stayed the old stock sword in demos/shots → when art is replaced, replace it everywhere it is drawn (bag icon, hand model, ground pickup) and show the in-game shot.
- 2026-11-01: user said the swing looked 'lower compared to the mouse' and I moved the whole swing up, but they meant it misses the aim direction → when a complaint names the mouse/aim, measure the aim alignment (draw the aim line on frames) before moving anything.
- 2026-11-01: tuned the ribbon trail look myself and sent it without a fresh art reviewer; missed a size jump at the fade and a worse shape than the approved P3 → every look change gets a fresh reviewer comparing it frame-by-frame to the approved reference BEFORE the user sees it.
- 2026-11-03: chop FX passed tests (hand-placed tree in ClassicArena) but did nothing in game: map-built trees cached a null HitFx in _ready → test world features in the real arena / Test yard too; look up group nodes late, not in _ready.
