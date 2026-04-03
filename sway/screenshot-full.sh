#!/usr/bin/env bash
set -euo pipefail

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S)_full.png"

grim "$file"
wl-copy < "$file"
notify-send "Screenshot saved" "$file"
