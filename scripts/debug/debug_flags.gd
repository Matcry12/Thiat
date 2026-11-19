class_name DebugFlags
## Read-only switches for game code. Only DebugOverlay writes them; game code never looks up a debug node.
## Default off: tests and release builds see "off".

static var shapes_on := false   ## F1: draw shapes (set by DebugOverlay.enabled)
