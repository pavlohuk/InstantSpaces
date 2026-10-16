#!/bin/bash
# Builds, copies to /Applications, and (re)launches the app.
set -euo pipefail
cd "$(dirname "$0")/.."

Scripts/build-app.sh

pkill -x InstantSpaces 2>/dev/null || true
sleep 0.5
rm -rf "/Applications/InstantSpaces.app"
cp -R "build/InstantSpaces.app" "/Applications/InstantSpaces.app"
open "/Applications/InstantSpaces.app"
echo "Installed and launched /Applications/InstantSpaces.app"
