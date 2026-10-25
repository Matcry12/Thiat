# Biome blending, rivers, lakes, "big world" research (Minecraft 1.18+, older MC, 2D practice)

Verified = read in a fetched source this session. "Unverified" = from memory / not confirmed. Our unit: 1 cell ~ 1 MC block for scale talk; screen = 36x21 cells; island 200x120 = ~5.6 x 5.7 screens.

## 1. MC 1.18+ multi-noise biome source
- 6 params per spot: temperature, humidity, continentalness, erosion, weirdness (PV = folded weirdness), depth. Only depth uses height; other 5 depend on x,z only. Temperature 5 levels, humidity 5, erosion 7, PV 5. If a point falls in no biome interval, the CLOSEST biome is used (nearest in parameter space). https://minecraft.wiki/w/World_generation
- Biome = lookup: continentalness+erosion(+PV) choose a band (ocean/coast/inland/peaks), then temperature+humidity pick the biome inside it (author's reading, "oversimplification"): https://dawnosaur.substack.com/p/how-minecraft-generates-worlds-you
- Why neighbours are compatible: all 5 params come from smooth noise, so they change gradually; a spot between two biomes has in-between params, so it lands in a table cell that is adjacent in temperature/humidity. No desert beside snow: temp goes 0..4 through steps, the middle step is always crossed. (Inference from the above; MC wiki says the same for oceans: frozen ocean only by snowy land, warm ocean only by desert/badlands: https://minecraft.wiki/w/Java_Edition_1.18)
- Noise data (verified, misode/mcmeta `data` branch, https://github.com/misode/mcmeta/tree/data/data/minecraft/worldgen/noise ): first_octave (base_octave) and octaves:
  | noise | first octave | octaves | amplitudes |
  |---|---|---|---|
  | temperature | -10 | 6 | 1.5, 0, 1, 0... |
  | vegetation (humidity) | -8 | 6 | 1, 1, 0... |
  | continentalness | -9 | 9 | 1,1,2,2,2,1,1,1,1 |
  | erosion | -9 | 5 | 1,1,0,1,1 |
  | ridge (weirdness) | -7 | 6 | 1,2,1,0... |
  | temperature_large (Large Biomes) | -12 | 6 | same |
  Router samples them with `xz_scale` 0.25 (density_function/overworld/continents.json, erosion.json, ridges.json) and domain shift `shift_x/shift_z` (domain warp). Octave -9 = wavelength 2^9 = 512 noise units, /0.25 = ~2048 blocks for the biggest wave (my calc). Temperature -10 => ~4096; humidity -8 => ~1024; ridge -7 => ~512. So: temperature changes slowest, humidity faster, so climate zones are huge and humidity patches are mid size. Large Biomes = 4x bigger (-12 vs -10).
- Level cut points (continentalness -1.05 mushroom, -0.455 ocean, -0.19 coast, -0.11 near-inland, 0.03 mid, 0.3 far; temperature -0.45/-0.15/0.2/0.55; humidity -0.35/-0.1/0.1/0.3): UNVERIFIED, from decompiled OverworldBiomeBuilder. Class listing: https://nekoyue.github.io/ForgeJavaDocs-NG/javadoc/1.20.6-neoforge/net/minecraft/world/level/biome/OverworldBiomeBuilder.html (no values shown).
- Talks: Kniberg, "Reinventing Minecraft world generation" https://www.youtube.com/watch?v=ob3VwY4JyzE ; "Minecraft terrain generation in a nutshell" https://www.youtube.com/watch?v=OROPAKsqzRs ; Mojang "Dev Diaries: World Generation" https://www.youtube.com/watch?v=yAEw1lJrsL4 . (Not watched/transcribed; only titles/descriptions seen.)

## 2. Rivers, lakes, beaches (1.18+)
- Rivers: "generate in the deepest part of valleys when PV values are at their lowest" (PV = folded weirdness: `-3*(|(|ridge|-0.6667)|-0.3333)`, verified in density_function/overworld/ridges_folded.json). I.e. a river is the zero-crossing line of a noise = a thin band where |ridge noise| is small: abs(noise) < w. Only in "valleys" PV with low continentalness or high erosion. Base river climate temp 0.5, downfall 0.5. Frozen River where temperature level 0. Rivers separate biomes of positive and negative weirdness. Low erosion inland can end a river abruptly; high erosion inland can leave it dry; near the coast, flat rivers are wide. https://minecraft.wiki/w/River , https://minecraft.wiki/w/World_generation
- Natural look comes from: ridge noise has ~512-unit waves plus octaves (kinks), domain shift, and terrain height is carved so the river sits in a real valley. Width/depth numbers: none published on the wiki.
- Beaches: low coastal land only; picked by temperature alone: Snowy Beach at 0, Beach at 1-3, none (desert) at 4. Oceans follow land temperature. https://minecraft.wiki/w/World_generation
- Lakes: not a separate system on the wiki. Water below Y=62 fills terrain dips; aquifers (cells 16x40x16 water-level, 64x40x64 water-or-lava) matter only for caves. Swamps blend with rivers (snapshot 5). https://minecraft.wiki/w/River

## 3. Pre-1.18 layers (2D friendly)
Verified https://minecraft.wiki/w/Biome/Before_1.18 : start 1:4096 mostly ocean + few islands; zoom x2 with random/"fuzzy" edges and "smooth" passes down to 1:1024 (land ~50%), 1:256 (climate zones assigned: 1 in 13 land areas "special"), 1:64, 1:4, 1:1. Ratios after early stage: ocean 31%, dry 13%, medium 22%, cold 23%, frozen 6%, rare 4%. Rivers: separate stack seeded from random noise, zoomed 4 times, merged at 1:4; river = edge where neighbouring noise values differ (not in ocean). Shore/beach layer added after a jagged-coast pass. Zoom+edge rule is pure integer grid logic: easy in GDScript, no float noise needed.

## 4. 2D techniques compared
| Technique | Pros | Cons |
|---|---|---|
| Whittaker (temp x moisture lookup; Red Blob uses elevation x moisture, cuts moisture 0.16/0.33/0.5/0.66/0.83, ocean <0.1, beach <0.12) https://www.redblobgames.com/maps/terrain-from-noise/ | trivial, tunable table, MC does same idea | needs 2 smooth noises or hard edges show up |
| Domain warp (FastNoiseLite `domain_warp_*`, default amplitude 30, freq 0.05) https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html | borders stop looking like noise blobs; built into Godot | warp too high = swirls |
| Ridge-noise rivers `abs(n)<w` (Red Blob ridged: `2*(0.5-abs(0.5-n))`) | 1 line, no sim, branch-free, always continuous, any chunk order | no tributaries, no direction; rivers can end nowhere unless masked; lakes not linked |
| Downhill flow on heightmap (mapgen4: rainfall -> flow; lg_min_flow = more small streams) https://www.redblobgames.com/maps/mapgen4/ ; Patel polygon map https://www-cs-students.stanford.edu/~amitp/game-programming/polygon-map-generation/ (page unreachable here; fetched only via Red Blob link) | real tributaries, rivers reach sea, lakes = filled pits | whole-map pass, needs finite map (fine for 200x120+), more code |
| Lakes: threshold noise below sea level / pits filled | cheap | random puddles unless tied to rivers |
| Mapgen2 note: biomes "based on distance to coastline and distance to water" https://www.redblobgames.com/maps/mapgen2/ | water makes land wetter => coherent | needs distance field |

## 5. "Feels big" in 2D
- Terraria: small 4200x1200, medium 6400x1800, large 8400x2400 tiles https://terraria.wiki.gg/wiki/World_size . Core Keeper: biomes in rings around the Core, first ring (dirt) to ~150 units, "biome chaos" setting lets same-ring biomes overlap https://core-keeper.fandom.com/wiki/World (page blocked; via search snippets only, low confidence). Don't Starve: Voronoi rooms from a task graph; 5 random set pieces per normal world, loop 50% chance, rooms get 0-2 background rooms https://dontstarve.wiki.gg/wiki/World_Generation (no tile size given).
- No source gives "screens" or POI-per-screen numbers; I found none. Don't invent: pick by playtest.
- Pattern across them: rings/graph of distinct areas + landmarks, not size alone.

## 6. Godot practicality
- TileMapLayer: rendering_quadrant_size 16 (16x16 tiles per canvas item), physics_quadrant_size 16 merges colliders; updates batched per frame; runtime tile-data updates are costly; coords are int16 (-32768..32767). https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html
- MultiMeshInstance2D: faster than many Sprite2D with large transparent areas; no per-instance culling, so split into several MultiMeshes per region; docs say individual objects fine into the "thousands", MultiMesh for "hundreds of thousands or millions". https://docs.godotengine.org/en/stable/classes/class_multimeshinstance2d.html , https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html
- No official number for StaticBody2D count. Practice (unverified): bake tree collision into tile/merged shapes or spawn bodies only in loaded chunks.

## What to copy for us
1. Climate = 2 slow noises (temperature, humidity) -> Whittaker table; temperature slowest (MC -10 vs -8 first octave = 4x). https://github.com/misode/mcmeta/tree/data/data/minecraft/worldgen/noise
2. Add continentalness-like "inland" noise (or our distance from coast) to gate beach/ocean/inland. https://minecraft.wiki/w/World_generation
3. Nearest-point lookup instead of if-chains: list biome points in (temp, humid, inland), pick min distance. Neighbours stay compatible. https://minecraft.wiki/w/World_generation
4. Domain-warp all climate sampling (FastNoiseLite warp). https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html
5. Rivers: abs(ridge noise)<w, ridge wavelength ~16x biggest-climate/ ~1/4 of it, low-frequency (MC ridge -7 is 4x finer than continents). https://github.com/misode/mcmeta/tree/data/data/minecraft/worldgen/noise
6. Rivers only where inland value in a band (low continentalness or high "erosion") so they end at coast/ocean and fade on high ground. https://minecraft.wiki/w/River
7. Frozen river = same river, tinted by temperature 0. https://minecraft.wiki/w/River
8. Beach by temperature: sand beach warm/mid, snowy beach cold, none for desert. https://minecraft.wiki/w/World_generation
9. Swamp where river meets wet lowland (rivers merge into swamps). https://minecraft.wiki/w/River
10. Lakes: low-inland + high-humidity pits, or widen river noise where a second noise peaks (lake = river band with bigger w). Alt: fill pits of a heightmap (Red Blob). https://www.redblobgames.com/maps/mapgen4/
11. Layer-style integer zoom/smooth if we want chunky tile-shaped biome borders and cheap rivers via edge detection. https://minecraft.wiki/w/Biome/Before_1.18
12. Keep distance-ring difficulty (forest/rocky/boss) and add set-piece landmarks per area (Don't Starve, Core Keeper). https://dontstarve.wiki.gg/wiki/World_Generation

## What does not port to 2D
- 3D density terrain, splines, depth parameter, caves/aquifers: no height axis for us.
- Rivers carving real valleys: we have no elevation unless we add a heightmap; the "natural" look partly comes from the carved valley.
- Weirdness variants (ice spikes etc.) and 7-level erosion tables: need a lot of art; use 3-5 levels.
- MC blocks are 1 m, view is ~100+ blocks; our screen is 36x21 cells, so MC biome sizes (hundreds of blocks) mean tens of screens. Scale to our island, do not copy raw frequencies.
- Large Biomes-style 2048-4096 cell waves exceed our 200x120 island; use ~40-120 cells for temperature, ~20-50 for humidity, ~15-30 for rivers (my guess, tune with F3).
- Unverified/missing: exact MC threshold tables, Kniberg talk contents, river widths, Patel's page (connection refused), Core Keeper size, any StaticBody2D benchmark.
