#!/usr/bin/env bash
# Install Wayland dotfiles (Sway or Hyprland session): waybar, wlogout, kitty, fuzzel, theme switcher, wallpaper picker.
# Run from the extracted sway-dotfiles directory: ./install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
INSTALL_PKGS=1
WALLPAPER_DIR_CLI=""
KEYBOARD_LAYOUT_CLI=""
SKIP_DISPLAY_MANAGER=0
DISPLAY_MANAGER_CLI=""
CHOSEN_DM=""
COMPOSITOR_CLI=""
# CHOSEN_SESSION: sway | hyprland (for messaging and optional packages)
CHOSEN_SESSION="sway"
DO_DNF_SWAY=0
DO_DNF_HYPR=0

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
  sed -n '1,130p' <<'EOF'
Usage: install.sh [options]

  Copies sway/, waybar/, wlogout/, kitty/, fuzzel/, and hypr/ (Hyprland starter with Waybar
  exec-once) from this directory into ~/.config/,
  writes WALLPAPER_DIR for wallpaper scripts (systemd user environment.d),
  sets executable bits on scripts, and optionally installs Fedora packages.

  If neither Sway nor Hyprland is installed, you are prompted to install one (or pass
  --compositor). Shared stack: waybar, wlogout, kitty, fuzzel, grim, slurp, etc.

Options:
  --dry-run          Print actions only; do not copy files or write env.
  --no-packages      Skip dnf install (dependencies must be present).
  --wallpaper-dir PATH
                     Set wallpaper folder (non-interactive). Expands ~.
  --display-manager NAME
                     When no display manager is installed: install NAME (sddm, lightdm,
                     gdm, or ly). Non-interactive; use with dnf-based installs.
  --skip-display-manager
                     Do not check, prompt, or install a display manager.
  --compositor NAME  When neither sway nor hyprland is installed: install NAME (sway or
                     hyprland). Non-interactive; requires dnf-based installs.
  --keyboard-layout CODE
                     XKB layout for Sway and Hyprland (e.g. us, se, gb, no, de). Use gb for
                     UK English. Non-interactive; default us if omitted in CI.
  -h, --help         Show this help.

Output uses ANSI colors on a TTY; set NO_COLOR=1 to disable (https://no-color.org/).

After install:
  - Log out and back in (or reboot) so systemd user environment.d picks up WALLPAPER_DIR,
    or run: systemctl --user import-environment WALLPAPER_DIR  (if your session supports it).
  - If a display manager was installed here, reboot (or start that service) so graphical login uses it.
  - Sway: edit ~/.config/sway/config for monitors (output ...) and personal apps ($term, etc.).
  - Hyprland: ~/.config/hypr/hyprland.conf is installed when Hyprland is used (Waybar exec-once).
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
        ui_err "missing name for --display-manager (sddm, lightdm, gdm, ly)"
        exit 1
      fi
      DISPLAY_MANAGER_CLI="${2,,}"
      shift
      ;;
    --skip-display-manager) SKIP_DISPLAY_MANAGER=1 ;;
    --compositor)
      if [[ -z "${2:-}" ]]; then
        ui_err "missing name for --compositor (sway or hyprland)"
        exit 1
      fi
      COMPOSITOR_CLI="${2,,}"
      shift
      ;;
    --keyboard-layout)
      if [[ -z "${2:-}" ]]; then
        ui_err "missing code for --keyboard-layout (e.g. us, se, gb, no)"
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

for d in sway waybar wlogout kitty fuzzel hypr; do
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
  printf '\n'
  printf '%s╭%s╮%s\n' "$UI_CYN" "$rule" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_CYN" "$UI_BLD" "Wayland dotfiles installer" "$UI_R" "$UI_CYN" "$UI_R"
  printf '%s│  %s%-52s%s  %s│%s\n' "$UI_CYN" "$UI_DIM" "Sway / Hyprland · waybar · kitty · fuzzel · wallpaper" "$UI_R" "$UI_CYN" "$UI_R"
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
  if [[ "$CHOSEN_SESSION" == "hyprland" ]]; then
    reload_line="Reload Hyprland: hyprctl reload"
    monitor_line="Hyprland: ~/.config/hypr/hyprland.conf (your layout)"
  else
    reload_line="Reload Sway: Mod+Shift+c"
    monitor_line="Monitors: ~/.config/sway/config"
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
  local default="${HOME}/Pictures/wallpapers"
  local input=""
  if [[ -n "$WALLPAPER_DIR_CLI" ]]; then
    normalize_wallpaper_dir "$WALLPAPER_DIR_CLI"
    return
  fi
  if [[ -t 0 ]]; then
    read -r -p "$(printf '%s▶%s Wallpaper directory for picker [ %s%s%s ]: ' "$UI_CYN" "$UI_R" "$UI_DIM" "$default" "$UI_R")" input || true
  fi
  # Non-interactive (piped CI, etc.): use default or pass --wallpaper-dir.
  if [[ -z "${input// }" ]]; then
    normalize_wallpaper_dir ""
  else
    normalize_wallpaper_dir "$input"
  fi
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
  local choice="" custom=""
  while true; do
    printf '\n%s▶ %sKeyboard layout (XKB)%s\n' "$UI_MAG" "$UI_BLD" "$UI_R"
    printf '%s%s%s\n' "$UI_DIM" "$(printf '─%.0s' {1..58})" "$UI_R"
    printf '%s Choose layout for Sway and Hyprland:%s\n\n' "$UI_R" "$UI_R"
    printf '   %s1)%s us     %s·%s US English\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %s2)%s se     %s·%s Swedish\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %s3)%s gb     %s·%s UK English\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %s4)%s no     %s·%s Norwegian\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %s5)%s dk     %s·%s Danish\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %s6)%s fi     %s·%s Finnish\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %s7)%s de     %s·%s German\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %s8)%s fr     %s·%s French\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %s9)%s es     %s·%s Spanish\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %so)%s        %s·%s Other — type xkb code (e.g. pl, nl, ru, ch)\n\n' "$UI_YLW" "$UI_R" "$UI_DIM" "$UI_R"
    read -r -p "$(printf '%s▶%s Enter 1–9, o, or press Enter for us [us]: ' "$UI_CYN" "$UI_R")" choice || true
    choice="${choice//[[:space:]]/}"
    choice="${choice,,}"
    case "${choice:-us}" in
      ""|1|us) echo us; return 0 ;;
      2|se) echo se; return 0 ;;
      3|gb|uk) echo gb; return 0 ;;
      4|no) echo no; return 0 ;;
      5|dk) echo dk; return 0 ;;
      6|fi) echo fi; return 0 ;;
      7|de) echo de; return 0 ;;
      8|fr) echo fr; return 0 ;;
      9|es) echo es; return 0 ;;
      o|other)
        read -r -p "$(printf '%s▶%s XKB layout code: ' "$UI_CYN" "$UI_R")" custom || true
        custom="$(apply_keyboard_layout_aliases "$custom")"
        if validate_xkb_layout_string "$custom"; then
          echo "$custom"
          return 0
        fi
        ui_warn "invalid layout — use letters, digits, commas, hyphen (e.g. us,latam)"
        ;;
      *)
        if validate_xkb_layout_string "$choice"; then
          echo "$(apply_keyboard_layout_aliases "$choice")"
          return 0
        fi
        ui_warn "invalid choice — enter 1–9, o, or a valid xkb code"
        ;;
    esac
  done
}

resolve_keyboard_layout() {
  local raw="" out=""
  if [[ -n "$KEYBOARD_LAYOUT_CLI" ]]; then
    raw="$(normalize_keyboard_layout_token "$KEYBOARD_LAYOUT_CLI")"
    raw="$(apply_keyboard_layout_aliases "$raw")"
    if ! validate_xkb_layout_string "$raw"; then
      ui_err "invalid --keyboard-layout (use xkb symbols: us, se, gb, no, or combos like us,ru)"
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
WALLPAPER_DIR_RESOLVED="$(resolve_wallpaper_dir)"
KEYBOARD_LAYOUT_RESOLVED="$(resolve_keyboard_layout)"

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

needs_hypr_dotfiles() {
  [[ "$DO_DNF_HYPR" -eq 1 ]] || rpm_have hyprland
}

any_display_manager_pkg() {
  rpm_have sddm || rpm_have lightdm || rpm_have gdm || rpm_have ly
}

list_installed_display_managers() {
  local parts=()
  rpm_have sddm && parts+=("sddm")
  rpm_have lightdm && parts+=("lightdm")
  rpm_have gdm && parts+=("gdm")
  rpm_have ly && parts+=("ly")
  (IFS=' '; echo "${parts[*]}")
}

normalize_dm_id() {
  case "${1,,}" in
    sddm) echo sddm ;;
    lightdm) echo lightdm ;;
    gdm) echo gdm ;;
    ly) echo ly ;;
    *) return 1 ;;
  esac
}

normalize_compositor_id() {
  case "${1,,}" in
    sway) echo sway ;;
    hyprland|hypr) echo hyprland ;;
    *) return 1 ;;
  esac
}

prompt_compositor_install() {
  local choice=""
  while true; do
    printf '\n%s▶ %sCompositor%s\n' "$UI_MAG" "$UI_BLD" "$UI_R"
    printf '%s%s%s\n' "$UI_DIM" "$(printf '─%.0s' {1..58})" "$UI_R"
    printf '%s No %ssway%s or %shyprland%s package is installed yet.%s\n' "$UI_DIM" "$UI_BLD" "$UI_DIM" "$UI_BLD" "$UI_DIM" "$UI_R"
    printf '%s Pick one to install with dnf:%s\n\n' "$UI_R" "$UI_R"
    printf '   %s1)%s sway       %s·%s i3-like tiling; this repo’s keybinds & theme target Sway\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %s2)%s hyprland   %s·%s Hyprland + xdg-desktop-portal-hyprland\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    read -r -p "$(printf '%s▶%s Enter 1 or 2 [1]: ' "$UI_CYN" "$UI_R")" choice || true
    choice="${choice//[[:space:]]/}"
    case "${choice:-1}" in
      1|sway) echo sway; return 0 ;;
      2|hyprland|hypr) echo hyprland; return 0 ;;
    esac
    ui_warn "invalid choice — enter 1 (sway) or 2 (hyprland)"
  done
}

choose_compositor_if_needed() {
  DO_DNF_SWAY=0
  DO_DNF_HYPR=0
  CHOSEN_SESSION="sway"

  local has_s=0 has_h=0
  if rpm_have sway; then has_s=1; fi
  if rpm_have hyprland; then has_h=1; fi

  if [[ "$has_s" -eq 1 && "$has_h" -eq 1 ]]; then
    ui_ok "compositor packages: Sway and Hyprland already installed"
    CHOSEN_SESSION=sway
    return 0
  fi
  if [[ "$has_s" -eq 1 ]]; then
    ui_ok "Sway package present"
    CHOSEN_SESSION=sway
    return 0
  fi
  if [[ "$has_h" -eq 1 ]]; then
    ui_ok "Hyprland package present"
    CHOSEN_SESSION=hyprland
    return 0
  fi

  ui_info "no sway or hyprland package detected"
  if [[ "$INSTALL_PKGS" -eq 0 ]]; then
    if [[ -n "$COMPOSITOR_CLI" ]]; then
      ui_err "--compositor cannot be used with --no-packages"
      exit 1
    fi
    ui_warn "install sway or hyprland yourself, or re-run without --no-packages"
    return 0
  fi
  if [[ -n "$COMPOSITOR_CLI" ]]; then
    if ! CHOSEN_SESSION="$(normalize_compositor_id "$COMPOSITOR_CLI")"; then
      ui_err "invalid --compositor (use sway or hyprland)"
      exit 1
    fi
    if ! command -v dnf >/dev/null 2>&1; then
      ui_err "--compositor requires dnf (not found in PATH)"
      exit 1
    fi
    if [[ "$CHOSEN_SESSION" == "sway" ]]; then
      DO_DNF_SWAY=1
    else
      DO_DNF_HYPR=1
    fi
    return 0
  fi
  if ! command -v dnf >/dev/null 2>&1; then
    ui_warn "dnf not found — install sway or hyprland with your package manager"
    return 0
  fi

  local pick=""
  if [[ "$DRY_RUN" -eq 1 ]]; then
    pick=sway
  elif [[ -t 0 ]]; then
    pick="$(prompt_compositor_install)"
  else
    ui_warn "non-interactive session — defaulting to sway (pass --compositor hyprland if needed)"
    pick=sway
  fi
  CHOSEN_SESSION="$pick"
  if [[ "$pick" == "sway" ]]; then
    DO_DNF_SWAY=1
  else
    DO_DNF_HYPR=1
  fi
}

build_system_pkgs_array() {
  SYSTEM_PKGS=(
    dnf-plugins-core
    waybar wlogout
    kitty fuzzel btop
    grim slurp wl-clipboard
    python3-gobject gtk3 gettext
    google-noto-sans-mono-vf-fonts fontawesome-6-free-fonts fontawesome-6-brands-fonts
  )
  # Sway: compositor + lock/idle/wallpaper helpers, wlroots portal, systemd session glue, shared Wayland session bits.
  local -a sway_pkgs=(
    sway
    swaylock
    swayidle
    swaybg
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk
    polkit-gnome
    qt6-qtwayland
    wireplumber
    sway-systemd
  )
  if [[ "$DO_DNF_SWAY" -eq 1 ]]; then
    SYSTEM_PKGS+=("${sway_pkgs[@]}")
  elif [[ "$CHOSEN_SESSION" == "sway" ]]; then
    # Sway RPM already present; still ensure lock, portals, polkit, PipeWire session, etc.
    SYSTEM_PKGS+=("${sway_pkgs[@]:1}")
  fi
  # Hyprland: compositor + Wayland session basics (portals, polkit prompts, Qt on Wayland).
  local -a hypr_pkgs=(
    hyprland
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    polkit-gnome
    qt6-qtwayland
    wireplumber
  )
  if [[ "$DO_DNF_HYPR" -eq 1 ]]; then
    SYSTEM_PKGS+=("${hypr_pkgs[@]}")
  elif [[ "$CHOSEN_SESSION" == "hyprland" ]]; then
    # Already had Hyprland RPM; still ensure session packages are present.
    SYSTEM_PKGS+=("${hypr_pkgs[@]:1}")
  fi
}

prompt_display_manager() {
  local choice=""
  while true; do
    printf '\n%s▶ %sDisplay manager%s\n' "$UI_MAG" "$UI_BLD" "$UI_R"
    printf '%s%s%s\n' "$UI_DIM" "$(printf '─%.0s' {1..58})" "$UI_R"
    printf '%s No package found for sddm, lightdm, gdm, or ly.%s\n' "$UI_DIM" "$UI_R"
    printf '%s Pick one to install and enable for graphical login:%s\n\n' "$UI_R" "$UI_R"
    printf '   %s1)%s sddm      %s·%s Wayland / Plasma-style setups\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %s2)%s lightdm   %s·%s GTK greeter, lightweight\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %s3)%s gdm       %s·%s GNOME display manager\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %s4)%s ly        %s·%s TUI (may be missing from Fedora repos)\n' "$UI_CYN" "$UI_R" "$UI_DIM" "$UI_R"
    printf '   %sq)%s skip      %s·%s do not install now\n\n' "$UI_YLW" "$UI_R" "$UI_DIM" "$UI_R"
    read -r -p "$(printf '%s▶%s Enter 1–4 or q [q]: ' "$UI_CYN" "$UI_R")" choice || true
    choice="${choice//[[:space:]]/}"
    case "$choice" in
      1|sddm) echo sddm; return 0 ;;
      2|lightdm) echo lightdm; return 0 ;;
      3|gdm) echo gdm; return 0 ;;
      4|ly) echo ly; return 0 ;;
      ""|q|Q|skip) return 1 ;;
    esac
    ui_warn "invalid choice — enter 1–4 or q"
  done
}

choose_display_manager_if_needed() {
  CHOSEN_DM=""
  [[ "$SKIP_DISPLAY_MANAGER" -eq 1 ]] && return 0
  if any_display_manager_pkg; then
    ui_ok "display manager already installed ($(list_installed_display_managers))"
    return 0
  fi
  ui_info "no display manager package among: sddm, lightdm, gdm, ly"
  if [[ "$INSTALL_PKGS" -eq 0 ]]; then
    if [[ -n "$DISPLAY_MANAGER_CLI" ]]; then
      ui_err "--display-manager cannot be used with --no-packages"
      exit 1
    fi
    ui_warn "with --no-packages, install one yourself (e.g. sudo dnf install sddm && sudo systemctl enable sddm)"
    return 0
  fi
  local picked=""
  if [[ -n "$DISPLAY_MANAGER_CLI" ]]; then
    if ! picked="$(normalize_dm_id "$DISPLAY_MANAGER_CLI")"; then
      ui_err "invalid --display-manager (use sddm, lightdm, gdm, or ly)"
      exit 1
    fi
    if ! command -v dnf >/dev/null 2>&1; then
      ui_err "--display-manager requires dnf (not found in PATH)"
      exit 1
    fi
    CHOSEN_DM="$picked"
    return 0
  fi
  if ! command -v dnf >/dev/null 2>&1; then
    ui_warn "dnf not found — install a display manager with your package manager and enable its service"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    ui_warn "non-interactive session — skipping display manager (use --display-manager NAME or --skip-display-manager)"
    return 0
  fi
  if picked="$(prompt_display_manager)"; then
    CHOSEN_DM="$picked"
  else
    ui_info "skipping display manager install"
  fi
}

dm_dnf_package_list() {
  case "$1" in
    sddm) echo sddm ;;
    lightdm) echo lightdm lightdm-gtk ;;
    gdm) echo gdm ;;
    ly) echo ly ;;
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
  run sudo systemctl disable gdm.service sddm.service lightdm.service ly.service 2>/dev/null || true
  run sudo systemctl enable "$svc"
  run sudo systemctl set-default graphical.target 2>/dev/null || true
  ui_ok "enabled $svc (reboot or start the service for graphical login)"
}

install_chosen_display_manager() {
  [[ -z "$CHOSEN_DM" ]] && return 0
  [[ "$INSTALL_PKGS" -eq 0 ]] && return 0
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

ensure_lgl_system_loadout() {
  [[ "$INSTALL_PKGS" -eq 0 ]] && return 0
  command -v dnf >/dev/null 2>&1 || return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry-run]%s would: sudo dnf copr enable -y linuxgamerlife/lgl-system-loadout\n' "$UI_YLW" "$UI_R"
    printf '%s[dry-run]%s would: sudo dnf install -y lgl-system-loadout\n' "$UI_YLW" "$UI_R"
    return 0
  fi
  ui_section "COPR: lgl-system-loadout"
  printf '%s · %senabling linuxgamerlife/lgl-system-loadout…%s\n' "$UI_CYN" "$UI_DIM" "$UI_R"
  run sudo dnf copr enable -y linuxgamerlife/lgl-system-loadout
  printf '%s · %sinstalling lgl-system-loadout…%s\n' "$UI_CYN" "$UI_DIM" "$UI_R"
  run sudo dnf install -y lgl-system-loadout
  ui_ok "lgl-system-loadout installed"
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

choose_compositor_if_needed

choose_display_manager_if_needed

ui_section "Paths"
ui_info "config → $CONFIG"
ui_info "wallpapers → $WALLPAPER_DIR_RESOLVED"
ui_info "keyboard (xkb) → $KEYBOARD_LAYOUT_RESOLVED"
ui_info "compositor → $CHOSEN_SESSION (packages as detected or selected)"

build_system_pkgs_array
if [[ "$INSTALL_PKGS" -eq 1 && "$DRY_RUN" -eq 0 ]] && command -v dnf >/dev/null 2>&1; then
  ui_section "System packages"
  printf '%s · %sInstalling dependencies with dnf (use --no-packages to skip)…%s\n' "$UI_CYN" "$UI_DIM" "$UI_R"
  run sudo dnf install -y "${SYSTEM_PKGS[@]}" || true
  if [[ "$CHOSEN_SESSION" == "sway" ]] || rpm_have sway; then
    printf '\n%s · optional: pip install --user autotiling · wallpaper picker deps are covered by dnf above%s\n' "$UI_DIM" "$UI_R"
  fi
elif [[ "$INSTALL_PKGS" -eq 1 && "$DRY_RUN" -eq 1 ]] && command -v dnf >/dev/null 2>&1; then
  ui_section "System packages"
  printf '%s[dry-run]%s would: sudo dnf install -y %s\n' "$UI_YLW" "$UI_R" "${SYSTEM_PKGS[*]}"
  if [[ "$CHOSEN_SESSION" == "sway" ]] || [[ "$DO_DNF_SWAY" -eq 1 ]]; then
    printf '%s · optional (Sway): pip install --user autotiling%s\n' "$UI_DIM" "$UI_R"
  fi
else
  if [[ "$INSTALL_PKGS" -eq 1 ]]; then
    ui_warn "dnf not found — install: sway or hyprland, waybar, wlogout, kitty, fuzzel, btop, grim, slurp, wl-clipboard, python3-gobject, gtk3, gettext, fonts"
  fi
fi

ensure_pavucontrol

ensure_lgl_system_loadout

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
    if [[ -f "$hypr_f" ]] || needs_hypr_dotfiles; then
      printf '%s[dry-run]%s would set kb_layout = %s in %s\n' "$UI_YLW" "$UI_R" "$layout" "$hypr_f"
    fi
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
      sed -i "s#^[[:space:]]*kb_layout[[:space:]]*=.*#    kb_layout = $layout#" "$hypr_f"
      ui_ok "keyboard layout → $layout ($hypr_f)"
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

if [[ "$DRY_RUN" -eq 0 ]]; then
  run mkdir -p "$WALLPAPER_DIR_RESOLVED"
fi

ui_section "Dotfiles"
for name in sway waybar wlogout kitty fuzzel; do
  dest="$CONFIG/$name"
  if [[ -e "$dest" ]]; then
    backup_if_exists "$dest"
  fi
done
if needs_hypr_dotfiles; then
  if [[ -e "$CONFIG/hypr" ]]; then
    backup_if_exists "$CONFIG/hypr"
  fi
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  run cp -a "$SCRIPT_DIR/sway" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/waybar" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/wlogout" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/kitty" "$CONFIG/"
  run cp -a "$SCRIPT_DIR/fuzzel" "$CONFIG/"
  if needs_hypr_dotfiles; then
    run cp -a "$SCRIPT_DIR/hypr" "$CONFIG/"
  fi
else
  cp -a "$SCRIPT_DIR/sway" "$CONFIG/"
  cp -a "$SCRIPT_DIR/waybar" "$CONFIG/"
  cp -a "$SCRIPT_DIR/wlogout" "$CONFIG/"
  cp -a "$SCRIPT_DIR/kitty" "$CONFIG/"
  cp -a "$SCRIPT_DIR/fuzzel" "$CONFIG/"
  if needs_hypr_dotfiles; then
    cp -a "$SCRIPT_DIR/hypr" "$CONFIG/"
    ui_ok "installed sway, waybar, wlogout, kitty, fuzzel, hypr (Hyprland: Waybar exec-once) → $CONFIG"
  else
    ui_ok "installed sway, waybar, wlogout, kitty, fuzzel → $CONFIG"
  fi
fi

write_keyboard_layout_configs "$KEYBOARD_LAYOUT_RESOLVED"

# Executable scripts
if [[ "$DRY_RUN" -eq 0 ]]; then
  while IFS= read -r -d '' f; do
    chmod +x "$f"
  done < <(find "$CONFIG/sway" "$CONFIG/waybar" -type f \( -name '*.sh' -o -name 'wallpaper-picker.py' \) -print0 2>/dev/null || true)
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

ui_footer
