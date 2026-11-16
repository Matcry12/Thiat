# docs - map

Made by `tools/docs_index.py` - do not edit by hand, run the script.
Start at the root [README.md](../README.md) and [AGENTS.md](../AGENTS.md).

| Where | What |
|---|---|
| [wiki/](wiki/) | How things work now, plans, backlog. Check each page's Status line |
| [decision/](decision/) | Why things are built this way. A newer record can replace an older one: check Status |
| [design/DESIGN.md](design/DESIGN.md) | UI style ("Island Workshop") |
| [reference/](reference/) | Outside research (other games, Godot notes, world gen). Read instead of re-researching |
| [superpowers/plans/](superpowers/plans/) | Old step-by-step build plans (done) |
| [demo/](demo/) | Videos and screenshots, not docs |

## Wiki

| Page | Title | Status |
|---|---|---|
| [3d-character-pipeline](wiki/3d-character-pipeline.md) | 3D character pipeline (player body) | Outdated: the player now uses `data/body_rigs/pixel_plains.tres` (Pixel Plains 2D frames, 0054); 3D frames retired, blocky rig is dev-only (`data/dev/`) |
| [add-a-weapon-picture](wiki/add-a-weapon-picture.md) | Add a weapon picture | Current |
| [artist-art-status](wiki/artist-art-status.md) | Artist art - what we have, where it goes | Current |
| [backlog](wiki/backlog.md) | Backlog | Backlog |
| [credits](wiki/credits.md) | Credits | Current |
| [day-night-algorithm](wiki/day-night-algorithm.md) | Day / night algorithm | Current |
| [debug-keys](wiki/debug-keys.md) | Debug keys and test mode (F1 / F2 / F3) | Current |
| [design-pillars](wiki/design-pillars.md) | BossFight — Design Pillars | Current |
| [enemy-spawning-algorithm](wiki/enemy-spawning-algorithm.md) | Enemy spawning algorithm | Current |
| [ground-tiles](wiki/ground-tiles.md) | Ground tiles — Pixel Crawler, tagged | Outdated: tags Pixel Crawler ground sheets, but the map now uses Pixel Plains, see [../../assets/game/map/pixel_plains/README.md](wiki/../../assets/game/map/pixel_plains/README.md) |
| [ground-tileset-algorithm](wiki/ground-tileset-algorithm.md) | Ground tile-set algorithm | Done plan (built in decision 0069, ground tile set), kept for history |
| [hit-feel-plan](wiki/hit-feel-plan.md) | Hit feel plan | Done plan (built in HitFx slices, decisions 0057 and later), kept for history |
| [how-to-tune](wiki/how-to-tune.md) | How to change the numbers yourself | Current |
| [ideas](wiki/ideas.md) | Ideas backlog | Merged into [backlog.md](wiki/backlog.md) on 2026-11-16. |
| [item-icons](wiki/item-icons.md) | Item icons (temporary art + template) | Current |
| [learning-godot-with-ai](wiki/learning-godot-with-ai.md) | Learning Godot to build with AI (not blind coding) | Personal notes, not project rules |
| [pixel-plains-art-todo](wiki/pixel-plains-art-todo.md) | Pixel Plains — art you need to draw | Merged into [backlog.md](wiki/backlog.md) on 2026-11-16. |
| [pixel-plains-research](wiki/pixel-plains-research.md) | Pixel Plains — research notes | Current |
| [playtest-todo](wiki/playtest-todo.md) | Playtest to-do | Merged into [backlog.md](wiki/backlog.md) on 2026-11-16. |
| [project-status](wiki/project-status.md) | Project status and problems (2026-11-16) | Current |
| [prototype-v0](wiki/prototype-v0.md) | Prototype v0 — Combat Scratch Build | Done plan (v0 slices built, see v1-design), kept for history |
| [replacing-art](wiki/replacing-art.md) | Replacing art — the 3 steps | Outdated: swaps a single Body Texture on the player Visual node, but bodies now use BodyRig frames, the player rig is `data/body_rigs/pixel_plains.tres` |
| [sound-algorithm](wiki/sound-algorithm.md) | Sound algorithm | Current |
| [survival-ideas](wiki/survival-ideas.md) | Survival + enemy ideas (to review, not decided) | Merged into [backlog.md](wiki/backlog.md) on 2026-11-16. |
| [testing-algorithm](wiki/testing-algorithm.md) | Testing algorithm: how we keep tests fast and still catch bugs | Current |
| [v1-design](wiki/v1-design.md) | BossFight v1 — design | Current |
| [vegetation-rules](wiki/vegetation-rules.md) | Vegetation rules (built, per biome) | Current |
| [world-gen-plan](wiki/world-gen-plan.md) | Big world plan (draft, not built) | Done plan (built in decisions 0026, 0037, 0038), kept for history |

## Decisions

| # | Decision | Status |
|---|---|---|
| [0001](decision/0001-design-reference-games.md) | Reference games for combat design | Active |
| [0002](decision/0002-pc-first.md) | PC first, mobile deferred | Active |
| [0003](decision/0003-loadout-and-swapping.md) | Loadout, hotbar and weapon swapping | Partly superseded by [0058](decision/0058-free-weapon-swap-no-weapon-limit.md) (weapon limit, swap cost) |
| [0004](decision/0004-dodge.md) | Dodge is baseline, cooldown-gated | Active |
| [0005](decision/0005-architecture.md) | Prototype architecture: data-driven, composed, swappable brain | Active |
| [0006](decision/0006-controls-and-parry.md) | Controls, and parry as a distinct defensive option | Partly superseded by [0013](decision/0013-parry-and-block-on-one-key.md) (parry and block on one key) |
| [0007](decision/0007-working-agreement.md) | Working agreement: vertical slices, playtest-driven | Active |
| [0008](decision/0008-rl-inference.md) | RL inference: GDScript matmul, not ONNX/.NET | Active |
| [0009](decision/0009-perspective-2-5d.md) | Perspective is 2.5D top-down (Soul Knight), not flat overhead | Active |
| [0010](decision/0010-sprite-templates.md) | Placeholder art is real sprite files, not code drawing (the template) | Active |
| [0011](decision/0011-hitbox-lives-on-the-weapon.md) | The hit area lives on the weapon, not in numbers | Partly superseded by [0020](decision/0020-snap-swing-sweeps-the-arc.md) (snapping swing sweeps arc), [0061](decision/0061-weapon-hit-area-from-picture.md) (hit size from picture) |
| [0012](decision/0012-weapon-behaviours.md) | Weapon behaviours: a few motions, many weapons | Active |
| [0013](decision/0013-parry-and-block-on-one-key.md) | Parry and block share one key; the shield is an effect, not an item | Partly superseded by [0014](decision/0014-shield-is-a-bar-that-breaks.md) (block is a breaking bar), [0015](decision/0015-block-is-a-sword-pose.md) (block shown as sword pose) |
| [0014](decision/0014-shield-is-a-bar-that-breaks.md) | The shield is a bar that breaks, and damage is a shared pattern | Partly superseded by [0015](decision/0015-block-is-a-sword-pose.md) (block visual is a sword pose) |
| [0015](decision/0015-block-is-a-sword-pose.md) | Blocking is shown by a sword pose; the shield becomes a weapon later | Active |
| [0016](decision/0016-weapons-are-scenes-and-swap-is-gated.md) | Each weapon is its own scene; swapping is gated | Partly superseded by [0058](decision/0058-free-weapon-swap-no-weapon-limit.md) (swap is instant, no gate) |
| [0017](decision/0017-model-routing.md) | Which model does which job | Active |
| [0018](decision/0018-weapon-skills.md) | Weapon skills (the E key) | Active |
| [0019](decision/0019-boss-v0.md) | The v0 boss | Partly superseded by [0022](decision/0022-boss-leash.md) (enrage replaced by leash) |
| [0020](decision/0020-snap-swing-sweeps-the-arc.md) | A snapping swing sweeps the arc in one frame | Active |
| [0021](decision/0021-procedural-arena.md) | Procedural grass arena from a third-party tile pack | Active |
| [0022](decision/0022-boss-leash.md) | Boss aggro and leash (replaces the enrage rule) | Active |
| [0023](decision/0023-hit-feel.md) | Hit feel: effects listen, global hit-stop | Active |
| [0024](decision/0024-hud-top-right.md) | HUD top-right: life bar and hotbar (Terraria style) | Partly superseded by [0030](decision/0030-hud-layout-icons.md) (HUD placement), [0043](decision/0043-ui-island-workshop.md) (HUD look) |
| [0025](decision/0025-v1-open-world.md) | v1 is an open-world prepare-then-fight game | Active |
| [0026](decision/0026-island-generator.md) | Island generator (W1) | Active |
| [0027](decision/0027-gathering.md) | Gathering with bare hands (W2) | Active |
| [0028](decision/0028-3d-rendered-characters.md) | Characters: 3D-rendered body, 2D hands and weapons | Partly superseded by [0054](decision/0054-remove-tiny-rpg-art.md) (player body is Pixel Plains 2D frames) |
| [0029](decision/0029-inventory.md) | Inventory: slots, hotbar selection, tools | Partly superseded by [0058](decision/0058-free-weapon-swap-no-weapon-limit.md) (weapon limit, swap, wheel), [0031](decision/0031-crafting.md) (start kit), [0043](decision/0043-ui-island-workshop.md) (look) |
| [0030](decision/0030-hud-layout-icons.md) | HUD layout and icons instead of words | Partly superseded by [0043](decision/0043-ui-island-workshop.md) (no-words HUD rule) |
| [0031](decision/0031-crafting.md) | Crafting: instant recipes, placed stations, a timed furnace | Partly superseded by [0045](decision/0045-ui-port-craft-book.md) (crafting window UI), [0043](decision/0043-ui-island-workshop.md) (look) |
| [0032](decision/0032-temp-tiny-rpg-art.md) | Temporary art: Tiny RPG Soldier (player) and Orc (boss) | Superseded by [0054](decision/0054-remove-tiny-rpg-art.md) |
| [0033](decision/0033-map-visuals.md) | Map visuals: baked ground, real shore, paths (looks only) | Partly superseded by [0034](decision/0034-map-art-pixel-crawler-only.md) (grass_sv map style), [0035](decision/0035-dirt-needs-a-reason.md) (random dirt patches), [0069](decision/0069-ground-tile-set.md) (ground baker, edges, foam / water) |
| [0034](decision/0034-map-art-pixel-crawler-only.md) | Map art: Pixel Crawler only | Superseded: map art is now Pixel Plains ([0046](decision/0046-ground-levels-and-borders.md), [0069](decision/0069-ground-tile-set.md)); no single record covers the switch |
| [0035](decision/0035-dirt-needs-a-reason.md) | Dirt needs a reason | Active |
| [0036](decision/0036-minecraft-gathering.md) | Gathering follows Minecraft logic (on top of HP) | Active |
| [0037](decision/0037-plains-forest-vegetation.md) | Plains + Forest biomes, Minecraft-style vegetation placement | Active |
| [0038](decision/0038-climate-biomes-big-island.md) | Climate biomes on a 512x512 island, swimmable water | Active |
| [0039](decision/0039-death-respawn.md) | Death and respawn (W6) | Partly superseded by [0042](decision/0042-death-drops.md) (death bag) |
| [0040](decision/0040-game-frame.md) | Game frame: title, pause, settings (W8) | Partly superseded by [0043](decision/0043-ui-island-workshop.md) (placeholder look) |
| [0041](decision/0041-save-load.md) | Save / load (W9) | Partly superseded by [0042](decision/0042-death-drops.md) (death bags -> saved pickups) |
| [0042](decision/0042-death-drops.md) | Death drops instead of the death bag (W6) | Partly superseded by [0058](decision/0058-free-weapon-swap-no-weapon-limit.md) (no weapon limit, 3rd weapon rule gone) |
| [0043](decision/0043-ui-island-workshop.md) | UI style "Island Workshop" (supersedes the look parts of 0024/0030, placeholder look of 0029/0031/0040) | Active |
| [0044](decision/0044-f3-debug-contract.md) | F3 dock + "debug" group contract (supersedes the F3 layout parts of rule 7 / prototype-v0) | Active |
| [0045](decision/0045-ui-port-craft-book.md) | Island Workshop UI in the game; crafting book with a Craft button (supersedes the UI part of 0031) | Active |
| [0046](decision/0046-ground-levels-and-borders.md) | Ground levels: step vs flat borders, made from the pack's edge shapes | Superseded by [0047](decision/0047-ground-all-flat.md) (ground levels and step borders), [0069](decision/0069-ground-tile-set.md) (borders, bank, foam) |
| [0047](decision/0047-ground-all-flat.md) | Ground is all flat (supersedes the level part of 0046) | Partly superseded by [0069](decision/0069-ground-tile-set.md) (level exports and steps deleted, only all_flat left) |
| [0048](decision/0048-no-hands-held-item-icon.md) | No hands, held item icon, bare hands gather nothing | Partly superseded by [0065](decision/0065-visible-hand.md) (no hands) |
| [0049](decision/0049-natural-sword-swing.md) | Natural sword swing (grip path, wrist, afterimages, alternating side) | Partly superseded by [0050](decision/0050-hitbox-follows-swing.md) (swing is visual only) |
| [0050](decision/0050-hitbox-follows-swing.md) | The sword's hit area follows the swing animation | Partly superseded by [0055](decision/0055-no-bare-hand-attack-and-move-facing.md) (side-only tool chop), [0061](decision/0061-weapon-hit-area-from-picture.md) (hit size from picture) |
| [0051](decision/0051-agent-team.md) | Our own agent team: design panel, parallel builders, judge | Active |
| [0052](decision/0052-enemies-slime.md) | World enemies: one enemy setup, slimes first (W5) | Partly superseded by [0053](decision/0053-natural-enemy-spawning.md) (spawn timer and biome list) |
| [0053](decision/0053-natural-enemy-spawning.md) | Natural enemy spawning: biome tables, slime spots, chance per second | Active |
| [0054](decision/0054-remove-tiny-rpg-art.md) | Remove the Tiny RPG art | Active |
| [0055](decision/0055-no-bare-hand-attack-and-move-facing.md) | No bare-hand attack, body faces movement | Active |
| [0056](decision/0056-test-yard.md) | Test yard (dev-only test map) | Active |
| [0057](decision/0057-tree-chop-feedback.md) | Tree chop feedback (sway, debris, pop, real wood sounds) | Active |
| [0058](decision/0058-free-weapon-swap-no-weapon-limit.md) | Weapon swap is free and instant, no weapon limit | Active |
| [0059](decision/0059-soft-edge-weapon-turning.md) | Weapon pictures turn with soft edges | Active |
| [0060](decision/0060-item-icon-auto-fit.md) | 0060 Item icons are centred automatically | Active |
| [0061](decision/0061-weapon-hit-area-from-picture.md) | Weapon hit area from the picture | Active |
| [0062](decision/0062-test-levels-by-change-size.md) | Test levels, and work sized by the change | Active |
| [0063](decision/0063-asset-folders-by-role.md) | Asset folders by role | Active |
| [0064](decision/0064-grip-and-hand-points.md) | Grip and Hand points (draggable markers) | Active |
| [0065](decision/0065-visible-hand.md) | The player has a visible hand | Active |
| [0066](decision/0066-data-driven-sound.md) | Sound comes from data: one SoundSet per thing, one SoundBoard | Active |
| [0067](decision/0067-day-night-cycle.md) | Day / night cycle | Active |
| [0069](decision/0069-ground-tile-set.md) | Ground tile set: every border, foam and water pixel is in a picture | Active |
