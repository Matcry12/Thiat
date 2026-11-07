# 0030 — HUD layout and icons instead of words

**Date:** 2026-10-09 · Supersedes the placement in [0024](0024-hud-top-right.md).

## Context
The user prefers the health bar at the bottom-left, the inventory at the top-left, and no words in the HUD ("Dodge", "Sword", "Life 80/100").

## Decision
- **Layout** (anchors and containers in `HUD`; the only positions are the `margin_x`, `margin_y` and `block_gap` exports):
  - top-left: `Hotbar`, and the bag opens right under it;
  - bottom-left: `AbilityBar` (three small icon slots: dodge, skill, guard) above the `HealthBar`;
  - bottom centre: the boss bar (`BossBar`), about 45% of the screen wide (`InventorySkin.boss_bar_width_fraction`), above the bottom margin. It slides / narrows so it never touches the bottom-left block or the F3 tuning panel.
- **No words.** Hotbar slots show `ItemData.icon` (placeholder PNGs in `assets/game/ui/placeholder/`: axe, pickaxe, wood, stone, copper ore; sword and bow keep their model art). Stack counts and the slot key number stay: they are information. The health bar is the bar alone (trail and low-health pulse kept). Cooldowns are a dim over the icon that drains, not seconds.
- **Ability slots** are the same `ItemSlot` scene as the hotbar, skinned by `InventorySkin` (`dodge_icon`, `skill_icon`, `guard_icon`, placeholder colour when empty). Dodge: dim = cooldown left. Skill: dim = cooldown left (fully dim when the weapon has no skill). Guard: dim = shield used (fully dim when broken). The slot frame lights while the ability is in use.
- **One hover tooltip** (`HudTooltip`): the item name over a hotbar or bag slot, the ability name over an ability icon, "73 / 100" over the health bar. It polls the mouse against the watched rectangles (so it also works over the hotbar while the bag is closed), ignores the mouse itself (never blocks a click), and hides while a stack is on the cursor. Its look is in the skin (`tooltip_*`: panel texture, font, padding, colours).
- **Boss bar = picture cues, no text.** Hidden by default. It appears (fade + slide, `boss_fade_time`, `boss_slide_px`) only when the boss is awake and hides when it sleeps (leash / return), or `boss_hide_delay` seconds after it is defeated so the kill reads. The one hook is `BossBar.set_awake(bool)`: today the HUD wires it to `Boss.aggro_changed` (engaged = awake); the W7 altar summon calls `set_awake(true)` and reuses the rest. Opaque dark background (full vs empty is clear), a marker at the phase-2 threshold, and in phase 2 the fill turns `boss_phase2_color` with a short flash.
- **Skin owns the bars.** Health bar and boss bar read sizes, colours, frame / fill textures and the marker width from `InventorySkin` (`health_*`, `boss_*`, `bar_*`); the exports left on `HealthBar` are behaviour only (trail, pulse). The tooltip border width is a skin field too.
- **No names mid-fight:** hotbar tooltips are hidden while the boss is engaged and the bag is closed.
- **F3 keeps its text.** The status panel now starts below the top-left block and ends above the bottom-left block (`HUD.f3_insets()`, also above an awake boss bar), and clips instead of growing. Nothing overlaps.

## Why
Icons read faster than words and are what drawn art will replace anyway. Names are still one hover away. Putting both corners on the left keeps the right side free for the boss and for F3.

## Consequences
- `HealthBar.label_text`, `font_size`, `label_format`, `text_gap`, `width_override` and the Hotbar name label are gone.
- The F3 status text is cut off at the bottom on a 648 px high screen (it already was); it clips instead of shrinking.
- Open question for the playtest: are the placeholder ability icons clear enough?
