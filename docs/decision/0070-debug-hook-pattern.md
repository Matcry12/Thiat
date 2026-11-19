# 0070 - One debug hook pattern

**Status:** Current

## Context
Debug code leaked into game code: `enemy_spawner.gd` found `../DebugOverlay` by node name, `enemy_debug_draw.gd`
sniffed the overlay by a property name, `hud.gd` held a NodePath to the tuning panel, and `arena_map.gd`
carried the F3 biome picture and F3 rows. F3 itself was already pull-based (group `debug`).

## Decision
Game nodes only expose state. `scripts/debug/` finds them by group and pulls. Game code never looks up a debug node.
- F3: join group `debug`, offer `debug_name/category/children/actions/heavy` and `status_text` (unchanged, 0044).
- F1 switch: `DebugFlags.shapes_on` (static, written only by `DebugOverlay`, default false). A node's own F1 draw may stay on the node, gated by it.
- Heavy F3 code goes to a child node in `scripts/debug/` (`MapDebug`); the owner keeps the values and emits a signal.
- The HUD finds the F3 panel by group `tuning_panel`.

## Why
No name or path lookups that break when a node is renamed; release builds and tests work with no debug node present.

## Consequences
New F3/F1 features follow this rule (AGENTS.md section 7). `ArenaMap` keeps four tiny `debug_*` methods (the panel reflects the node itself) that forward to `MapDebug`.
