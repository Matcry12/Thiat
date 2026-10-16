class_name InventorySkin
extends Resource
## The look of the hotbar and the bag, as data (CLAUDE.md §5). Drop a PNG into a texture field and the
## look changes with no code change. Empty texture = the placeholder drawn from the colours below.
## Sizes here drive the layout (containers), nothing is positioned by pixel in code.

@export_group("Textures (empty = placeholder)")
@export var slot_texture: Texture2D:
	set(v):
		slot_texture = v
		emit_changed()  ## frame of every slot (hotbar + bag), nine-patch
@export var slot_selected_texture: Texture2D:
	set(v):
		slot_selected_texture = v
		emit_changed()  ## drawn over the selected slot, nine-patch
@export var bag_panel_texture: Texture2D:
	set(v):
		bag_panel_texture = v
		emit_changed()  ## background of the bag panel, nine-patch
@export var lock_texture: Texture2D:
	set(v):
		lock_texture = v
		emit_changed()  ## over a slot while the bag is locked
@export var dodge_icon: Texture2D:
	set(v):
		dodge_icon = v
		emit_changed()  ## HUD ability slots; empty = a plain coloured square
@export var skill_icon: Texture2D:
	set(v):
		skill_icon = v
		emit_changed()  
@export var guard_icon: Texture2D:
	set(v):
		guard_icon = v
		emit_changed()  
@export_group("Sizes")
@export var slot_size := 44:
	set(v):
		slot_size = v
		emit_changed()
@export var slot_gap := 6:
	set(v):
		slot_gap = v
		emit_changed()
@export var selected_grow := 3:
	set(v):
		selected_grow = v
		emit_changed()  ## the selected frame is this much bigger than the slot, px
@export var icon_inset := 3:
	set(v):
		icon_inset = v
		emit_changed()
@export var bag_pad := 8:
	set(v):
		bag_pad = v
		emit_changed()  ## bag panel inner margin
@export_group("Nine-patch margins")
@export var slot_patch_margin := 4:
	set(v):
		slot_patch_margin = v
		emit_changed()
@export var selected_patch_margin := 4:
	set(v):
		selected_patch_margin = v
		emit_changed()
@export var bag_patch_margin := 6:
	set(v):
		bag_patch_margin = v
		emit_changed()
@export_group("Text")
@export var font: Font:
	set(v):
		font = v
		emit_changed()  ## empty = project default
@export var count_font_size := 12:
	set(v):
		count_font_size = v
		emit_changed()
@export var count_color := Color.WHITE:
	set(v):
		count_color = v
		emit_changed()
@export var key_font_size := 12:
	set(v):
		key_font_size = v
		emit_changed()
@export var key_color := Color(1, 1, 1, 0.9):
	set(v):
		key_color = v
		emit_changed()
@export_group("Placeholder colours")
@export var frame_color := Color(0.12, 0.14, 0.2, 0.8):
	set(v):
		frame_color = v
		emit_changed()
@export var frame_border := Color(0.35, 0.4, 0.55):
	set(v):
		frame_border = v
		emit_changed()
@export var selected_border := Color(1.0, 0.9, 0.45):
	set(v):
		selected_border = v
		emit_changed()
@export var bag_color := Color(0.08, 0.1, 0.15, 0.92):
	set(v):
		bag_color = v
		emit_changed()
@export var lock_color := Color(0, 0, 0, 0.55):
	set(v):
		lock_color = v
		emit_changed()

@export_group("Bars: textures (empty = placeholder)")
@export var bar_frame_texture : Texture2D:
	set(v):
		bar_frame_texture = v
		emit_changed()
@export var bar_fill_texture : Texture2D:
	set(v):
		bar_fill_texture = v
		emit_changed()
@export var bar_frame_patch_margin := 4:
	set(v):
		bar_frame_patch_margin = v
		emit_changed()
@export var boss_bg_texture : Texture2D:
	set(v):
		boss_bg_texture = v
		emit_changed()
@export var boss_fill_texture : Texture2D:
	set(v):
		boss_fill_texture = v
		emit_changed()
@export_group("Health bar")
@export var health_bar_width := 220:
	set(v):
		health_bar_width = v
		emit_changed()
@export var health_bar_height := 18:
	set(v):
		health_bar_height = v
		emit_changed()
@export var bar_frame_margin := 2:
	set(v):
		bar_frame_margin = v
		emit_changed()
@export var bar_frame_color := Color(0.08, 0.02, 0.02, 0.85):
	set(v):
		bar_frame_color = v
		emit_changed()
@export var bar_frame_border := Color(0, 0, 0, 0.95):
	set(v):
		bar_frame_border = v
		emit_changed()
@export var health_fill_color := Color(0.82, 0.14, 0.14):
	set(v):
		health_fill_color = v
		emit_changed()
@export var health_low_color := Color(1.0, 0.5, 0.4):
	set(v):
		health_low_color = v
		emit_changed()
@export var health_trail_color := Color(1.0, 0.78, 0.7, 0.9):
	set(v):
		health_trail_color = v
		emit_changed()
@export_group("Boss bar")
@export var boss_bar_width_fraction := 0.45:
	set(v):
		boss_bar_width_fraction = v
		emit_changed()   ## of the screen width
@export var boss_fade_time := 0.3:
	set(v):
		boss_fade_time = v
		emit_changed()   ## fade + slide in when it wakes, out when it sleeps
@export var boss_slide_px := 12:
	set(v):
		boss_slide_px = v
		emit_changed()
@export var boss_hide_delay := 1.5:
	set(v):
		boss_hide_delay = v
		emit_changed()   ## after the boss is defeated, so the kill reads
@export var boss_bar_height := 20:
	set(v):
		boss_bar_height = v
		emit_changed()
@export var boss_bg_color := Color(0.07, 0.04, 0.09, 1.0):
	set(v):
		boss_bg_color = v
		emit_changed()
@export var boss_border_color := Color(0, 0, 0, 1):
	set(v):
		boss_border_color = v
		emit_changed()
@export var boss_fill_color := Color(0.8, 0.2, 0.9):
	set(v):
		boss_fill_color = v
		emit_changed()
@export var boss_phase2_color := Color(1.0, 0.35, 0.2):
	set(v):
		boss_phase2_color = v
		emit_changed()
@export var boss_flash_color := Color(1, 1, 1):
	set(v):
		boss_flash_color = v
		emit_changed()
@export var boss_flash_time := 0.6:
	set(v):
		boss_flash_time = v
		emit_changed()
@export var boss_marker_color := Color.WHITE:
	set(v):
		boss_marker_color = v
		emit_changed()
@export var boss_marker_width := 3:
	set(v):
		boss_marker_width = v
		emit_changed()
@export var slot_border_width := 2:
	set(v):
		slot_border_width = v
		emit_changed()
@export var bag_border_width := 2:
	set(v):
		bag_border_width = v
		emit_changed()
@export var lock_hint_color := Color(1, 0.6, 0.5):
	set(v):
		lock_hint_color = v
		emit_changed()
@export var boss_border_width := 2:
	set(v):
		boss_border_width = v
		emit_changed()
@export var boss_inset := 2:
	set(v):
		boss_inset = v
		emit_changed()
@export var boss_flash_speed := 18.0:
	set(v):
		boss_flash_speed = v
		emit_changed()
@export var boss_flash_mix := 0.5:
	set(v):
		boss_flash_mix = v
		emit_changed()
@export_group("Tooltip")
@export var tooltip_border_width := 2:
	set(v):
		tooltip_border_width = v
		emit_changed()

@export var tooltip_texture: Texture2D:
	set(v):
		tooltip_texture = v
		emit_changed()   ## nine-patch background of the hover name; empty = flat placeholder
@export var tooltip_patch_margin := 4:
	set(v):
		tooltip_patch_margin = v
		emit_changed()
@export var tooltip_pad := 6:
	set(v):
		tooltip_pad = v
		emit_changed()
@export var tooltip_font_size := 14:
	set(v):
		tooltip_font_size = v
		emit_changed()
@export var tooltip_color := Color.WHITE:
	set(v):
		tooltip_color = v
		emit_changed()
@export var tooltip_bg := Color(0.05, 0.06, 0.1, 0.92):
	set(v):
		tooltip_bg = v
		emit_changed()
@export var tooltip_border := Color(0.35, 0.4, 0.55):
	set(v):
		tooltip_border = v
		emit_changed()
@export var tooltip_offset := Vector2(14, 18):   ## from the mouse
	set(v):
		tooltip_offset = v
		emit_changed()
@export_group("Ability placeholder colours")
@export var dodge_color := Color(0.35, 0.6, 0.9)
@export var skill_color := Color(0.95, 0.8, 0.3)
@export var guard_color := Color(0.65, 0.68, 0.75)

@export_group("Crafting window (W4, decision 0031)")
@export var window_texture: Texture2D:
	set(v):
		window_texture = v
		emit_changed()   ## the centred crafting window: nine-patch; empty = flat placeholder
@export var section_texture: Texture2D:
	set(v):
		section_texture = v
		emit_changed()   ## frame of the crafting / furnace area inside the window: nine-patch; empty = flat
@export var craft_tab_icon: Texture2D:
	set(v):
		craft_tab_icon = v
		emit_changed()   ## the Crafting tab (empty = a coloured square)
@export var hand_icon: Texture2D:
	set(v):
		hand_icon = v
		emit_changed()   ## station marker when you craft by hand (empty = a coloured square)
@export var window_patch_margin := 8:
	set(v):
		window_patch_margin = v
		emit_changed()
@export var window_pad := 10:
	set(v):
		window_pad = v
		emit_changed()   ## inner margin of the window, px
@export var window_gap := 8:
	set(v):
		window_gap = v
		emit_changed()   ## between the window parts, px
@export var section_patch_margin := 6:
	set(v):
		section_patch_margin = v
		emit_changed()
@export var section_pad := 6:
	set(v):
		section_pad = v
		emit_changed()   ## inner margin of the crafting / furnace area, px
@export var craft_area_height := 112:
	set(v):
		craft_area_height = v
		emit_changed()   ## height of the crafting area (the same for Crafting and Furnace), px
@export var craft_slot_size := 44:
	set(v):
		craft_slot_size = v
		emit_changed()   ## recipe icons and ingredient slots, px
@export var furnace_slot_size := 56:
	set(v):
		furnace_slot_size = v
		emit_changed()   ## the big result slot, px
@export var craft_slot_gap := 4:
	set(v):
		craft_slot_gap = v
		emit_changed()   ## between icons in the recipe grid and the ingredient grid, px
@export var craft_grid_columns := 9:
	set(v):
		craft_grid_columns = v
		emit_changed()   ## result icons per row in the recipe grid
@export var craft_grid_rows := 2:
	set(v):
		craft_grid_rows = v
		emit_changed()   ## rows shown before the recipe grid scrolls
@export var furnace_arrow_width := 60:
	set(v):
		furnace_arrow_width = v
		emit_changed()   ## px
@export var furnace_arrow_height := 22:
	set(v):
		furnace_arrow_height = v
		emit_changed()   ## px, the drawn triangle
@export var tab_size := 36:
	set(v):
		tab_size = v
		emit_changed()   ## the tab / station-marker squares, px
@export var window_color := Color(0.07, 0.09, 0.14, 0.96):
	set(v):
		window_color = v
		emit_changed()
@export var window_border := Color(0.35, 0.4, 0.55):
	set(v):
		window_border = v
		emit_changed()
@export var section_color := Color(0.12, 0.14, 0.2, 0.8):
	set(v):
		section_color = v
		emit_changed()
@export var section_border := Color(0.3, 0.34, 0.48):
	set(v):
		section_border = v
		emit_changed()
@export var craft_dim_color := Color(1, 1, 1, 0.45):
	set(v):
		craft_dim_color = v
		emit_changed()   ## recipe icon / result slot tint when you lack the items
@export var craft_lit_color := Color(1, 1, 1, 1):
	set(v):
		craft_lit_color = v
		emit_changed()   ## recipe icon tint when you can craft it
@export var furnace_arrow_color := Color(0.9, 0.9, 0.9, 0.9):
	set(v):
		furnace_arrow_color = v
		emit_changed()
@export var furnace_fill_color := Color(1.0, 0.62, 0.2):
	set(v):
		furnace_fill_color = v
		emit_changed()   ## the progress arrow fill
@export var craft_short_color := Color(1.0, 0.35, 0.3):
	set(v):
		craft_short_color = v
		emit_changed()   ## ingredient count when you have too few
@export var craft_enough_color := Color(1, 1, 1):
	set(v):
		craft_enough_color = v
		emit_changed()   ## ingredient count when you have enough
@export var tab_color := Color(0.55, 0.6, 0.75):
	set(v):
		tab_color = v
		emit_changed()   ## Crafting tab square while there is no icon
@export var hand_color := Color(0.8, 0.7, 0.55):
	set(v):
		hand_color = v
		emit_changed()   ## station marker square while there is no icon
@export var furnace_tab_glow_color := Color(1.5, 1.1, 0.7):
	set(v):
		furnace_tab_glow_color = v
		emit_changed()   ## the Furnace tab pulses to this while the furnace smelts or has output ready (>1 brightens)
@export var furnace_tab_pulse_speed := 5.0:
	set(v):
		furnace_tab_pulse_speed = v
		emit_changed()
@export var craft_flash_color := Color(1.0, 0.3, 0.3):
	set(v):
		craft_flash_color = v
		emit_changed()   ## a dimmed recipe icon flashes this when you click it
@export var craft_flash_time := 0.25:
	set(v):
		craft_flash_time = v
		emit_changed()
@export var tooltip_icon_size := 28:
	set(v):
		tooltip_icon_size = v
		emit_changed()   ## ingredient icons in a recipe's hover tooltip
@export var craft_lit_backdrop := Color(0.72, 0.78, 0.9, 0.95):
	set(v):
		craft_lit_backdrop = v
		emit_changed()   ## behind a craftable icon: a light square, so dark art (the anvil) still reads as lit
@export var craft_dim_backdrop := Color(0.04, 0.05, 0.08, 0.95):
	set(v):
		craft_dim_backdrop = v
		emit_changed()   ## behind a dimmed icon: a dark square (the whole slot is also tinted by craft_dim_color)
@export_group("Held stack (the cursor)")
@export var cursor_offset := Vector2(8, 8):
	set(v):
		cursor_offset = v
		emit_changed()   ## the held stack is drawn this far from the pointer, px
@export var cursor_scale := 1.1:
	set(v):
		cursor_scale = v
		emit_changed()
@export var cursor_shadow_size := 6:
	set(v):
		cursor_shadow_size = v
		emit_changed()
@export var cursor_shadow_color := Color(0, 0, 0, 0.5):
	set(v):
		cursor_shadow_color = v
		emit_changed()
@export var cursor_shadow_offset := Vector2(3, 4):
	set(v):
		cursor_shadow_offset = v
		emit_changed()
