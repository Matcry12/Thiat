# Sound algorithm

**Status:** Current

How the game picks which sound to play. Status: **built** (SoundBoard, `data/sounds/*.tres`, `tests/test_sound_system.gd`). Decision record still to write.
Built from how Minecraft and Terraria do it. Reuse it for every new node, station, item, weapon, tool, enemy.

## What we have now (audit, 2026-11-08)
All sounds go through `HitFx.fire(type)` -> `HitFxProfile.sound` (`data/hit_fx/*.tres`) -> `HitSound` (8 voices, +/-8 % pitch).

| Problem | Where | What the player hears |
|---|---|---|
| The breaking hit plays **two** sounds: the hit (`chop` / `mine`) and the break (`tree_break` / `node_break`) in the same frame | `resource_node.gd` `take_gather_hit` -> `_break` | The last hit is a muddy double sound, louder and different from the others |
| The sound belongs to the **effect type**, not the thing. A node says `hit_type = &"chop"` and the sound is hidden inside that profile | `resource_node_data.gd`, `data/hit_fx/chop.tres` | A new material (copper, ice) needs a new HitFx profile copied by hand, or it borrows rock sounds |
| Weapon hits are picked **in code** by tag: every melee hit = `sword` | `HitFxProfile.type_for_tag` | An axe hitting a slime sounds like a sword. A new weapon cannot have its own sound without code |
| Weapons, tools, items have **no sound field** at all | `weapon_data.gd`, `add_weapon.py` | No swing sound; a new weapon can never fit in by data |
| Wrong-tool "clink" uses the sword file at pitch 1.6 | `data/hit_fx/clink.tres` | Hitting copper with bare hands sounds like a sword |
| Stations: sound by two magic names per scene (`knock_type`, `pickup_type`) | `scenes/stations/*.tscn` | Furnace / anvil use the default stone names; placing a station is silent |
| Sound is a layer of HitFx: `Hit FX` off = silence | `hit_fx.gd` | Can't test feel without sound or sound without feel |

## Sources
| Rule | Minecraft | Terraria |
|---|---|---|
| Who owns the sound | Each block points to one `SoundType` (WOOD, STONE, METAL, GRASS...): `break`, `step`, `place`, `hit`, `fall` + volume + pitch | Each tile has `HitSound` (Dig, Tink for stone); each NPC has `HitSound` + `DeathSound` |
| Hit vs break | Hit sound while mining (quiet, low pitch); on break only the break sound | Hit sound per hit; break plays the kill/break sound |
| Weapons | Swing / attack sounds by attack result; the **target** makes the hurt sound | Each item has `UseSound` (swing); the **target NPC** makes the hit sound |
| New content | New block picks an existing `SoundType`, no code | New tile / item sets one field |
| Variety | Several files per event, random pick, small random pitch | Same: random variants + pitch |

## Our algorithm
1. **`SoundSet` = how one material / thing sounds.** A Resource in `data/sounds/<name>.tres` with one slot per event. Each slot is a `SoundCue` (stream, `volume_db`, `pitch`, `pitch_gain`). Empty slot = silent, on purpose.

   | Slot | Played when |
   |---|---|
   | `hit` | Something hits this thing (node chopped, slime / boss / player hurt, station knocked) |
   | `break` | This thing breaks / dies / is picked up (tree falls, rock pops, boss dies) |
   | `wrong_tool` | Hit with a tool that is too weak (the old clink) |
   | `place` | This thing is placed (stations) |
   | `swing` | This weapon / tool is swung or shot (needs whoosh files; empty until then) |
   | `block`, `parry` | The player's guard blocks / parries |

2. **Every thing points to one set by data.** `ResourceNodeData.sound_set`, `WeaponData.sound_set`, `EnemyData.sound_set`, the station's data, the player, the boss. No names in code.
3. **The target makes the impact sound** (Minecraft + Terraria). Sword on slime = slime's `hit`. Axe on tree = tree's `hit`. The weapon only makes its own `swing`.
4. **One owner plays it: `SoundBoard`** (the old `HitSound`, grown up; a node in the arena). `SoundBoard.play(set, &"hit", info)`. HitFx profiles keep the look (flash, shake, sway) and only say *which slot* (`sound_slot = &"hit"`), not which file.
5. **Break wins:** a hit that breaks plays only `break`. One sound per event, never two.
6. **Variety:** each cue's stream may be an `AudioStreamRandomizer` (5 Kenney files now) + SoundBoard's random pitch. `pitch_gain` keeps the "higher as it nears breaking" feel.
7. **New content = pick a set.** `add_weapon.py --sound <set>` (default by kind: sword -> `blade`, axe / pickaxe -> `tool`). A test fails if any node / weapon / station / enemy has no set.

## Starting sets (reuse today's files)
| Set | hit | break | used by |
|---|---|---|---|
| `wood` | wood_chop | wood_break | all trees, workbench |
| `stone` | stone_hit | stone_break | rock, furnace, anvil |
| `metal_ore` | stone_hit (pitch up) | stone_break | copper rock |
| `flesh` | hit_sword | boom | slime, dummy |
| `boss_orc` | hit_boss | boom (+ phase) | boss |
| `player` | player_hurt | - | player (block, parry slots; eating: `eat` eat_chew, `drink` drink_sip, `gulp` eat_gulp) |
| `blade`, `tool`, `bow` | - | - | weapons / tools (swing empty for now; arrow / charged keep their hit via the arrow's set) |

## Test mode
- F3 section `SoundBoard` (master volume, pitch variation, voices) + one section per set and slot (`Sound wood`: `hit_volume_db`, `hit_pitch`...). Live.
- F3 status `[Sound]`: last event (`wood.hit`), plays, voices busy, silent events (a slot asked for but empty).
- F3 button `Test sound` (cycles every set + slot).
- Switch `HitFx.sound_on` moved to `SoundBoard.enabled`. Section name is `Sound`; extra slot `hit_charged` (bow set) for the charged arrow; the lunge has no weapon so it falls back to the target's `hit`.
- Eating slots `eat` / `drink` / `gulp` (player set): `Consumer` plays `ItemData.use_sound` (`eat`, potion `drink`) every `eat_sound_every` while holding, and `gulp` when an item is used. Placeholder wavs from `tools/make_sfx.py` (procedural, own work, CC0).

## Later (not now)
`step` (footsteps per ground), `pickup` (item into bag), `craft`, music buses. Add a slot when the event exists.
