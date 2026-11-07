# 0057 - Tree chop feedback (sway, debris, pop, real wood sounds)

## Context
Chopping a tree gave almost no feedback: a 3 px slide, a white flash, 5 sparks and the sword sound. The user compared variants in a demo video (`tools/demo/chop_fx/`) and picked A1 + D2 + B2 + C2, no flash, natural sound.

## Decision
- Each ResourceNode Visual has a `Reaction` node (`scripts/fx/node_hit_reaction.gd`): the Body sways around its foot (skew) and pops (scale about the foot) before the stump shows. A shared `NodeReaction` under HitFx (`scripts/fx/node_reaction_fx.gd`) draws pooled wood chips and leaves and holds the numbers.
- `HitFxProfile.reaction` (`chop` / `pop`) picks the reaction; `pitch_gain` raises pitch as HP drops. Hit info carries `hp_fraction` + `direction`; gather code never touches visuals.
- Trees break with their own profile `tree_break`; rocks and copper keep `node_break`.
- Sounds are real recordings: Kenney "Impact Sounds" (CC0), `assets/game/audio/kenney_impact/`, through `AudioStreamRandomizer` files `wood_chop.tres` (medium) and `wood_break.tres` (heavy).

## Why
The video let the user choose by feel before building. Keeping the reaction in its own node means an animated tree sprite later replaces only that node. A real recording sounded natural where the synth did not.

## Consequences
New hit kinds (rocks, copper) can reuse `reaction` with their own chip colours. Any CC0 sound drops into a profile with no code change.
Done (user request): rocks and copper use the same reaction (profiles `mine` and `node_break`: `reaction`, `sway_scale` 0.4, `leaf_scale` 0.5 dust, `picture_chips` = grey chips) with stone sounds (`stone_hit.tres`, `stone_break.tres`); a node with no stump waits for the pop before it is freed.
Stations (workbench, furnace, anvil) use it too: a wrong tool wobbles with a dull knock (`station_knock_wood|stone`), a pickaxe pops it with a burst of chips in its own colours (`station_pickup_wood|stone`) and the node is freed after the pop; the inventory gain happens at once as before.
