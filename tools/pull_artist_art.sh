#!/usr/bin/env bash
# Copy new / changed art from the artist's Google Drive folder into assets/source/artist_inbox/.
# Setup + how to move art into the game: assets/source/artist_inbox/README.md
set -euo pipefail

REMOTE="matcry"          # rclone remote name (rclone config)
DRIVE_FOLDER="GameDev (NAT - PNH)" # her folder on Drive
SHARED_WITH_ME=0      # 1 = folder is in "Shared with me", 0 = in My Drive

cd "$(dirname "$0")/.."
command -v rclone >/dev/null || { echo "rclone missing: sudo apt install rclone"; exit 1; }
[ "$DRIVE_FOLDER" != "CHANGE_ME" ] || { echo "Set DRIVE_FOLDER in $0"; exit 1; }

# copy (not sync): never deletes local files. Skip Drive-only docs (Google Docs/Sheets).
rclone copy "$REMOTE:$DRIVE_FOLDER" assets/source/artist_inbox \
  --drive-skip-gdocs --exclude "/README.md" --exclude "*.import" --progress \
  $( [ "$SHARED_WITH_ME" = 1 ] && echo --drive-shared-with-me ) "$@"

echo "New / changed since last commit:"
git status --short assets/source/artist_inbox
