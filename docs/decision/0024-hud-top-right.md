# 0024 — HUD top-right: life bar and hotbar (Terraria style)

## Context
The HUD was a bottom-left stack of text and a plain bar. The user asked for a Terraria-like life bar and item
bar in the top-right corner. Items will come later, so the hotbar must work for any number of slots.

## Decision
- New nodes in `scripts/ui/`: `HealthBar` (text line + bar + "recent damage" trail), `Hotbar`, `HotbarSlot`.
  They only read `Health` and `Loadout` (polling + the swap signals). Combat never calls them.
- Looks are slots: `frame_style` / `selected_style` (any StyleBox) and `fill_texture`. Sizes, colours, trail
  delay/speed, low-HP pulse are `@export` and show in F3 (sections `HUD`, `HealthBar`, `Hotbar`).
- `WeaponData` gets optional `icon` and `display_name`. No icon: the slot shows the `Art` sprite of the weapon's
  model scene. No name: the file name, prettified ("iron_sword" -> "Iron Sword"). A real icon is a data swap.
- The old bottom-left life bar and the "weapon / swap" text line are removed. Dodge / E / guard text stays for now.
- F3 overlap: the F3 tuning panel is 352 px wide on the right edge, full height. While F3 is open the HUD block
  moves left 368 px and down 64 px (below the boss bar). F3 itself is untouched. New F3 button: `Hurt player 20`.

## Why
Example: when you take a hit, the bar drops at once, but a light chunk stays and drains a moment later. You see
how much the hit took. Terraria players know this layout, so no explanation is needed.
Keeping HUD code apart from combat means a drawn frame or icon later touches zero combat code.

## Consequences
- `HUD` must sit before `TuningPanel` in `arena.tscn` (F3 reads the HUD's child nodes when it starts).
- The fallback icon is the raw sprite turned 45 degrees: not sharp pixel art. Real icons replace it.
- Shield is not shown here (the guard bar next to the player owns it, decision 0015).
