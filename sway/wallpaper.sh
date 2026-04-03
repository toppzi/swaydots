#!/usr/bin/env bash
# Random wallpaper from disk. Directory can be overridden with WALLPAPER_DIR.
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/wallpaper-lib.sh"

WALLPAPER_DIR="${WALLPAPER_DIR:-/mnt/HDD/Wallpapers}"
MODE="${WALLPAPER_MODE:-fill}"

if [[ ! -d "$WALLPAPER_DIR" ]]; then
  echo "wallpaper.sh: not a directory: $WALLPAPER_DIR" >&2
  command -v notify-send >/dev/null 2>&1 && notify-send -a sway "Wallpaper" "Folder missing or not mounted: $WALLPAPER_DIR" || true
  exit 1
fi

mapfile -t files < <(find "$WALLPAPER_DIR" -type f \( \
  -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \
  -o -iname '*.jxl' -o -iname '*.bmp' -o -iname '*.gif' \) 2>/dev/null)

if ((${#files[@]} == 0)); then
  echo "wallpaper.sh: no images under $WALLPAPER_DIR" >&2
  command -v notify-send >/dev/null 2>&1 && notify-send -a sway "Wallpaper" "No images found in $WALLPAPER_DIR" || true
  exit 1
fi

idx=$((RANDOM % ${#files[@]}))
file="${files[$idx]}"

wallpaper_apply "$file" "$MODE"
wallpaper_save_state "$file" "$MODE"
