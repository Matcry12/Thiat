#!/usr/bin/env bash
# UserPromptSubmit hook: if the prompt looks like a correction, remind Claude to log it.
# ponytail: keyword regex, extend the pattern when a real correction slips through.
PROMPT=$(cat | python3 -c 'import sys,json; print(json.load(sys.stdin).get("prompt",""))' 2>/dev/null)
if printf '%s' "$PROMPT" | grep -qiE '^(no[,. ]|nope|wrong)|not (that|what i)|don.?t (do|use|touch|ever)|\b(not|never|don.?t|didn.?t)\b[^.]*\b(again|twice)\b|i (told|said|asked)|stop (doing|using)|you (broke|missed|forgot|ignored)|why did you|that.?s (wrong|not)'; then
  cat <<'MSG'
[correction-detector] This prompt looks like a correction. If Claude made a real mistake:
1. Append ONE line to .claude/memory/mistakes.md now: `- YYYY-MM-DD: <what went wrong> → <rule>`
2. Then fix the issue. Never repeat a rule already in that file.
MSG
fi
exit 0
