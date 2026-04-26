#!/usr/bin/env bash
set -euo pipefail

tmp="$(mktemp "${TMPDIR:-/tmp}/swaydots-keys.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

cat >"$tmp" <<'EOF'
swaydots keybind cheat sheet
===========================

Basics
------
Super + Return     Terminal (kitty)
Super + Q          Close focused window
Super + A          App launcher (fuzzel)
Super + B          Browser (Helium)
Super + E          File manager (thunar)

Theming / bar
-------------
Super + Shift + T  Theme switcher
Super + Shift + G  Waybar style picker
Super + Shift + /  This cheat sheet

Wallpaper / power
-----------------
Super + W          Wallpaper picker
Super + Shift + W  Random wallpaper
Super + Shift + E  Power menu (wlogout)

Window management
-----------------
Super + H/J/K/L    Focus left/down/up/right
Super + Shift + H/J/K/L
                   Move window left/down/up/right
Super + F          Fullscreen
Super + Shift + Space
                   Toggle floating

Workspaces
----------
Super + 1..0       Switch workspace 1..10
Super + Shift + 1..0
                   Move window to workspace 1..10
Super + minus      Toggle scratchpad
Super + Shift + minus
                   Send window to scratchpad

Media / hardware keys
---------------------
Volume up/down/mute
Mic mute
Brightness up/down
Media play/next/prev
EOF

if command -v kitty >/dev/null 2>&1; then
  exec kitty --title "swaydots keybinds" bash -lc "less -R \"$tmp\""
fi

if command -v notify-send >/dev/null 2>&1; then
  notify-send -a "swaydots" "Keybind cheat sheet" "Install kitty for full cheat sheet popup."
fi

exit 0
