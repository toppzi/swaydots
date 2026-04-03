#!/usr/bin/env bash
# Re-apply last wallpaper (runs on every sway reload via exec_always).
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/wallpaper-lib.sh"

if wallpaper_restore_if_possible; then
  exit 0
fi
# State missing or image path gone (e.g. HDD unmounted): pick a new random one if possible.
exec "$SCRIPT_DIR/wallpaper.sh"
