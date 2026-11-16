# 0022 — Boss aggro and leash (replaces the enrage rule)

**Status:** Active

## Context
[0019](0019-boss-v0.md) had an enrage rule: the player stays outside the `FightZone` for more than
3 s and the boss charges at 2x speed until they come back. The map is now 2x the screen
([0021](0021-procedural-arena.md)) and the boss waits in one part of it, so the player walks to the
boss. "Leave the zone" now means "I am walking away", not "I am hiding in the arena". Punishing that
makes no sense. On 2026-10-01 the user chose a **leash** instead of enrage.

## Decision
- The `FightZone` is the **aggro zone**. Three boss states (`Boss.Aggro`): `IDLE`, `ENGAGED`, `RETURNING`.
  - `IDLE`: waits at its spawn (`home`), no attacks, does not even ask its brain.
  - Player enters the zone -> `ENGAGED`: fights as before (slam, spread, charge, ring, phase 2).
  - Player leaves the zone for more than `leash_delay` (1.0 s) -> `RETURNING`. Coming back inside the
    delay changes nothing. The delay stops edge-dancing.
  - `RETURNING`: drops the attack in progress (telegraph and hitbox cleaned up; bolts already flying keep
    flying), **heals to full and resets to phase 1** (`reset_heals`, default on), walks to `home` at
    `return_speed` (200) and takes no damage (`invulnerable_while_returning`, default on, done with
    `Health.invulnerable`). At home it is `IDLE` again.
  - The player entering the zone while it walks home engages it again at once (it is already reset; the
    invulnerability ends).
- The visual is told by `aggro_changed(state)`; `BossVisual.set_aggro()` tints the body pale blue while
  returning. Combat never touches the visual (CLAUDE.md §5).
- F3 shows `aggro`, the outside timer and `home`; the boss HUD label shows the state (the bar stays
  visible while idle). F1 draws the zone labelled `AGGRO ZONE (state)` (blue idle, red engaged, pale
  returning) and a ring at `home`.
- `force_next(action)` (F3 `-> slam` etc.) while **idle** runs that attack once and does not engage the
  boss, so the leash cannot cancel the demo attack. While **returning** it is ignored.
- A boss with no zone assigned (a bare boss in a test) is always engaged.
- **Deleted, not kept:** `enrage_delay`, `enraged`, `enraged_changed`, `outside_time` as an enrage timer,
  the brain's `enraged` state key and its "charge every time" branch, `ChargeAttack`'s
  `enrage_speed_multiplier` / `enraged_cooldown`, `BossVisual.enraged_color`.

## Why
It matches what the player means: walking out of the zone is a retreat, so the boss resets like a
Soul Knight / Terraria boss that is left behind. It cannot be abused for a free heal-and-reset
(the boss is invulnerable while it walks, and the full reset is the cost of leaving).

## Consequences
- The boss no longer punishes standing far away. Ranged weapons cannot snipe from outside the zone
  without the boss resetting (it can still be shot at the edge for `leash_delay`). Playtest.
- The boss cannot be pathfound home: it walks in a straight line and ignores rocks (as before). If a
  non-rock obstacle is ever put between it and home, it needs pathfinding.
- 0019's "Enrage" bullets are superseded by this record; the rest of 0019 stands.

## Amendment (2026-10-01)

A hit wakes an idle boss (a "pull"). Without this the player could shoot it from outside the zone
forever. If the shooter stays outside, the normal leash resets and heals it after `leash_delay`.
