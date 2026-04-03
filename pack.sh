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

rsync -a --delete "$SRC/waybar/" "$SCRIPT_DIR/waybar/"
rsync -a --delete "$SRC/wlogout/" "$SCRIPT_DIR/wlogout/"

echo "Packed from $SRC into $SCRIPT_DIR"
echo "Next: tar czf sway-dotfiles.tar.gz -C $(dirname "$SCRIPT_DIR") $(basename "$SCRIPT_DIR")"
