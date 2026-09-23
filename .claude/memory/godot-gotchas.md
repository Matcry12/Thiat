# Godot gotchas
- `.godot/`, `*.import`, `*.uid` are generated — never edit (also denied in settings.json).
- Hand-edited `.tscn`: keep `[gd_scene ... format=3]` header and node paths intact; re-check headless.
- `@export` changes need the editor to re-scan; tell the user when a reload is required.
