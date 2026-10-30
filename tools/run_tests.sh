#!/usr/bin/env bash
# Runs tests/test_*.gd, each in its own godot process. Judges by EXIT CODE, not by grepping for "PASS":
# some tests only call quit(0/1).
#   tools/run_tests.sh                 all tests, 8 at a time
#   tools/run_tests.sh -j 1            one at a time
#   tools/run_tests.sh --changed       only tests related to files changed vs main (+ uncommitted)
#   tools/run_tests.sh tests/test_x.gd ...   just these
# Every process gets its own user:// (XDG_DATA_HOME temp dir), so parallel runs - and other worktrees -
# never share save.json / tuning.cfg / test cfg files. That shared folder was why parallel runs clashed.
cd "$(dirname "$0")/.."
# Tests that load arena.tscn (map_seed 0 = random island) get a fixed island, so a tree on the line of
# fire cannot flake a shooting test. Single runs stay random unless you export this yourself.
export BOSSFIGHT_TEST_SEED=${BOSSFIGHT_TEST_SEED:-11}
# Tests that write repo files (res://) while running; they run alone after the parallel batch so no other
# test loads a half-edited file. test_save_rig rewrites the player's BodyRig .tres, then puts it back.
SERIAL="tests/test_save_rig.gd"
# Tests with a wall-clock speed budget ("built in < 600 ms"). Eight tests at once slow every process, so a
# budget can miss under load. If one of these fails in the batch it runs again ALONE: the result alone counts.
SPEED="tests/test_f3_startup.gd tests/test_chunks.gd tests/test_water.gd tests/test_island_nodes.gd tests/test_station_placement.gd tests/test_island_arena.gd"

jobs=8
changed=0
tests=()
while (($#)); do
	case $1 in
		-j) jobs=$2; shift ;;
		-j*) jobs=${1#-j} ;;
		--changed) changed=1 ;;
		*) tests+=("$1") ;;
	esac
	shift
done
((${#tests[@]})) || mapfile -t tests < <(ls tests/test_*.gd)
if ((changed)); then
	mapfile -t tests < <(tools/changed_tests.sh | sort -u)
	((${#tests[@]})) || { echo "no tests match the changed files"; exit 0; }
fi

# Import new / changed assets ONCE before the batch; otherwise every parallel process tries to import
# the same files into .godot/ at the same time (a fresh worktree has no .godot/ at all).
stamp=.godot/.tests_imported
if [[ ! -f $stamp ]] || [[ -n $(find assets data scenes -newer "$stamp" -print -quit 2>/dev/null) ]]; then
	godot --headless --import >/dev/null 2>&1 && touch "$stamp"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export work

# One test: own fresh user dir, fixed 1/60 s frames (a busy CPU cannot change frame-timed results), result line "PASS|FAIL <ms> <test>" in $work/res, output in $work/<name>.out.
run_one() {
	local t=$1 name; name=$(basename "$t" .gd)
	local t0; t0=$(date +%s%N)
	if XDG_DATA_HOME=$(mktemp -d -p "$work") timeout 60 godot --headless --fixed-fps 60 --script "$t" >"$work/$name.out" 2>&1; then r=PASS; else r=FAIL; fi
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

fails=$(grep -c '^FAIL' "$work/res")
if ((fails)); then
	echo; echo "=== failures ==="
	grep '^FAIL' "$work/res" | while read -r _ _ t; do
		echo "$t"
		grep -v '^Godot Engine' "$work/$(basename "$t" .gd).out" | head -15 | sed 's/^/      /'
	done
fi
echo; echo "slowest 15:"
sort -k2 -n -r "$work/res" | head -15 | awk '{printf "  %6.1fs  %s\n", $2/1000, $3}'
printf '\n%d tests, %d failing, wall %.1fs (-j %s)\n' "$(wc -l < "$work/res")" "$fails" "$(bc <<< "scale=1; $wall/1000")" "$jobs"
exit $((fails > 0))
