#!/usr/bin/env bash
# Runs every tests/test_*.gd ONE AT A TIME — concurrent Godot instances clash and
# report false failures. Judges by EXIT CODE, not by grepping for "PASS": some
# tests only call quit(0/1).
cd "$(dirname "$0")/.."
fails=0
for t in tests/test_*.gd; do
	printf '%-42s ' "$t"
	if out=$(timeout 60 godot --headless --script "$t" 2>&1); then
		echo PASS
	else
		echo FAIL
		echo "$out" | grep -v '^Godot Engine' | head -15 | sed 's/^/      /'
		fails=$((fails + 1))
	fi
done
echo
echo "$fails failing"
exit $((fails > 0))
