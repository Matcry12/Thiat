#!/usr/bin/env bash
# Records the W6 / W8 / W9 demo (title, death drops, pause + settings, save & continue) to docs/demo/w6_w8_w9.mp4.
# XDG_DATA_HOME points at a temp folder so the bot's save + settings never touch the player's own user:// files.
#   tools/demo/record_w6_w8_w9.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
FPS="${FPS:-60}"
TMP="$(mktemp -d)"
RAW="$TMP/demo.avi"
echo "recording (invisible screen)..."
XDG_DATA_HOME="$TMP/data" xvfb-run -a --server-args="-screen 0 1152x648x24" \
	godot --rendering-driver opengl3 --write-movie "$RAW" --fixed-fps "$FPS" \
	--resolution 1152x648 res://tools/demo/w6_w8_w9_demo.tscn 2>&1 | grep -E '^(tree|BEAT|DONE|SCRIPT ERROR|ERROR)' || true
[ -f "$RAW" ] || { echo "no video written" >&2; exit 1; }
echo "encoding..."
ffmpeg -y -loglevel error -i "$RAW" -an -r 30 -vf "scale=1152:-2:out_range=tv,format=yuv420p" -c:v libx264 -color_range tv \
	-crf 27 -movflags +faststart docs/demo/w6_w8_w9.mp4
rm -rf "$TMP"
ls -lh docs/demo/w6_w8_w9.mp4
