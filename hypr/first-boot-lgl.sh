#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/swaydots"
STATE_FILE="$STATE_DIR/lgl-firstboot.done"
mkdir -p "$STATE_DIR"

[[ -f "$STATE_FILE" ]] && exit 0
touch "$STATE_FILE"

# Prefer opening LGL on first boot if installed.
if command -v lgl-system-loadout >/dev/null 2>&1; then
  nohup lgl-system-loadout >/dev/null 2>&1 &
  exit 0
fi

# Fallback: welcome notification with keybinds + LGL hint.
if command -v notify-send >/dev/null 2>&1; then
  notify-send -a "swaydots" "Welcome to Hyprland" \
"Core keys: Super+Return terminal, Super+Q kill, Super+B browser, Super+E files, Super+W wallpapers, Super+Shift+T themes, Super+Shift+E power menu.
Install LGL with: sudo dnf copr enable -y linuxgamerlife/lgl-system-loadout && sudo dnf install -y lgl-system-loadout"
fi
