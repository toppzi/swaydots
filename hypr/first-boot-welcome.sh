#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/swaydots"
STATE_FILE="$STATE_DIR/firstboot-welcome.done"
mkdir -p "$STATE_DIR"

[[ -f "$STATE_FILE" ]] && exit 0
touch "$STATE_FILE"

if command -v notify-send >/dev/null 2>&1; then
  notify-send -a "swaydots" "Welcome to Hyprland" \
"Core keys: Super+Return terminal, Super+Q kill, Super+B browser, Super+E files, Super+W wallpapers, Super+Shift+T themes, Super+Shift+E power menu."
fi
