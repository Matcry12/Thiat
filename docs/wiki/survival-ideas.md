# Survival + enemy ideas (to review, not decided)

Proposed 2026-10-23. Nothing here is built or decided; pick items, then each becomes a slice + decision record.
Rule they follow: the world exists to prepare for the boss in a 20-30 min run ([v1-design](v1-design.md), [design-pillars](design-pillars.md)).

## 1. Survival features

### Best fits (give the big map a purpose)
| # | Feature | What it is | Why it works | Uses what we have |
|---|---|---|---|---|
| 1 | **Enemies per biome** | Slimes in forest, tougher enemies in rocky/snow, guards near the boss | An empty map has nothing to do; enemies make walking somewhere a choice with risk, and their drops feed crafting. Already planned (W5, W10) | Combat, knockback, hit feel, biomes |
| 2 | **Healing from nature** | Berries from bushes, mushrooms + flowers brewed into a healing potion | Bushes, mushrooms and flowers are on the map but only decoration; this gives them a use. A healing potion is already in the design (30 s cooldown) | Vegetation passes, crafting, hotbar |
| 3 | **Campfire = respawn + heal point** | Rest at the campfire to heal; you wake there after death | A "safe base" feeling and a reason to come home; ties into death (W6) | Campfire art in the pack, home point |
| 4 | **Death drop bag** | Die -> lose ~50% of each material stack in a bag at the death spot; walk back to get it | Death costs something but stays cheap to retry (Terraria lesson: hard fights need fast retry). Already planned (W6) | Pickups, home |
| 5 | **A special resource per biome** | Copper in rocky hills, pine wood in taiga, reeds (arrows) in swamp, something in snow | Each biome gets a reason to visit; crafting grows without grind | Biomes, gathering, crafting |

### Good, later
| Feature | What it is | Why later |
|---|---|---|
| Chest storage | A placeable box | Useful once there are many item types |
| Armor | Defense gear | Planned for v2; needs the damage rule (flat defense) first |
| Cold in snow | Slow health loss in snow unless you wear warm gear | Gates the boss's snowy land behind gear; fits "difficulty = new rules, not bigger numbers" |
| Fishing | Fish in lakes/rivers for food | Water exists now, but the pack has no fishing art |

### Skip
| Feature | Why |
|---|---|
| Hunger / thirst | Chores in a 20-30 min run; no fun added before the boss |
| Day / night | Big work, nothing gained for the boss fight |
| Farming | Too slow for the run length |

**Suggested next slice:** #1 + #2 + #3 together (something to fight, something to heal from, somewhere to return to).

## 2. Enemy spawning (Minecraft "where" + Terraria "danger")

### Where (natural)
| Rule | What it is | Why it works | From |
|---|---|---|---|
| Biome spawn lists | Each biome has its own enemy list with weights; rare kinds get low weight | Enemies match the place, so the world reads as one ecosystem | Minecraft biome spawn tables |
| Packs | 1-4 enemies spawn around one point | Groups look like animals living together, not random dots | Minecraft pack spawning |
| Never in view | Spawn just outside the screen (between screen edge and loaded chunks) | You never see an enemy pop in | Terraria off-screen spawning |
| Cap near the player | Max ~8 enemies near you (slider), also per type | Keeps fights readable and performance steady | Minecraft mob cap |
| Despawn when far | Far, not-fighting enemies disappear; never mid-fight | The world refreshes as you travel; no pile-up | Minecraft despawn |
| Safe places | No spawns near home, campfire, or your stations | Your base feels safe; you can craft in peace | Terraria towns lower spawns |
| Dens | Some enemies live at fixed spots (wolf den, slime pond) and don't respawn constantly | Feels hand-made; a landmark to find and clear | Set pieces (Don't Starve, Terraria) |

### Danger
| Rule | What it is | Why it works |
|---|---|---|
| Danger grows with distance / biome | Home = easy slimes; forest, taiga = medium; rocky, snow = strong; boss land = guards | The map itself tells you how far you are ready to go (Terraria biome tiers) |
| Elites | ~5% of spawns: bigger, more HP and one extra move | Surprise danger without inflating every enemy; "new move, not bigger numbers" |
| Mini-boss at landmarks | One tough enemy guarding a den, copper vein or chest | A goal worth the detour; practice for the boss |
| Biome = warning | Danger is readable from the biome | Going into snow early is the player's choice and risk |

### Test mode (ships with it)
- F1: spawn ring, safe zones, den areas.
- F3: count per type vs cap, spawn rate / pack / elite sliders; buttons "Spawn pack here", "Spawn elite".

Next step if chosen: a decision record + a $0 picture of one island with packs, dens and safe zones, before W5.
