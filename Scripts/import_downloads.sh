#!/usr/bin/env bash
# Moves the 6 generated images from ~/Downloads into ArtSource/ (dropping the "3d_" prefix,
# replacing older files) and imports them into the asset catalogs.
#
#   Scripts/import_downloads.sh            # uses ~/Downloads
#   Scripts/import_downloads.sh ~/Desktop  # or another folder
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$HOME/Downloads}"
NAMES=(AppIcon mascot_pointing game_chess game_sudoku game_math game_word)

missing=0
for n in "${NAMES[@]}"; do
  if [[ ! -f "$SRC/3d_$n.png" ]]; then
    echo "Missing: $SRC/3d_$n.png"
    missing=1
  fi
done
if [[ $missing -eq 1 ]]; then
  echo "Nothing was moved. Put all 6 files in $SRC and run this again."
  exit 1
fi

for n in "${NAMES[@]}"; do
  mv -f "$SRC/3d_$n.png" "$ROOT/ArtSource/$n.png"
  echo "Moved 3d_$n.png → ArtSource/$n.png"
done

python3 "$ROOT/Scripts/import_art.py"
echo "Done. Build in Xcode (⌘B), then commit:  git add -A && git commit -m 'Add 3D art' && git push"
