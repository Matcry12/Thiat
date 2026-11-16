# Testing algorithm: how we keep tests fast and still catch bugs

**Status:** Current

Status: approved 2026-11-06, decision [0062](../decision/0062-test-levels-by-change-size.md).

Goal: a small change spends seconds on tests, not minutes. Real bugs must still be caught before commit.

## Where the time goes (measured 2026-11-05, 110 tests, `-j 2`)

| What | Number | What it means |
|---|---|---|
| Full suite | 296 s wall, 578 s of test time | 5 minutes each run |
| Godot start, empty script | 0.4 s | Starting a new process per test is NOT the problem |
| Load the real arena, one time | 4.6 s (1.1 s load files + 3.4 s build the island) | This is the problem: 61 tests pay it |
| Same arena, 192-cell map | 1.8 s | Saves 2.8 s per test |
| `--changed` after editing `player.gd` | picks 75 of 110 tests | Almost the full suite, about 200 s. It follows player -> player scene -> arena -> every test using the arena |
| Tests that name `player.gd` directly | 5 tests | What a small player change really needs first |
| Parse check after each edit (hook) | 0.9 s | Fine, keep it |

From the session logs since 2026-11-01 (8 sessions, a small sample):

| What | Number | What it means |
|---|---|---|
| Full suite runs | 31 in 8 sessions, 13 in one session | The "once before commit" rule is not followed |
| Suite killed by the 120 s Bash limit | about 4 runs | Two minutes wasted, no result, run again |
| Suite run again soon after a run | seen on 11-01 (10:06 then 10:09) | One cause: `tail` / `grep` hid the names of the failed tests |
| Base failures | 2 or 3 tests red in almost every run | Each agent must work out again that these are not its fault |
| Small coding turns (1-3 code files) | 13 turns, 114 min, 34 min of it test commands | 30 % is tests. Worst turn: 25 min, 13 min of tests, 23 runs |
| Judge | 16 judges, about 2.8 min each | Cheap per judge. The cost is the fix round after it |
| Bare `godot --script tests/...` | 66 runs, no time limit in many | One of these hung for 1 hour once |

## Sources: how others do it

| Who | What they do | What we take |
|---|---|---|
| [Factorio FFF #60](https://factorio.com/blog/post/fff-60) | Fast unit tests load no graphics or prototypes. Integration tests build a small map, run it, and check the result | Most tests use a **small map**. It is still the real game code |
| [Factorio FFF #315](https://factorio.com/blog/post/fff-315) | Heavy tests take 400-600 s. They moved to servers that run after each commit, so developers do not run them locally | Heavy tests do not belong in the fix round |
| [Rare, Sea of Thieves](https://gamedeveloper.com/design/how-rare-automates-testing-for-ai-and-more-in-sea-of-thieves-part-4-of-4-) | Most tests are unit tests. Smaller tests run about every 20 minutes, big ones overnight. Humans still judge polish | Tiers. Feel is left to playtest |
| [Riot, League of Legends](https://www.riotgames.com/en/news/automated-testing-league-legends) | 5,500 tests in about 18 min. A small smoke set guards each deploy. New tests stay in "staging" for a week. Tests wait on conditions, not on sleep | Small smoke set. Unreliable tests are kept apart, so they do not block |
| [Google SWE book, ch. 11](https://abseil.io/resources/swe-book/html/ch11.html) | Test size means limits, not lines. Suggested mix: about 80 % unit, 15 % integration, 5 % end to end | Be strict about what a test is allowed to load |
| [Unity Test Framework](https://docs.unity3d.com/Packages/com.unity.test-framework@1.4/manual/edit-mode-vs-play-mode-tests.html) | Prefer a plain test unless it must wait for frames | New logic tests should not load the arena |
| [Godot engine docs](https://docs.godotengine.org/en/stable/engine_details/architecture/unit_testing.html) | Filter tests by name. Stress tests can be excluded | Run tests by name |
| [GUT](https://gut.readthedocs.io/en/latest/Command-Line.html) | Run a part of the tests by file or name | We already have this in `run_tests.sh`. No need to move to a framework |

Could not read: Unreal's automation guide (page empty or blocked), so nothing here relies on it. Speed comparison of GUT and gdUnit4: only one anecdote found, not used.

## Our rules

**Three test levels**

| Level | When | What runs | Time |
|---|---|---|---|
| Quick | Every fix round | Tests that name the changed file, plus one real-arena smoke test. A file with no such test uses tests with a matching name or folder word | Usually seconds. A class used everywhere, like `Health`, picks many tests |
| Full | Once, just before commit, or when the user asks. After a fix: `--failed`, then `--changed`; shared code gets one more Full | All tests. Most on the small map | About 210 s |
| Playtest | The user | Feel, timing, looks | Not automatic |

**Size of the change decides the work**

| Size | Example | Builder | Judge | Tests |
|---|---|---|---|---|
| Small | Change a number, fix one function, 1-3 code files, no new system | No, do it directly | No | Quick |
| Normal | New feature, or more than 3 code files | Yes | Yes, one round, then only what changed | Quick in rounds, Full once |
| Risky | Save format, map generation, shared combat code | Yes | Yes | Full once. Add `--real-map` if the change could depend on island size |

If a small change grows, it becomes normal. No test is removed.

**Test-run habits**
- Use `run_tests.sh`, not bare `godot --script`, because it has a time limit.
- Run the Full level in the background, because of the 120 s Bash limit.
- Read the saved log. Do not run the suite again to see what failed.

**Known red tests** are listed by name with a reason. They still run and are still shown, but they do not make the run fail. A red test on this list must have a follow-up to fix it.

## What we do not do, and why

- **Move to GUT or gdUnit4:** start time is only 0.4 s, so it would not save time. It means rewriting 110 tests.
- **Share one arena between tests:** faster, but one test can leave a mess that breaks the next one. Tests would pass or fail by order.
- **Delete tests:** not needed.
- **Build server at night:** we have no server. The Full level before commit does that job.

## Tuning

| Value | Start | Where |
|---|---|---|
| Small map size | 192 cells (96 saves only 0.4 s more) | `run_tests.sh` |
| `REAL_MAP`: tests where the runner sets no small map | 36 tests: they fail on small, are about the map or a seed, or use their own small layout (ClassicArena), plus the smoke test | `run_tests.sh` |
| Small change limit | 3 code files | `CLAUDE.md` rule 2 |
| Time limit per test | 60 s (already there) | `run_tests.sh` |

## How we check it

Plant real bugs, one at a time. The old-style and new full runs must catch the same ones. Quick misses show the risk of skipping Full during fix rounds.

## Results (2026-11-06, `-j 2`, 111 tests)

| Same task | Before | After |
|---|---|---|
| Full suite | 296 s | 213 s |
| Tests in a fix round, one edit to `player.gd` | 231 s, 75 tests | 10 s, 6 tests |
| Tests for that small change, including one full run | 527 s | 223 s, and the full run only happens at commit |

Quick time depends on the file: 9-80 s across the planted bugs (2 to 40 tests).

| Planted bug | Old full | New full | Quick | Quick time |
|---|---|---|---|---|
| Armor adds damage (`health.gd`) | 6 tests fail | same 6 | same 6 | 70 s |
| Boss slam never hits (`slam_attack.gd`) | 1 | same 1 | same 1 | 16 s |
| No clear land at home (`map_gen.gd`) | 3 | same 3 | same 3 | 80 s |
| Save stores wrong seed (`save_game.gd`) | 1 | same 1 | same 1 | 9 s |
| Parry works from behind (`guard.gd`) | **missed** | missed | missed | 33 s |
| Weapons stack (`item_data.gd`) | **missed** | missed | missed | 33 s |

The new setup lost nothing. The last two are holes that were already in the tests: no test catches these bugs in any run. Six bugs is a small sample, not proof. `boss.gd` and `health.gd` still pick many tests (78 and 40).
