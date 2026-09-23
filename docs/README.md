# docs — map

| Where | What |
|---|---|
| [wiki/design-pillars.md](wiki/design-pillars.md) | The design: combat, bosses, items, progression. Durable. |
| [wiki/prototype-v0.md](wiki/prototype-v0.md) | What v0 builds and does not; architecture; debug + tuning tools. |
| [decision/](decision/) | Why things are the way they are. `NNNN-<slug>.md`, append-only in spirit — supersede, never silently edit. |
| [reference/game-design/](reference/game-design/) | Terraria, Necesse, Soul Knight research. Read instead of re-researching. |
| [reference/godot/](reference/godot/) | Godot 4 combat patterns, juice recipes, RL/ONNX findings. |

## Decisions so far
| # | Decision |
|---|---|
| [0001](decision/0001-design-reference-games.md) | Necesse = combat feel, Terraria = bosses/items, Soul Knight = support |
| [0002](decision/0002-pc-first.md) | PC first; mobile deferred |
| [0003](decision/0003-loadout-and-swapping.md) | Hotbar, max 2 weapons, gated swaps |
| [0004](decision/0004-dodge.md) | Dodge baseline, cooldown-gated (not stamina) |
| [0005](decision/0005-architecture.md) | Data-driven weapons, composition, swappable Brain |
| [0006](decision/0006-controls-and-parry.md) | Q dodge / E skill / F parry; parry is a timing window |
| [0007](decision/0007-working-agreement.md) | Vertical slices, playtest-gated |
| [0008](decision/0008-rl-inference.md) | RL: JSON weights + GDScript matmul (ONNX node is .NET-only) |
