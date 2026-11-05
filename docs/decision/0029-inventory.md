# 0029 — Inventory: slots, hotbar selection, tools

> **Max 2 weapons, the swap cost and the wheel wait superseded by [0058](0058-free-weapon-swap-no-weapon-limit.md).** The rest still stands.

**Date:** 2026-10-09 · **Slice:** W3

## Context
W2 had an Inventory that was only a list of counts, and a temporary key `3` to put the weapon away so the fists could punch trees. Decision 0003 already says: hotbar of about 9 slots, number keys / wheel select, at most 2 weapons, weapon swap costs a cast and a cooldown, bag locked in combat. W3 builds that, plus tools (axe, pickaxe).

## Decision
- **36 slots.** Slots 0-8 are the hotbar, 9-35 the bag. A slot is one `ItemData` and a count. `ItemData` gets `category` (material / tool / weapon), `max_stack` (default 64) and an optional `weapon: WeaponData`. Anything with a `weapon` stacks to 1.
- **`Inventory.add(item, n)` returns the leftover.** It fills open stacks first, then empty slots. Materials try the bag first (so wood never takes a hotbar slot while the bag has room). Tools and weapons try the hotbar first. A pickup that does not fit stays on the ground (the Collector does not pull it in).
- **The Inventory owns the items. The Loadout owns "what is in my hands".** `Loadout.weapons` is no longer set by hand: it is rebuilt from the hotbar every time the inventory changes (`Loadout.sync`). Max 2 weapons in the hotbar (`Inventory.max_hotbar_weapons`); a 3rd weapon can only sit in the bag.
- **Selecting** (`Loadout.select(slot)`, keys `1`-`9`, wheel):
  - weapon slot: the old swap (0003: cast + cooldown), except going back to the weapon you put away, which is instant (as key `3` was);
  - tool, material or empty slot: instant. A tool is held as the "hands" weapon; an empty slot or a material is the fists.
  So the swap cost still only ever applies between the two weapons.
- **The wheel waits** (`Player.wheel_settle`, 0.12 s) before it selects, so scrolling from the sword to the axe does not start a swap cast on the bow on the way.
- **Tools** are `WeaponData` (`stone_axe.tres`, `stone_pickaxe.tres`) with `tool_kind`. `ResourceNodeData` gets `preferred_tool` and `tool_bonus` (3.0). A matching tool multiplies `gather_damage`. The axe has `tool_power` 0 so it cannot mine copper (needs 1); the pickaxe has 2. Tree: 2 axe hits (6 punches by hand). Both tools reuse the fists model as a placeholder.
- **Starting kit:** sword 1, bow 2, axe 3, pickaxe 4 (`Inventory.start_items`). Crafting is W4. *(Superseded by [0031](0031-crafting.md): the start kit is a wooden sword only; F3 `Give W3 kit` gives this one.)*
- **Bag panel** (`BagPanel`, `Tab` or `I`): placeholder squares under the hotbar. Click picks up a stack, click places / merges / swaps, right click picks up half, shift click moves between hotbar and bag. All rules live in `Inventory.click_slot` / `shift_move`, not in the UI. Closing with a stack on the cursor puts it back. The game keeps running; attack input is ignored while the mouse is over the panel or the (then clickable) hotbar.
- **Locked while a boss is `ENGAGED`** (`Inventory.locked()`, group `boss`). The panel will not open (a short hint shows) and closes by itself if the boss engages while it is open.
- The old key `3` holster toggle and the `ItemCounter` are removed. The hotbar shows icon (or tinted square) and count.

## Why
- One owner per fact: items in the Inventory, the held thing in the Loadout. The hotbar and bag are views.
- Keeping weapon <-> weapon as the only costly switch keeps decision 0003 intact and the boss's opponent bounded, while tools stay free to use.
- The rules (stacks, max 2 weapons, lock) live in data-like code that tests can call without a UI.

## Consequences
- The free way back from a tool or hands is only to the same weapon that was put away. If that weapon left the hotbar and came back, taking it out costs the full cast (stricter, still 0003).
- An item never vanishes: if it cannot go back into a slot after closing the bag, it drops on the ground at the player.
- Anything that needs the weapon list reads `Loadout.weapons` as before, but must not write it.
- `weapon_1`, `weapon_2`, `hands` input actions are gone: `slot_1`..`slot_9` and `bag` replace them. Tests and the demo bot were updated.
- `Inventory.clear()` now removes materials only (tools and weapons stay), so the F3 "Clear items" button cannot strip the player's weapons.
- New items (potions, armor) are `.tres` files; armor and potion rules are still to come (0003).
- Unsure / watch in playtest: the wheel delay, the bag sitting under the hotbar (top right) instead of above it, and the ordering of "materials go to the bag first".
