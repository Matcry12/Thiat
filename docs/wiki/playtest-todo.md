# Playtest to-do

Things built but **not yet played by you**. Tick them off (or write what felt wrong) when you play.
Newest slice at the top. Run the game, press `F3` for the test buttons.

## W3 — inventory and tools (building now)

- [ ] HUD: hotbar top-left, health bottom-left, dodge / skill / guard icons above the health bar. No words. OK?
- [ ] Hover a slot, an ability icon or the health bar: a small name (or "73 / 100") shows. It must not show while you carry a stack.
- [ ] Are the placeholder icons (axe, pickaxe, wood, stone, copper, dodge, skill, guard) clear enough?
- [ ] Open F3: nothing should overlap the HUD.

- [ ] Keys `1` to `4`: sword, bow, axe, pickaxe. Does the hotbar show them clearly? (Tools are plain coloured squares with a letter for now.)
- [ ] Press `3` (axe) or `4` (pickaxe): the switch is instant. Press `1` or `2`: weapon to weapon still has the cast and cooldown.
- [ ] From the axe, press `1`: your sword comes back at once. Then press `2`: that one is a normal swap.
- [ ] Press `5` to `9` (empty slots): bare hands, same as the old key `3`.
- [ ] Mouse wheel: it waits a moment before it selects. Too slow? (F3 → `Player` → `wheel_settle`.)
- [ ] Axe on a tree: 2 hits. Hands: 6 hits. Is the axe too strong or too weak? (F3 → `Tool stone_axe`, `Node tree` → `tool_bonus`)
- [ ] Axe on copper: "clink". Pickaxe on copper: it breaks. Is it clear why?
- [ ] `Tab` or `I`: the bag opens under the hotbar. Pick up a stack, put it down, right click for half, shift click to send it to the hotbar.
- [ ] Try to put a 3rd weapon in the hotbar (F3 → `Give sword`, then move it). It must not go in.
- [ ] Close the bag while holding a stack: the stack goes back.
- [ ] Click on the bag: you should not swing your weapon.
- [ ] Walk to the boss until it wakes up: the bag closes and says it is locked.
- [ ] F3 → `Fill bag`, then punch a tree: the wood stays on the ground (bag is full). Does that feel right?
- [ ] The bag is under the hotbar (top right), not above it. OK?

## W2 — trees and rocks

- [ ] Press `3`: your weapon goes away, bare hands. Press `3` again: the same weapon is back at once.
- [ ] Hands → press `2` (the other weapon): it should be a normal swap (cast + cooldown), not free.
- [ ] Punch a tree: does it shake, do chips fly, does it feel good? About 6 punches to break — too many / too few?
- [ ] Wood and stone fly to you when you walk near. Is the magnet range right? (F3 → `Collector`)
- [ ] The counter under the hotbar goes up.
- [ ] Punch copper in the rocky area: "clink", no damage. Is it clear *why*?
- [ ] Sword swing at a tree passes through. OK, or should the sword chop slowly?
- [ ] Walk behind a big tree: it turns see-through.
- [ ] The fists are small and hard to see in the video. Can you see your punch?
- [ ] The player sprite turns red while punching (the old debug swing tint). Keep or remove?
- [ ] Trees are big (96 x 124 px) and overlap a lot. Too big?
- [ ] Shoot an arrow at a tree or rock: it should stop there (cover). Same for the boss's bolts.
- [ ] Are there too many / too few trees and rocks? (F3 → `Node tree` / `Node rock` density, then `New map`)

## W1 — big island

- [ ] Walk home → boss. You said the map is too small; decide later: bigger map (`map_cols` / `map_rows`) or slower walk.
- [ ] Walk into the water at an angle: you stop at the shore, never on water.
- [ ] F3 `Go home` / `Go to boss` work.
- [ ] Try a few seeds (F3 seed box): every island different, always a way to the boss.
- [ ] Boss area looks too much like the forest (placeholder dark grass) — new placeholder now, or wait for your art?
- [ ] Campfire looks unlit — OK for now?

## Older (from v0 slices, still open)

- [ ] Hit feel numbers (hit-stop, shake, sparks), knockback strength.
- [ ] Boss leash at the zone edge.
- [ ] Run bounce + dust: dust maybe too faint; a dodge from standing gives a double puff.
- [ ] HUD look (top-right life bar + hotbar).
