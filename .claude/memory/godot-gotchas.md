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
- Downloaded pixel-art icons are usually upscaled (e.g. 608px for 19 art pixels). Resize DOWN to
  the true art-pixel grid with NEAREST (608 -> 19), then up by an integer factor. Non-integer
  resizing blurs pixel art.
- `godot .` inside a project directory **runs the game**. To open the EDITOR use `godot -e .`
  (or `godot --editor --path <dir>`). Told the user the wrong one on 2026-09-24.
- Sprites whose texture is assigned in `_ready()` show as EMPTY in the editor — you cannot align
  what you cannot see. Any visual node the user must position by dragging needs `@tool` plus
  property setters that call an `_apply_all()`, and `_process`/`_physics_process` guarded with
  `Engine.is_editor_hint()`.
- Hardcoded node paths in one script break silently when a node is reparented elsewhere (the debug
  overlay held `WeaponVisual/Hitbox`). Use groups (`add_to_group("hitbox")`) for cross-script
  lookups, and NodePath exports for scene-local wiring.
- A node sitting AT a pivot does not change `global_position` when the pivot rotates — only its
  carried shape turns. Assert on `global_transform.get_rotation()` (or a transformed shape point),
  not on position.
- Recording a demo (`tools/demo/`): **do not aim with `warp_mouse()`**. A recording runs on a
  screen with no cursor, Godot then reports the mouse at `(0,0)`, the player aims up-left, and every
  directional mechanic (guard arc, parry) reads as broken when it is fine. Drive
  `player.aim_override` instead — added for exactly this.
- A scripted demo must wait for a **fresh** enemy wind-up, not `phase == TELEGRAPH`: the enemy
  starts winding up the instant the player enters range, so a beat can join one already in progress
  and press the key after the hit landed.
- Measure damage from the start of the beat being tested, and count **hp + shield**. hp alone is a
  lie (30 shield absorbs a whole hit with hp unmoved), and a snapshot taken too early blames the
  previous attack's hit on this beat. Both bugs reported a WORKING parry as broken — verify the
  measurement before doubting the game.
