# CLAUDE.md — Operating Plan

This file is the **plan**. Read it, follow it, every task.

## 1. Spawn an agent, or do it yourself?

Before starting any task, ask this **first**:

> Should this be delegated to an agent, or done inline?

- **Delegate** (spawn a subagent on the *lowest capable model*) when the work is:
  multi-file, repetitive, a search sweep, a refactor, drafting, or anything that
  would dump lots of output into this context. Keep only the *conclusion* here.
  - `haiku` — lookups, mechanical edits, per-item classification, bulk work.
  - `sonnet` — standard implementation, drafts, refactors, multi-file edits.
  - `opus` — planning, architecture, review/critique only. **Not the doer.**
- **Do it yourself** only for: trivial single edits, one command, a quick answer,
  a small change (rule 2.4), or config in `.claude/**` / `CLAUDE.md` / `docs/**`.

Default bias: **delegate the doing, keep the deciding.**

**Which model for which job** ([0017](docs/decision/0017-model-routing.md)). In this project
`sonnet` = **Sonnet 5.5** (set in `.claude/settings.json`), `opus` = Opus 5.5.

| Job | Model | Why |
|---|---|---|
| Plan a slice, split it into tasks, decide design | Opus (main loop) | Deciding is where mistakes cost most |
| Design question, "what should this be?" | `design-panel` skill: 5 `design-*` Sonnet agents in parallel, Opus merges | The user is new to design; several views beat one ([0051](docs/decision/0051-agent-team.md)) |
| Build a slice / feature, write tests, refactor | `godot-builder` (Sonnet 5.5), several in parallel by file (`build-slice` skill) | Normal coding; tested and judged after |
| Judge Sonnet's work (rule 2.4) | `slice-judge` (Opus), fresh context, one per builder as it lands | A weak judge hides bugs; nobody sees them until playtest |
| Judge work Opus did itself | `slice-judge` with `model: sonnet` | Different eyes matter more than strength |
| Hard bug (flaky, timing, "can't reproduce") | Opus agent | Opus 5.5 was 2x faster on our debug test; both fixed it |
| Exact steps + an auto-check (`--check-only`, tests), text only: renames across files, same `@export` / F3 line in N scripts, test scaffolds from written cases, N items / recipes from a table, doc table updates | DeepSeek flash (`ds`, `deepseek:deepseek` skill; thinking is always on, `--effort` does nothing); fails twice -> Sonnet | ~1/50 of Sonnet's cost; Sonnet decides once, `ds` fills each row in parallel |
| Lookups, file sweeps, blind grading, mechanical edits with no check, anything with pictures | Haiku agent | Cheap and enough |
| Explain to the user | Opus (main loop) | It holds the conversation |

**Escalate, don't retry blind:** if a Sonnet agent fails the same task twice (tests red, or the
judge confirms a real bug twice), give that task to an Opus agent. Note it in the slice log.

**Slice log = the real-world score.** When a slice is done, add one line under that slice in
`docs/wiki/v1-design.md` §13: who built it, what the judge found, what the user found. After a few
slices this tells us where each model is weak — better data than a lab test.


## 2-8. Project rules

@AGENTS.md

All project rules (verify, mistakes, tidy files, build for replacement, how to talk to the user,
test mode, project facts) live in [AGENTS.md](AGENTS.md), same section numbers, so every model
reads the same rules. This file keeps only Claude-specific setup (§1 above). Edit rules there, not here.
