# 0008 — RL inference: GDScript matmul, not ONNX/.NET

**Status:** Active

**Date:** 2026-09-23

## Context
Research ([rl-and-onnx.md](../reference/godot/rl-and-onnx.md), 2026-09-23) found that
`godot_rl_agents`' official ONNX inference path **requires the .NET/Mono build of Godot**. Our
stack is GDScript-only (CLAUDE.md §5). Options found:

| Option | GDScript? | Cost |
|---|---|---|
| Official ONNX Sync node | No — C#/.NET only | Switch the whole project to .NET |
| `godot-onnx-loader` GDExtension | Yes (4.6+) | Third-party dep, per-platform binaries, CI |
| Hand-rolled matmul in GDScript | Yes, any 4.x | ~40 lines + a one-off weight exporter |

## Decision
**Train in Python (stable-baselines3 + godot_rl_agents). Ship inference as a ~40-line GDScript
matrix multiply over weights exported to JSON.**

- Training is unchanged: godot_rl_agents against a headless export, PPO, parallel envs.
- After training, a one-off Python script dumps the policy MLP weights to JSON.
- `RLBrain` loads that JSON and computes the forward pass in GDScript, returning the same
  `choose_action(state) -> String` as `ScriptedBrain` ([0005](0005-architecture.md)).
- No ONNX runtime, no GDExtension, no .NET build, no Python in the shipped game.

## Why
- The policy is tiny (~20 observations, ~6 discrete actions, a small MLP). A forward pass is a
  couple of matrix multiplies — not worth a runtime dependency.
- Switching the project to .NET to get an "experimental" official path is a whole-codebase change
  for one node's benefit.
- A third-party GDExtension means shipping compiled binaries per platform and tracking a small
  addon's maintenance for the life of the game.
- The `Brain` boundary from 0005 contains this entirely — the inference method is an implementation
  detail of `RLBrain` and touches nothing else. If a first-class GDScript ONNX path appears later,
  swapping to it is a one-file change.

## Consequences
- We own the weight-export script and the matmul. Both need a test: same input → same output as
  the Python policy, within float tolerance. This is the regression test that RL inference works.
- If the policy ever grows large (CNN over a rendered view, recurrent policy), this decision must
  be revisited — the matmul approach only stays sane for a small MLP.
- **UNVERIFIED and to confirm at training time:** exact SB3 attribute names for weight extraction
  (`policy.mlp_extractor`, `action_net`) vary by version — check the pinned SB3 version in
  `godot_rl_agents`' requirements before writing the exporter.
- Action masking for cooldowns has no first-class API; default approach is to penalize illegal
  actions in the reward and treat them as no-ops rather than depending on `sb3-contrib`.
