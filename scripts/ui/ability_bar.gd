class_name AbilityBar
extends HBoxContainer
## Dodge, E skill and guard as three small keycap frames (no words but the cooldown seconds). Each is an ItemSlot driven by the
## same InventorySkin: icon textures `dodge_icon` / `skill_icon` / `guard_icon` (placeholder colour when
## empty). The cooldown is a dim that drains from the top; the slot's selected frame lights while the
## ability is in use. Reads Dodge / SkillSlot / Guard by polling; never changes them.

@export var skin: InventorySkin
@export var art_gap := 4                       ## art px between the frames (step 26 - 22)
@export var actions: Array[String] = ["dodge", "skill", "guard"]   ## input actions whose key shows on the keycap
@export var fallback_keys: Array[String] = ["Q", "E", "F"]       ## when the action has no short key

var _dodge: Dodge
var _skill: SkillSlot
var _loadout: Loadout
var _guard: Guard
var _slots: Array[AbilitySlot] = []

func bind(dodge: Dodge, skill: SkillSlot, loadout: Loadout, guard: Guard) -> void:
	_dodge = dodge
	_skill = skill
	_loadout = loadout
	_guard = guard

func slots() -> Array[AbilitySlot]:
	return _slots

func get_skin() -> InventorySkin:
	if skin == null:
		skin = load("res://data/ui/inventory_skin.tres")
	return skin

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in 3:
		var s := AbilitySlot.new()
		s.name = ["Dodge", "Skill", "Guard"][i]
		s.tip_override = s.name
		s.key_text = _key_text(i)
		add_child(s)
		_slots.append(s)

func _key_text(i: int) -> String:
	if InputMap.has_action(actions[i]):
		for ev in InputMap.action_get_events(actions[i]):
			if ev is InputEventKey:
				var t := (ev as InputEventKey).as_text_physical_keycode()
				if t.length() <= 2:
					return t
	return fallback_keys[i]

func _process(_delta: float) -> void:
	if _dodge == null or _slots.is_empty():
		return
	var sk := get_skin()
	add_theme_constant_override("separation", art_gap * sk.art_scale)
	for s in _slots:
		s.skin = sk
	_slots[0].set_picture(sk.dodge_icon, sk.dodge_color)
	_slots[0].cooldown_frac = clampf(_dodge.cooldown_remaining() / maxf(_dodge.cooldown, 0.001), 0.0, 1.0)
	_slots[0].cooldown_secs = _dodge.cooldown_remaining()
	_slots[0].selected = _dodge.is_dashing()
	var w: WeaponData = _loadout.active_weapon() if _loadout else null
	var skill: Skill = _skill.skill_for(w) if _skill and w else null
	_slots[1].set_picture(sk.skill_icon, sk.skill_color)
	_slots[1].tip_override = skill.skill_name if skill else "No skill"
	_slots[1].cooldown_frac = 1.0 if skill == null else clampf(_skill.cooldown_left(w) / maxf(w.skill_cooldown, 0.001), 0.0, 1.0)
	_slots[1].cooldown_secs = 0.0 if skill == null else _skill.cooldown_left(w)
	_slots[1].selected = _skill.is_active()
	_slots[2].set_picture(sk.guard_icon, sk.guard_color)
	_slots[2].cooldown_frac = 1.0 if _guard.state == Guard.State.BROKEN else 1.0 - _guard.tank_fraction()
	_slots[2].selected = _guard.is_guarding()
	for s in _slots:
		s.queue_redraw()


## One ability frame: carved frame + icon + cooldown wipe + keycap. Real size (art px * skin.art_scale), nearest.
class AbilitySlot extends Control:
	@export var icon_art := 16
	@export var icon_x := 3
	@export var icon_y := 3
	@export var keycap_x := 5
	@export var keycap_y := 17
	@export var frame_art := 22
	@export_range(0.0, 1.0) var cooldown_icon_dim := 0.55   ## icon brightness while cooling down (the seconds read over it)
	@export var active_color := Color8(244, 200, 76)   ## 1 art px ring while the ability is in use
	var skin: InventorySkin
	var tip_override := ""
	var key_text := ""
	var cooldown_frac := 0.0
	var cooldown_secs := 0.0
	var selected := false
	var _picture: Texture2D
	var _fallback := Color.GRAY

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func tip_text() -> String:
		return tip_override

	func set_picture(tex: Texture2D, fallback: Color) -> void:
		_picture = tex
		_fallback = fallback

	func has_picture() -> bool:
		return _picture != null

	func _process(_d: float) -> void:
		if skin == null:
			return
		var sc := skin.art_scale
		var kc := skin.ability_keycap_tex.get_size() if skin.ability_keycap_tex != null else Vector2(13, 11)
		custom_minimum_size = Vector2(frame_art, maxf(frame_art, keycap_y + kc.y)) * sc   # the keycap hangs below the frame
		queue_redraw()

	func _draw() -> void:
		if skin == null:
			return
		var sc := skin.art_scale
		var fpx := PixelArt.font_px(skin, "bold")
		var fr_size := skin.ability_frame_tex.get_size() if skin.ability_frame_tex != null else Vector2(frame_art, frame_art)
		PixelArt.draw_pic(self, skin.ability_frame_tex, Vector2.ZERO, sc)
		var ir := Rect2(Vector2(icon_x, icon_y) * sc, Vector2(icon_art, icon_art) * sc)
		if _picture:
			var d := cooldown_icon_dim if cooldown_frac > 0.0 else 1.0
			draw_texture_rect(_picture, ir, false, Color(d, d, d, 1.0))
		else:
			draw_rect(ir.grow(-2.0 * sc), _fallback)
		if cooldown_frac > 0.0:
			var h := roundf(ir.size.y * cooldown_frac / sc) * sc
			draw_rect(Rect2(ir.position, Vector2(ir.size.x, h)), Color(skin.pal_shadow, skin.cooldown_alpha))
			var edge := Rect2(ir.position + Vector2(0, h - sc), Vector2(ir.size.x, sc))
			var digit := Rect2()
			if cooldown_secs > 0.0:   # the edge line stops short of the digit, so "-2-" never reads as a strike-through
				var dw := skin.ui_font("bold").get_string_size(str(ceili(cooldown_secs)), HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x
				digit = Rect2(ir.get_center() - Vector2(dw * 0.5 + sc, 6.0 * sc), Vector2(dw + 2.0 * sc, 12.0 * sc))
			if digit.intersects(edge):
				draw_rect(Rect2(edge.position, Vector2(digit.position.x - edge.position.x, sc)), skin.pal_cream)
				draw_rect(Rect2(Vector2(digit.end.x, edge.position.y), Vector2(edge.end.x - digit.end.x, sc)), skin.pal_cream)
			else:
				draw_rect(edge, skin.pal_cream)
			if cooldown_secs > 0.0:
				PixelArt.text_centered(self, skin.ui_font("bold"), str(ceili(cooldown_secs)), fpx, ir.get_center(), skin.pal_cream, skin.text_outline_color)
		if selected:
			draw_rect(Rect2(Vector2.ZERO, fr_size * sc), active_color, false, float(sc))
		var kp := Vector2(keycap_x, keycap_y) * sc
		var kc_size := skin.ability_keycap_tex.get_size() if skin.ability_keycap_tex != null else Vector2(13, 11)
		PixelArt.draw_pic(self, skin.ability_keycap_tex, kp, sc)
		PixelArt.text_centered(self, skin.ui_font("bold"), key_text, fpx, kp + kc_size * sc * Vector2(0.5, 0.45), skin.pal_out)
