# 0028 - Characters: 3D-rendered body, 2D hands and weapons

**Status:** Partly superseded by [0054](0054-remove-tiny-rpg-art.md) (player body is Pixel Plains 2D frames)

## Context
The user can draw, but not hundreds of frames. A character in 8 directions × many animations is about
400 drawings, and every redesign starts over. No budget for paid AI art (PixelLab, Gemini).
Dead Cells solves this by building characters in 3D and rendering them as small, sharp pixel sprites.
We tested it in 4 rounds (2026-10-08): knight, chibi, a 3D twin of the drawn player, then body + 2D hands.

## Decision
- **Body = 3D render.** Built in code in Blender (`tools/blender/`), rendered headless to sprite sheets:
  no anti-aliasing, palette snapped to the drawn player's colours, 2 flat light bands, 1 px black outline.
- **Camera 80° from straight down** (near front view, like the Pixel Crawler art).
- **3 facings, 2 renders:** front (facing down) and 3/4 front turned 25° (right; flipped for left).
  No back view: facing up keeps the 3/4 side. The face is always visible, like Dead Cells.
- **Few frames, held poses** (idle 2, run 6, hit 2) so it reads as 2D, not as a rotating 3D model.
- **Hands and weapons stay 2D** — the existing `WeaponVisual` / `Hands` / `SwingFx` nodes, unchanged.
  The body has no arms. Attacks are never animated in 3D.
- The old drawn player art stays loadable by a resource swap (CLAUDE.md §5).

## Why
- A redesign or a new animation is a few poses + a 5 s re-render, not dozens of drawings.
- Body and weapon are separate: a new weapon is 1 small 2D picture that works on every character.
- Swing timing stays in `WeaponData` (tuned in F3), never baked into art.
- 8 directions and many in-between frames looked "too 3D" to the user; 3 facings and held poses fix that.

## Consequences
- New characters: build a body in Blender (script) → render → SpriteFrames. How-to: `docs/wiki/3d-character-pipeline.md`.
- Blender 4.5 LTS is a dev tool (`~/.local/bin/blender`), not a game dependency. `tools/blender/.gdignore` keeps
  Godot from importing `.blend` files.
- The user's own drawing time goes to faces, icons, weapons and special frames.
- Free 3D models (Kenney, Quaternius, CC0) can be used as a starting point instead of building from boxes.


## Update 2026-10-08 (round 7): blocky 18 px, no 3D arms

The user chose the blocky Minecraft-style body at **18 px** (Core Keeper / Tinkerlands scale) over the soft round body.
- **Size:** 14 px lost the face (1 px eyes), 22 px was almost the old size. 18 px keeps eyes, hair, shirt and legs readable and gives
  small, clean, easy-to-animate sprites. Cell 32x32, 18 px body, about 20 px with the outline.
- **No arms in 3D, thick body:** hands/weapons stay 2D. A thin torso looked like a stick man, so the torso is wide and thick, legs wide.
- **Side view yaw 30:** 25 showed the face best but little leg swing; 35-45 lose an eye. 30 is the compromise.
- **Per-character fit = `BodyRig`** (`data/body_rigs/*.tres`): frames, body position, shadow, weapon/hand visual scale, slash scale, pivot.
  Weapon art scales to 0.7, hand discs shrink; **hitbox/muzzle keep their world size** (visual only). The slash crescent comes from the real
  hitbox, so a scaled crescent shows less than the real reach: `slash_scale` can be 1.0 to show the truth.
- The soft 3D body and the old drawn art stay loadable by swapping the rig resource.
