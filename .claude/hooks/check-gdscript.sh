#!/usr/bin/env bash
# PostToolUse(Edit|Write): parse-check any edited .gd file. No-op if godot isn't on PATH.
FILE=$(cat | python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)
case "$FILE" in *.gd) ;; *) exit 0 ;; esac
GODOT=$(command -v godot || command -v godot4) || { echo "[check-gdscript] godot not on PATH — parse-check skipped, run it manually"; exit 0; }
OUT=$(cd "$CLAUDE_PROJECT_DIR" && timeout 60 "$GODOT" --headless --check-only --script "$FILE" 2>&1)
if printf '%s' "$OUT" | grep -qiE 'error|parse'; then
  printf '[check-gdscript] %s FAILED:\n%s\n' "$FILE" "$OUT"
  exit 2   # ponytail: exit 2 = feed back to Claude as blocking error
fi
exit 0
