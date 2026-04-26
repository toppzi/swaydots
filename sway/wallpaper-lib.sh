# shellcheck shell=bash
# Sourced by wallpaper scripts — do not run directly.
WALLPAPER_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sway"
WALLPAPER_STATE_FILE="$WALLPAPER_STATE_DIR/last-wallpaper"
WALLPAPER_SWAYBG_PID_FILE="$WALLPAPER_STATE_DIR/swaybg.pid"

esc_sway() { printf '%s' "$1" | sed "s/'/'\\\\''/g"; }

wallpaper_apply_with_swaybg() {
  local path="$1" mode="${2:-fill}"
  # Keep one swaybg instance for Hyprland sessions.
  if [[ -f "$WALLPAPER_SWAYBG_PID_FILE" ]]; then
    local old_pid
    old_pid="$(sed -n '1p' "$WALLPAPER_SWAYBG_PID_FILE" 2>/dev/null || true)"
    if [[ -n "${old_pid:-}" ]] && kill -0 "$old_pid" 2>/dev/null; then
      kill "$old_pid" 2>/dev/null || true
    fi
  fi
  nohup swaybg -m "$mode" -i "$path" >/dev/null 2>&1 &
  printf '%s\n' "$!" >"$WALLPAPER_SWAYBG_PID_FILE"
}

wallpaper_apply() {
  local path="$1" mode="${2:-fill}"
  if [[ -n "${SWAYSOCK:-}" ]] && command -v swaymsg >/dev/null 2>&1; then
    swaymsg "output * bg '$(esc_sway "$path")' $mode" >/dev/null 2>&1 || true
    return 0
  fi
  if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v swaybg >/dev/null 2>&1; then
    wallpaper_apply_with_swaybg "$path" "$mode"
    return 0
  fi
  # Generic fallback for other Wayland sessions.
  if command -v swaybg >/dev/null 2>&1; then
    wallpaper_apply_with_swaybg "$path" "$mode"
    return 0
  fi
  echo "wallpaper: could not apply (need swaymsg on Sway or swaybg installed)" >&2
  return 1
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
