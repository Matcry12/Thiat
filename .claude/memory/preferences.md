# User preferences

Rules already in AGENTS.md (§5 build for replacement, §6 how to talk, §7 `@export` everything) are not repeated here.

## How we work
- Vertical slices, playtest-gated (0007). Never stack unverified slices.
- User answers in **feel language** ("too floaty", "swing lands late"). Turning that into numbers is my job.
- "This isn't fun" is normal feedback, not failure. No defending a decision doc.
- I verify it runs; only the user can say it feels right. Never claim a feel outcome.
- Fast loop: Sonnet builds, a fresh Opus judges (code + screenshots), fix, re-judge. Pick sensible defaults, say which, let the user redirect.
- Ask "commit?" once per slice; never commit without a clear "commit".
- Before big new systems: research with sources + a plan + demo pictures.
- All harness config stays project-local (never `~/.claude`).

## Design rules the user chose
- Combat is the product. Story / world / meta never constrain the fight.
- **One owner per property:** if a human drags it in the editor, no script writes it. Code owns only what animates.
- **Shared effect over per-weapon animation** (0013): an effect that says WHAT happened covers every weapon.
  A pose that is one number per weapon is fine; anything needing per-weapon frames is a shared effect.
- Decoration on swappable things (cracks on a shield) is a shared overlay, never a copy per item.
- Never use watermarked / stock images. Draw an original or use CC0.

## Look and UI
- Judges judge the LOOK too: give them renders, ask "does it read well at game size?".
- No words in the HUD: icons + counts; names and numbers only in hover tooltips, hidden mid-fight.
- Every UI piece is art-swappable through `data/ui/inventory_skin.tres`.
- Crafting: grid of result icons, click -> cursor -> slot. Not a Minecraft grid.
- Ground brightness / saturation 1.0. Map art is Pixel Plains now (0046, 0069).

## Map / world
- Dirt only where something explains it (0035). Natural like Minecraft: density per biome, mixed tree ages, flowers in clumps.
- Any new look: a $0 preview picture first, user approves, then build. Show several seeds when asked.
- Water is swimmable; deep ocean is the edge. Every map number in F3, and the F3 World map shows the whole island.
