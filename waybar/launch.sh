#!/usr/bin/env bash
set -euo pipefail

CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
STYLE_FILE="$CFG_DIR/style.css"

if [[ -n "${SWAYSOCK:-}" ]]; then
  CONFIG_FILE="$CFG_DIR/config.jsonc"
elif [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  CONFIG_FILE="$CFG_DIR/config-hyprland.jsonc"
else
  CONFIG_FILE="$CFG_DIR/config.jsonc"
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "waybar-launch: missing $CONFIG_FILE" >&2
  exit 1
fi

if [[ ! -f "$STYLE_FILE" ]]; then
  echo "waybar-launch: missing $STYLE_FILE" >&2
  exit 1
fi

exec waybar -c "$CONFIG_FILE" -s "$STYLE_FILE"
