#!/usr/bin/env bash
# Prints the tests related to files changed vs main (committed on this branch + uncommitted + untracked).
# Used by `tools/run_tests.sh --changed`. Simple text matching, no dependency graph:
#   1. a changed test is picked;
#   2. every test that names a changed file (file name) or a class_name it declares (word match);
#   3. ONE hop: a .tscn / .tres that directly references a changed file, and the tests that name THAT file.
#      Never hops to SKIP_HOP (scenes that nearly every test loads), unless that file itself changed;
#   4. a changed file nothing names: tests whose FILE NAME has a word (4+ letters) of its name or parent folder
#      (scripts/boss/slam_attack.gd -> test_boss_slam.gd), minus the GENERIC words;
#   5. project.godot changed (input map, autoloads) -> every test;
#   6. tests/test_smoke_arena.gd always.
# CHANGED_FILES="a b" (space separated) replaces the git lookup (for tests of this script).
# ponytail: misses use through a scene or a resource two hops away (player.gd -> player.tscn -> arena.tscn),
# code reached only through load() of a computed path, and a deleted file's class name (the file is gone, so
# tests that use only the class are not picked); the full run before commit covers that.
cd "$(dirname "$0")/.."
SKIP_HOP="scenes/arena.tscn scenes/player.tscn"
GENERIC="scripts data scene scenes visual assets tests test base main common"
if [[ -v CHANGED_FILES ]]; then read -ra files <<< "$CHANGED_FILES"
else
	base=$(git merge-base HEAD "${BASE:-main}" 2>/dev/null || echo HEAD)
	mapfile -t files < <({ git diff --name-only "$base"; git ls-files --others --exclude-standard; } | sort -u)
fi

echo tests/test_smoke_arena.gd
for f in "${files[@]}"; do
	case $f in   # a deleted file still counts: the tests that used it must run
		project.godot) ls tests/test_*.gd; exit 0 ;;
		tests/test_*.gd) [[ -f $f ]] && echo "$f" ;;
		*.gd|*.tscn|*.tres|*.gdshader|*.png|*.json|*.cfg)
			group=("$f")   # the file + the scenes / resources that directly reference it (one hop)
			while read -r r; do
				[[ -n $r && " $SKIP_HOP " != *" $r "* ]] && group+=("$r")
			done < <(grep -rlF --include='*.tscn' --include='*.tres' "res://$f" scenes data 2>/dev/null)
			pats=()
			for g in "${group[@]}"; do
				pats+=("$(basename "$g")")
				[[ $g == *.gd ]] && c=$(sed -n 's/^class_name \([A-Za-z0-9_]*\).*/\1/p' "$g" 2>/dev/null | head -1) && [[ -n $c ]] && pats+=("$c")
			done
			picks=$(grep -lwF "${pats[@]/#/-e}" tests/test_*.gd)
			if [[ -z $picks ]]; then   # nothing names it: guess from the words in its name and folder
				b=$(basename "$f"); b=${b%.*}
				for w in $(echo "$b $(basename "$(dirname "$f")")" | tr 'A-Z' 'a-z' | tr -c 'a-z\n' ' '); do
					((${#w} >= 4)) && [[ " $GENERIC " != *" $w "* ]] && picks+=$'\n'$(ls tests/test_*"$w"*.gd 2>/dev/null)
				done
			fi
			[[ -n $picks ]] && echo "$picks" ;;
	esac
done | grep .
exit 0
