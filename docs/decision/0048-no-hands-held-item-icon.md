# 0048 - No hands, held item icon, bare hands gather nothing

**Status:** Partly superseded by [0065](0065-visible-hand.md) (no hands)

## Context
The player drew two round placeholder hands (`HandsVisual`) with relax / sway / guard / bow-draw poses. They looked wrong
next to the pixel body and held nothing for materials or placeables. Fists could also fell trees, so the axe felt optional.

## Decision
- Delete `HandsVisual`, the `Hands` node, the `HandMain` / `HandOff` markers and the hand fields of `BodyRig`.
- New `HeldItemVisual` (`WeaponVisual/HeldItem`): shows the inventory icon of a material or placeable in the selected slot,
  upright at the grip, following the aim. Weapons and tools keep their model; an empty slot shows nothing.
- `fists.tres` `gather_damage = 0`: bare hands clink on trees and rocks (Terraria-style).
- Start kit: wooden sword + stone axe + stone pickaxe.

## Why
No hands = nothing placeholder to rebuild when real art arrives. The icon is data that already exists. Tools first makes the
first minute of play (gather, craft) read clearly.

## Consequences
- `player.gd` sets the item each frame via `HeldItemVisual.set_item()` (cheap, idempotent); combat never reaches in.
- Old saves load fine: the save replaces every slot. Tests that felled trees with fists now use the stone axe.
- A real held-item sprite replaces `HeldItemVisual` with the same `set_item()` contract.

**Accepted risk (user, 2026-10-31):** tools drop on death (`drop_gear`) and despawn; with hands at 0 gather, losing every tool means no more wood / stone. Intended — lose it, you lose it. No safety net.
