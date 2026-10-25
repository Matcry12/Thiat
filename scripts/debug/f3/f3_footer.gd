class_name F3Footer
extends VBoxContainer
## Dock footer: "● N overrides (K to .tres, S scene-only)", a stale button, `Write K to .tres`, `Clear overrides` (danger, "Sure?").
## It only shows the F3Overrides state of the TuningPanel (`panel`) and calls its write_to_tres / clear_overrides / drop_stale.

@export var font_size := 11
@export var on_color := Color("e6b450")
@export var off_color := Color("7a8494")
@export var stale_color := Color("ff8f87")

var panel   # TuningPanel
var _info: Label
var _stale: Button
var _write: Button
var _clear: Button

func setup(p) -> void:
	panel = p
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", font_size)
	_info.mouse_filter = Control.MOUSE_FILTER_STOP   # for the tooltip
	add_child(_info)
	var row := HFlowContainer.new()
	add_child(row)
	_write = Button.new()
	_write.focus_mode = Control.FOCUS_NONE
	_write.add_theme_font_size_override("font_size", font_size)
	_write.tooltip_text = "Write the overrides of .tres resources into their files (a fresh copy of each file, only the changed values)"
	_write.pressed.connect(func(): panel.write_to_tres())
	row.add_child(_write)
	_clear = panel.dock.danger_button("Clear overrides", func(): panel.clear_overrides())
	row.add_child(_clear)
	_stale = Button.new()
	_stale.focus_mode = Control.FOCUS_NONE
	_stale.add_theme_font_size_override("font_size", font_size)
	_stale.add_theme_color_override("font_color", stale_color)
	_stale.pressed.connect(func(): panel.drop_stale())
	row.add_child(_stale)
	refresh()

func refresh() -> void:
	if panel == null or panel.overrides == null or _info == null:
		return
	var o: F3Overrides = panel.overrides
	var n := o.count()
	var k := o.tres_count()
	_info.text = "● %d overrides  (%d to .tres, %d scene-only)" % [n, k, n - k] if n > 0 else "no F3 overrides"
	_info.add_theme_color_override("font_color", on_color if n > 0 else off_color)
	var unknown: Array = panel.stale.get("unknown", [])
	_info.tooltip_text = "saved in %s, re-applied at every start" % o.path + ("\nnot found (renamed?): %s" % ", ".join(unknown) if not unknown.is_empty() else "")
	_write.text = "Write %d to .tres" % k
	_write.disabled = k == 0
	_clear.disabled = n == 0
	var st: Array = panel.stale.get("stale", [])
	_stale.visible = not st.is_empty()
	_stale.text = "%d stale" % st.size()
	_stale.tooltip_text = "Skipped at start: the file changed since the edit.\n%s\nClick to drop them." % "\n".join(st)
