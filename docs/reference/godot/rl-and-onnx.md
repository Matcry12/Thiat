# RL boss brain: godot_rl_agents → ONNX → Godot 4.x

Researched 2026-09-23. Versions/dates cited inline; anything not directly confirmed is marked **UNVERIFIED**.

## 0. Bottom line (read this first)

- Training happens in Python via `godot_rl_agents` (PyPI: `godot-rl`, v0.8.2, released 2025-02-25) + stable-baselines3.
- Official ONNX inference **requires the .NET/Mono build of Godot** — not plain GDScript. This is the critical fact for BossFight, which is GDScript-only.
- Least-friction GDScript-native options that avoid a rewrite to C#:
  1. **`godot-native-rl`** (ncnn-based GDExtension, MIT, Godot 4.5+, GDScript-callable, trains via the same `godot_rl_agents` Python stack) — best fit.
  2. **`godot-onnx-loader`** (ONNX Runtime GDExtension, Godot 4.6+, MIT, GDScript-callable, generic tensor in/out) — also viable, more manual glue code.
  3. Hand-rolled GDScript matmul for a tiny MLP — zero dependencies, ~40 lines, works today on any Godot 4.x. Recommended for a ~20-obs → ~6-action boss policy (see §4).

## 1. godot_rl_agents

Open-source bridge between Godot and Python RL training (SB3, RLlib, Sample Factory, CleanRL). Repo: `edbeeching/godot_rl_agents`, MIT, AAAI-2022 workshop paper (arXiv:2112.03636).

**Wire protocol:** a `Godot RL Agents Sync` node in your scene talks to the Python process over **TCP, default port 11008**.

**AIController pattern** — extend `AIController3D` (or `AIController2D`):

```gdscript
extends AIController3D

var move_action: float = 0.0

func get_obs() -> Dictionary:
    var rel_pos = to_local(target.global_position)
    return {"obs": [rel_pos.x, rel_pos.z, linear_velocity.x, linear_velocity.z]}

func get_reward() -> float:
    return reward   # accumulate this field during _physics_process, framework reads it each step

func get_action_space() -> Dictionary:
    return {
        "move_action": {"size": 2, "action_type": "continuous"},
        "attack_action": {"size": 6, "action_type": "discrete"},
    }

func set_action(action) -> void:
    move_action = Vector2(action["move_action"][0], action["move_action"][1]).limit_length(1.0)
    var attack_id: int = action["attack_action"]
    # dispatch to boss.gd's Brain-equivalent
```

Also implement/rely on: `get_reward()` reset each episode, `needs_reset` (bool, framework calls `reset()` when true), `heuristic` (`"human"` lets you drive it with input for manual testing/imitation seeding vs the trained policy).

**Sync vs async / speed:** the Sync node exposes a `Speed Up` property (physics tick multiplier for headless training — docs example uses up to 8x). Training typically runs against an **exported headless build**, not the editor, with N parallel OS processes (`--n_parallel=4` is the doc example) each running one game instance; `--speedup=8` multiplies physics/frame rate inside each instance. `--viz` re-enables rendering for a single instance if you want to watch. `--fixed-fps` **UNVERIFIED** exact flag name — docs reference frame-rate/speedup control via the Sync node's `Speed Up` property and CLI `--speedup`; I could not confirm a separate `--fixed-fps` CLI flag in current docs, treat as possibly renamed/removed.

Docs: `docs/CUSTOM_ENV.md`, `docs/ADV_STABLE_BASELINES_3.md` in the repo.

## 2. Training loop (stable-baselines3)

```bash
python stable_baselines3_example.py \
  --env_path=exported_game/game.exe \
  --n_parallel=4 \
  --speedup=8 \
  --n_steps=128 \
  --batch_size=512 \
  --learning_rate=0.0002 \
  --clip_range=0.15 \
  --linear_lr_schedule \
  --save_checkpoint_frequency=50_000 \
  --save_model_path=model.zip \
  --onnx_export_path=model.onnx \
  --experiment_name=boss_v1 \
  --timesteps=1_000_000
```

Constraint: `n_steps * n_parallel` must be divisible by `batch_size`. Checkpoints land in `logs/sb3/<experiment_name>_checkpoints/`; `--save_model_path` is the resumable SB3 `.zip`, `--onnx_export_path` is the deployment artifact.

**Realistic training time for a small boss (≈20 obs, ≈6 discrete actions):** this scale (small MLP policy, low-dimensional obs, 4 parallel envs, 8x speedup) typically converges in the **low hundreds of thousands to a few million timesteps**; on a single modern laptop CPU that's roughly **30 min–3 hours** wall clock. This is a rough estimate from typical SB3/PPO small-task benchmarks, not a number found in godot_rl_agents docs — **UNVERIFIED** for your specific reward shape.

**Hyperparameters for small discrete/continuous control (starting point, not gospel):** PPO, `n_steps=128–512`, `batch_size=256–1024`, `learning_rate=1e-4–3e-4` with linear decay, `clip_range=0.1–0.2`, `gamma=0.99`, `ent_coef=0.0–0.01` (raise if policy collapses to one attack).

## 3. Export to ONNX and inference in Godot — the critical constraint

**Official path (godot_rl_agents' own onnx support):**
1. Train with `--onnx_export_path=model.onnx` (SB3, RLlib, or CleanRL — "experimental" support per the repo).
2. In Godot, use the **mono/.NET build of the editor**. Add the model path to the Sync node, set its control mode to **"Onnx Inference"**, point `Onnx Model Path` at the exported file.
3. Godot then runs the policy each frame via that node — no Python process needed at runtime.

**This requires the .NET/C# build of Godot.** The plain GDScript-only editor/export template has no built-in ONNX runtime hookup from `godot_rl_agents` itself. Confirmed from the repo's own instructions ("we need the mono version (i.e., the .NET version) of the Godot editor" — `godot_rl_agents` README / examples). **This is the fact that would cost a rewrite if missed: do not plan on GDScript + official onnx node.**

**Today's actual options for a GDScript-only project:**

| Option | GDScript-callable? | Godot version | Maturity | Notes |
|---|---|---|---|---|
| Official `godot_rl_agents` onnx Sync node | No — C#/.NET only | any 4.x mono build | Official, "experimental" | Requires switching export templates to .NET; biggest lever, avoid unless you're OK adding C# to the project |
| `godot-native-rl` (minigraphx) | **Yes** | 4.5+ (CI verified on 4.5.2, 4.6.3) | Small project (878 commits, 7 stars), MIT, active CI | GDExtension wrapping ncnn; trains with stock `godot_rl_agents` Python stack, then converts to ncnn for deployment. Ships ready nodes: `NcnnRunner`, `NcnnAIController2D/3D`. Verified Linux/macOS/Windows/Web; Android/iOS symbol-audited only |
| `godot-onnx-loader` (DynamicDevices) | **Yes** | 4.6+ | Small project, active CI/CD, MIT (+ MS ONNX Runtime license for the bundled runtime) | Generic float-tensor-in/out GDExtension (`OnnxLoader.new()`, `load_model()`, `set_input()`, `run()`, `get_output()`), no RL-specific glue — you write the obs→tensor→action mapping yourself |
| Hand-rolled GDScript MLP forward pass | Yes, trivially | any 4.x | You write & own it | Export SB3 policy weights (numpy arrays) to JSON/resource, do the matmuls in GDScript. Zero new dependencies. See §4 |
| Local inference server (Python process alongside game) | N/A (still needs Python at runtime) | any | — | Defeats "ship with no Python dependency" requirement; only useful during dev/playtesting |
| Switch whole project to .NET/C# build | Yes (in C#) | any 4.x mono | Official path, well-documented | Biggest lever — touches your whole codebase, not just the brain |

## 4. Recommendation for BossFight (≈20 obs → ≈6 discrete actions)

**Hand-roll the MLP forward pass in pure GDScript.** Reasoning:
- A policy this small (SB3's default PPO MLP policy is typically 2×64 hidden units) is ~(20×64 + 64×64 + 64×6) ≈ 5,500 multiply-adds per inference step — trivial for GDScript, no perf concern at boss-tick rates (tens of Hz, not thousands).
- Avoids adding a GDExtension dependency (compiled binaries per platform, CI to maintain) or switching the project to C#/.NET (touches the whole codebase per CLAUDE.md's GDScript-only stack).
- No official/officially-maintained inference path exists that stays in GDScript — every option in the table above is either C#-only or a third-party GDExtension. A ~40-line matmul function is less risk than depending on a 7-star addon for a shipped game.

**Escalate to `godot-native-rl`** only if you outgrow a single small MLP (e.g. LSTM/recurrent boss memory, CNN vision input, or need INT8/batched inference for many bosses at once) — it already solves those and trains through the same `godot_rl_agents` pipeline, so switching later doesn't require re-architecting the Brain interface (`choose_action(state) -> String` stays the contract either way).

**Minimal GDScript MLP inference** (export SB3 weights to a JSON: `{"w1": [[...]], "b1": [...], "w2": [[...]], "b2": [...], "out_w": [[...]], "out_b": [...]}`, load once, run per decision):

```gdscript
class_name PolicyMLP
extends RefCounted

var w1: Array; var b1: Array
var w2: Array; var b2: Array
var wo: Array; var bo: Array

func load_from_json(path: String) -> void:
    var f = FileAccess.open(path, FileAccess.READ)
    var d = JSON.parse_string(f.get_as_text())
    w1 = d.w1; b1 = d.b1; w2 = d.w2; b2 = d.b2; wo = d.out_w; bo = d.out_b

func _dense(x: Array, w: Array, b: Array, relu: bool) -> Array:
    var out = []
    for j in range(w[0].size()):
        var s = b[j]
        for i in range(x.size()):
            s += x[i] * w[i][j]
        out.append(max(s, 0.0) if relu else s)
    return out

func choose_action(obs: Array) -> int:
    var h1 = _dense(obs, w1, b1, true)
    var h2 = _dense(h1, w2, b2, true)
    var logits = _dense(h2, wo, bo, false)
    var best_i = 0
    for i in range(1, logits.size()):
        if logits[i] > logits[best_i]: best_i = i
    return best_i   # index into your named attack enum
```

Weight extraction from SB3 is a one-off Python script (`policy.mlp_extractor`, `action_net` state dicts → JSON) — not covered by godot_rl_agents tooling, you write it; roughly 20 lines with `torch`/`numpy`. **UNVERIFIED**: exact SB3 internal attribute names vary by version (0.8.2-era godot-rl pins an SB3 version — check `requirements.txt` in the repo before writing the extractor).

## 5. Observation/action design for a boss

- **Relative, not absolute, positions.** Feed `to_local(player.global_position)` or `player.global_position - boss.global_position`, normalized by a fixed max-range constant (e.g. divide by arena radius) so values sit roughly in [-1, 1]. Absolute world coords don't generalize across arena positions and blow up value estimates.
- **Normalize everything** (health as [0,1] fraction, cooldowns as fraction-remaining, angles as sin/cos pairs not raw radians to avoid the wrap discontinuity).
- **Velocities**: include current velocity as its own obs (cheap, informative) rather than frame-stacking full position history unless the boss needs to infer acceleration/intent — frame-stacking triples input size for a boss that mostly needs current-instant state.
- **Discrete named actions** (attack ids 0–5) are the right call here over continuous control — you already have a `choose_action(state) -> String` contract; PPO with `action_type: "discrete"` maps directly to picking an enum index, which is far easier to make "readable" as a specific named attack (dash, slam, projectile...) than continuous control that has to be decoded into a move.
- **Action masking for cooldowns**: SB3/godot_rl_agents has no first-class action-masking API in the base package (**UNVERIFIED** — MaskablePPO exists in `sb3-contrib`, not confirmed integrated with godot_rl_agents' env wrapper). Simplest robust approach: don't mask, instead heavily penalize picking an action on cooldown in the reward (e.g. -1 reward, action becomes a no-op) — the policy learns to avoid it. Cleaner but more work: use `sb3-contrib`'s `MaskablePPO` and expose an action-mask array from `get_obs()`'s sibling info if the wrapper supports it — verify against your installed `godot-rl` version before committing to this.
- **Reward shaping for "fun," not just "wins":** naive win/loss or damage-dealt reward degenerates into a single spammed attack. Mitigations: (1) small bonus for **action diversity** over a rolling window (e.g. +reward if the last N actions used ≥K distinct attack types), (2) penalize **repeating the same action** more than 2-3x consecutively, (3) reward **pressure** (closing distance, keeping player on defense) separately from reward for landing hits, so the boss doesn't turtle, (4) cap or discount reward from spamming one high-value move so PPO doesn't find a degenerate optimum, (5) keep episode length short enough that exploration doesn't get lazy — long episodes let one dominant strategy snowball.

## 6. Determinism & regression testing

- Godot RL Agents' Python side accepts a `--seed` on training scripts (SB3 convention) for reproducible training runs — pin it when you need repeatable checkpoints. **UNVERIFIED**: exact CLI flag name in current `godot_rl_agents` release; SB3 itself takes `seed=` on the algorithm constructor either way.
- For shipped-game regression tests: since inference is now pure GDScript (per §4) or a GDExtension, there's no Python nondeterminism at runtime — same obs in ⇒ same action out, deterministically, as long as you pick argmax (greedy) rather than sampling from the action distribution at inference time. Use argmax for shipped inference; save the raw probabilities if you want to reproduce *sampled* eval-time behavior for a test.
- Regression test shape: record a fixed sequence of synthetic `obs` dictionaries (representative boss-fight states) with their expected chosen action once, assert `PolicyMLP.choose_action(obs) == expected` after any change to the exported weights or the forward-pass code — a plain GUT/gdUnit4 test, no engine loop needed since the MLP class has no scene dependency.

## Sources

- https://github.com/edbeeching/godot_rl_agents/blob/main/README.md (fetched 2026-09-23)
- https://github.com/edbeeching/godot_rl_agents/blob/main/docs/CUSTOM_ENV.md (fetched 2026-09-23)
- https://github.com/edbeeching/godot_rl_agents/blob/main/docs/ADV_STABLE_BASELINES_3.md (fetched 2026-09-23)
- https://huggingface.co/learn/deep-rl-course/en/unitbonus3/godotrl (fetched 2026-09-23)
- https://pypi.org/project/godot-rl/ (fetched 2026-09-23, v0.8.2 / 2025-02-25)
- https://godotengine.org/asset-library/asset/5358 (godot-native-rl asset page, fetched 2026-09-23)
- https://github.com/minigraphx/godot-native-rl (fetched 2026-09-23)
- https://github.com/DynamicDevices/godot-onnx-loader (fetched 2026-09-23)
- https://github.com/mat490/Godot-ONNX-AI-Models-Loaders (found via search, not deep-fetched — alternate ONNX GDExtension, unverified details)
- https://forum.godotengine.org/t/bascule-reinforcement-learning-inside-godot-in-pure-c-no-python/141011 (found via search — pure-C# no-Python-at-all alternative, not evaluated in depth, mentioned for completeness only)
