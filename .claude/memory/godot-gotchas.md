# Godot gotchas

**Installed: Godot 4.7.stable** (`~/.local/bin/godot` -> `~/Downloads/Godot_v4.7-stable_linux.x86_64`).
Reference docs in `docs/reference/godot/` were researched against 4.3/4.4 — if an API is renamed in
4.7, fix it and add the difference here.

- `.godot/`, `*.import`, `*.uid` are generated — never edit (also denied in settings.json).
- Hand-edited `.tscn`: keep `[gd_scene ... format=3]` header and node paths intact; re-check headless.
- `@export` changes need the editor to re-scan; tell the user when a reload is required.
- Verify with `godot --headless --check-only --script <file>` (the PostToolUse hook runs this
  automatically on every `.gd` edit and blocks on parse errors).
- `Vector2.angle_to()` returns a **signed** angle in [-PI, PI]. Arc/cone hit filters must use
  `absf(aim.angle_to(to_target)) <= half_arc` — without `absf` every target *behind* the attacker
  passes the filter. Regression test: `tests/test_arc_filter.gd`.
- A `Hurtbox` may have no sibling `Health` (the player in slice 1 cannot take damage yet) —
  `get_node_or_null`, and callers must handle null.
- A `NodePath` written into a `.tscn` does NOT resolve into a typed-Node `@export` (e.g.
  `@export var hitbox: Hitbox`) — it stays **null** with no error. Export a `NodePath` and resolve
  it with `get_node_or_null()` in `_ready()`, plus an `assert`.
- `Area2D.area_entered` never fires for a target already overlapping when `monitoring` is switched
  on — the usual case for a melee hitbox against a stationary enemy. Poll `get_overlapping_areas()`
  during the active window instead.
- A `ColorRect` background defaults to `mouse_filter = STOP` and will eat clicks over the whole
  screen. Set it to `IGNORE` (2).
- Headless tests: the mouse reads as (0,0), so any script that aims at `get_global_mouse_position()`
  will fight the test. `set_physics_process(false)` on the player before asserting on aim.
