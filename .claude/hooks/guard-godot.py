#!/usr/bin/env python3
# PreToolUse(Bash): two test habits that cost real time (decision 0058), enforced.
#   1. `godot --script` without `timeout`: one hung for an hour unnoticed.
#   2. The full test suite in the foreground under a short limit: Bash kills it at 120 s, no result.
# ponytail: reads the command as text; a godot call hidden in a script or variable gets through.
import json, re, sys

tool = json.load(sys.stdin).get("tool_input", {})
cmd = re.sub(r"<<-?\s*['\"]?(\w+)['\"]?.*?\n\s*\1\b", "", tool.get("command", ""), flags=re.S)  # no heredoc text
cmd = re.sub(r"\$\([^()]*\)", "x", cmd)                       # VAR=$(mktemp -d) is one word
cmd = re.sub(r"\"[^\"]*\"|'[^']*'", "x", cmd)                 # no quoted text: commit messages, grep patterns
cmd = re.sub(r"\d*>>?&?\s*\S+", "", cmd)                      # no redirect targets (> /tmp/test_out.txt)
PREFIX = r"(?:time\s+|env\s+|\w+=\S*\s+)*"
for seg in re.split(r"[;&|\n]+", cmd):
	seg = seg.strip().lstrip("(").strip()
	if re.match(PREFIX + r"(?:\S*/)?godot4?\s", seg) and "--script" in seg and "--check-only" not in seg:
		print("[guard-godot] godot --script needs a time limit: `timeout 60 godot ...`, or use tools/run_tests.sh.", file=sys.stderr)
		sys.exit(2)
	full = re.match(PREFIX + r"(?:timeout\s+\S+\s+)?(?:bash\s+)?\S*run_tests\.sh\b(.*)", seg)
	if full and not re.search(r"test_|tests/|--changed|--failed", full.group(1)):
		if not tool.get("run_in_background") and tool.get("timeout", 0) < 400000:
			print("[guard-godot] The full suite takes minutes: set run_in_background (or timeout >= 400000). Results stay in .godot/test_logs/last.txt.", file=sys.stderr)
			sys.exit(2)
sys.exit(0)
