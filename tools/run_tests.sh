#!/usr/bin/env bash
# Runs tests/test_*.gd, each in its own godot process. Judges by EXIT CODE, not by grepping for "PASS":
# some tests only call quit(0/1).
#   tools/run_tests.sh                 all tests, 8 at a time, small test map (192 cells) except REAL_MAP tests
#   tools/run_tests.sh -j 2            two at a time (use this while the PC is in use)
#   tools/run_tests.sh --changed       only tests related to files changed vs main (+ uncommitted)
#   tools/run_tests.sh --failed        only the tests in .godot/test_logs/failed.txt (the last run's failures)
#   tools/run_tests.sh --real-map      every test on the real 512 island (the old behaviour; for comparisons)
#   tools/run_tests.sh tests/test_x.gd ...   just these
# Logs: .godot/test_logs/last.txt (all output), failed.txt (failing paths), <test>.out (one per test; copied at the
# end of a run, last run wins). failed.txt is written only by a full run or --failed, never by named / --changed
# runs. The last line printed is that folder. Run the full suite in the background / with a long timeout (3-5 min).
# Every process gets its own user:// (XDG_DATA_HOME temp dir), so parallel runs - and other worktrees -
# never share save.json / tuning.cfg / test cfg files. That shared folder was why parallel runs clashed.
cd "$(dirname "$0")/.."
# Tests that load arena.tscn (map_seed 0 = random island) get a fixed island, so a tree on the line of
# fire cannot flake a shooting test. Single runs stay random unless you export this yourself.
export BOSSFIGHT_TEST_SEED=${BOSSFIGHT_TEST_SEED:-11}
# Small map by default: the arena builds in 1.8 s instead of 4.6 s (ArenaMap reads this in _ready).
export BOSSFIGHT_TEST_MAP_CELLS=${BOSSFIGHT_TEST_MAP_CELLS:-192}
# Tests the runner does NOT give the small map (variable unset; includes ClassicArena tests whose own layout the
# 192 override would replace): they fail on the small map, or their point is the map / a seed.
REAL_MAP="arena_map boss_bodies boss_bolts boss_parry_charge boss_phase2 boss_spread bow_shoots brain_contract chunk_deco_orientation chunks debug_contract dummy_fits enemy_slime enemy_spawner f3_startup ground_bake island_arena island_gen island_nodes map_gen map_gen_pins map_size pickup pixel_plains_ground pp_veg resource_node hotbar_select inventory_judge_fixes tool_target save_game smoke_arena station_placement tuning_panel water water_edge weapon_model_geometry ysort_props"
# Red on main, not caused by a change; they still run and print, but do not fail the run. Each needs a fix.
#   player_animation: red on main (2026-11-05)   run_dust_shadow: red on main (2026-11-05)
KNOWN_RED="tests/test_player_animation.gd tests/test_run_dust_shadow.gd"
# Tests that write repo files (res://) while running; they run alone after the parallel batch so no other
# test loads a half-edited file. test_save_rig rewrites the player's BodyRig .tres, then puts it back.
SERIAL="tests/test_save_rig.gd"
# Tests with a wall-clock speed budget ("built in < 600 ms"). Eight tests at once slow every process, so a
# budget can miss under load. If one of these fails in the batch it runs again ALONE: the result alone counts.
SPEED="tests/test_f3_startup.gd tests/test_chunks.gd tests/test_water.gd tests/test_island_nodes.gd tests/test_station_placement.gd tests/test_island_arena.gd"
logs=.godot/test_logs

jobs=8
changed=0; failed=0; realall=0
tests=()
while (($#)); do
	case $1 in
		-j) jobs=$2; shift ;;
		-j*) jobs=${1#-j} ;;
		--changed) changed=1 ;;
		--failed) failed=1 ;;
		--real-map) realall=1 ;;
		*) tests+=("$1") ;;
	esac
	shift
done
mkdir -p "$logs"
writefailed=$failed; ((${#tests[@]} == 0 && !changed)) && writefailed=1   # full run or --failed
if ((failed)); then   # read the last failures BEFORE this run overwrites them
	[[ -f $logs/failed.txt ]] || { echo "no $logs/failed.txt yet: run the full suite first"; exit 1; }
	mapfile -t tests < <(grep . "$logs/failed.txt")
	((${#tests[@]})) || { echo "no failed tests in $logs/failed.txt"; exit 0; }
fi
((${#tests[@]})) || mapfile -t tests < <(ls tests/test_*.gd)
if ((changed)); then
	mapfile -t tests < <(tools/changed_tests.sh | sort -u)
	((${#tests[@]})) || { echo "no tests match the changed files"; exit 0; }
fi

main() {
# Import new / changed assets ONCE before the batch; otherwise every parallel process tries to import
# the same files into .godot/ at the same time (a fresh worktree has no .godot/ at all).
stamp=.godot/.tests_imported
if [[ ! -f $stamp ]] || [[ -n $(find assets data scenes -newer "$stamp" -print -quit 2>/dev/null) ]]; then
	if timeout 300 godot --headless --import >/dev/null 2>&1; then touch "$stamp"
	else echo "WARNING: godot --import failed or timed out (300 s); stamp not updated, running the tests anyway"; fi
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/out"; touch "$work/res"   # per-run output; copied to $logs at the end, so a second run cannot delete what this one judges
export work realall REAL_MAP

# One test: own fresh user dir, fixed 1/60 s frames (a busy CPU cannot change frame-timed results), result line "PASS|FAIL <ms> <test>" in $work/res, output in $work/out/<name>.out.
run_one() {
	local t=$1 name; name=$(basename "$t" .gd)
	local t0; t0=$(date +%s%N)
	local envs=(-u BOSSFIGHT_UNSET_NOTHING)
	if ((realall)) || [[ " $REAL_MAP " == *" ${name#test_} "* ]]; then envs=(-u BOSSFIGHT_TEST_MAP_CELLS); fi
	local o="$work/out/$name.out" code
	XDG_DATA_HOME=$(mktemp -d -p "$work") env "${envs[@]}" timeout 60 godot --headless --fixed-fps 60 --script "$t" >"$o" 2>&1; code=$?
	((code == 0)) && r=PASS || r=FAIL
	echo "$code" > "$work/out/$name.code"
	# The smoke test runs the real arena: any script error or engine ERROR fails it even if every check passed
	# (only the at-exit "resources still in use" leak line is ignored).
	[[ $name == test_smoke_arena ]] && grep -E '^(SCRIPT )?ERROR' "$o" | grep -qv 'resources still in use' && r=FAIL
	local ms=$(( ($(date +%s%N) - t0) / 1000000 ))
	printf '%-42s %s %6.1fs\n' "$t" "$r" "$(bc <<< "scale=1; $ms/1000")"
	echo "$r $ms $t" >> "$work/res"
}
export -f run_one

start=$(date +%s%N)
par=(); ser=()
for t in "${tests[@]}"; do [[ " $SERIAL " == *" $t "* ]] && ser+=("$t") || par+=("$t"); done
((${#par[@]})) && printf '%s\n' "${par[@]}" | xargs -P "$jobs" -I{} bash -c 'run_one "$1"' _ {}
for t in "${ser[@]}"; do run_one "$t"; done
for t in $SPEED; do
	if grep -q "^FAIL [0-9]* $t\$" "$work/res"; then
		echo "  (speed budget missed under load: $t again, alone)"
		sed -i "\| $t\$|d" "$work/res"
		run_one "$t"
	fi
done
wall=$(( ($(date +%s%N) - start) / 1000000 ))

# every picked test must have produced a result line
missing=()
for t in "${tests[@]}"; do grep -q " $t\$" "$work/res" || missing+=("$t"); done
if ((${#missing[@]})); then echo; echo "ERROR: no result for ${#missing[@]} test(s):"; printf '  %s\n' "${missing[@]}"; fi

# known red: still run and shown, never fail the run
fails=0; red=0
: > "$work/failed.txt"
while read -r r _ t; do
	if [[ " $KNOWN_RED " == *" $t "* ]]; then
		if [[ $r == FAIL ]]; then red=$((red+1)); else echo "$t passes now: remove it from KNOWN_RED"; fi
	elif [[ $r == FAIL ]]; then fails=$((fails+1)); echo "$t" >> "$work/failed.txt"
	fi
done < "$work/res"
show() {   # failure lines first (max 15), then where the full output is
	local n; n=$(basename "$1" .gd)
	local code; code=$(cat "$work/out/$n.code" 2>/dev/null)
	{ ((code == 124)) && echo "timed out (60 s)" || echo "exit code $code"; grep -E 'FAIL|ERROR' "$work/out/$n.out" | head -15; } | sed 's/^/      /'
	echo "      full output: $logs/$n.out"
}
if ((fails)); then
	echo; echo "=== failures ==="
	while read -r t; do echo "$t"; show "$t"; done < "$work/failed.txt"
fi
if ((red)); then
	echo; echo "=== known red (not counted) ==="
	for t in $KNOWN_RED; do grep -q "^FAIL [0-9]* $t\$" "$work/res" && { echo "$t"; show "$t"; }; done
fi
echo; echo "slowest 15:"
sort -k2 -n -r "$work/res" | head -15 | awk '{printf "  %6.1fs  %s\n", $2/1000, $3}'
printf '\n%d tests, %d failing, %d known red, wall %.1fs (-j %s)\n' "$(wc -l < "$work/res")" "$fails" "$red" "$(bc <<< "scale=1; $wall/1000")" "$jobs"
echo "log: $logs/last.txt"
cp "$work"/out/*.out "$logs"/ 2>/dev/null
((writefailed)) && { cp "$work/failed.txt" "$logs/failed.tmp.$$" && mv "$logs/failed.tmp.$$" "$logs/failed.txt"; }
return $((fails > 0 || ${#missing[@]} > 0))
}
set -o pipefail
main 2>&1 | tee "$logs/last.txt"
exit "${PIPESTATUS[0]}"
