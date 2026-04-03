#!/usr/bin/env bash
# Apply a unified theme to Sway borders, Waybar, Kitty, Fuzzel, and GTK (Thunar).
# Usage: theme-switch.sh [theme|menu|list] [--no-reload]
# Themes: run `theme-switch.sh list` (18 palettes: dark + light)
#
# Note: Sway runs "exec" with a minimal PATH — do not use pipefail on the fuzzel pipeline.
set -eu
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${PATH:+:$PATH}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
PALETTES="$SCRIPT_DIR/themes/palettes"
TPL="$SCRIPT_DIR/themes/tpl"
STATE="$CONFIG/sway/active-theme"
KITTY_THEMES="$CONFIG/kitty/themes"

THEME_NAMES=(
  catppuccin catppuccin-frappe catppuccin-latte catppuccin-macchiato
  dracula everforest-dark everforest-light gruvbox nord
  one-dark one-light rainbow rose-pine rose-pine-dawn
  solarized-dark solarized-light tokyo-night tokyo-night-day
)
RELOAD=1

notify_err() {
  local msg="$1"
  echo "theme-switch: $msg" >&2
  command -v notify-send >/dev/null 2>&1 && notify-send -u critical -a sway "Theme switch" "$msg" 2>/dev/null || true
}

envsubst_cmd() {
  if command -v envsubst >/dev/null 2>&1; then
    command -v envsubst
  elif [[ -x /usr/bin/envsubst ]]; then
    echo /usr/bin/envsubst
  fi
}

if [[ ! -d "$SCRIPT_DIR/themes/palettes" ]] || [[ ! -d "$SCRIPT_DIR/themes/tpl" ]]; then
  notify_err "Missing $SCRIPT_DIR/themes — copy the full sway/ tree from swaydots (includes themes/palettes and themes/tpl)."
  exit 1
fi

usage() {
  sed -n '1,25p' <<'EOF'
Usage: theme-switch.sh [menu|list|<theme>] [--no-reload]

  menu          Pick a theme with fuzzel (default when run with no arguments).
  list          Print theme names.
  <theme>       Run `theme-switch.sh list` for all names (18 themes).

  --no-reload   Do not swaymsg reload / signal waybar & kitty (for install scripts).

Updates ~/.config for waybar, sway config.d/40-theme.conf, fuzzel, kitty theme-active,
gtk-3.0/settings.ini and gtk-4.0/settings.ini (Thunar). Install matching GTK themes
from your distro if names like Nordic or Dracula are missing.
EOF
}

hex_to_rgb() {
  local h="${1#\#}"
  h="${h,,}"
  printf '%d %d %d' $((16#${h:0:2})) $((16#${h:2:2})) $((16#${h:4:2}))
}

export_rgb_from_hex() {
  local hex="$1"
  local pfx="$2"
  read -r r g b <<< "$(hex_to_rgb "$hex")"
  export "${pfx}_R=$r" "${pfx}_G=$g" "${pfx}_B=$b"
}

valid_theme() {
  local t="$1"
  local x
  for x in "${THEME_NAMES[@]}"; do
    [[ "$x" == "$t" ]] && return 0
  done
  return 1
}

apply_theme() {
  local name="$1"
  local pal="$PALETTES/${name}.env"

  if [[ ! -f "$pal" ]]; then
    echo "theme-switch: unknown theme '$name' (no $pal)" >&2
    echo "Try: ${THEME_NAMES[*]}" >&2
    exit 1
  fi

  # shellcheck source=/dev/null
  source "$pal"

  export_rgb_from_hex "$BASE" BASE
  export_rgb_from_hex "$OVERLAY0" OVL0
  export_rgb_from_hex "$ACCENT" ACCENT

  local _es
  _es="$(envsubst_cmd)"
  if [[ -z "$_es" ]]; then
    notify_err "envsubst not found. Install gettext (Fedora: sudo dnf install gettext)."
    exit 1
  fi

  mkdir -p "$CONFIG/sway/config.d" "$CONFIG/waybar" "$CONFIG/fuzzel" "$KITTY_THEMES" \
    "$CONFIG/gtk-3.0" "$CONFIG/gtk-4.0"

  "$_es" <"$TPL/waybar.css.tpl" >"$CONFIG/waybar/style.css"
  "$_es" <"$TPL/sway-theme.conf.tpl" >"$CONFIG/sway/config.d/40-theme.conf"
  "$_es" <"$TPL/fuzzel.ini.tpl" >"$CONFIG/fuzzel/fuzzel.ini"
  "$_es" <"$TPL/gtk-settings.ini.tpl" >"$CONFIG/gtk-3.0/settings.ini"
  cp -a "$CONFIG/gtk-3.0/settings.ini" "$CONFIG/gtk-4.0/settings.ini"

  if [[ ! -f "$KITTY_THEMES/${name}.conf" ]]; then
    echo "theme-switch: missing $KITTY_THEMES/${name}.conf" >&2
    exit 1
  fi
  cp -a "$KITTY_THEMES/${name}.conf" "$KITTY_THEMES/theme-active.conf"

  printf '%s\n' "$name" >"$STATE"

  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a sway "Theme" "Applied: ${name}. Restart Thunar if its colors did not update." 2>/dev/null || true
  fi

  if [[ "$RELOAD" -eq 1 ]]; then
    swaymsg reload 2>/dev/null || true
    pkill -SIGUSR2 waybar 2>/dev/null || true
    pkill -SIGUSR1 kitty 2>/dev/null || true
  fi
}

run_menu() {
  local fuzzel_bin
  fuzzel_bin="$(command -v fuzzel 2>/dev/null || true)"
  if [[ -z "$fuzzel_bin" ]] && [[ -x /usr/bin/fuzzel ]]; then
    fuzzel_bin=/usr/bin/fuzzel
  fi
  if [[ -z "$fuzzel_bin" ]]; then
    notify_err "fuzzel not in PATH. Install fuzzel or run: ~/.config/sway/theme-switch.sh catppuccin"
    exit 1
  fi
  local choice
  choice="$(printf '%s\n' "${THEME_NAMES[@]}" | "$fuzzel_bin" -d -p "Theme: ")" || true
  [[ -z "$choice" ]] && exit 0
  valid_theme "$choice" || {
    echo "theme-switch: invalid choice '$choice'" >&2
    exit 1
  }
  apply_theme "$choice"
}

# Args (--no-reload can appear before or after the theme name)
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --no-reload) RELOAD=0 ;;
    *) POSITIONAL+=("$1") ;;
  esac
  shift
done
set -- "${POSITIONAL[@]}"

case "${1:-}" in
  "")
    run_menu
    ;;
  list)
    printf '%s\n' "${THEME_NAMES[@]}"
    ;;
  menu)
    run_menu
    ;;
  *)
    valid_theme "$1" || {
      echo "theme-switch: unknown theme '$1'" >&2
      echo "Valid: ${THEME_NAMES[*]}" >&2
      exit 1
    }
    apply_theme "$1"
    ;;
esac
