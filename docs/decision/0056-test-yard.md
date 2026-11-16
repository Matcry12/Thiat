# 0056 - Test yard (dev-only test map)

**Status:** Active

## Context
Testing one feature (e.g. tree chop effects) meant generating and walking the 512x512 island to find the right tree, rock or station.

## Decision
A `Test yard` button on the title (only `OS.is_debug_build()`) sets `ArenaMap.yard_mode` and starts the normal `arena.tscn`. `ArenaMap` creates a `TestYard` node (`scripts/map/test_yard.gd`) and builds a small flat map (`cells`, default 64) through the same `MapGen.generate` with `Params.yard`: all land, one Plains biome, no water or vegetation, nodes = exactly `TestYard.node_list()` (every Pixel Plains oak, season columns x age rows; rocks; copper). `TestYard` also places the 3 stations, a slime, gives the dev kit, and adds the F3 `[Test yard]` status + `Reset yard` button. Saving (`SaveGame.io_enabled`) and natural spawning are off. The boss zone is parked far off the map so nothing engages.

## Why
Same obstacle dicts, chunk streamer, ResourceNode and Station code as the island, so chop / mine / craft behave identically. No forked map code; the yard is one branch in `_shape_island` and `_place_nodes`.

## Consequences
- `yard_mode` is cleared when the title is shown again; F3 Restart reloads the yard.
- Layout spacing, map size and station list are `@export`s on `TestYard` (F3 tunable).
- Placer's boss-path check is skipped in the yard. A map rebuild from an F3 slider returns placed stations to the bag; `Reset yard` does not.
- Not playtested: looks and spacing of the layout.
- Item picker (addendum): `TestYard` makes an `ItemPicker` that gives the crafting book a catalog: a 4th `Items` side tab, so it exists only in the yard (an empty catalog = the normal 3 tabs). A tab, not a side panel: the user wants one book, and a tab still fits with the F3 dock open. It lists every `ItemData` in `data/items` through `RecipeBook.load_dir`; a click gives the item through `Inventory.give_or_drop`. A picture alone is not an item: a new sword needs an item `.tres` (+ weapon + model) and then shows up with no code. `sword1` has no recipe, so only the picker gives it. `fists.tres` has no item on purpose (0055).
