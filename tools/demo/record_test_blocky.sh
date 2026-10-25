#!/usr/bin/env bash
# Records scenes/demo/test_blocky_demo.tscn to docs/demo/test_blocky.mp4 (same method as record.sh).
set -euo pipefail
cd "$(dirname "$0")/../.."
RAW="$(mktemp -d)/t.avi"
xvfb-run -a --server-args="-screen 0 1152x648x24" \
	godot --rendering-driver opengl3 --write-movie "$RAW" --fixed-fps 60 \
	--resolution 1152x648 res://scenes/demo/test_blocky_demo.tscn 2>&1 | grep -Ev '^(Godot Engine|Vulkan|OpenGL|  )' || true
ffmpeg -y -loglevel error -i "$RAW" -an -vf "scale=1152:-2:out_range=tv,format=yuv420p" -c:v libx264 -color_range tv \
	-crf 22 -movflags +faststart docs/demo/test_blocky.mp4
rm -rf "$(dirname "$RAW")"
ls -lh docs/demo/test_blocky.mp4
