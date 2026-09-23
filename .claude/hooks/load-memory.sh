#!/usr/bin/env bash
# SessionStart hook: inject every memory file so past mistakes/preferences are always in context.
# ponytail: ~4 chars/token. Warn past 2000 tokens — prune/merge rules instead of raising the cap.
DIR="$(dirname "$0")/../memory"
OUT=$(for f in "$DIR"/*.md; do [ -f "$f" ] && { cat "$f"; echo; }; done)
printf '%s\n' "$OUT"
TOK=$(( ${#OUT} / 4 ))
[ "$TOK" -gt 2000 ] && echo "[load-memory] WARNING: memory is ~${TOK} tokens. Merge/prune .claude/memory/*.md (target < 2000)."
exit 0
