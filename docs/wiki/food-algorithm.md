# Food algorithm

**Status:** Current (approved 2026-11-20, decision [0071](../decision/0071-hunger-and-potion.md))

How hunger, eating and the healing potion work. A **temporary first design**: small, so we can feel it and change it.
Code (planned): `scripts/components/hunger.gd` (the food bar), `scripts/components/consumer.gd` (eat / drink), `scripts/ui/food_bar.gd` (HUD).
Built from how Minecraft, Terraria and Don't Starve do it, not guessed.

Note: [backlog.md](backlog.md) says "hunger skipped by choice" and [v1-design.md](v1-design.md) §10 lists hunger as out of v1.
This page changes that. When it is approved, a decision record (0071) says so and both pages are updated.

## Sources
| Rule | Minecraft | Terraria | Don't Starve |
|---|---|---|---|
| Food bar | 20 points (10 drumsticks) + hidden "saturation" buffer | No hunger. Food gives a "Well Fed" buff (small stat bonus, minutes long) | 150 points |
| Drains | Through "exhaustion": running, jumping, fighting, healing | — | Steady 75 per day (8 min day): empty in ~16 min |
| Empty bar | Lose 1 HP every 4 s. Easy: stops at 10 HP, Normal: stops at 1 HP, Hard: can kill | — | Lose ~1 HP/s, can kill |
| Full bar | HP regenerates (that is where most healing comes from) | — | Nothing extra |
| Eating | Hold use 1.6 s. Refused when the bar is full | Instant | Instant |
| Food values | Raw pork 3, bread 5, stew 6, cooked pork 8. Cooked ≈ 2-3x raw | Better food = longer, stronger buff | Raw meat 25 (hurts sanity), cooked meat 25 (+1 HP). Cooking makes it safe, not bigger |
| Healing potion | (Potion of Healing: +4 HP, instant) | Lesser 50 HP, normal 100 HP, instant. Then "Potion Sickness": no healing potion for 60 s | Healing items (salve 20 HP), no cooldown |
| On respawn | Food bar full | — | Half |

## Our rules
1. **One food bar, one owner.** A `Hunger` node on the player holds `food` (0..`max_food`). Nothing else changes it.
2. **Steady drain (Don't Starve)**, not Minecraft's exhaustion: `food` goes down by `drain_per_min` every real minute of play.
   Easy to read: "a full bar lasts 10 minutes". A 20-30 min run needs 2-3 meals.
   It does not drain while paused, in menus, or in headless tests (like the day clock).
3. **Empty bar = starving (Minecraft Normal).** At 0 you lose `starve_damage` HP every `starve_interval` s, but it **stops at 1 HP**.
   Hunger alone never kills you; it makes the next hit dangerous. The HP bar's "low" pulse shows it.
   Damage goes straight to HP, not through the shield or armor (it is not a hit: no hit flash, no knockback).
4. **No regeneration from a full bar.** Our design says HP does not regenerate (design-pillars §2: only the shield does).
   Food is not a healer. The potion is.
5. **Eating.** Select food on the hotbar, press the attack click. One item is used, `food` goes up by the item's `food_value` (capped at max).
   Instant (Terraria, Don't Starve), no eat animation in this slice. Refused when the bar is full (Minecraft): nothing is used.
6. **Healing potion.** Same click. Heals `heal_value` HP at once (capped at max HP). Then a personal cooldown of
   `potion_cooldown` s (Terraria's potion sickness; our design-pillars §2 already says 30 s). Refused at full HP or during the cooldown.
   The cooldown shows on the HUD (a dark sweep over the potion's hotbar slot), as design-pillars §2 asks for every cooldown.
7. **Allowed in boss fights.** The bag is locked in a fight, but the hotbar works. Bring food and potions in the hotbar.
8. **Item data decides.** `ItemData` gets `food_value` and `heal_value` (0 = not food / not a potion). A new food is a new `.tres`, no code.
   Raw pork gives less than cooked pork (Minecraft), so cooking is worth it later (cooking at the furnace is a later slice).
9. **Respawn = full bar (Minecraft).** Death already costs you; starving again right away would be a death spiral.
10. **Save.** `food` is saved with HP in `user://save.json` (old saves load with a full bar).
11. **Key** stays a plain item, unused.

## Example
You start with a full food bar (100). After 5 minutes of mining it is at 50. You eat bread (+25): 75.
You forget to eat. 10 minutes later it is 0: every 4 s you lose 1 HP, the HP bar turns red and pulses, but you never drop below 1 HP.
A slime hits you for 10 and you have 6 HP left. You drink the healing potion: +50 HP, then 30 s before the next one works.

## Tuning (all `@export`, F3; starting values, tune)
| Number | Start value | Where |
|---|---|---|
| `max_food` | 100 | Hunger |
| `drain_per_min` | 10 (full bar lasts 10 min) | Hunger |
| `starve_damage` | 1 HP | Hunger |
| `starve_interval` | 4 s | Hunger |
| `starve_floor` | 1 HP (never kills) | Hunger |
| `start_food` | 100 | Hunger |
| `potion_cooldown` | 30 s | Consumer |
| bread `food_value` | 25 | `data/items/bread.tres` |
| raw pork | 10 | `raw_pork.tres` |
| cooked pork | 35 | `cooked_pork.tres` |
| sausage | 20 | `sausage.tres` |
| soup | 40 | `soup.tres` |
| healing potion `heal_value` | 50 HP (half of 100) | `healing_potion.tres` |

## Test mode
- **F3:** Hunger row: `food`, `drain_per_min`, starving yes/no, time to next starve tick. Consumer row: potion cooldown left, last refusal ("full", "cooldown").
- **F3 buttons:** "Hunger empty" (food = 0, starving starts) and "Hunger full".
- **Test yard:** a stack of each food and potions on the ground.
- [debug-keys.md](debug-keys.md) gets the new rows and buttons.

## HUD
A food bar under the HP bar, bottom left, same Island Workshop style (rope frame), orange-brown fill, a drumstick/bread icon instead of the heart.
Designed in the web mockup (`tools/ui_mock/`) first and shown to you as a picture before it is built.

## Later (not in this slice)
Eat time + animation, cooking raw pork at the furnace, Terraria-style "Well Fed" buff from good food, food that heals a little (Don't Starve), faster drain while running.
