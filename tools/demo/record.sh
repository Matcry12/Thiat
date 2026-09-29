#!/usr/bin/env bash
# Records a scripted playthrough to docs/demo/<name>.mp4 — no keyboard, no
# window on your desktop (xvfb = an invisible screen).
#
#   tools/demo/record.sh slice3-parry
#   tools/demo/record.sh slice3a-weapons --scenario=weapons
#
# Everything after <name> is forwarded to Godot as user args (after `--`),
# which demo_bot.gd reads via OS.get_cmdline_user_args() to pick a storyboard.
#
# Godot's movie-maker mode (--write-movie) writes one frame per tick to an AVI
# instead of drawing in real time, so the result is smooth even when rendering
# is slower than 60fps. ffmpeg then makes it small enough to send.
set -euo pipefail
cd "$(dirname "$0")/../.."

NAME="${1:-demo}"
shift || true
FPS="${FPS:-60}"
OUT_DIR="docs/demo"
RAW="$(mktemp -d)/${NAME}.avi"
mkdir -p "$OUT_DIR"

echo "recording (invisible screen, no window will open)..."
xvfb-run -a --server-args="-screen 0 1152x648x24" \
	godot --rendering-driver opengl3 --write-movie "$RAW" --fixed-fps "$FPS" \
	--resolution 1152x648 res://tools/demo/demo.tscn -- "$@" 2>&1 \
	| grep -Ev '^(Godot Engine|Vulkan|OpenGL|  )' || true

[ -f "$RAW" ] || { echo "no video written — see the log above" >&2; exit 1; }

echo "encoding..."
ffmpeg -y -loglevel error -i "$RAW" -vf "scale=1152:-2" -c:v libx264 -pix_fmt yuv420p \
	-crf 24 -movflags +faststart "$OUT_DIR/${NAME}.mp4"
rm -rf "$(dirname "$RAW")"

ls -lh "$OUT_DIR/${NAME}.mp4"
