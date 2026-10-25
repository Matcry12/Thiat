# 0039 — Death and respawn (W6)

> The death bag below was replaced by loose death drops in [0042](0042-death-drops.md).

Implements [v1-design §8](../wiki/v1-design.md). Replaces "player dies -> end screen + R" from v0.

## Context
Dying ended the run: a "You died" label and `R` reloaded the arena. v1 is a long run with gathering, so a death
must cost something but must not throw the run away.

## Decision
- `Respawner` (child of Player) owns death. `Health.died` -> deaths + 1, boss resets, materials go into a bag,
  and after `respawn_delay` (2 s) the player wakes at `ArenaMap.home_point()` with full HP.
- Each **material** stack loses `drop_share` (0.5, rounded down) into ONE `DeathBag` at the death spot (none if
  nothing dropped). Weapons, tools and stations never drop.
- The bag is a world node (group `death_bag`) with its own `Visual` child. The existing `Collector` hands the
  contents back when the player is within `bag_pickup_radius`; what does not fit stays in the bag. Several bags can exist.
- The boss resets on every player death (`Boss.reset_fight()`: full HP, phase 1, walks home, idle). A defeated boss stays defeated.
- `EndScreen` no longer reacts to player death. It keeps "Boss defeated" + `R` (W7 changes that).
- Deaths are counted in `Respawner.deaths` (this run), for the later win screen / save.

## Why
Reuses the Collector, Inventory and boss leash instead of new systems. One owner for death (Respawner) keeps
`player.gd` and `end_screen.gd` simple. The Collector skips while the player is dead, so a bag is never
picked up by the corpse.

## Consequences
- Dying in deep water or far away leaves the bag there; walk back to it (F3 `Go to nearest bag`).
- Bags are not saved yet: W9 (save / load) must store them.
- A player who dies on a spot the boss cannot leave still sees the boss reset: it walks home during the delay.
