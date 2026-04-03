#!/usr/bin/env bash
set -euo pipefail

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S)_region.png"

grim -g "$(slurp)" "$file"
wl-copy < "$file"
notify-send "Region screenshot saved" "$file"
