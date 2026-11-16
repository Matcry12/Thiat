# 3D character pipeline (player body)

**Status:** Outdated: the player now uses `data/body_rigs/pixel_plains.tres` (Pixel Plains 2D frames, 0054); 3D frames retired, blocky rig is dev-only (`data/dev/`)

> **Round 7 update:** the shipped body is now the chunky **blocky 18 px** one (`assets/dev/characters/player/blocky/`, `data/dev/body_rigs/blocky.tres`). The older sections below describe the soft 3D body, which is still loadable (see "Swap characters").

The player's BODY is a 3D model built in code, rendered to small pixel sheets. Hands and weapon stay 2D
(`WeaponVisual` / `Hands` / `SwingFx`, unchanged). Decision: [0028](../decision/0028-3d-rendered-characters.md).

## Where things are

| What | Where |
|---|---|
| Model + rig + poses (Blender script) | `tools/blender/make_player_body.py` -> `tools/blender/player_body.blend` |
| Renderer + packer + checks | `tools/blender/render_body.py` |
| SpriteFrames builder | `tools/blender/build_frames.py` (called by the renderer) |
| Output (what the game loads) | `assets/game/characters/player/3d/`: `idle.png`, `run.png`, `hit.png`, `sheet_info.json`, `player_3d_frames.tres`, `run_preview_4x.gif`, `contact_sheet_4x.png` |
| Old drawn art (kept) | `assets/dev/characters/player/player_frames.tres` |

Needs Blender 4.5 LTS (`~/.local/bin/blender`) and Python with Pillow. `tools/blender/.gdignore` keeps Godot from importing `.blend`.

## Change the model, re-render (about 10 s)

```
blender --background --python tools/blender/make_player_body.py    # builds the model + poses
python3 tools/blender/render_body.py                               # renders, packs, builds the .tres, checks
godot --headless --editor --quit                                   # lets Godot import the new PNGs
```

- Shape/colour: edit the `rbox(...)` lines and the `PAL` colours (sRGB bytes from the drawn player) in `make_player_body.py`.
- Poses: `idle` / `run` / `hit` functions in the same file. Moves are snapped to whole pixels. Run = 6 frames
  (contact, down, up, x2); squash on down, stretch on up.
- Timing: `HOLD_MS` in `render_body.py` (ms per frame). It is baked into the `.tres`, and the game plays it as-is.
- Camera/look: `PITCH` (80 = near front), `YAW` (25 = the 3/4 side view), `PPU`, `LIGHT`, `PALETTE` in `render_body.py`.
- Compare yaws: `python3 tools/blender/render_body.py --yaw-compare`. Only the run GIF: `--gif`.

## Rules the renderer enforces

- **The face is rigid.** The head is rendered ONCE per view (front / side) with no rotation, then stamped on the body
  at whole-pixel offsets (`HEAD_OFF`). Squash/stretch only touches the body. After each render the script checks that
  every head pixel (eyes, mouth, skin) is identical in every frame and fails loudly if not.
- No anti-aliasing, hard alpha, colours snapped to the player palette, 1 px black outline.
- Rows: front (S) and 3/4 side (E; the game flips it for left). There is no back view; facing up keeps the side.

## In the game

`scripts/visual/sprite_actor_visual.gd` detects a directional SpriteFrames (it has `idle_front`) and then:
- plays `<idle|run|hit>_<front|side>`; front if the facing is within `front_half_angle_deg` (45) of straight down,
  else side, flipped for left; up keeps the current left/right (`facing_hysteresis_deg` stops flicker on the border);
- skips the code bounce (it is baked into the art), emits `landed` on `landing_frames` (RunDust) and shrinks the shadow on `lift_frames`;
- plays the hit pose once on `flash()` (every hit goes through HitFx), then returns to idle/run (`hit_time_scale`).

Body `AnimatedSprite2D` stays at (0,-19), scale 2, so the shadow, hands and weapon do not move.

## Swap back to the old drawn art

Set the Body's `sprite_frames` in `scenes/player.tscn` to `res://assets/dev/characters/player/player_frames.tres`
(the `ext_resource id="8b"` line). No code change: plain `idle`/`run` animations switch the visual to the old behaviour
(fps exports, code bounce, `flip_h`). `tests/test_player_3d_body.gd` covers both.

## F3 test mode

`Visual` status line: `anim, frame, ... facing: front|side (flipped)  hit: <seconds left>`. `Visual` section: `front_half_angle_deg`,
`facing_hysteresis_deg`, `landing_frames`, `lift_frames`, `hit_time_scale`. Hit pose: `Hurt player 20`.


## Blocky 18 px body (current)

| What | Where |
|---|---|
| Model + poses | `tools/blender/make_blocky_body.py` -> `tools/blender/blocky_body.blend` |
| Renderer, checks, GIF, before/after | `tools/blender/render_blocky_body.py` (`--yaw-compare`, `--yaw N`, `--ppu N`) |
| Output | `assets/dev/characters/player/blocky/`: `idle|run|hit.png`, `sheet_info.json`, `blocky_frames.tres`, `run_preview_4x.gif`, `contact_sheet_4x.png`, `before_after_4x.png`, `yaw_compare_4x.png` |

```
blender --background --python tools/blender/make_blocky_body.py
python3 tools/blender/render_blocky_body.py
godot --headless --editor --quit
```

- Minecraft-style rigid parts, **no arms** (hands and weapon are the game's 2D visuals). A plain wide box read as a CUBE, so the silhouette is
  three separate masses: big head, a stepped/tapered torso (shoulders about the head width, narrower waist, gold belt, 1 px dark neck
  line), and two short legs with a gap and darker shoes. Idle = small A-stance (8 deg out); run = 42 deg diagonal swing + 10 deg lean;
  hit = lean back, legs diagonal backward. `assets/dev/characters/test_blocky/body_shape_compare_4x.png` compares arms / cube / new.
- 18 px body (about 20 px with the outline), `PPU_DEFAULT` 4.9. Side view yaw 30 (`BLOCKY_YAW` env or `--yaw`): the leg swing reads
  and the cube-head face keeps both eyes. Pitch 80, front + side (flipped for left), idle 2 / run 4 / hit 2.
- Same renderer rules: rigid face (head stamped at whole-pixel offsets) + "no second head" check, whole-pixel body bob/foot lift.
- Why 18 px: at 14 px the face is 1 px eyes and mud, at 22 px it is almost the old size. See decision 0028.

## One setting per character: `BodyRig`

`scripts/visual/body_rig.gd` (resource) holds everything that fits a body, its hands and its weapon:
`sprite_frames`, `body_position` (feet on the actor origin), `body_scale`, `shadow_scale`, and the weapon/hand fit:
`visual_scale` (weapon picture + hand offsets), `slash_scale` (the slash crescent), the `MainHandHold` marker in `player.tscn` (where every weapon is held), `hand_radius`,
`hand_rest_main/off`. `SpriteActorVisual.rig` applies it to the Body, the Shadow and (via `apply_rig()`) to `WeaponVisual`, `Hands`, `SwingFx`.

| Rig | File | visual_scale | slash_scale | pivot | hand radius | shadow |
|---|---|---|---|---|---|---|
| blocky 18 px (current) | `data/dev/body_rigs/blocky.tres` | 0.7 | 0.7 | (0,-13) | 3 | 0.65 |
| soft 3D body | `data/body_rigs/soft_body.tres` | 1.0 | 1.0 | (0,-9) | 5 | 1.0 |
| old drawn art | `data/dev/body_rigs/drawn_art.tres` | 1.0 | 1.0 | (0,-9) | 5 | 1.0 |

**Gameplay is never scaled.** `WeaponVisual` scales the model's picture and hand markers; the `Hitbox` and `Muzzle` get the inverse
scale, so their world shape/position are exactly as at scale 1 (`tests/test_body_rig.gd` checks sword, bow and fists).
Caveat: `SwingFx` draws the crescent from the REAL hitbox, so `slash_scale` 0.7 shows less than the real reach. Set `slash_scale` 1.0
to see the true area (F1 also draws the hitbox).

## Swap characters (one resource)

In `scenes/player.tscn`, the `Visual` node's `rig` line (`ext_resource id="rig"`): point it at
`data/body_rigs/soft_body.tres` (soft 3D body) or `data/dev/body_rigs/drawn_art.tres` (old drawn art, plain idle/run, code bounce).
No code change. In code or F3: `visual.rig = load(...)`. A new character = a new `.tres` with its own frames and numbers.

## F3

Section `BodyRig` (all numbers live), the `Visual` status line adds `rig <name>: visual_scale ... hand r ... pivot ... shadow ...`.
