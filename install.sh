#!/usr/bin/env bash
# Install Wayland dotfiles (Hyprland or Sway session): waybar, wlogout, kitty, fuzzel, theme switcher, wallpaper picker.
# Run from the extracted sway-dotfiles directory: ./install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
INSTALL_PKGS=1
WALLPAPER_DIR_CLI=""
KEYBOARD_LAYOUT_CLI=""
SKIP_DISPLAY_MANAGER=0
WANT_CURSOR="auto"
DISPLAY_MANAGER_CLI=""
CHOSEN_DM=""
COMPOSITOR_CLI=""
CHOSEN_SESSION="hyprland"
DO_DNF_HYPR=0
# Fedora Hyprland from COPR + full walkthrough (netinstall / COPR enable):
URL_FEDORA_HYPR_TUTORIAL="https://discussion.fedoraproject.org/t/tutorial-fedora-43-install-hyprland-from-scratch/168386"
HYPR_FEDORA_COPR_MAIN="solopasha/hyprland"
HELIUM_FEDORA_COPR="v8v88v8v88/helium"
CURSOR_RPM_URL="https://api2.cursor.sh/updates/download/golden/linux-x64-rpm/cursor/3.2"

UI_init() {
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    UI_R=$'\033[0m'
    UI_DIM=$'\033[2m'
    UI_BLD=$'\033[1m'
    UI_CYN=$'\033[36m'
    UI_GRN=$'\033[32m'
    UI_YLW=$'\033[33m'
    UI_RED=$'\033[31m'
    UI_MAG=$'\033[35m'
  else
    UI_R=; UI_DIM=; UI_BLD=; UI_CYN=; UI_GRN=; UI_YLW=; UI_RED=; UI_MAG=
  fi
}

ui_err() {
  printf '%s✗ %s%s\n' "$UI_RED" "$UI_R" "$*" >&2
}

UI_init

usage() {
  sed -n '1,135p' <<'EOF'
Usage: install.sh [options]

  Copies sway/ (scripts, themes, wallpapers), waybar/, wlogout/, kitty/, fuzzel/, and optionally hypr/
  into ~/.config/, writes WALLPAPER_DIR (systemd user environment.d), sets executable bits,
  and optionally installs Fedora packages (Hyprland or Sway compositor and stack).

  Interactive install (TTY): Step 1 login manager, Step 2 compositor, Step 3 keyboard (XKB), Step 4 dotfiles.
  Non-interactive: use the flags below.

  Shared stack: waybar, wlogout, kitty, fuzzel, grim, slurp, etc.

Options:
  --dry-run          Print actions only; do not copy files or write env.
  --no-packages      Skip dnf install (dependencies must be present).
  --wallpaper-dir PATH
                     Set wallpaper folder (non-interactive). Expands ~.
  --display-manager NAME
                     Set login manager to NAME (sddm or lightdm). Non-interactive;
                     installs if needed with dnf.
  --skip-display-manager
                     Do not check, prompt, or install a display manager.
  --with-cursor      Install Cursor IDE from official RPM URL without prompting.
  --skip-cursor      Skip Cursor install without prompting.
  --compositor NAME  Choose compositor: hyprland or sway (default: hyprland).
  --keyboard-layout CODE
                     XKB layout for the selected compositor (se, us, no, fi, fr, dk, gb). Use gb for UK English.
                     Non-interactive; default us if omitted in CI.
  -h, --help         Show this help.

Output uses ANSI colors on a TTY; set NO_COLOR=1 to disable (https://no-color.org/).

After install:
  - Log out and back in (or reboot) so systemd user environment.d picks up WALLPAPER_DIR,
    or run: systemctl --user import-environment WALLPAPER_DIR  (if your session supports it).
  - If a display manager was installed here, reboot (or start that service) so graphical login uses it.
  - Hyprland: ~/.config/hypr/hyprland.conf (Waybar exec-once). Edit monitors and binds as needed.
  - Sway: ~/.config/sway/config and ~/.config/sway/config.d/*.conf.
    On Fedora, if hyprland is missing from default repos, the installer may enable COPR
    solopasha/hyprland and retry; see also:
    https://discussion.fedoraproject.org/t/tutorial-fedora-43-install-hyprland-from-scratch/168386
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --no-packages) INSTALL_PKGS=0 ;;
    --wallpaper-dir)
      if [[ -z "${2:-}" ]]; then
        ui_err "missing path for --wallpaper-dir"
        exit 1
      fi
      WALLPAPER_DIR_CLI="$2"
      shift
      ;;
    --display-manager)
      if [[ -z "${2:-}" ]]; then
        ui_err "missing name for --display-manager (sddm or lightdm)"
        exit 1
      fi
      DISPLAY_MANAGER_CLI="${2,,}"
      shift
      ;;
    --skip-display-manager) SKIP_DISPLAY_MANAGER=1 ;;
    --with-cursor) WANT_CURSOR="yes" ;;
    --skip-cursor) WANT_CURSOR="no" ;;
    --compositor)
      if [[ -z "${2:-}" ]]; then
        ui_err "missing name for --compositor (hyprland or sway)"
        exit 1
      fi
      COMPOSITOR_CLI="${2,,}"
      shift
      ;;
    --keyboard-layout)
      if [[ -z "${2:-}" ]]; then
        ui_err "missing code for --keyboard-layout (se, us, no, fi, fr, dk, gb)"
        exit 1
      fi
      KEYBOARD_LAYOUT_CLI="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) ui_err "unknown option: $1"; usage >&2; exit 1 ;;
  esac
  shift
done

for d in sway waybar wlogout kitty fuzzel; do
  if [[ ! -d "$SCRIPT_DIR/$d" ]]; then
    ui_err "missing directory: $SCRIPT_DIR/$d"
    ui_err "run ./pack.sh on your source machine, or extract a complete archive."
    exit 1
  fi
done

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
ENV_DIR="$CONFIG/environment.d"
ENV_FILE="$ENV_DIR/99-sway-dotfiles-wallpaper.conf"

ui_banner() {
  local mode="" rule
  rule="$(printf '─%.0s' {1..58})"
  [[ "$DRY_RUN" -eq 1 ]] && mode+="dry-run"
  [[ "$INSTALL_PKGS" -eq 0 ]] && mode+="${mode:+ · }no-packages"
  if [[ "$WANT_CURSOR" == "yes" ]]; then
    mode+="${mode:+ · }with-cursor"
  elif [[ "$WANT_CURSOR" == "no" ]]; then
    mode+="${mode:+ · }skip-cursor"
  fi
  printf '\n'
  printf '%s╭%s╮%s\n' "$UI_CYN" "$rule" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_CYN" "$UI_BLD" "Wayland dotfiles installer" "$UI_R" "$UI_CYN" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_CYN" "$UI_DIM" "Hyprland/Sway · waybar · kitty · fuzzel · wallpaper" "$UI_R" "$UI_CYN" "$UI_R"
  if [[ -n "$mode" ]]; then
    printf '%s│  %s%-52s%s  %s│%s\n' "$UI_CYN" "$UI_YLW" "$mode" "$UI_R" "$UI_CYN" "$UI_R"
  fi
  printf '%s╰%s╯%s\n' "$UI_CYN" "$rule" "$UI_R"
  printf '\n'
}

ui_section() {
  printf '\n%s▶ %s%s%s\n' "$UI_MAG" "$UI_BLD" "$1" "$UI_R"
  printf '%s%s%s\n' "$UI_DIM" "$(printf '─%.0s' {1..58})" "$UI_R"
}

ui_info() {
  printf '%s · %s%s\n' "$UI_CYN" "$UI_R" "$*"
}

ui_ok() {
  printf '%s ✓ %s%s\n' "$UI_GRN" "$UI_R" "$*"
}

ui_warn() {
  printf '%s ! %s%s\n' "$UI_YLW" "$UI_R" "$*" >&2
}

ui_footer() {
  local rule reload_line monitor_line
  rule="$(printf '─%.0s' {1..58})"
  if [[ "$CHOSEN_SESSION" == "sway" ]]; then
    reload_line="Reload Sway config: swaymsg reload"
    monitor_line="Edit: ~/.config/sway/config"
  else
    reload_line="Reload Hyprland: hyprctl reload"
    monitor_line="Monitors: ~/.config/hypr/hyprland.conf"
  fi
  printf '\n'
  printf '%s╭%s╮%s\n' "$UI_GRN" "$rule" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_GRN" "$UI_BLD" "All set — quick reference" "$UI_R" "$UI_GRN" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_GRN" "$UI_R" "$reload_line" "$UI_R" "$UI_GRN" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_GRN" "$UI_R" "$monitor_line" "$UI_R" "$UI_GRN" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_GRN" "$UI_R" "WALLPAPER_DIR: log out/in or import-environment" "$UI_R" "$UI_GRN" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_GRN" "$UI_DIM" "Theme (Mod+Shift+t): keep sway/themes from repo" "$UI_R" "$UI_GRN" "$UI_R"
  printf '%s╰%s╯%s\n' "$UI_GRN" "$rule" "$UI_R"
  printf '\n'
}

expand_tilde_path() {
  local p="$1"
  if [[ "$p" == '~' ]]; then
    printf '%s' "$HOME"
  elif [[ "$p" == '~/'* ]]; then
    printf '%s' "${HOME}/${p#~/}"
  else
    printf '%s' "$p"
  fi
}

normalize_wallpaper_dir() {
  local raw="$1"
  local p
  if [[ -z "$raw" ]]; then
    p="${HOME}/Pictures/wallpapers"
  else
    p="$(expand_tilde_path "$raw")"
  fi
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$p"
  else
    printf '%s' "$p"
  fi
}

resolve_wallpaper_dir() {
  # Minimal installer default: always use ~/Pictures/wallpapers unless overridden by flag.
  if [[ -n "$WALLPAPER_DIR_CLI" ]]; then
    normalize_wallpaper_dir "$WALLPAPER_DIR_CLI"
    return
  fi
  normalize_wallpaper_dir ""
}

normalize_keyboard_layout_token() {
  local s="${1//[[:space:]]/}"
  printf '%s' "${s,,}"
}

apply_keyboard_layout_aliases() {
  local s
  s="$(normalize_keyboard_layout_token "$1")"
  case "$s" in
    uk) printf '%s' gb ;;
    *) printf '%s' "$s" ;;
  esac
}

validate_xkb_layout_string() {
  [[ "$1" =~ ^[a-zA-Z0-9_,-]+$ ]]
}

prompt_keyboard_layout() {
  local choice=""
  while true; do
    {
      printf '\n%s▶ %sStep 3/4 — Keyboard layout (XKB)%s\n' "$UI_MAG" "$UI_BLD" "$UI_R"
      printf '%s%s%s\n' "$UI_DIM" "$(printf '─%.0s' {1..58})" "$UI_R"
      printf '%s Choose keyboard layout for %s:%s\n' "$UI_R" "$CHOSEN_SESSION" "$UI_R"
      printf '%s   %s1=se  2=us  3=no  4=fi  5=fr  6=dk  7=gb%s\n\n' "$UI_BLD" "$UI_CYN" "$UI_R"
      printf '   %s1)%s se     %s·%s Swedish\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s2)%s us     %s·%s US English\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s3)%s no     %s·%s Norwegian\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s4)%s fi     %s·%s Finnish\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s5)%s fr     %s·%s French\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s6)%s dk     %s·%s Danish\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s7)%s gb     %s·%s British English\n\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    } >&2
    read -r -p "$(printf '%s▶%s Type 1–7 or Enter for us [2]: ' "$UI_CYN" "$UI_R")" choice || true
    choice="${choice//[[:space:]]/}"
    choice="${choice,,}"
    case "${choice:-2}" in
      1|se) printf '%s\n' se; return 0 ;;
      2|us) printf '%s\n' us; return 0 ;;
      3|no) printf '%s\n' no; return 0 ;;
      4|fi) printf '%s\n' fi; return 0 ;;
      5|fr) printf '%s\n' fr; return 0 ;;
      6|dk) printf '%s\n' dk; return 0 ;;
      7|gb|uk) printf '%s\n' gb; return 0 ;;
      *) ui_warn "invalid choice — use 1=se 2=us 3=no 4=fi 5=fr 6=dk 7=gb" ;;
    esac
  done
}

resolve_keyboard_layout() {
  local raw="" out=""
  if [[ -n "$KEYBOARD_LAYOUT_CLI" ]]; then
    raw="$(normalize_keyboard_layout_token "$KEYBOARD_LAYOUT_CLI")"
    raw="$(apply_keyboard_layout_aliases "$raw")"
    case "$raw" in
      se|us|no|fi|fr|dk|gb) ;;
      *)
        ui_err "invalid --keyboard-layout (allowed: se, us, no, fi, fr, dk, gb)"
        exit 1
        ;;
    esac
    if ! validate_xkb_layout_string "$raw"; then
      ui_err "invalid --keyboard-layout token"
      exit 1
    fi
    printf '%s' "$raw"
    return 0
  fi
  if [[ -t 0 ]]; then
    prompt_keyboard_layout
    return 0
  fi
  ui_warn "non-interactive: using keyboard layout us (pass --keyboard-layout CODE)"
  printf '%s' us
}

ui_banner

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry-run]%s ' "$UI_YLW" "$UI_R"
    printf '%q ' "$@"
    echo
  else
    "$@"
  fi
}

rpm_have() {
  command -v rpm >/dev/null 2>&1 || return 1
  rpm -q "$1" >/dev/null 2>&1
}

any_display_manager_pkg() {
  rpm_have sddm || rpm_have lightdm || rpm_have gdm
}

list_installed_display_managers() {
  local parts=()
  rpm_have sddm && parts+=("sddm")
  rpm_have lightdm && parts+=("lightdm")
  rpm_have gdm && parts+=("gdm")
  (IFS=' '; echo "${parts[*]}")
}

normalize_dm_id() {
  case "${1,,}" in
    sddm) echo sddm ;;
    lightdm) echo lightdm ;;
    gdm)
      ui_err "GDM is not supported by this installer; use sddm or lightdm"
      exit 1
      ;;
    *) return 1 ;;
  esac
}

prompt_compositor() {
  local choice=""
  while true; do
    {
      printf '\n%s▶ %sStep 2/4 — Compositor/session%s\n' "$UI_MAG" "$UI_BLD" "$UI_R"
      printf '%s%s%s\n' "$UI_DIM" "$(printf '─%.0s' {1..58})" "$UI_R"
      printf '%s Choose which session this installer should configure and install packages for.%s\n' "$UI_R" "$UI_R"
      printf '%s   %s1=hyprland  2=sway%s\n\n' "$UI_BLD" "$UI_CYN" "$UI_R"
      printf '   %s1)%s hyprland %s·%s dynamic tiling compositor\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s2)%s sway     %s·%s i3-compatible Wayland compositor\n\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    } >&2
    read -r -p "$(printf '%s▶%s Type 1-2, Enter for hyprland [1]: ' "$UI_CYN" "$UI_R")" choice || true
    choice="${choice//[[:space:]]/}"
    choice="${choice,,}"
    case "${choice:-1}" in
      1|hyprland|hypr) printf '%s\n' hyprland; return 0 ;;
      2|sway) printf '%s\n' sway; return 0 ;;
      *) ui_warn "invalid choice — use 1=hyprland or 2=sway" ;;
    esac
  done
}

choose_compositor_if_needed() {
  DO_DNF_HYPR=0
  CHOSEN_SESSION="hyprland"

  local picked=""
  local has_h=0
  local has_s=0
  rpm_have hyprland && has_h=1
  rpm_have sway && has_s=1

  if [[ -n "$COMPOSITOR_CLI" ]]; then
    case "${COMPOSITOR_CLI}" in
      hyprland|hypr) picked="hyprland" ;;
      sway) picked="sway" ;;
      *)
        ui_err "invalid --compositor (use hyprland or sway)"
        exit 1
        ;;
    esac
  elif [[ "$DRY_RUN" -eq 1 || ! -t 0 ]]; then
    picked="hyprland"
  else
    picked="$(prompt_compositor)"
  fi

  CHOSEN_SESSION="$picked"

  if [[ "$CHOSEN_SESSION" == "hyprland" ]]; then
    if [[ "$INSTALL_PKGS" -eq 0 ]] && [[ "$has_h" -eq 0 ]]; then
      ui_err "hyprland is not installed; install it first or re-run without --no-packages"
      exit 1
    fi
    [[ "$has_h" -eq 0 ]] && DO_DNF_HYPR=1
    if [[ "$DO_DNF_HYPR" -eq 1 ]] && [[ "$INSTALL_PKGS" -eq 1 ]] && ! command -v dnf >/dev/null 2>&1; then
      ui_err "hyprland install path requires dnf (not found in PATH)"
      exit 1
    fi
    if [[ ! -d "$SCRIPT_DIR/hypr" ]]; then
      ui_err "missing directory: $SCRIPT_DIR/hypr"
      ui_err "run ./pack.sh on your source machine, or extract a complete archive."
      exit 1
    fi
  else
    if [[ "$INSTALL_PKGS" -eq 0 ]] && [[ "$has_s" -eq 0 ]]; then
      ui_err "sway is not installed; install it first or re-run without --no-packages"
      exit 1
    fi
    if [[ "$INSTALL_PKGS" -eq 1 ]] && [[ "$has_s" -eq 0 ]] && ! command -v dnf >/dev/null 2>&1; then
      ui_err "sway install path requires dnf (not found in PATH)"
      exit 1
    fi
  fi
}

build_system_pkgs_array() {
  SYSTEM_PKGS=(
    dnf-plugins-core
    waybar wlogout
    kitty fuzzel btop
    thunar firefox
    helium
    swaybg
    wob
    brightnessctl playerctl
    grim slurp wl-clipboard
    python3-gobject gtk3 gettext
    google-noto-sans-mono-vf-fonts fontawesome-6-free-fonts fontawesome-6-brands-fonts
  )
  local -a hypr_pkgs=(
    hyprland
    hyprland-qtutils
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    mate-polkit
    qt6-qtwayland
    wireplumber
  )
  local -a sway_pkgs=(
    sway
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk
    swayidle
    swaylock
    seatd
    wireplumber
  )
  if [[ "$CHOSEN_SESSION" == "hyprland" ]]; then
    if [[ "$DO_DNF_HYPR" -eq 1 ]]; then
      SYSTEM_PKGS+=("${hypr_pkgs[@]}")
    else
      SYSTEM_PKGS+=("${hypr_pkgs[@]:1}")
    fi
  else
    SYSTEM_PKGS+=("${sway_pkgs[@]}")
  fi
}

verify_chosen_compositor_installed() {
  [[ "$INSTALL_PKGS" -eq 0 ]] && return 0
  [[ "$DRY_RUN" -eq 1 ]] && return 0
  command -v rpm >/dev/null 2>&1 || return 0
  if [[ "$CHOSEN_SESSION" == "hyprland" ]] && [[ "$DO_DNF_HYPR" -eq 1 ]] && ! rpm_have hyprland; then
    ui_err "hyprland did not install — check dnf errors above."
    printf '%s  Fedora: sudo dnf copr enable %s && sudo dnf install hyprland%s\n' "$UI_DIM" "$HYPR_FEDORA_COPR_MAIN" "$UI_R" >&2
    printf '%s  Walkthrough: %s%s\n' "$UI_DIM" "$URL_FEDORA_HYPR_TUTORIAL" "$UI_R" >&2
    exit 1
  fi
  if [[ "$CHOSEN_SESSION" == "sway" ]] && ! rpm_have sway; then
    ui_err "sway did not install — check dnf errors above."
    exit 1
  fi
}

dnf_install_system_packages() {
  # Best-practice preflight: refresh repo metadata before install.
  # Helium browser is distributed through COPR on Fedora.
  run sudo dnf copr enable -y "$HELIUM_FEDORA_COPR" || true
  run sudo dnf makecache --refresh
  if run sudo dnf install -y "$@"; then
    return 0
  fi
  # Safe retry pattern: clear stale metadata and try once more.
  ui_warn "dnf install failed — cleaning metadata and retrying once…"
  run sudo dnf clean metadata
  run sudo dnf makecache --refresh
  if run sudo dnf install -y "$@"; then
    return 0
  fi
  if [[ "$CHOSEN_SESSION" == "hyprland" ]] && [[ "$DO_DNF_HYPR" -eq 1 ]] && rpm -q fedora-release &>/dev/null; then
    ui_warn "dnf failed — Hyprland on Fedora is often packaged via COPR ($HYPR_FEDORA_COPR_MAIN); see $URL_FEDORA_HYPR_TUTORIAL"
    ui_warn "Enabling COPR $HYPR_FEDORA_COPR_MAIN and retrying install…"
    run sudo dnf copr enable -y "$HYPR_FEDORA_COPR_MAIN"
    run sudo dnf makecache --refresh
    if run sudo dnf install -y "$@"; then
      return 0
    fi
  fi
  ui_err "dnf install failed — see output above"
  return 1
}

# Step 1/4 — Login manager (order: 1 SDDM, 2 LightDM)
prompt_display_manager() {
  local choice=""
  while true; do
    {
      printf '\n%s▶ %sStep 1/4 — Login manager (graphical greeter)%s\n' "$UI_MAG" "$UI_BLD" "$UI_R"
      printf '%s%s%s\n' "$UI_DIM" "$(printf '─%.0s' {1..58})" "$UI_R"
      printf '%s Pick which display manager should be installed (if needed) and set as the active default.%s\n' "$UI_R" "$UI_R"
      if any_display_manager_pkg; then
        printf '%s Installed now: %s%s%s\n' "$UI_DIM" "$UI_BLD" "$(list_installed_display_managers)" "$UI_R"
      else
        printf '%s No sddm / lightdm / gdm detected — one will be installed with dnf (GDM is not offered here).%s\n' "$UI_DIM" "$UI_R"
      fi
      printf '%s   %s1=sddm  2=lightdm  q=skip%s\n\n' "$UI_BLD" "$UI_CYN" "$UI_R"
      printf '   %s1)%s sddm      %s·%s Wayland / Plasma-style setups\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %s2)%s lightdm   %s·%s GTK greeter, lightweight\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
      printf '   %sq)%s skip      %s·%s do not change / install a display manager now\n\n' "$UI_YLW" "$UI_R" "$UI_DIM" "$UI_R"
    } >&2
    read -r -p "$(printf '%s▶%s Type 1–2 (see map above), Enter for SDDM, or q to skip [1]: ' "$UI_CYN" "$UI_R")" choice || true
    choice="${choice//[[:space:]]/}"
    choice="${choice,,}"
    case "${choice:-1}" in
      q|skip) return 1 ;;
      1|sddm) printf '%s\n' sddm; return 0 ;;
      2|lightdm) printf '%s\n' lightdm; return 0 ;;
    esac
    ui_warn "invalid choice — type 1=sddm, 2=lightdm, Enter=SDDM, or q (see map above)"
  done
}

choose_display_manager_if_needed() {
  CHOSEN_DM=""
  [[ "$SKIP_DISPLAY_MANAGER" -eq 1 ]] && return 0

  if [[ -n "$DISPLAY_MANAGER_CLI" ]]; then
    local picked=""
    if ! picked="$(normalize_dm_id "$DISPLAY_MANAGER_CLI")"; then
      ui_err "invalid --display-manager (use sddm or lightdm)"
      exit 1
    fi
    CHOSEN_DM="$picked"
    if [[ "$INSTALL_PKGS" -eq 0 ]]; then
      if ! rpm_have "$picked"; then
        ui_err "package for --display-manager $picked is not installed; install it first or re-run without --no-packages"
        exit 1
      fi
    elif ! command -v dnf >/dev/null 2>&1; then
      ui_err "--display-manager install path requires dnf (not found in PATH)"
      exit 1
    fi
    return 0
  fi

  [[ "$DRY_RUN" -eq 1 ]] && return 0

  if [[ ! -t 0 ]]; then
    ui_warn "non-interactive session — skipping display manager (use --display-manager NAME or --skip-display-manager)"
    return 0
  fi

  local picked=""
  if picked="$(prompt_display_manager)"; then
    CHOSEN_DM="$picked"
    if [[ "$INSTALL_PKGS" -eq 0 ]] && ! rpm_have "$picked"; then
      ui_err "$picked is not installed — install it first or re-run without --no-packages"
      exit 1
    fi
    if [[ "$INSTALL_PKGS" -eq 1 ]] && ! command -v dnf >/dev/null 2>&1; then
      if ! rpm_have "$picked"; then
        ui_err "dnf not found — install $picked with your package manager, then re-run"
        exit 1
      fi
      ui_warn "dnf not found — will only enable $picked if the package is already present"
    fi
  else
    ui_info "skipping display manager"
  fi
}

dm_dnf_package_list() {
  case "$1" in
    sddm) echo sddm ;;
    lightdm) echo lightdm lightdm-gtk ;;
    *) return 1 ;;
  esac
}

enable_chosen_display_manager() {
  [[ -z "$CHOSEN_DM" ]] && return 0
  local svc="${CHOSEN_DM}.service"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry-run]%s would disable other display managers, enable %s, set-default graphical.target\n' "$UI_YLW" "$UI_R" "$svc"
    return 0
  fi
  run sudo systemctl disable gdm.service sddm.service lightdm.service 2>/dev/null || true
  run sudo systemctl enable "$svc"
  run sudo systemctl set-default graphical.target 2>/dev/null || true
  ui_ok "enabled $svc (reboot or start the service for graphical login)"
}

install_chosen_display_manager() {
  [[ -z "$CHOSEN_DM" ]] && return 0
  if [[ "$INSTALL_PKGS" -eq 0 ]]; then
    if rpm_have "$CHOSEN_DM"; then
      ui_section "Display manager"
      printf '%s · %sSetting %s as the active login manager (packages already present)…%s\n' "$UI_CYN" "$UI_R" "$UI_BLD$CHOSEN_DM$UI_R" "$UI_R"
      enable_chosen_display_manager
    fi
    return 0
  fi
  command -v dnf >/dev/null 2>&1 || return 0
  local list
  list="$(dm_dnf_package_list "$CHOSEN_DM")" || return 1
  local -a pkgs=()
  read -r -a pkgs <<< "$list"
  [[ ${#pkgs[@]} -eq 0 ]] && return 1
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry-run]%s would: sudo dnf install -y %s\n' "$UI_YLW" "$UI_R" "${pkgs[*]}"
    enable_chosen_display_manager
    return 0
  fi
  ui_section "Display manager"
  printf '%s · %sInstalling %s%s…%s\n' "$UI_CYN" "$UI_R" "$UI_BLD" "$CHOSEN_DM" "$UI_R"
  run sudo dnf install -y "${pkgs[@]}"
  enable_chosen_display_manager
}

ensure_pavucontrol() {
  [[ "$INSTALL_PKGS" -eq 0 ]] && return 0
  command -v dnf >/dev/null 2>&1 || return 0
  if rpm_have pavucontrol; then
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry-run]%s would: sudo dnf install -y pavucontrol\n' "$UI_YLW" "$UI_R"
    return 0
  fi
  ui_section "Audio (pavucontrol)"
  printf '%s · %sInstalling PulseAudio / PipeWire volume UI…%s\n' "$UI_CYN" "$UI_R" "$UI_R"
  run sudo dnf install -y pavucontrol
  ui_ok "pavucontrol installed"
}

ensure_cursor_optional() {
  if [[ "$WANT_CURSOR" == "auto" ]]; then
    if [[ "$INSTALL_PKGS" -eq 1 ]] && [[ -t 0 ]]; then
      local ans=""
      printf '\n%s▶ %sOptional — Cursor IDE%s\n' "$UI_MAG" "$UI_BLD" "$UI_R"
      printf '%s%s%s\n' "$UI_DIM" "$(printf '─%.0s' {1..58})" "$UI_R"
      printf '%s Cursor will be installed from:%s\n' "$UI_R" "$UI_R"
      printf '%s %s%s\n\n' "$UI_DIM" "$CURSOR_RPM_URL" "$UI_R"
      read -r -p "$(printf '%s▶%s Install Cursor now? [y/N]: ' "$UI_CYN" "$UI_R")" ans || true
      ans="${ans//[[:space:]]/}"
      ans="${ans,,}"
      case "${ans:-n}" in
        y|yes) WANT_CURSOR="yes" ;;
        *) WANT_CURSOR="no" ;;
      esac
    else
      WANT_CURSOR="no"
    fi
  fi

  [[ "$WANT_CURSOR" == "no" ]] && {
    ui_info "skipping Cursor. To install later: ./install.sh --with-cursor"
    return 0
  }
  [[ "$INSTALL_PKGS" -eq 0 ]] && {
    ui_warn "--with-cursor needs package install; re-run without --no-packages or install Cursor manually"
    return 0
  }
  command -v dnf >/dev/null 2>&1 || return 0
  if rpm_have cursor; then
    ui_ok "cursor already installed"
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry-run]%s would: sudo dnf install -y %s\n' "$UI_YLW" "$UI_R" "$CURSOR_RPM_URL"
    return 0
  fi
  ui_section "Optional — Cursor IDE"
  printf '%s · %sinstalling Cursor from official RPM URL…%s\n' "$UI_CYN" "$UI_DIM" "$UI_R"
  run sudo dnf install -y "$CURSOR_RPM_URL"
  if rpm_have cursor; then
    ui_ok "cursor installed"
  else
    ui_warn "Cursor install command completed but package was not detected. Verify with: rpm -q cursor"
  fi
}

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" && "$DRY_RUN" -eq 0 ]]; then
    local ts
    ts="$(date +%Y%m%d%H%M%S)"
    run mv "$path" "${path}.bak.${ts}"
    ui_ok "backed up → ${path}.bak.${ts}"
  elif [[ -e "$path" ]]; then
    ui_info "would back up: $path"
  fi
}

ensure_linutil_aliases() {
  local alias_line="alias linutil='curl -fsSL https://christitus.com/linux | sh'"
  local start_marker="# >>> swaydots linutil alias >>>"
  local end_marker="# <<< swaydots linutil alias <<<"
  local -a rc_files=("$HOME/.bashrc" "$HOME/.zshrc")
  local rc_file tmp

  ui_section "Shell alias"
  ui_info "ensuring linutil alias in ~/.bashrc and ~/.zshrc"

  for rc_file in "${rc_files[@]}"; do
    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '%s[dry-run]%s would ensure linutil alias in %s\n' "$UI_YLW" "$UI_R" "$rc_file"
      continue
    fi
    [[ -f "$rc_file" ]] || : >"$rc_file"
    tmp="$(mktemp "${TMPDIR:-/tmp}/swaydots-rc.XXXXXX")"
    awk -v s="$start_marker" -v e="$end_marker" '
      $0 == s { skip=1; next }
      $0 == e { skip=0; next }
      skip != 1 { print }
    ' "$rc_file" >"$tmp"
    {
      cat "$tmp"
      printf '\n%s\n%s\n%s\n' "$start_marker" "$alias_line" "$end_marker"
    } >"$rc_file"
    rm -f "$tmp"
    ui_ok "updated $rc_file with linutil alias"
  done
}

choose_compositor_if_needed

choose_display_manager_if_needed

KEYBOARD_LAYOUT_RESOLVED="$(resolve_keyboard_layout)"
# One-line token only (wizard UI must go to stderr, not stdout)
KEYBOARD_LAYOUT_RESOLVED="$(printf '%s' "$KEYBOARD_LAYOUT_RESOLVED" | tr -d '\r\n' | sed -n '1p')"
if ! validate_xkb_layout_string "$KEYBOARD_LAYOUT_RESOLVED"; then
  ui_err "invalid keyboard layout after resolve — use --keyboard-layout CODE"
  exit 1
fi
WALLPAPER_DIR_RESOLVED="$(resolve_wallpaper_dir)"

ui_section "Paths"
ui_info "config → $CONFIG"
ui_info "wallpapers → $WALLPAPER_DIR_RESOLVED"
ui_info "keyboard (xkb) → $KEYBOARD_LAYOUT_RESOLVED"
ui_info "session → $CHOSEN_SESSION (packages as detected or installed)"

build_system_pkgs_array
if [[ "$INSTALL_PKGS" -eq 1 && "$DRY_RUN" -eq 0 ]] && command -v dnf >/dev/null 2>&1; then
  ui_section "System packages"
  printf '%s · %sInstalling dependencies with dnf (use --no-packages to skip)…%s\n' "$UI_CYN" "$UI_DIM" "$UI_R"
  if ! dnf_install_system_packages "${SYSTEM_PKGS[@]}"; then
    exit 1
  fi
  verify_chosen_compositor_installed
elif [[ "$INSTALL_PKGS" -eq 1 && "$DRY_RUN" -eq 1 ]] && command -v dnf >/dev/null 2>&1; then
  ui_section "System packages"
  printf '%s[dry-run]%s would: sudo dnf install -y %s\n' "$UI_YLW" "$UI_R" "${SYSTEM_PKGS[*]}"
  if [[ "$DO_DNF_HYPR" -eq 1 ]]; then
    printf '%s[dry-run]%s if that failed on Fedora: would enable COPR %s then retry (see %s)\n' "$UI_YLW" "$UI_R" "$HYPR_FEDORA_COPR_MAIN" "$URL_FEDORA_HYPR_TUTORIAL"
  fi
else
  if [[ "$INSTALL_PKGS" -eq 1 ]]; then
    ui_warn "dnf not found — install: hyprland, waybar, wlogout, kitty, fuzzel, btop, grim, slurp, wl-clipboard, python3-gobject, gtk3, gettext, fonts"
  fi
fi

ensure_pavucontrol

install_chosen_display_manager

mkdir_p() {
  run mkdir -p "$1"
}

ui_section "Environment"
mkdir_p "$CONFIG"
mkdir_p "$ENV_DIR"

if [[ -e "$ENV_FILE" ]]; then
  backup_if_exists "$ENV_FILE"
fi

write_keyboard_layout_configs() {
  local layout="$1"
  local sway_f="$CONFIG/sway/config.d/10-xkb-layout.conf"
  local hypr_f="$CONFIG/hypr/hyprland.conf"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry-run]%s would write %s (xkb_layout %s)\n' "$UI_YLW" "$UI_R" "$sway_f" "$layout"
    printf '%s[dry-run]%s would set kb_layout = %s in %s\n' "$UI_YLW" "$UI_R" "$layout" "$hypr_f"
    return 0
  fi
  mkdir_p "$CONFIG/sway/config.d"
  printf '%s\n' \
    '# Written by install.sh — keyboard layout (xkb)' \
    'input type:keyboard {' \
    "    xkb_layout $layout" \
    '    xkb_model pc105' \
    '}' >"$sway_f"
  ui_ok "keyboard layout → $layout ($sway_f)"
  if [[ -f "$hypr_f" ]]; then
    if grep -qE '^[[:space:]]*kb_layout[[:space:]]*=' "$hypr_f"; then
      local tmp
      tmp="$(mktemp "${TMPDIR:-/tmp}/swaydots-hyprkbd.XXXXXX")"
      if awk -v l="$layout" '
        /^[[:space:]]*kb_layout[[:space:]]*=/ {
          print "    kb_layout = " l
          next
        }
        { print }
      ' "$hypr_f" >"$tmp"; then
        mv -f "$tmp" "$hypr_f"
        ui_ok "keyboard layout → $layout ($hypr_f)"
      else
        rm -f "$tmp"
        ui_err "failed to patch kb_layout in $hypr_f"
        exit 1
      fi
    else
      ui_warn "no kb_layout line in $hypr_f — add: input { kb_layout = $layout }"
    fi
  fi
}

write_wallpaper_env() {
  local content esc
  esc="$WALLPAPER_DIR_RESOLVED"
  esc="${esc//\\/\\\\}"
  esc="${esc//\"/\\\"}"
  content="# Written by sway-dotfiles install.sh — WALLPAPER_DIR for wallpaper.sh and wallpaper-picker.py
WALLPAPER_DIR=\"$esc\"
"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry-run]%s would write %s\n' "$UI_YLW" "$UI_R" "$ENV_FILE"
    while IFS= read -r line || [[ -n "$line" ]]; do
      printf '%s[dry-run]%s %s\n' "$UI_YLW" "$UI_R" "$line"
    done <<< "$content"
  else
    printf '%s' "$content" >"$ENV_FILE"
    ui_ok "wrote $ENV_FILE"
  fi
}

write_wallpaper_env

ensure_linutil_aliases

if [[ "$DRY_RUN" -eq 0 ]]; then
  run mkdir -p "$WALLPAPER_DIR_RESOLVED"
fi

ui_section "Step 4/4 — Dotfiles"
for name in sway waybar wlogout kitty fuzzel; do
  dest="$CONFIG/$name"
  if [[ -e "$dest" ]]; then
    backup_if_exists "$dest"
  fi
done
if [[ "$CHOSEN_SESSION" == "hyprland" ]] && [[ -e "$CONFIG/hypr" ]]; then
  backup_if_exists "$CONFIG/hypr"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  run cp -a "$SCRIPT_DIR/sway" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/waybar" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/wlogout" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/kitty" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/fuzzel" "$CONFIG/"
  if [[ "$CHOSEN_SESSION" == "hyprland" ]]; then
    run cp -a "$SCRIPT_DIR/hypr" "$CONFIG/"
  fi
else
  cp -a "$SCRIPT_DIR/sway" "$CONFIG/"
  cp -a "$SCRIPT_DIR/waybar" "$CONFIG/"
  cp -a "$SCRIPT_DIR/wlogout" "$CONFIG/"
  cp -a "$SCRIPT_DIR/kitty" "$CONFIG/"
  cp -a "$SCRIPT_DIR/fuzzel" "$CONFIG/"
  if [[ "$CHOSEN_SESSION" == "hyprland" ]]; then
    cp -a "$SCRIPT_DIR/hypr" "$CONFIG/"
    ui_ok "installed sway (scripts/themes), waybar, wlogout, kitty, fuzzel, hypr → $CONFIG"
  else
    ui_ok "installed sway (scripts/themes), waybar, wlogout, kitty, fuzzel → $CONFIG"
  fi
fi

# Waybar: choose modules by selected compositor.
if [[ "$CHOSEN_SESSION" == "hyprland" ]] && [[ -f "$SCRIPT_DIR/waybar/config-hyprland.jsonc" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run cp -a "$SCRIPT_DIR/waybar/config-hyprland.jsonc" "$CONFIG/waybar/config.jsonc"
  else
    cp -a "$SCRIPT_DIR/waybar/config-hyprland.jsonc" "$CONFIG/waybar/config.jsonc"
    ui_ok "waybar: using Hyprland modules (config-hyprland.jsonc → ~/.config/waybar/config.jsonc)"
  fi
elif [[ "$CHOSEN_SESSION" == "sway" ]] && [[ -f "$SCRIPT_DIR/waybar/config.jsonc" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run cp -a "$SCRIPT_DIR/waybar/config.jsonc" "$CONFIG/waybar/config.jsonc"
  else
    cp -a "$SCRIPT_DIR/waybar/config.jsonc" "$CONFIG/waybar/config.jsonc"
    ui_ok "waybar: using Sway/default modules (config.jsonc)"
  fi
fi

write_keyboard_layout_configs "$KEYBOARD_LAYOUT_RESOLVED"

# Executable scripts
if [[ "$DRY_RUN" -eq 0 ]]; then
  if [[ "$CHOSEN_SESSION" == "hyprland" ]]; then
    while IFS= read -r -d '' f; do
      chmod +x "$f"
    done < <(find "$CONFIG/sway" "$CONFIG/waybar" "$CONFIG/hypr" -type f \( -name '*.sh' -o -name 'wallpaper-picker.py' \) -print0 2>/dev/null || true)
  else
    while IFS= read -r -d '' f; do
      chmod +x "$f"
    done < <(find "$CONFIG/sway" "$CONFIG/waybar" -type f \( -name '*.sh' -o -name 'wallpaper-picker.py' \) -print0 2>/dev/null || true)
  fi
  if [[ -f "$CONFIG/sway/theme-switch.sh" ]]; then
    chmod +x "$CONFIG/sway/theme-switch.sh"
  fi
  if [[ -x "$CONFIG/sway/theme-switch.sh" ]] && [[ -d "$CONFIG/sway/themes/palettes" ]] && command -v envsubst >/dev/null 2>&1; then
    "$CONFIG/sway/theme-switch.sh" catppuccin --no-reload 2>/dev/null || true
  elif ! command -v envsubst >/dev/null 2>&1; then
    ui_warn "install gettext (envsubst) for the theme switcher (Mod+Shift+t)"
  elif [[ ! -d "$CONFIG/sway/themes/palettes" ]]; then
    ui_warn "missing ~/.config/sway/themes/ — copy sway/themes from the repo, then: ~/.config/sway/theme-switch.sh catppuccin"
  fi
fi

ensure_cursor_optional

ui_footer
