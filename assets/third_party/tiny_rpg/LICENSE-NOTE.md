# Tiny RPG Character Asset Pack (Soldier + Orc) - license note

- Pack: "Tiny RPG Character Asset Pack" (01 v2.0, free Soldier & Orc), by zerie, itch.io.
- Copied from the "Characters(100x100 split)" folder, no-shadow version, left unedited. (The Soldier's "no shadow" files still have a baked shadow; see tools/tiny_rpg_unshadow.py, which writes cleaned copies to assets/characters/tiny_rpg/.)
- Terms (as given by the user): use in games and modifying is OK. **No redistribution. No use for AI training.**
- **Exception (2026-10-16, user report):** zerie gave the user permission to train an AI model on these packs.
  Exact scope (private model? commercial outputs? credit?) not recorded yet. Keep zerie's written reply
  (screenshot / message) next to this note as `zerie-permission.png` or `.txt`. The no-redistribution rule still applies to the art itself.
- This repo has no remote (local only). Before the repo is ever published or shared, remove this folder
  and `assets/characters/tiny_rpg/` (the art is temporary, see docs/decision/0032-temp-tiny-rpg-art.md).
- `.gdignore` here: Godot does not import this folder. The game uses copies in `assets/characters/tiny_rpg/` (Orc sheets copied as they are, Soldier sheets derived).
- Never edit the files in this folder. Derived or cropped files go to `assets/characters/tiny_rpg/`.
