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
