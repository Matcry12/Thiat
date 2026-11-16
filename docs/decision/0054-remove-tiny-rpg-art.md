# 0054 - Remove the Tiny RPG art

**Status:** Active

**Date:** 2026-11-02 - **Supersedes** [0032](0032-temp-tiny-rpg-art.md).

## Context
0032 added the Tiny RPG Soldier (player) and Orc (boss) as temporary art. Its licence forbids redistribution and AI training. The player now uses Pixel Plains art, so only the boss still used it.

## Decision
Delete `assets/third_party/tiny_rpg/`, `assets/characters/tiny_rpg/`, `data/body_rigs/tiny_soldier.tres`, the Tiny RPG test, shot / compare tools, the `tinyrpg` demo scenario and the `docs/demo/tiny_rpg*` pictures. `boss.tscn` no longer sets `body_frames`: the boss shows its flat stand-in. Tests that used the soldier rig use `pixel_plains.tres` or a small in-test side-only SpriteFrames.

## Why
Licence, and the repo should be safe to share. `BossVisual` already has a "no `body_frames`" path (rule 5: swap, not rewrite), so no combat code changes.

## Consequences
- The boss is a placeholder until real art: set `BossVisual.body_frames`.
- Side-only support in `SpriteActorVisual` stays and is still tested.
- 0032 stays as history. Git history still holds the pack files: scrub it before publishing.
