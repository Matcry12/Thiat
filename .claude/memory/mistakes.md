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
