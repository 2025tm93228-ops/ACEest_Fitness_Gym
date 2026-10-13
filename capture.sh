#!/usr/bin/env bash
# Screenshot helper for the VM.
#   ./capture.sh 06 pytest-pass        -> docs/screenshots/06-pytest-pass.png
#   ./capture.sh 16 jenkins-green 8    -> same, but waits 8s first (time to switch windows)
set -euo pipefail
cd "$(dirname "$0")"

NUM="${1:?usage: ./capture.sh <number> <short-name> [delay-seconds]}"
NAME="${2:?usage: ./capture.sh <number> <short-name> [delay-seconds]}"
DELAY="${3:-3}"
OUT="docs/screenshots/${NUM}-${NAME}.png"
mkdir -p docs/screenshots

echo "Capturing in ${DELAY}s -> ${OUT}"
echo "Switch to the window you want captured NOW."

if   command -v gnome-screenshot >/dev/null 2>&1; then sleep "$DELAY"; gnome-screenshot -f "$OUT"
elif command -v scrot            >/dev/null 2>&1; then scrot -d "$DELAY" "$OUT"
elif command -v import           >/dev/null 2>&1; then sleep "$DELAY"; import -window root "$OUT"
elif command -v spectacle        >/dev/null 2>&1; then sleep "$DELAY"; spectacle -b -n -o "$OUT"
else
  echo "No screenshot tool found. Install one:"
  echo "    sudo apt-get install -y gnome-screenshot"
  echo "    # or: sudo apt-get install -y scrot"
  exit 1
fi

echo "Saved: $OUT  ($(du -h "$OUT" | cut -f1))"
