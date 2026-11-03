# Playtest to-do

Things built but **not yet played by you**. Tick them off (or write what felt wrong) when you play.
Newest slice at the top. Run the game, press `F3` for the test buttons.

## W5 - slimes (built, not played)

- [ ] Walk out from home into the forest. Do slimes show up at a pace that feels natural (about 1 group a minute)? Too many / too few: `F3` -> `EnemySpawner` -> `base_chance`.
- [ ] `F1`: faint green squares = slime spots. Walk into one: is there already a small group living there? Does it feel like a "slime meadow" you could come back to?
- [ ] Do you ever see a slime pop in on screen? (It should only appear off-screen.)
- [ ] A slime squashes and turns yellow on top before it jumps. Can you see it coming and dodge (`Space`)? Warning time: `Enemy slime data` -> `hop_windup`.
- [ ] Hit it with the sword: flash, push back, numbers, gel pops out and flies to you.
- [ ] Walk far away while one chases you: it gives up and walks home.
- [ ] Draw order: a slime behind a tree is hidden by the leaves; behind you, it is behind your body; the sword is always over the slime.
- [ ] Other biomes: swamp (dark slimes, more), beach (yellow, rare), snow (blue, rare, tough), rocky (grey, rare, tough). `F3` -> `Go to boss` / walk there.
- [ ] Never near home or your stations; none while the boss fight is on.
- [ ] The boss is now a plain red circle (old art removed). Can you still read its attacks?
- [ ] `F3` -> `Spawn slime pack here`, `Kill all enemies`, `Spawner on/off` work.

## W9 - save and load (built, not played)

- [ ] Play a while: chop a tree, place a furnace with ore in it, die once so a bag lies on the ground. Press `Esc`, then `Save & quit`.
- [ ] On the title, `Continue` is lit. Click it. Is it the same island, the same spot, the same items?
- [ ] The chopped tree is still a stump. The furnace still has its ore and keeps smelting. The bag is still there.
- [ ] Is your selected slot right? If it was the bow, does it start with no swap wait?
- [ ] Press `Play` instead: a new island, a new run. Quit at once: the old save is overwritten. OK for you?
- [ ] Wait 60 s: `F3` -> `[Save]` shows a new save time. Is 60 s a good time?
- [ ] Fight the boss and press `Esc` -> `Save & quit`: the button says "Not saved: boss engaged", then you go to the title. Is that clear?
- [ ] After you kill the boss, save and continue: it should work again.
- [ ] Close the window with the X: next start, `Continue` has your latest state.
- [ ] `F3` buttons: `Save now`, `Load save`, `Delete save` (title `Continue` greys out after delete).

## W8 - title, pause, settings (built, not played)

- [ ] The game starts on the title: Play, Continue, Settings, Quit. `Continue` is grey without a save.
- [ ] `Esc` in the game pauses. Everything stops. `Esc` again resumes.
- [ ] Open the bag, press `Esc`: the bag closes, no pause. `Esc` again pauses.
- [ ] Settings: move the volume (do sounds get louder / quieter?), the shake (0 = no shake after a hit), the fullscreen button (clear ON / OFF?).
- [ ] Close and start the game again: are your settings still there?
- [ ] Hold the guard (`F`), press `Esc`, let go, resume: the guard must not stay stuck.
- [ ] `F3` still works in the arena, and `F1`, `F2`. (The F3 panel freezes while paused: OK?)
- [ ] `Quit to title` from pause: is slow-motion (`F2`) reset?

## W6 - death and respawn (built, not played; death bag replaced by drops, 0042)

- [ ] Collect some wood and stone, then die (or `F3` -> `Kill player`). No "You died" screen: after 2 s you wake at the campfire with full health.
- [ ] Everything you carried pops out around where you died, like Minecraft: materials, tools and weapons. Does the spray look good? Is it easy to see? (`F3` -> `Respawner` -> `spray_min`, `spray_max`, `pop_height`)
- [ ] You are empty after waking up (fists). Walk back to the pile: the items fly to you and everything comes back.
- [ ] Too hard or too soft? Keep gear: `F3` -> `Respawner` -> `drop_gear` off. Keep half the materials: `drop_share` 0.5.
- [ ] Leave the pile for 5 minutes: it vanishes. Is 5 minutes right? (`despawn_time`; 0 = never) `F3` `[Death]` shows the time left.
- [ ] You cannot pick things up while dead. The corpse lies on top of the drops: nothing should vanish into you.
- [ ] Get a 3rd weapon from a pile: it must go to the bag, not the hotbar.
- [ ] Save and continue with a pile on the ground: it is still there with its timer.
- [ ] Die while the boss fight is on: the boss walks home, heals, and goes back to phase 1.
- [ ] Die in the middle of a dodge: the body should stop, not slide.
- [ ] `F3` -> `Go to nearest drop` takes you to the pile. Is the 2 s delay right? (`respawn_delay`)
- [ ] `R` now only works after you beat the boss.

## W4 - crafting (building now)

You start with a wooden sword only. Press `F3` and use `Give W3 kit` if you want the old kit back, or `Give materials (20 each)` to skip the grind.

- [ ] Punch trees, then press `Tab`. One window opens in the middle: icons on top, your bag and hotbar below.
- [ ] With 1 wood a dim workbench icon shows ("you are on the way"). With 10 wood it lights up. With nothing, no icon. Is that clear?
- [ ] Hover an icon: the name and the ingredients (icons + numbers) show. A red number = you lack it. Enough to know what to gather?
- [ ] Click a lit icon: the item sticks to the mouse and the materials are gone. Click a bag or hotbar slot to put it down. Does it feel like moving a bag stack?
- [ ] Click the same icon again while holding: the stack grows. Click a dim icon: it flashes red and does nothing.
- [ ] Close the window while holding an item: it must go back into the bag (or drop at your feet), never vanish.
- [ ] Shift click a lit icon: the item goes straight into the bag.
- [ ] The window covers the screen centre (and you). OK, or should it sit higher?
- [ ] Craft the workbench (10 wood). Select it in the hotbar: a ghost follows you. White = free, red = not allowed. Click to place it.
- [ ] Try to place it on water, on a tree, on another station, near the boss. It should say no (red) every time.
- [ ] Stand near the workbench and open the window: stone pickaxe, stone axe, bow and furnace appear (the anvil only when you hold copper bars). Walk away: they go. The nearest station's recipes come first.
- [ ] The small icon at the top-left of the window shows which station you are at (hand, workbench, anvil).
- [ ] Is the distance to a station right? (`craft_radius` on the station scene. Press `F1` to see the pink circle.)
- [ ] Hit a station with the **pickaxe**: you get it back. A punch or an axe must not.
- [ ] Mine copper, place a furnace, open the window near it: a Furnace tab (and a Crafting tab) show. On the furnace tab shift click copper ore in a bag slot. The arrow fills; a bar above the furnace fills in the world too.
- [ ] One bar takes 3 seconds. Too slow, too fast? (`F3` -> `Smelt copper_bar` -> `smelt_time`)
- [ ] Walk away while it smelts. Come back: the bars are waiting. Shift click the output to take them.
- [ ] Craft an anvil (5 copper bars, at the workbench). Place it. At the anvil: copper sword, axe, pickaxe.
- [ ] Is the copper sword clearly stronger than the wooden one? Is the tint (brown vs orange) readable?
- [ ] Are the amounts fair? Workbench 10 wood. Stone pickaxe 4 wood + 6 stone. Furnace 10 stone + 4 wood. Anvil 5 bars. Copper sword 6 bars + 3 wood. (`F3` -> `Recipe ...` sections)
- [ ] Walk to the boss until it wakes: the window closes and locks.
- [ ] Crafting with a full bag: the item should drop at your feet.
- [ ] Use `F3` buttons `Place workbench here`, `Place furnace here`, `Place anvil here`, `Finish smelting`.
- [ ] The three station pictures come from the Pixel Crawler sheets. Do they look right next to the trees?

## W3 — inventory and tools

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
- [ ] Try to put a 3rd weapon in the hotbar (F3 → `Give W3 kit`, then move a sword in). It must not go in.
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
