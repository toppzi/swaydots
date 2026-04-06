#!/usr/bin/env bash
# Copy live ~/.config/{sway,waybar,wlogout} into this bundle for sharing or backup.
# Run from sway-dotfiles: ./pack.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${XDG_CONFIG_HOME:-$HOME/.config}"

rsync -a --delete \
  --exclude 'sway-dotfiles/' \
  --exclude '.cursor/' \
  --exclude '.cursorignore' \
  --exclude '.claude/' \
  "$SRC/sway/" "$SCRIPT_DIR/sway/"

rsync -a --delete \
  --exclude 'config-hyprland.jsonc' \
  "$SRC/waybar/" "$SCRIPT_DIR/waybar/"
rsync -a --delete "$SRC/wlogout/" "$SCRIPT_DIR/wlogout/"
if [[ -d "$SRC/kitty" ]]; then
  rsync -a --delete "$SRC/kitty/" "$SCRIPT_DIR/kitty/"
fi
if [[ -d "$SRC/fuzzel" ]]; then
  rsync -a --delete "$SRC/fuzzel/" "$SCRIPT_DIR/fuzzel/"
fi
if [[ -d "$SRC/hypr" ]]; then
  rsync -a --delete "$SRC/hypr/" "$SCRIPT_DIR/hypr/"
fi

echo "Packed from $SRC into $SCRIPT_DIR"
echo "Next: tar czf sway-dotfiles.tar.gz -C $(dirname "$SCRIPT_DIR") $(basename "$SCRIPT_DIR")"
