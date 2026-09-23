# Godot gotchas

**Installed: Godot 4.7.stable** (`~/.local/bin/godot` -> `~/Downloads/Godot_v4.7-stable_linux.x86_64`).
Reference docs in `docs/reference/godot/` were researched against 4.3/4.4 — if an API is renamed in
4.7, fix it and add the difference here.

- `.godot/`, `*.import`, `*.uid` are generated — never edit (also denied in settings.json).
- Hand-edited `.tscn`: keep `[gd_scene ... format=3]` header and node paths intact; re-check headless.
- `@export` changes need the editor to re-scan; tell the user when a reload is required.
- Verify with `godot --headless --check-only --script <file>` (the PostToolUse hook runs this
  automatically on every `.gd` edit and blocks on parse errors).
