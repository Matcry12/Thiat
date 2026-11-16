# 0005 — Prototype architecture: data-driven, composed, swappable brain

**Status:** Active

**Date:** 2026-09-22

## Context
[Prototype v0](../wiki/prototype-v0.md) is a scratch combat build, but we already know three
things are coming: many weapons, an RL-driven boss, and real content. A throwaway prototype
would have to be rewritten for all three.

## Decision
Three architectural rules in v0, nothing more:

1. **Weapons are data.** A `WeaponData` Resource (`.tres`) + ~3 behavior scripts
   (arc / projectile / hitscan). A new weapon is a data file, not a class.
2. **Composition over inheritance.** Shared logic lives in component nodes
   (`Health`, `Hitbox`, `Telegraph`, `WeaponHolder`, `Brain`) attached to player, trash and boss
   alike. No `Boss extends Enemy extends Entity` tree.
3. **The boss's decision-making is a swappable `Brain`.** `boss.gd` owns bodies/phases/hitboxes
   and asks `Brain.choose_action(state) -> String`. v0 ships `ScriptedBrain`; `RLBrain` later
   answers the same question from an ONNX policy with no other change. `state` is a plain
   Dictionary that doubles as the RL observation vector.

Everything else stays as simple as possible — no abstraction until a second use case exists.

## Why
- These are **known** requirements, not speculative ones, so the usual YAGNI objection does not apply.
- A class-per-weapon hierarchy duplicates the damage/timing logic N times; data-driven keeps one copy.
- The `Brain` boundary is the difference between "add RL later" and "rewrite the boss later."
- Keeping the RL observation as the same Dictionary the scripted brain reads means the observation
  space is exercised from day one instead of being invented at training time.

## Consequences
- Balance passes are `.tres` edits in the editor — no rebuild.
- `ScriptedBrain` is kept permanently as the RL training baseline and as a regression test.
- Accepted throwaway: arena, HUD, placeholder shapes. Do not polish them.
- Open: do trash enemies reuse `WeaponHolder` (uniform, slightly more setup) or get a simpler
  bespoke attack path (less code now, divergence later)?
