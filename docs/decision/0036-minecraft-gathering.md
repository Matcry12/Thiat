# 0036 — Gathering follows Minecraft logic (on top of HP)

**Status:** Active

Builds on W2 gathering (HP per node, `gather_damage` per swing, `required_power`, `preferred_tool` + `tool_bonus`).

## Context
The user wants gathering to feel like Minecraft. Minecraft has no HP: a block breaks after a timer that runs while
you hold the button (time = hardness x 1.5 / tool speed), progress resets when you stop, and stone mined without a
pickaxe drops nothing. Big trees are just more log blocks. We have no blocks and our gathering shares the combat swing
(hit flash, shake, sound).

## Decision
- **Keep HP.** Break time = HP / damage per second, same math as a timer, and every swing keeps its hit feel.
- **Progress resets:** no hit for `ResourceNodeData.reset_delay` seconds -> the node is back to full HP (0 = never).
- **No tool, no drop:** `ResourceNodeData.drop_needs_tool` = true (rocks) -> broken without its `preferred_tool`, it drops
  nothing. Trees drop wood even by hand, like Minecraft.
- **Hold to gather:** holding attack with a tool or bare hands keeps swinging (`Player.hold_to_gather`). Weapons stay
  click per swing (combat feel unchanged).
- **Bigger tree = more HP** (our version of "more log blocks"). Comes with the tree-size placement rules, not here.
- No tool durability for now: extra grind that pulls the player away from the boss.

## Why
Same feel as Minecraft without rebuilding gathering; tuned in F3 like every other number.

## Consequences
- F3 `Node tree/rock/copper` sections get `reset_delay` and `drop_needs_tool`; `[Gather]` shows "no drop" (the reset shows on the next hit; the line updates only on hits).
- The reset clock counts game time, so F2 slow-mo and hit-stop never reset a node mid-gather.
