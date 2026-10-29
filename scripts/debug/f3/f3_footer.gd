class_name F3Footer
extends VBoxContainer
## Dock footer, ONE line inside the frame's paper card: `● N overrides` chip, `K stale` (red, only when there are some),
## [Write K] (primary), [Clear] (danger, "Sure? 2s"). The detail (.tres / scene-only split, unknown keys) lives in the chip's tooltip.
## It only shows the F3Overrides state of the TuningPanel (`panel`) and calls its write_to_tres / clear_overrides / drop_stale.

var panel   # TuningPanel
var _info: Label
var _chip: PanelContainer
var _stale: Button
var _write: Button
var _clear: Button

func setup(p) -> void:
	panel = p
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", panel.dock.pad_x)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(row)
	var pad := Control.new()
	pad.custom_minimum_size.x = 2
	row.add_child(pad)
	_chip = PanelContainer.new()   # "● 5 overrides" (the dot is a picture, the text carries the number)
	_chip.add_theme_stylebox_override("panel", F3Theme.box("chip_idle", panel.dock.art_scale))
	_chip.mouse_filter = Control.MOUSE_FILTER_STOP   # for the tooltip
	row.add_child(_chip)
	var cb := HBoxContainer.new()
	cb.add_theme_constant_override("separation", panel.dock.pad_x)
	cb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.add_child(cb)
	cb.add_child(panel.dock.icon_rect("icon_dot_changed"))
	_info = Label.new()
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cb.add_child(_info)
	_stale = Button.new()
	_stale.theme_type_variation = "F3Icon"
	_stale.focus_mode = Control.FOCUS_NONE
	_stale.add_theme_font_override("font", UiFonts.get_font("bold"))
	_stale.add_theme_font_size_override("font_size", UiFonts.NATIVE["bold"] * panel.dock.art_scale)
	_stale.add_theme_color_override("font_color", panel.dock.hp_dark_color)
	_stale.add_theme_color_override("font_hover_color", panel.dock.hp_color)
	_stale.pressed.connect(func(): panel.drop_stale())
	row.add_child(_stale)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	_write = Button.new()
	_write.theme_type_variation = "F3Primary"
	_write.focus_mode = Control.FOCUS_NONE
	_write.tooltip_text = "Write the overrides of .tres resources into their files (a fresh copy of each file, only the changed values)"
	_write.pressed.connect(func(): panel.write_to_tres())
	row.add_child(_write)
	_clear = panel.dock.danger_button("Clear", func(): panel.clear_overrides())
	row.add_child(_clear)
	refresh()

func refresh() -> void:
	if panel == null or panel.overrides == null or _info == null:
		return
	var o: F3Overrides = panel.overrides
	var n := o.count()
	var k := o.tres_count()
	_info.text = "%d overrides" % n if n > 0 else "no overrides"
	_info.theme_type_variation = "F3ChipText" if n > 0 else "F3Small"
	var unknown: Array = panel.stale.get("unknown", [])
	_chip.tooltip_text = "%d overrides: %d to .tres, %d scene-only (copy the value into the scene)\nsaved in %s, re-applied at every start" % [n, k, n - k, o.path] \
		+ ("\nnot found (renamed?): %s" % ", ".join(unknown) if not unknown.is_empty() else "")
	_write.text = "Write %d" % k
	_write.disabled = k == 0
	_clear.disabled = n == 0
	var st: Array = panel.stale.get("stale", [])
	_stale.visible = not st.is_empty()
	_stale.text = "%d stale" % st.size()
	_stale.tooltip_text = "Skipped at start: the file changed since the edit.\n%s\nClick to drop them." % "\n".join(st)
