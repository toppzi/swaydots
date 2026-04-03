# shellcheck shell=bash
# Sourced by wallpaper scripts — do not run directly.
WALLPAPER_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sway"
WALLPAPER_STATE_FILE="$WALLPAPER_STATE_DIR/last-wallpaper"

esc_sway() { printf '%s' "$1" | sed "s/'/'\\\\''/g"; }

wallpaper_apply() {
  local path="$1" mode="${2:-fill}"
  swaymsg "output * bg '$(esc_sway "$path")' $mode"
}

wallpaper_save_state() {
  local path="$1" mode="${2:-fill}"
  mkdir -p "$WALLPAPER_STATE_DIR"
  printf '%s\n%s\n' "$path" "$mode" >"$WALLPAPER_STATE_FILE"
}

# Returns 0 if a wallpaper was applied, 1 if nothing to restore / file missing.
wallpaper_restore_if_possible() {
  [[ -f "$WALLPAPER_STATE_FILE" ]] || return 1
  local path mode
  IFS= read -r path <"$WALLPAPER_STATE_FILE" || return 1
  mode=$(sed -n '2p' "$WALLPAPER_STATE_FILE")
  [[ -z "${mode:-}" ]] && mode=fill
  [[ -f "$path" ]] || return 1
  wallpaper_apply "$path" "$mode"
  return 0
}
