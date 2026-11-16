# Big world plan (draft, not built)

**Status:** Done plan (built in decisions 0026, 0037, 0038), kept for history

Goal (user): a world like Minecraft — biomes blend naturally, it feels big and worth exploring, with rivers, lakes and more.
Research: [worldgen-biomes-water-research.md](../reference/worldgen-biomes-water-research.md),
[worldgen-vegetation-research.md](../reference/worldgen-vegetation-research.md). Demo: `tools/asset_viewer/world_preview.py`
-> `docs/demo/world_*.png`. Keeps the agreed Plains/Forest look ([0037](../decision/0037-plains-forest-vegetation.md)).

## 1. How Minecraft makes biomes feel natural (what we copy)
| Idea | What it means | Why it works | Source |
|---|---|---|---|
| Climate maps, not painted regions | 4-5 smooth noise maps (temperature, humidity, continentalness = land/sea, erosion = flat/rough, weirdness) cover the world | A smooth map can't jump: hot never sits next to cold, so neighbours always "fit" | [MC wiki: World generation](https://minecraft.wiki/w/World_generation), [noise data](https://github.com/misode/mcmeta/tree/data/data/minecraft/worldgen/noise) |
| Biome = nearest point in a table | Each cell reads its climate values and takes the closest biome in a small table (e.g. cold+wet = taiga) | Biome order follows climate order, like real Earth (Whittaker diagram) | [OverworldBiomeBuilder](https://nekoyue.github.io/ForgeJavaDocs-NG/javadoc/1.20.6-neoforge/net/minecraft/world/level/biome/OverworldBiomeBuilder.html), [Red Blob: terrain from noise](https://www.redblobgames.com/maps/terrain-from-noise/) |
| Temperature is the slowest map | Its biggest wave is ~4096 blocks, land/sea ~2048 | Big climate zones = long walks through one feeling, then a slow change | [noise data](https://github.com/misode/mcmeta/tree/data/data/minecraft/worldgen/noise) |
| Domain warp | Bend the noise coordinates with another noise | Borders wiggle like coastlines instead of round blobs | [Godot FastNoiseLite](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html) (built in) |
| Rivers = thin band of a ridge noise | River where \|noise\| < width, only inland | One line of code gives long winding rivers that never end in a dead end mid-land | [MC wiki: River](https://minecraft.wiki/w/River), [Java 1.18](https://minecraft.wiki/w/Java_Edition_1.18) |
| Beaches by temperature, frozen rivers when cold | Shore = sand if warm, stone if cold | Water edges match the climate around them | [MC wiki: World generation](https://minecraft.wiki/w/World_generation) |
| Lakes = water in dips; swamps where rivers meet wet lowland | Low pockets fill with water | Water sits where it "would flow" | [Red Blob mapgen4](https://www.redblobgames.com/maps/mapgen4/) |
| Vegetation by density per biome | Already built (0037) | Plains ~200x sparser than forest | [vegetation research](../reference/worldgen-vegetation-research.md) |

## 2. Our biomes (only ones we have Pixel Crawler art for)
Plains, Forest (built) -> Autumn forest (yellow/orange oak, red pine), Taiga (fir + pine), Snowy taiga (snow trees),
Rocky hills (rocks, dead trees), Swamp (dark grass, reeds, dead trees), Beach, River, Lake, Ocean.
Boss area = a far set place in a rocky/cold biome; home = a Plains/Forest start.

## 3. "Feels big" — numbers
- Player walks 260 px/s = ~8 cells/s. Today's island (200x120 cells) is ~25 s across.
- Target first world: 512x512 cells (~350 screens), ~1 min straight across, much longer with trees, rivers and detours.
  Biome zones of ~100-150 cells = ~15 s of walking each, then a new feeling. (Minecraft: ~1-2 min per biome.)
- Reference sizes: Terraria small world 4200x1200 tiles ([wiki](https://terraria.wiki.gg/wiki/World_size));
  Don't Starve: a graph of rooms + 5 set pieces per world ([wiki](https://dontstarve.wiki.gg/wiki/World_Generation)).
- Exploration needs things to find: a few set places (ruins, camps, the boss site) spread across biomes. No source gives
  "points per screen", so tune by playtest.

## 4. Why we must change how the map is built
512x512 = 262k cells. With 0037 density that is thousands of trees + tens of thousands of plants. Today every tree is
a node and the ground is one baked picture — fine for 200x120, too much for 512x512.
- **Chunks**: split the world into 32x32-cell chunks; only chunks near the player get nodes (trees, rocks) and plants.
  Same seed -> same chunk, so leaving and coming back looks identical (store chopped trees per chunk).
- **Ground** per chunk (baked image or TileMapLayer, 16x16 quadrants: [Godot TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html)).
- **Plants** as one MultiMesh per chunk (no per-instance culling, so per chunk: [Godot MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)).

## 5. Build steps (each playable, each judged)
1. Climate + biome map (no art change): noise layers, biome lookup, F3 map view, biome under the player.
2. Chunks: generate and stream ground + existing Plains/Forest per chunk; bigger world size.
3. Water: ocean shore, rivers, lakes, beaches. Rivers block walking except at shallow fords (decision for the user).
4. New biomes one at a time (Taiga, Autumn, Snowy, Rocky, Swamp), each with a preview picture first.
5. Set places: home, boss site far away, a few landmarks.

## 6. Open questions for the user
- Rivers: walls you cross at fords / bridges, or shallow water you can wade through slowly?
- World size: 512x512 first, bigger later?
- Is the world still an island (ocean all around), or a continent with an edge?
