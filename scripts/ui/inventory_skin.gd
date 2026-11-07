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

@export_group("Health bar")
@export var health_low_color := Color(1.0, 0.5, 0.4):
	set(v):
		health_low_color = v
		emit_changed()
@export_group("Boss bar")
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
@export var boss_fill_color := Color(0.8, 0.2, 0.9):
	set(v):
		boss_fill_color = v
		emit_changed()
@export var boss_phase2_color := Color(1.0, 0.23, 0.53):  ## modulate over the grey gloss ramp of boss_fill: hot pink (~#d0306e), never red (the HP bar is red)
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
@export var dodge_color := Color(0.35, 0.6, 0.9):
	set(v):
		dodge_color = v
		emit_changed()
@export var skill_color := Color(0.95, 0.8, 0.3):
	set(v):
		skill_color = v
		emit_changed()
@export var guard_color := Color(0.65, 0.68, 0.75):
	set(v):
		guard_color = v
		emit_changed()

@export_group("Crafting window (W4, decision 0031)")
@export var craft_tab_icon: Texture2D:
	set(v):
		craft_tab_icon = v
		emit_changed()   ## the Crafting tab (empty = a coloured square)
@export var hand_icon: Texture2D:
	set(v):
		hand_icon = v
		emit_changed()   ## station marker when you craft by hand (empty = a coloured square)
@export var craft_dim_color := Color(1, 1, 1, 0.45):
	set(v):
		craft_dim_color = v
		emit_changed()   ## recipe icon / result slot tint when you lack the items
@export var craft_lit_color := Color(1, 1, 1, 1):
	set(v):
		craft_lit_color = v
		emit_changed()   ## recipe icon tint when you can craft it
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

## ===== Island Workshop parts (decision 0043) =====
## Baked by tools/ui_bake/bake_game_parts.py into assets/game/ui/skin/ (art scale 1; draw at art_scale, nearest). Slot lists per screen: assets/game/ui/skin/README.md.
## <part>_tex = the picture. Nine-patch + content margins are NOT fields: PixelArt reads them from assets/game/ui/skin/slices.json (part name = the
## field name without "_tex"), so a rebake cannot drift from the code.
@export_group("Island Workshop: scale")
@export_range(1, 4) var art_scale := 2:
	set(v):
		art_scale = v
		emit_changed()  ## 1 art px = this many screen px. Part size * art_scale = size on screen.
@export_group("Island Workshop: Menus")
@export var panel_title_tex: Texture2D:
	set(v):
		panel_title_tex = v
		emit_changed()
@export var panel_pause_tex: Texture2D:
	set(v):
		panel_pause_tex = v
		emit_changed()
@export var panel_settings_tex: Texture2D:
	set(v):
		panel_settings_tex = v
		emit_changed()
@export var title_plaque_tex: Texture2D:
	set(v):
		title_plaque_tex = v
		emit_changed()
@export var title_logo_tex: Texture2D:
	set(v):
		title_logo_tex = v
		emit_changed()
@export var title_rope_tex: Texture2D:
	set(v):
		title_rope_tex = v
		emit_changed()
@export var button_menu_idle_tex: Texture2D:
	set(v):
		button_menu_idle_tex = v
		emit_changed()
@export var button_menu_hover_tex: Texture2D:
	set(v):
		button_menu_hover_tex = v
		emit_changed()
@export var button_menu_pressed_tex: Texture2D:
	set(v):
		button_menu_pressed_tex = v
		emit_changed()
@export var button_menu_primary_tex: Texture2D:
	set(v):
		button_menu_primary_tex = v
		emit_changed()
@export var button_menu_primary_pressed_tex: Texture2D:
	set(v):
		button_menu_primary_pressed_tex = v
		emit_changed()
@export var button_menu_disabled_tex: Texture2D:
	set(v):
		button_menu_disabled_tex = v
		emit_changed()
@export var menu_arrow_tex: Texture2D:
	set(v):
		menu_arrow_tex = v
		emit_changed()
@export var slider_groove_tex: Texture2D:
	set(v):
		slider_groove_tex = v
		emit_changed()
@export var slider_fill_tex: Texture2D:
	set(v):
		slider_fill_tex = v
		emit_changed()
@export var slider_fill_hover_tex: Texture2D:
	set(v):
		slider_fill_hover_tex = v
		emit_changed()
@export var slider_knob_tex: Texture2D:
	set(v):
		slider_knob_tex = v
		emit_changed()
@export var checkbox_off_tex: Texture2D:
	set(v):
		checkbox_off_tex = v
		emit_changed()
@export var checkbox_on_tex: Texture2D:
	set(v):
		checkbox_on_tex = v
		emit_changed()
@export var checkbox_hover_tex: Texture2D:
	set(v):
		checkbox_hover_tex = v
		emit_changed()
@export_group("Island Workshop: HUD")
@export var hotbar_panel_tex: Texture2D:
	set(v):
		hotbar_panel_tex = v
		emit_changed()
@export var slot_idle_tex: Texture2D:
	set(v):
		slot_idle_tex = v
		emit_changed()
@export var slot_hover_tex: Texture2D:
	set(v):
		slot_hover_tex = v
		emit_changed()
@export var slot_pick_tex: Texture2D:
	set(v):
		slot_pick_tex = v
		emit_changed()
@export var slot_sel_tex: Texture2D:
	set(v):
		slot_sel_tex = v
		emit_changed()
@export var ability_frame_tex: Texture2D:
	set(v):
		ability_frame_tex = v
		emit_changed()
@export var ability_keycap_tex: Texture2D:
	set(v):
		ability_keycap_tex = v
		emit_changed()
@export var hp_frame_tex: Texture2D:
	set(v):
		hp_frame_tex = v
		emit_changed()
@export var hp_fill_tex: Texture2D:
	set(v):
		hp_fill_tex = v
		emit_changed()
@export var hp_trail_tex: Texture2D:
	set(v):
		hp_trail_tex = v
		emit_changed()
@export var boss_frame_tex: Texture2D:
	set(v):
		boss_frame_tex = v
		emit_changed()
@export var boss_fill_tex: Texture2D:
	set(v):
		boss_fill_tex = v
		emit_changed()
@export var boss_mark_tex: Texture2D:
	set(v):
		boss_mark_tex = v
		emit_changed()
@export var boss_plate_tex: Texture2D:
	set(v):
		boss_plate_tex = v
		emit_changed()
@export_group("Island Workshop: Bag & book")
@export var bag_panel_tex: Texture2D:
	set(v):
		bag_panel_tex = v
		emit_changed()
@export var divider_line_tex: Texture2D:
	set(v):
		divider_line_tex = v
		emit_changed()
@export var book_cover_tex: Texture2D:
	set(v):
		book_cover_tex = v
		emit_changed()
@export var book_tab_active_tex: Texture2D:
	set(v):
		book_tab_active_tex = v
		emit_changed()
@export var book_tab_idle_1_tex: Texture2D:
	set(v):
		book_tab_idle_1_tex = v
		emit_changed()
@export var book_tab_idle_2_tex: Texture2D:
	set(v):
		book_tab_idle_2_tex = v
		emit_changed()
@export var well_tex: Texture2D:
	set(v):
		well_tex = v
		emit_changed()
@export var qty_box_tex: Texture2D:
	set(v):
		qty_box_tex = v
		emit_changed()
@export var button_small_idle_tex: Texture2D:
	set(v):
		button_small_idle_tex = v
		emit_changed()
@export var button_small_hover_tex: Texture2D:
	set(v):
		button_small_hover_tex = v
		emit_changed()
@export var button_small_pressed_tex: Texture2D:
	set(v):
		button_small_pressed_tex = v
		emit_changed()
@export var button_small_disabled_tex: Texture2D:
	set(v):
		button_small_disabled_tex = v
		emit_changed()
@export var craft_disabled_tex: Texture2D:
	set(v):
		craft_disabled_tex = v
		emit_changed()
@export var lock_banner_tex: Texture2D:
	set(v):
		lock_banner_tex = v
		emit_changed()
@export var padlock_tex: Texture2D:
	set(v):
		padlock_tex = v
		emit_changed()
@export var tooltip_tex: Texture2D:
	set(v):
		tooltip_tex = v
		emit_changed()
@export var tooltip_pin_tex: Texture2D:
	set(v):
		tooltip_pin_tex = v
		emit_changed()
@export_group("Island Workshop: palette (DESIGN.md section 2)")
@export var pal_out := Color8(62, 36, 39):
	set(v):
		pal_out = v
		emit_changed()  ## outline, text on paper
@export var pal_line := Color8(118, 64, 65):
	set(v):
		pal_line = v
		emit_changed()  ## secondary text on paper
@export var pal_paper := Color8(214, 179, 142):
	set(v):
		pal_paper = v
		emit_changed()  ## tooltip line 2
@export var pal_cream := Color8(252, 242, 222):
	set(v):
		pal_cream = v
		emit_changed()  ## text on dark / buttons (with OUT outline)
@export var pal_goldtxt := Color8(244, 200, 76):
	set(v):
		pal_goldtxt = v
		emit_changed()  ## sub-titles, item type
@export var pal_muted := Color8(150, 104, 86):
	set(v):
		pal_muted = v
		emit_changed()  ## disabled text only
@export var pal_okg := Color8(150, 214, 96):
	set(v):
		pal_okg = v
		emit_changed()  ## have enough
@export var pal_hp_l := Color8(255, 128, 104):
	set(v):
		pal_hp_l = v
		emit_changed()  ## not enough
@export var pal_hp_d := Color8(150, 26, 44):
	set(v):
		pal_hp_d = v
		emit_changed()
@export var pal_shadow := Color8(20, 10, 14):
	set(v):
		pal_shadow = v
		emit_changed()  ## cooldown wipe base (alpha below)
@export var text_outline_color := Color8(84, 48, 46):  ## pixel-font outline (dark wood brown, not near-black pal_out)
	set(v):
		text_outline_color = v
		emit_changed()
@export var text_outline_size := 1:  ## art px of that outline
	set(v):
		text_outline_size = v
		emit_changed()
@export var dim_color := Color8(26, 14, 20):
	set(v):
		dim_color = v
		emit_changed()
@export var dim_alpha_menu := 0.5:  ## title, book
	set(v):
		dim_alpha_menu = v
		emit_changed()
@export var dim_alpha_pause := 0.55:  ## pause, settings
	set(v):
		dim_alpha_pause = v
		emit_changed()
@export var cooldown_alpha := 0.45:  ## ability wipe, over pal_shadow
	set(v):
		cooldown_alpha = v
		emit_changed()
@export var missing_icon_alpha := 0.4:  ## recipe icon you cannot craft (the mock also greys it)
	set(v):
		missing_icon_alpha = v
		emit_changed()
@export_group("Island Workshop: fonts")
@export var font_body: Font:  ## empty = UiFonts.get_font("body"); drawn at 9 * art_scale
	set(v):
		font_body = v
		emit_changed()
@export var font_bold: Font:  ## empty = UiFonts.get_font("bold"); 9 * art_scale (headers x2)
	set(v):
		font_bold = v
		emit_changed()
@export var font_small: Font:  ## empty = UiFonts.get_font("small"); 5 * art_scale
	set(v):
		font_small = v
		emit_changed()

func ui_font(kind: String) -> Font:
	## kind: "body" | "bold" | "small". Skin override, else the baked pixel font with outline support.
	var f: Font = get("font_" + kind)
	return f if f != null else UiFonts.get_font(kind)
