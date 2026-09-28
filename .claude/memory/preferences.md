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

## Prefer one abstract effect over per-weapon animation (2026-09-25)
User rejected "animate the weapon into a block pose" in favour of a shield effect in front of the
player: *"it help us not to care about animation too much"*. An effect that says WHAT happened
(blocked) instead of HOW (this weapon's pose) covers every current and future weapon with one piece
of art. Default to the weapon-independent effect; only animate the weapon when the weapon's own
character is the point. Extended 2026-09-28: the same for DECORATION — damage is a crack overlay
laid on any shield, never a cracked copy of each shield. Anything that decorates a swappable object
is a shared pattern by default. See [0013](../../docs/decision/0013-parry-and-block-on-one-key.md).
