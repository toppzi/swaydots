#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
ACTIVE_THEME_FILE="$CONFIG_DIR/sway/active-theme"

# Theme names managed by sway/theme-switch.sh
is_light_theme() {
  local t="${1:-}"
  case "$t" in
    catppuccin-latte|everforest-light|one-light|rose-pine-dawn|solarized-light|tokyo-night-day)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

theme_name=""
if [[ -f "$ACTIVE_THEME_FILE" ]]; then
  theme_name="$(sed -n '1p' "$ACTIVE_THEME_FILE" | tr -d '\r\n')"
fi

declare -a extra_flags
if is_light_theme "$theme_name"; then
  # Keep light palette in browser/chrome UI when a light theme is active.
  extra_flags=(--disable-features=WebUIDarkMode)
else
  # Use dark browser UI + pages when dark theme is active.
  extra_flags=(--force-dark-mode --enable-features=WebUIDarkMode)
fi

if command -v helium >/dev/null 2>&1; then
  exec helium "${extra_flags[@]}" "$@"
fi

echo "helium-theme-launch: helium not found in PATH" >&2
exit 127
