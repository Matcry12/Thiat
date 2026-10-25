# 0043 — UI style "Island Workshop" (supersedes the look parts of 0024/0030, placeholder look of 0029/0031/0040)

## Context
The UI was placeholder: dark slate boxes, a smooth system font, bars without frames. It did not fit the
Pixel Crawler map. The user tried two directions (old tome, then storybook) and rejected both. They then
picked a cozy-RPG reference screenshot (tan panels, open-book crafting, glossy bars). They asked for our
own twist and a **natural, hand-made** look ("not always straight lines").

## Decision
- The UI style is defined in `docs/design/DESIGN.md`, and the live web mockup `tools/ui_mock/index.html`
  is the source of truth. It was built in a 7-round build→review loop (Sonnet builds, a fresh judge
  reviews) and approved by the user at 8/10 on 2026-10-25.
- **Design first in the web mockup, then port to Godot.** New UI looks are approved in the mockup first.
- The fonts are our own pixel fonts (no third-party font, no credit line).
- **HUD words (supersedes the "no words in HUD" rule of 0030):** the boss name plate and the HP number
  (`70/100`) are allowed in the HUD. All other names stay in tooltips. Layout positions from 0030 stay.

## Why
- The user judges the look much faster on a live page than in game builds, and pixel drawing in code
  costs $0.
- A written spec plus the mockup means the next screens are *applied*, not re-designed from scratch.

## Consequences
- The port bakes the mockup's drawing helpers to PNGs plus a bitmap font, plugged into `InventorySkin`
  slots, in 3 vertical slices (see DESIGN.md §9). Every number becomes an `@export` (F3).
- Organic panel edges are baked at their real size, not stretched.
- The keys shown on ability keycaps must follow `project.godot` input actions.
