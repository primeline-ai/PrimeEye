#!/bin/bash
# Double-clickable launcher for PrimeEye.
# Looks for PrimeEye.app next to the repo root (one level up from scripts/), then in
# /Applications, then ~/Applications. Adjust APP_PATH below if you keep it elsewhere.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

for candidate in \
  "$REPO_ROOT/PrimeEye.app" \
  "/Applications/PrimeEye.app" \
  "$HOME/Applications/PrimeEye.app"; do
  if [ -d "$candidate" ]; then
    open "$candidate"
    echo "Started: $candidate"
    exit 0
  fi
done

echo "PrimeEye.app not found. Build it first with ./make-app.sh, or move the .app to /Applications."
exit 1
