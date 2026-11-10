#!/usr/bin/env bash
# Records the sound-system demo WITH AUDIO to docs/demo/sound_system.mp4. Runs on the real display (one Godot, GPU).
# XDG_DATA_HOME points at a temp folder so the demo never touches the player's own user:// files.
#   tools/demo/record_sound.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
FPS="${FPS:-60}"
TMP="$(mktemp -d)"
RAW="$TMP/demo.avi"
echo "recording (real display)..."
XDG_DATA_HOME="$TMP/data" timeout "${MAXSEC:-240}" godot --write-movie "$RAW" --fixed-fps "$FPS" --resolution 1152x648 \
	res://tools/demo/sound_demo.tscn 2>&1 | grep -E '^(BEAT|DONE|SCRIPT ERROR|ERROR)' || true
[ -f "$RAW" ] || { echo "no video written" >&2; exit 1; }
echo "encoding..."
ffmpeg -y -loglevel error -i "$RAW" -r 30 -vf "scale=1152:-2:out_range=tv,format=yuv420p" -c:v libx264 -color_range tv \
	-crf 27 -c:a aac -b:a 128k -movflags +faststart docs/demo/sound_system.mp4
rm -rf "$TMP"
ls -lh docs/demo/sound_system.mp4
