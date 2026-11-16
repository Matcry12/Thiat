# 0017 — Which model does which job

**Status:** Active

## Context

Opus 5.5 and Sonnet 5.5 arrived. We started a lab evaluation (16 runs: build, judge, debug,
explain). After the debug job (4 runs: every run fixed the bug; Opus 5.5 ~2x faster than Sonnet 5),
the user chose to stop: 2 runs per cell cannot tell luck from skill, and the runs delay the game.

## Decision

- `sonnet` means Sonnet 5.5 in this project (`env.ANTHROPIC_DEFAULT_SONNET_MODEL` in
  `.claude/settings.json`). Verified: a Sonnet agent's log shows `claude-sonnet-5-5`.
- Routing table lives in `CLAUDE.md` §1: Opus plans and judges, Sonnet 5.5 builds, Haiku looks up.
- A Sonnet task that fails twice escalates to Opus.
- Each finished slice gets a one-line log (builder, judge findings, user findings) in
  `docs/wiki/prototype-v0.md`. That log replaces the lab evaluation.

## Why

Every slice is already built, tested and judged by a second model. Recording what the judge and the
user found turns normal work into a free, real evaluation — more runs, on real tasks.

## Consequences

- The lab harness stays in `.claude/eval-harness/` (gitignored), unused. Re-run the judge job
  (4 runs) only if the slice log shows Opus judges missing bugs, or to test Sonnet as a judge.
- Changing the Sonnet version = one line in `settings.json`, then restart Claude Code (env is read
  at session start, `/compact` is not enough).
