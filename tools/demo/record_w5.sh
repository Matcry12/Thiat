#!/usr/bin/env bash
# Records the W5 slime demo (wander, hop telegraph, dodge, kill, gel, bag, F1 circles, leash) to docs/demo/w5_slimes.mp4.
# XDG_DATA_HOME points at a temp folder so the bot's save + settings never touch the player's own user:// files.
#   tools/demo/record_w5.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
FPS="${FPS:-60}"
TMP="$(mktemp -d)"
RAW="$TMP/demo.avi"
echo "recording (invisible screen)..."
# USE_XVFB=0 records on the real display (GPU renders); default is an invisible xvfb screen.
RUN=(xvfb-run -a --server-args="-screen 0 1152x648x24")
[ "${USE_XVFB:-1}" = "0" ] && RUN=()
XDG_DATA_HOME="$TMP/data" "${RUN[@]}" \
	godot --rendering-driver opengl3 --write-movie "$RAW" --fixed-fps "$FPS" \
	--resolution 1152x648 res://tools/demo/w5_slime_demo.tscn 2>&1 | grep -E '^(tree|BEAT|DONE|SCRIPT ERROR|ERROR)' || true
[ -f "$RAW" ] || { echo "no video written" >&2; exit 1; }
echo "encoding..."
ffmpeg -y -loglevel error -i "$RAW" -an -r 30 -vf "scale=1152:-2:out_range=tv,format=yuv420p" -c:v libx264 -color_range tv \
	-crf 27 -movflags +faststart docs/demo/w5_slimes.mp4
rm -rf "$TMP"
ls -lh docs/demo/w5_slimes.mp4
