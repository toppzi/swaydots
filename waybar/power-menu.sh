#!/usr/bin/env bash
set -euo pipefail

# Default wlogout look (upstream style.css + 3x2 grid). ~/.config/wlogout/ overrides /etc.

if command -v wlogout >/dev/null 2>&1; then
  exec wlogout
fi

exec swaynag -t warning \
  -m "Power options (install wlogout: sudo dnf install wlogout)" \
  -B "Lock" "swaylock -f" \
  -B "Logout" "swaymsg exit" \
  -B "Suspend" "systemctl suspend" \
  -B "Reboot" "systemctl reboot" \
  -B "Shutdown" "systemctl poweroff"
