# 0066 - Sound comes from data: one SoundSet per thing, one SoundBoard

Algorithm: [sound-algorithm.md](../wiki/sound-algorithm.md) (Minecraft `SoundType`, Terraria `HitSound` / `UseSound`).

## Context
Sounds hid inside HitFx profiles and were picked by names and tags in code (every melee hit = sword). A breaking hit played the hit and the break sound together. Weapons and tools had no sound field, so new content could not fit without code.

## Decision
- `SoundSet` (`data/sounds/<set>.tres`) has slots: hit, break_, wrong_tool, place, swing, block, parry, phase, hit_charged. Each slot is a `SoundCue` file (`data/sounds/cues/<set>_<slot>.tres`: stream, volume, pitch, pitch_gain). Empty = silent.
- Every resource node, weapon / tool, enemy, station, player, boss, dummy points to one set by `sound_set`.
- The target makes the impact sound. If the attacker's weapon set has that slot filled (bow arrows), the weapon's sound plays instead.
- HitFx profiles only name the slot (`sound_slot`). `SoundBoard` (child of HitFx) is the one player.
- Break wins: a hit that breaks a node or kills the boss plays only the break sound.
- `tools/add_weapon.py --sound <set>` (sword -> blade, tools -> tool).

## Consequences
- A new thing = pick a set in its `.tres`. A new material = a new set + cues, no code.
- F3: `Sound`, `Sound <set>`, `Sound <set> <slot>` sections (writable to .tres), `[Sound]` status, `Test sound`.
- `tests/test_sound_system.gd` fails if anything has no set.
- Swing sounds are silent until whoosh files exist. Lunge now plays the target's hit sound.
