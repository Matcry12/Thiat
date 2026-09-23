# Mistakes — never repeat
<!-- format: - YYYY-MM-DD: <what went wrong> → <rule>  (fed by detect-correction hook) -->
- 2026-09-22 (seed): agents claim "scene works" without running Godot → always run `godot --headless --check-only` before reporting.
- 2026-09-23: drew debug/ground shapes squashed into ellipses to fake 3D depth → Soul Knight is
  FLAT 2D. Depth comes only from layering (draw order) + upright sprites + a simple shadow.
  Never add perspective squashing, foreshortening or fake-3D projection.
