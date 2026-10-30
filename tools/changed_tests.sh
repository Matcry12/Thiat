#!/usr/bin/env bash
# Prints the tests related to files changed vs main (committed on this branch + uncommitted + untracked).
# Used by `tools/run_tests.sh --changed`. Simple text matching, no dependency graph:
#   1. a changed test is picked;
#   2. every .tscn / .tres that references a changed file, transitively (player.gd -> player.tscn -> arena.tscn);
#   3. every test that names one of those files (res:// path or file name) or a class_name they declare.
# ponytail: misses code reached only through load() of a computed path; the full suite before commit covers that.
cd "$(dirname "$0")/.."
base=$(git merge-base HEAD "${BASE:-main}" 2>/dev/null || echo HEAD)
mapfile -t files < <({ git diff --name-only "$base"; git ls-files --others --exclude-standard; } | sort -u)

declare -A seen
queue=()
for f in "${files[@]}"; do
	case $f in   # a deleted file still counts: the tests that used it must run
		tests/test_*.gd) [[ -f $f ]] && echo "$f" ;;
		*.gd|*.tscn|*.tres|*.gdshader|*.png|*.json|*.cfg) seen[$f]=1; queue+=("$f") ;;
	esac
done
# Walk up: resources that reference a seen file are affected too.
while ((${#queue[@]})); do
	f=${queue[0]}; queue=("${queue[@]:1}")
	while read -r r; do
		[[ -n $r && -z ${seen[$r]} ]] && { seen[$r]=1; queue+=("$r"); }
	done < <(grep -rlF --include='*.tscn' --include='*.tres' "res://$f" scenes data 2>/dev/null)
done

pats=()
for f in "${!seen[@]}"; do
	pats+=("$(basename "$f")")
	[[ $f == *.gd ]] && c=$(sed -n 's/^class_name \([A-Za-z0-9_]*\).*/\1/p' "$f" 2>/dev/null | head -1) && [[ -n $c ]] && pats+=("$c")
done
((${#pats[@]})) && grep -lwF "${pats[@]/#/-e}" tests/test_*.gd
