# Food algorithm

**Status:** Current (v2 approved 2026-11-20, decision [0072](../decision/0072-food-effects.md)). Replaces the hunger-bar design of [0071](../decision/0071-hunger-and-potion.md).

How food, raw food and the healing potion work. **No hunger bar.** Food gives effects with a timer (Minecraft style).
The bar under HP will become the **mana bar** later (its own design page, not this one).
Code (planned): `scripts/components/effects.gd` (the player's active effects), `scripts/components/consumer.gd` (eat / drink, kept),
`scripts/items/effect_data.gd` (one effect as data), HUD effect icons.
Built from how Minecraft, Terraria and Tinkerlands-like games do it, not guessed.

## Why the change (v1 -> v2)
A bar that always goes down is a chore in a 20-30 min run. Terraria and similar games use food as **preparation**:
you eat, you get an effect for a while. Food matters most before and between fights.

## Sources
| Rule | Minecraft | Terraria |
|---|---|---|
| What food does | Fills hunger; some food adds effects (golden apple: Regeneration II + Absorption) | "Well Fed" buff (small stats), tier by food quality |
| Raw / bad food | Raw chicken: 30% chance of "Hunger" debuff. Rotten flesh: 80%. Poisonous potato: Poison | No raw food |
| Heal over time | Regeneration I: 1 HP / 2.5 s. Regeneration II: 1 HP / 1.2 s | Regeneration potion, Campfire, Heart Lantern: +HP/s |
| Instant heal | Potion of Healing (instant) | Healing potion 50 / 100 HP, then Potion Sickness 60 s |
| Same effect again | Does **not** stack. Stronger level replaces weaker. Same level: the longer time wins | Does not stack. Using it again resets the timer |
| Show it | Icon + timer, top right; blinks in the last seconds | Icon + timer row under the hotbar |

## Our rules
1. **One owner.** An `Effects` node on the player holds the active effects. Each effect: id, strength, time left. Nothing else changes them.
2. **Effects are data.** One `EffectData` per kind: `regen` (heal per second), `sick` (debuff). An item lists what it gives:
   effect, strength, duration. A new food = a new `.tres`, no code.
3. **Cooked food = Regeneration.** Heals a little every second while the timer runs. Better food = faster heal or longer time.
4. **Raw food = Sick (debuff).** Raw pork still heals a tiny bit, but you are Sick: move 20% slower for 15 s. You eat it only when you must.
5. **Potion = best.** Instant +50 HP, then a 30 s cooldown (kept from v1). Food can never heal this much this fast.
5b. **Eating takes time (hold).** Hold the attack button 1.6 s (`eat_time` in `data/food/eating.tres`) on food or a potion; then one item is used.
   Release early, switch slot, dodge or die = cancel, nothing eaten. Refused items (potion on cooldown, full hp) never start.
   Keep holding = the next one starts after a pause `eat_gap` (same file) (0.5 s; no bob / crumbs in the gap; release resets it).
   Sounds: a chew (`ItemData.use_sound`, `eat`; potions `drink`) every `eat_sound_every` (0.25 s) while eating, then one `gulp` when an item is used. You walk x0.5 slower while eating (`eat_move_mult`) and the body does not turn.
   The item and both hands bob 3 px, 5 times a second; tiny crumbs in the item's colours fly off (`EatCrumbs`).
6. **Stacking (Minecraft rule).** One effect of each kind at a time.
   - New effect is **stronger**: it replaces the old one.
   - **Same strength**: the timer becomes the longer of the two (not added).
   - **Weaker** while a stronger one runs: refused, the item is **not** used (no waste).
   - Same strength but **shorter** than the time left: nothing would change, so refused too (item not used).
   - Strength = the Regen level (I = 0.5 HP/s, II = 1 HP/s; was 1 / 2, playtest 2026-11-20: too fast), not the food. Bread and sausage are both Regen I, so they count as the same.
   - Example: bread Regen running (6 s left), you eat bread again: timer back to 10 s. Not 16 s. Eating 5 bread at once does not heal 5 times more.
   - Different kinds run together: Regen + Sick at the same time is fine.
7. **Efficiency.** Total heal per item = rate x time. Food heals slowly (good between fights), the potion heals at once (good in a fight).
   Spamming food does not add up (rule 6), so a stack of bread is not a stack of potions.
8. **Never at full HP:** Regen food at full HP is refused (nothing used). Raw food is never refused (it is your choice).
9. **Boss fights:** allowed. The bag is locked, the hotbar works. Note: design-pillars §2 says HP does not regenerate; food Regen is a small, timed exception. Tune it down if fights get too easy.
10. **Death / respawn:** all effects end. **Save:** effects are saved with their time left.
11. **Key** stays a plain item, unused.

## Example
You have 40/100 HP after mining. You eat cooked pork: Regen II, 1 HP/s for 20 s, so 60 HP. You eat a second cooked pork 3 s later:
same strength, timer back to 20 s (not 37 s). In the boss fight you drop to 20 HP: you drink the potion, +50 at once, then 30 s cooldown.
Hungry and nothing cooked? Raw pork: +5 HP over 10 s, but Sick: slower for 15 s.

## Tuning (all `@export` / item data, F3; starting values, tune)
| Item | Effect | Rate | Time | Total |
|---|---|---|---|---|
| Raw pork | Regen I + Sick (-20% speed) | 0.5 HP/s | 10 s (Sick 15 s) | 5 HP |
| Bread | Regen I | 0.5 HP/s | 20 s | 10 HP |
| Sausage | Regen I | 0.5 HP/s | 30 s | 15 HP |
| Cooked pork | Regen II | 1 HP/s | 20 s | 20 HP |
| Soup | Regen II | 1 HP/s | 30 s | 30 HP |
| Healing potion | instant | — | — | 50 HP, then 30 s cooldown |

Other numbers: `sick_speed_mult` 0.8, `blink_time` 3 s (icon blinks before it ends), `potion_cooldown` 30 s.

## Replacing the eating art / sounds
Everything below is data or one small node. No combat code changes.
- **Sounds:** replace `assets/game/audio/eat_chew.wav`, `drink_sip.wav`, `eat_gulp.wav` (same file name), or point the cues `data/sounds/cues/player_eat.tres`, `player_drink.tres`, `player_gulp.tres` at new files.
- **Timings** (`eat_time`, `eat_gap`, `eat_sound_every`, `eat_move_mult`): `data/food/eating.tres` (`EatingData`). Stretch the art to these, never the other way.
- **Crumbs:** set `crumb_texture` in `data/food/eating.tres`. Empty = small squares in the food's colours. Or replace the `EatCrumbs` node: it only reads `Consumer.is_eating()` and the `HeldItem` position and picture. Nothing reaches into it.
- **Pose and bob** (item in front of the chest, hands, up-down bob while eating): `data/held_item/chest_hold.tres` (`ChestHoldData`).
- **Body "eat" animation (not built):** the body visual would read `Consumer.is_eating()` and play it. Same signal the bob and crumbs use.
- F3 sections `ChestHold` and `Eating` show these files; "Write to .tres" keeps your tuning.

## HUD
A row of effect icons (one per active effect, timer under it), near the HP bar. Raw-food Sick in a red frame, good effects in a normal frame.
Designed in the web mockup first, shown to you before it is built. The food bar from v1 is removed; its place waits for mana.

## Test mode
- **F3:** Effects row: each active effect, strength, time left. Consumer row: potion cooldown, last refusal.
- **F3 buttons:** "Give Regen", "Give Sick", "Clear effects".
- **Test yard:** a stack of each food and potions (kept from v1).

## What v1 code is kept / removed
- Kept: `Consumer` (hold to eat / drink, one item used, refusals), potion + cooldown + slot sweep, test-yard food, save hook.
- Removed: `Hunger` node, food bar, starving, `food_value`.

## Later (not in this design)
Mana bar (own page: what uses mana?), cooking raw pork at the furnace, more effects (speed, damage, shield).
