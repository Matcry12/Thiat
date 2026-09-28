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
