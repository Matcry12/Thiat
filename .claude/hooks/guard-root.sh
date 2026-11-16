#!/usr/bin/env bash
# PreToolUse(Write): block new files in the project root. Rule 4, enforced.
FILE=$(cat | python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)
[ -z "$FILE" ] && exit 0
REL="${FILE#$CLAUDE_PROJECT_DIR/}"
case "$REL" in */*) exit 0 ;; esac                       # in a subfolder: fine
case "$REL" in CLAUDE.md|AGENTS.md|README.md|project.godot|.gitignore|.gitattributes|LICENSE|pyproject.toml|requirements.txt|export_presets.cfg) exit 0 ;; esac
[ -e "$FILE" ] && exit 0                                  # editing an existing root file: fine
echo "[guard-root] Refusing to create '$REL' in project root. Put it in scenes/, scripts/, rl/, docs/wiki|decision|reference/, or .claude/."
exit 2
