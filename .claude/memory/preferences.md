# User preferences

## How we work
- **Vertical slices, playtest-gated** ([0007](../../docs/decision/0007-working-agreement.md)).
  One playable slice -> hand over with "run it / do this / judge this" -> user playtests -> tune ->
  next slice. Never stack unverified slices.
- User answers in **feel language** ("too floaty", "swing lands late"). Translating that into
  numbers is my job, not theirs.
- **"This isn't fun" is expected feedback**, not failure. No sunk-cost defence of a decision doc.
- I verify it *runs* (headless check). Only the user can verify it *feels right* — never claim a
  feel outcome.

## Output style
- Short answers, code first. No essays.
- Lowest capable model does the work; Opus plans/reviews only.
- All harness config stays project-local (never `~/.claude`).

## Project
- Combat is the product. Story/world/meta come later and never constrain the fight.
- Every feel number is tunable live (`F3` panel / Godot Remote inspector) — expose new ones as
  `@export`, never hardcode.

## Build for replacement (CLAUDE.md §5)
- Placeholders are stand-ins with an interface, never throwaway code to rebuild later.
- Visuals live in their own node; combat only emits signals. Sprite swap must touch zero
  combat code.
- Timings live in data; art stretches to fit the tuned timing, never the reverse.
- User cares about this specifically — flagged it unprompted on 2026-09-23.

## Communication (CLAUDE.md §6)
- English level B1, max B2. Short sentences, common words, one idea per sentence.
- ALWAYS give a concrete example — user said explanations were "hard to imagine" without one.
- Explain what breaks and what the user would SEE on screen, not what the code does.
- No jargon without plain words beside it. Asked for this on 2026-09-23.
- Never put watermarked/stock images (Dreamstime etc.) into the project — not licensed.
  Draw an original placeholder instead, or use CC0 (Kenney.nl). Came up 2026-09-23.

## One owner per property (learned the hard way, 2026-09-24)
If a human places something by dragging in the editor, NO script may write that property.
Code owns only what animates. Hit twice: Blade.position (hand_distance) and Body.position
(body_offset). Both exports deleted.

## Prefer one abstract effect over per-weapon animation (2026-09-25; narrowed 2026-09-28)
User rejected "animate the weapon into a block pose" in favour of a shield effect in front of the
player: *"it help us not to care about animation too much"*. An effect that says WHAT happened
(blocked) instead of HOW (this weapon's pose) covers every current and future weapon with one piece
of art. Default to the weapon-independent effect; only animate the weapon when the weapon's own
character is the point. Extended 2026-09-28: the same for DECORATION — damage is a crack overlay
laid on any shield, never a cracked copy of each shield. Anything that decorates a swappable object
is a shared pattern by default. See [0013](../../docs/decision/0013-parry-and-block-on-one-key.md).
**Narrowed 2026-09-28:** the user then chose a sword GUARD POSE for blocking after all, because the
shield will become its own off-hand weapon. It is acceptable because in this codebase a pose is one
eased rotation number per weapon (`WeaponData.guard_angle_degrees`), not animation frames. So: a
weapon-held pose that is a single number is fine; anything needing per-weapon FRAMES still defaults
to a shared effect.

## Judges judge the LOOK too (2026-10-08)
For art/visual work, give the Opus judge the rendered PNGs and video frames and ask strictly "does it read well
at game size?", not only code. User: "tell opus to judge harder" after a blocky body read as a cube.

## UI and look choices (2026-10-09..16, user decided)
- **No words in the HUD.** Icons + counts only; names, HP number and recipe ingredients show only in the hover tooltip.
  Tooltips are hidden mid-fight (boss engaged, bag closed).
- HUD layout: hotbar + bag top-left, health + ability icons bottom-left, boss bar bottom centre and only while the boss is awake.
- Every UI piece is art-swappable through `data/ui/inventory_skin.tres` (one ItemSlot scene, role-named children, layout owned by the scene).
- Crafting = simple: grid of result icons (lit = craftable, dim = holds part of it, hidden = holds nothing);
  click a lit icon -> item on the cursor -> click a slot. NOT a Minecraft grid. Smelting takes time (3 s/bar, no fuel).
- Ground brightness/saturation 1.0 (user rejected 0.8/0.85). Map style default = Pixel Crawler only; Serene Village is an option.
- Characters: Tiny RPG Soldier/Orc are TEMPORARY, both at scale 3 (user picked same pixel size over "boss looks bigger").

## How the user likes the work run (2026-10-16)
- Fast loop: Sonnet builds, a fresh Opus agent judges (code + screenshots), fix, re-judge. The user wants speed; pick sensible
  defaults instead of asking, say which defaults were taken, and let the user redirect.
- The user often skips "commit?" questions; ask once per slice, never commit without a clear "commit".
- Visual/tile work: verify on test shapes before baking the real map (see mistakes.md 2026-10-16).
- Tests: fix rounds → `tools/run_tests.sh --changed` (only tests tied to changed files) or name tests: `tools/run_tests.sh tests/test_x.gd`. Full `tools/run_tests.sh` (100 tests, ~2 min, 8 in parallel) once before a commit. Parallel runs are safe now: each process has its own user://. The user asked why a one-number change took minutes (2026-10-22).

## Map / world (2026-10-23)
- Map art = Pixel Crawler only (0034). Dirt only where something explains it, never random (0035). Roads off by default.
- "Look natural like Minecraft": density per biome, not blobs or hard lines; trees of mixed ages; flowers in clumps.
- Any new look: a $0 preview picture first (`tools/asset_viewer/*.py`), user approves, then build. Show several seeds when asked.
- Water is swimmable (slower + effect), deep ocean is the edge. 512x512 island now; a bigger Minecraft-like world later.
- The user wants every map number in F3 (grouped) and the F3 World map to see the whole island after a change.
- Before big new systems, the user asks for research with citations + a plan + demo pictures.
