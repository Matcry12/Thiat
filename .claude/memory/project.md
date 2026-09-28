# BossFight — state of play

**What it is:** Godot 4.7 top-down 2D combat game, PC first, hard bosses (later RL-driven).
Placeholder art is circles/rectangles drawn in code — deliberately, permanently, for v0.

**Read these before design work:**
- `docs/wiki/design-pillars.md` — the combat/boss/item system
- `docs/wiki/prototype-v0.md` — what v0 builds, what it does not, architecture
- `docs/decision/` — 0001..0008, the record of why

**Settled decisions (do not re-litigate without a superseding record):**
- Reference games: Necesse = combat feel, Terraria = bosses/items, Soul Knight = support [0001]
- PC first, mobile deferred; mouse aim, no auto-aim [0002]
- Minecraft-style hotbar, max 2 weapons; weapon swap 0.6s cast / 5s cd, armor 1.5s / 10s cd,
  heal potion 30s; bag locked in combat [0003]
- Dodge is baseline, cooldown-gated not stamina: 0.3s i-frames, 2s cd [0004]
- Weapons are DATA (`WeaponData` Resource + ~3 behavior scripts); composition over inheritance;
  boss asks a swappable `Brain.choose_action(state)` [0005]
- Controls: WASD / mouse / LMB attack / `Q` dodge / `E` weapon skill / `F` parry / 1-2 weapons.
  Parry is a 0.25s timing window (not a hold-block): success = negate + stagger 0.8s + 25% shield;
  miss = take the hit + 0.5s recovery. Not every attack is parryable (purple tell) [0006]
- Vertical slices, playtest-gated [0007]
- `F` = tap parry / hold block; both directional (`parry_arc_degrees`, 180 default). Block drains a
  shield bar that BREAKS at 0; purple breaks it instantly. Block is SHOWN by a sword guard pose
  (angle/forward/side per weapon). Shield icon, cracks and their art are DELETED;
  only the shield BAR mechanic remains (curved GuardBar). Old version at commit a365828 [0013, 0014, 0015]
- RL inference: train in Python, ship JSON weights + ~40-line GDScript matmul.
  **The official godot_rl_agents ONNX node is .NET-only — we are GDScript** [0008]

**Debug keys:** `F1` hitboxes/timing overlay, `F2` 0.25x slow motion, `F3` live tuning panel.

**Status (2026-09-23):** docs + research complete, git initialised, Godot on PATH.
Nothing built yet. Next: slice 1 — move, aim, sword arc, one dummy, F1 overlay.
Question it answers: *does swinging feel good?*
